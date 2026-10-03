#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/../lib.sh"
top=$(cd "$here/../.." && pwd -P)
[ $# -eq 1 ] || { echo "usage: tests/ios-xcode/check.sh <empty work folder>" >&2; exit 2; }
command -v xcodegen > /dev/null || { echo "check: xcodegen is not on PATH" >&2; exit 2; }
mkdir -p "$1" && work=$(cd "$1" && pwd -P) || exit 2
app="$work/sample"
ev="$work/evidence"
dd="$work/DerivedData-Debug"
device=""
mkdir -p "$ev"

start=$(date +%s)

say() {
    printf '\n== [%s s] %s\n' "$(($(date +%s) - start))" "$*"
}

step() {
    printf '   [%s s] %s\n' "$(($(date +%s) - start))" "$*"
}

limit() {
    local seconds=$1 pid watch rc
    shift
    "$@" &
    pid=$!
    perl -e 'sleep $ARGV[0]; print STDERR "TIME LIMIT: $ARGV[0] s passed; stopping $ARGV[2]\n"; kill "TERM", $ARGV[1]' "$seconds" "$pid" "$1" &
    watch=$!
    wait "$pid"
    rc=$?
    kill "$watch" 2>/dev/null
    wait "$watch" 2>/dev/null
    return "$rc"
}

yes_no() {
    "$@" > /dev/null 2>&1 && echo yes || echo no
}

json() {
    python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2" 2>/dev/null || echo "(unreadable: $1)"
}

show_logs() {
    local log
    [ "$failed" -eq 0 ] && return
    for log in "$ev"/*.log "$ev"/mutate/*.log "$ev"/*.out "$ev"/*.err; do
        [ -f "$log" ] || continue
        printf '\n-- last 40 lines of %s\n' "${log#"$ev"/}"
        tail -n 40 "$log"
    done
}

cleanup() {
    show_logs
    [ -n "$device" ] || return
    bash "$top/scripts/claim-device.sh" --device "$device" --worktree "$app" --release > /dev/null 2>&1
    xcrun simctl shutdown "$device" > /dev/null 2>&1
    xcrun simctl delete "$device"
}
trap cleanup EXIT

# ── The sample project ────────────────────────────────────────────────────

newest_runtime() {
    xcrun simctl list -j runtimes available | python3 -c '
import json, sys
ios = [r for r in json.load(sys.stdin)["runtimes"] if r.get("platform") == "iOS" and r.get("isAvailable")]
best = max(ios, key=lambda r: [int(p) for p in r["version"].split(".")])
phones = [t for t in best["supportedDeviceTypes"] if t.get("productFamily") == "iPhone"]
print(best["identifier"], phones[-1]["identifier"])' | python3 -c '
import json, subprocess, sys
runtime, fallback = sys.stdin.read().split()
types = json.loads(subprocess.run(["xcrun", "simctl", "list", "-j", "devicetypes"], capture_output=True).stdout)["devicetypes"]
phones = [t for t in types if t.get("productFamily") == "iPhone" and t.get("minRuntimeVersion")]
newest = max(phones, key=lambda t: (t["minRuntimeVersion"], t["identifier"]), default=None)
print(runtime, newest["identifier"] if newest else fallback)'
}

make_project() {
    say "sample project"
    cp -R "$here/sample" "$app"
    mkdir -p "$app/.claude" "$app/scripts"
    cp "$top/skills/platform-ios/mutation-runner.sh" "$app/scripts/mutation-runner.sh"
    printf -- '---\nplatform: ios\nios_workspace: Sample.xcodeproj\nios_scheme: Sample\nios_runtime: %s\ntest_processes: xcodebuild,xctest\nmutation_runner: scripts/mutation-runner.sh\n---\n' "$runtime" > "$app/.claude/agentic-delivery.md"
    (cd "$app" && xcodegen generate --spec project.yml > "$ev/xcodegen.log" 2>&1)
    check "xcodegen generate" 0 $?
    (cd "$app" && git init -q . && git add -A && git -c user.name=check -c user.email=check@example.invalid -c commit.gpgsign=false commit -qm sample)
    check "git commit of the sample" 0 $?
}

key() {
    (cd "$app" && bash "$top/scripts/project-config.sh" "$1")
}

# ── The simulator ─────────────────────────────────────────────────────────

make_device() {
    say "simulator"
    device=$(xcrun simctl create agentic-ios-check "$device_type" "$(key ios_runtime)")
    check "simctl create prints an id" yes "$(yes_no test -n "$device")"
    printf 'runtime %s, device type %s, device %s\n' "$runtime" "$device_type" "$device"
    bash "$top/scripts/claim-device.sh" --device "$device" --worktree "$app" > "$ev/claim.log" 2>&1
    check "claim-device claims the new device" 0 $?
}

# ── The commands of the skill ─────────────────────────────────────────────

xcb() {
    local log=$1
    shift
    step "xcodebuild ${1}, log $log"
    (cd "$app" && limit 900 xcodebuild "$@" < /dev/null > "$ev/$log" 2>&1)
}

skill_commands() {
    local open=(-project "$(key ios_workspace)") scheme dest
    scheme=$(key ios_scheme)
    dest="platform=iOS Simulator,id=$device"
    say "skill: build"
    xcb build.log "${open[@]}" -scheme "$scheme" -destination "$dest" -derivedDataPath "$dd" build
    check "build: exit 0" 0 $?
    say "skill: test"
    xcb test.log test "${open[@]}" -scheme "$scheme" -destination "$dest" -derivedDataPath "$dd" \
        -resultBundlePath "$ev/test.xcresult" \
        -test-timeouts-enabled YES -default-test-execution-time-allowance 30 -collect-test-diagnostics never
    check "test: exit 0" 0 $?
    xcrun xcresulttool get test-results summary --path "$ev/test.xcresult" > "$ev/test-summary.json" 2> "$ev/xcresulttool.err"
    check "test: 3 passed (2 XCTest, 1 Swift Testing), 1 skipped, 0 failed" "3 1 0" "$(json "$ev/test-summary.json" 'd["passedTests"], d["skippedTests"], d["failedTests"]' | tr -d '(),')"
    say "skill: release build"
    xcb release.log "${open[@]}" -scheme "$scheme" -configuration Release -destination "$dest" \
        -derivedDataPath "$work/DerivedData-Release" build
    check "release build: exit 0" 0 $?
}

screenshot() {
    say "skill: install, launch, screenshot"
    step "boot $device"
    limit 300 xcrun simctl bootstatus "$device" -b > "$ev/boot.log" 2>&1
    check "boot" yes "$(yes_no sh -c "xcrun simctl list devices | grep -F '$device' | grep -qF Booted")"
    xcrun simctl install "$device" "$dd/Build/Products/Debug-iphonesimulator/Sample.app" > "$ev/install.log" 2>&1
    check "install from the derived data path" 0 $?
    xcrun simctl launch "$device" dev.agentic.Sample > "$ev/launch.log" 2>&1
    check "launch" 0 $?
    step "settle-screenshot"
    limit 300 "$top/scripts/settle-screenshot.swift" --capture "xcrun simctl io $device screenshot {out}" --out "$ev/screen.png" > "$ev/settle.log" 2>&1
    check "settle-screenshot: settled" 0 $?
}

# ── The mutation runner ───────────────────────────────────────────────────

runner() {
    local name=$1
    shift
    rc=0
    step "runner $name: $*"
    (cd "$app" && AGENTIC_TEST_DEVICE="$device" AGENTIC_DERIVED_DATA="$dd" limit 600 \
        scripts/mutation-runner.sh --out "$ev/$name.json" --log "$ev/$name.log" -- "$@" < /dev/null > /dev/null 2>&1) || rc=$?
}

entries() {
    json "$ev/$1.json" 'str(d["compiled"]) + " " + " ".join(sorted(t["result"] for t in d["tests"]))'
}

runner_calls() {
    say "runner: direct calls"
    runner pass SampleTests/AgeTests/testAdult
    check "pass: exit 0" 0 "$rc"
    check "pass: passed" "True passed" "$(entries pass)"
    runner class SampleTests/AgeTests
    check "class id: one entry for each test case" "True passed passed skipped" "$(entries class)"
    runner skipped SampleTests/AgeTests/testSkipped
    check "skipped: skipped" "True skipped" "$(entries skipped)"
    runner absent SampleTests/AgeTests/testDoesNotExist
    check "misnamed test: xcodebuild exits 0" yes "$(yes_no grep -qF 'xcodebuild exit 0' "$ev/absent.log")"
    check "misnamed test: no entry" "True " "$(entries absent)"
}

node_urls() {
    xcrun xcresulttool get test-results tests --path "$1" 2>/dev/null | python3 -c '
import json, sys
def walk(n):
    if n.get("nodeIdentifierURL"):
        print("     node", n.get("nodeType"), n.get("result"), n["nodeIdentifierURL"])
    for c in n.get("children", []):
        walk(c)
for n in json.load(sys.stdin).get("testNodes", []):
    walk(n)' || echo "     (no test tree)"
}

swift_testing() {
    say "runner: Swift Testing ids"
    runner swift_parens 'SampleTests/AgeSwiftTests/adultAt18()'
    check "Swift Testing, id with (): passed" "True passed" "$(entries swift_parens)"
    node_urls "$ev/swift_parens.xcresult"
    runner swift_bare SampleTests/AgeSwiftTests/adultAt18
    check "Swift Testing, id without (): xcodebuild exits 0" yes "$(yes_no grep -qF 'xcodebuild exit 0' "$ev/swift_bare.log")"
    check "Swift Testing, id without (): no entry" "True " "$(entries swift_bare)"
    runner swift_suite SampleTests/AgeSwiftTests
    check "Swift Testing, suite id: passed" "True passed" "$(entries swift_suite)"
}

mutations() {
    say "runner: through mutate.sh"
    cat > "$work/manifest.json" <<'EOF'
[
 {"label": "survives", "file": "Sources/Age.swift", "find": "age >= 18", "replace": "age > 18", "test": "SampleTests/AgeTests/testAdult"},
 {"label": "killed", "file": "Sources/Age.swift", "find": "age >= 18", "replace": "age > 18", "test": "SampleTests/AgeTests/testAdultAt18"},
 {"label": "nocompile", "file": "Sources/Age.swift", "find": "age >= 18", "replace": "age >= \"18\"", "test": "SampleTests/AgeTests/testAdultAt18"},
 {"label": "swift-killed", "file": "Sources/Age.swift", "find": "age >= 18", "replace": "age > 18", "test": "SampleTests/AgeSwiftTests/adultAt18()"}
]
EOF
    rc=0
    step "mutate.sh, 4 mutations and a baseline"
    (cd "$app" && AGENTIC_TEST_DEVICE="$device" AGENTIC_DERIVED_DATA="$dd" limit 1500 \
        "$top/scripts/mutate.sh" --manifest "$work/manifest.json" --out "$ev/mutate" > "$ev/mutate.out" 2> "$ev/mutate.err") || rc=$?
    cat "$ev/mutate.out"
    check "mutate: exit 1, one survivor" 1 "$rc"
    check "mutate: verdicts" "survived survives
killed killed
did-not-compile nocompile
killed swift-killed" "$(awk 'NR >= 2 && NR <= 5 { print $1, $2 }' "$ev/mutate.out")"
    check "mutate: tree clean" "" "$(cd "$app" && git status --porcelain)"
}

# ── The run ───────────────────────────────────────────────────────────────

xcodebuild -version
xcodegen --version
read -r runtime device_type <<< "$(newest_runtime)"
make_project
make_device
skill_commands
screenshot
runner_calls
swift_testing
mutations
finish
