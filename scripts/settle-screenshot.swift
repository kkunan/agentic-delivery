#!/usr/bin/env swift

import Foundation
import CoreGraphics
import ImageIO

struct Options {
    var capture: String?
    var out = "screenshot.png"
    var interval = 0.4
    var attempts = 12
    var tolerance = 0.001
}

struct Frame {
    let bytes: [UInt8]
    let width: Int
    let height: Int
}

struct Difference {
    let changed: Int
    let total: Int
    var fraction: Double { total == 0 ? 1 : Double(changed) / Double(total) }
    let minX: Int, minY: Int, maxX: Int, maxY: Int
    var boxDescription: String {
        changed == 0 ? "none" : "\(maxX - minX + 1)x\(maxY - minY + 1) at (\(minX),\(minY))"
    }
}

let usage = """
usage: settle-screenshot.swift --capture '<command>' [--out <path.png>]
                               [--interval <seconds>] [--attempts <n>]
                               [--tolerance <fraction>]

Runs the capture command repeatedly until two consecutive frames match, then
writes the settled frame to --out. The command runs with /bin/sh -c. Every {out}
in it is replaced with the path the command must write a PNG to.

example: --capture 'xcrun simctl io <device-id> screenshot {out}'

exit 0  settled, --out written
exit 1  never settled within --attempts; --out holds the last frame and
        stderr names what kept moving
exit 2  usage or capture error
"""

let scratch = FileManager.default.temporaryDirectory
    .appendingPathComponent("settle-\(ProcessInfo.processInfo.processIdentifier)")

func leave(_ code: Int32) -> Never {
    try? FileManager.default.removeItem(at: scratch)
    exit(code)
}

func fail(_ message: String, code: Int32 = 2) -> Never {
    FileHandle.standardError.write(Data("settle-screenshot: \(message)\n".utf8))
    leave(code)
}

func parseOptions() -> Options {
    var o = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    while let flag = args.first {
        args.removeFirst()
        func value(_ name: String) -> String {
            guard let v = args.first else { fail("\(name) needs a value") }
            args.removeFirst()
            return v
        }
        switch flag {
        case "--capture": o.capture = value(flag)
        case "--out": o.out = value(flag)
        case "--interval": o.interval = Double(value(flag)) ?? o.interval
        case "--attempts": o.attempts = Int(value(flag)) ?? o.attempts
        case "--tolerance": o.tolerance = Double(value(flag)) ?? o.tolerance
        case "--help", "-h":
            print(usage)
            leave(0)
        default: fail("unknown option \(flag)")
        }
    }
    return o
}

func shellQuote(_ text: String) -> String {
    "'" + text.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

func capture(command: String, to path: String) {
    try? FileManager.default.removeItem(atPath: path)
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/sh")
    p.arguments = ["-c", command.replacingOccurrences(of: "{out}", with: shellQuote(path))]
    let errPath = scratch.appendingPathComponent("capture-stderr.txt").path
    FileManager.default.createFile(atPath: errPath, contents: nil)
    p.standardError = FileHandle(forWritingAtPath: errPath)
    p.standardOutput = FileHandle.nullDevice
    do { try p.run() } catch { fail("could not run the capture command: \(error.localizedDescription)") }
    p.waitUntilExit()
    let text = String(decoding: FileManager.default.contents(atPath: errPath) ?? Data(), as: UTF8.self)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    guard p.terminationStatus == 0 else {
        fail("the capture command exited \(p.terminationStatus): \(text)")
    }
    guard FileManager.default.fileExists(atPath: path) else {
        fail("the capture command wrote no file at \(path): \(text)")
    }
}

func load(_ path: String) -> Frame {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fail("could not decode \(path)")
    }
    let w = image.width, h = image.height
    var bytes = [UInt8](repeating: 0, count: w * h * 4)
    guard let context = CGContext(data: &bytes, width: w, height: h,
                                  bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fail("could not build a bitmap context for \(path)")
    }
    context.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
    return Frame(bytes: bytes, width: w, height: h)
}

func compare(_ a: Frame, _ b: Frame) -> Difference {
    guard a.width == b.width, a.height == b.height else {
        return Difference(changed: a.width * a.height, total: a.width * a.height,
                          minX: 0, minY: 0, maxX: a.width - 1, maxY: a.height - 1)
    }
    var changed = 0
    var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
    for y in 0..<a.height {
        let row = y * a.width * 4
        for x in 0..<a.width {
            let i = row + x * 4
            if a.bytes[i] != b.bytes[i] || a.bytes[i + 1] != b.bytes[i + 1]
                || a.bytes[i + 2] != b.bytes[i + 2] {
                changed += 1
                if x < minX { minX = x }
                if x > maxX { maxX = x }
                if y < minY { minY = y }
                if y > maxY { maxY = y }
            }
        }
    }
    if changed == 0 { return Difference(changed: 0, total: a.width * a.height, minX: 0, minY: 0, maxX: 0, maxY: 0) }
    return Difference(changed: changed, total: a.width * a.height,
                      minX: minX, minY: minY, maxX: maxX, maxY: maxY)
}

let options = parseOptions()
guard let command = options.capture else {
    FileHandle.standardError.write(Data("settle-screenshot: --capture is required\n\(usage)\n".utf8))
    leave(2)
}
try? FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)

let probe = scratch.appendingPathComponent("probe.png").path
capture(command: command, to: options.out)
var previous = load(options.out)
var last: Difference?

for attempt in 1...options.attempts {
    Thread.sleep(forTimeInterval: options.interval)
    capture(command: command, to: probe)
    let current = load(probe)
    let d = compare(previous, current)
    last = d
    try? FileManager.default.removeItem(at: URL(fileURLWithPath: options.out))
    try? FileManager.default.copyItem(atPath: probe, toPath: options.out)
    if d.changed == 0 {
        print("settled after \(attempt) comparison(s), identical; wrote \(options.out)")
        leave(0)
    }
    if d.fraction <= options.tolerance {
        let pct = String(format: "%.4f", d.fraction * 100)
        print("settled after \(attempt) comparison(s), \(d.changed) px differ (\(pct)%, within tolerance, moving region \(d.boxDescription)); wrote \(options.out)")
        leave(0)
    }
    previous = current
}

let d = last!
let pct = String(format: "%.3f", d.fraction * 100)
FileHandle.standardError.write(Data("""
settle-screenshot: never settled after \(options.attempts) comparisons at \(options.interval)s.
  still moving: \(d.changed) px (\(pct)%), region \(d.boxDescription)
  \(options.out) holds the last frame.
  A tall narrow region is usually a text caret: dismiss the keyboard, or raise --tolerance.
  A large region means the screen is still animating or loading: raise --attempts.

""".utf8))
leave(1)
