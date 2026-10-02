#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/lib.sh"
script="$here/../scripts/settle-screenshot.swift"
red="$here/fixtures/frame-red.png"
blue="$here/fixtures/frame-blue.png"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
rc=0

run() {
    rc=0
    swift "$script" "$@" > "$tmp/stdout" 2> "$tmp/stderr" || rc=$?
}

# ── A steady screen settles ───────────────────────────────────────────────
odd="$tmp/it's here"
mkdir -p "$odd"
run --capture "cp '$red' {out}" --out "$odd/shot.png" --interval 0.05 --attempts 3
check "steady: exit 0" 0 "$rc"
check "steady: frame written to a path with a quote" yes "$([ -s "$odd/shot.png" ] && echo yes || echo no)"
check "steady: frame is the captured one" yes "$(cmp -s "$red" "$odd/shot.png" && echo yes || echo no)"

# ── A screen that never stops changing ────────────────────────────────────
counter="$tmp/counter"
echo 0 > "$counter"
flip="n=\$(cat '$counter'); echo \$((n + 1)) > '$counter'; if [ \$((n % 2)) = 0 ]; then cp '$red' {out}; else cp '$blue' {out}; fi"
run --capture "$flip" --out "$tmp/moving.png" --interval 0.05 --attempts 3
check "moving: exit 1" 1 "$rc"
check "moving: stderr names the region" yes "$(grep -q 'region 8x8 at (0,0)' "$tmp/stderr" && echo yes || echo no)"
check "moving: last frame kept" yes "$([ -s "$tmp/moving.png" ] && echo yes || echo no)"

# ── A capture that writes nothing is never a success ──────────────────────
run --capture "true" --out "$tmp/none.png" --interval 0.05 --attempts 2
check "writes nothing: exit 2" 2 "$rc"
check "writes nothing: stderr says no file" yes "$(grep -q 'wrote no file' "$tmp/stderr" && echo yes || echo no)"

# ── A capture that fails reports its stderr ───────────────────────────────
run --capture "echo device offline >&2; exit 3" --out "$tmp/fail.png" --interval 0.05 --attempts 2
check "fails: exit 2" 2 "$rc"
check "fails: stderr passes the command message on" yes "$(grep -q 'device offline' "$tmp/stderr" && echo yes || echo no)"

# ── No capture command ────────────────────────────────────────────────────
run --out "$tmp/x.png"
check "no capture: exit 2" 2 "$rc"
check "no capture: usage printed" yes "$(grep -q 'usage: settle-screenshot.swift --capture' "$tmp/stderr" && echo yes || echo no)"

finish
