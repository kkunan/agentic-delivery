#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/lib.sh"
top=$(cd "$here/.." && pwd -P)
runner="$top/skills/platform-go/mutation-runner.sh"
fake="$here/fixtures/go/fake-go.sh"

work=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$work"' EXIT
app="$work/app"
mkdir -p "$app"
git -C "$app" init -q
export FAKE_CALLS="$work/calls"
export FAKE_GO_DIR="$work/go"
mkdir -p "$FAKE_GO_DIR"

field() {
    python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2" 2>/dev/null || echo "(no result file)"
}

entries() {
    field "$work/$1.json" 'str(d["compiled"]) + " " + " ".join(t["id"] + "=" + t["result"] for t in d["tests"])'
}

events() {
    local key
    key=$(printf '%s' "$1" | tr -c 'A-Za-z0-9' '_')
    shift
    printf '%s\n' "$@" > "$FAKE_GO_DIR/$key.jsonl"
}

exit_code() {
    local key
    key=$(printf '%s' "$1" | tr -c 'A-Za-z0-9' '_')
    printf '%s\n' "$2" > "$FAKE_GO_DIR/$key.rc"
}

run() {
    name=$1
    shift
    rc=0
    : > "$FAKE_CALLS"
    (cd "$app" && GO_BIN="$fake" "$runner" --out "$work/$name.json" --log "$work/$name.log" -- "$@" < /dev/null 2>/dev/null) || rc=$?
}

# ── Results ───────────────────────────────────────────────────────────────

events ./a \
    '{"Action":"run","Package":"example.test/a","Test":"TestAdd"}' \
    '{"Action":"pass","Package":"example.test/a","Test":"TestAdd"}' \
    '{"Action":"fail","Package":"example.test/a","Test":"TestSub"}' \
    '{"Action":"skip","Package":"example.test/a","Test":"TestSkip"}' \
    '{"Action":"pass","Package":"example.test/a","Test":"TestClamp/a+b"}' \
    '{"Action":"fail","Package":"example.test/a"}'
exit_code ./a 1

run pass ./a::TestAdd
check "pass: exit 0" 0 "$rc"
check "pass: entry" "True ./a::TestAdd=passed" "$(entries pass)"
check "pass: the call" "test -json -count=1 -run ^TestAdd$ ./a" "$(cat "$FAKE_CALLS")"

run fail ./a::TestSub
check "fail: entry" "True ./a::TestSub=failed" "$(entries fail)"

run skip ./a::TestSkip
check "skip: entry" "True ./a::TestSkip=skipped" "$(entries skip)"

run sub './a::TestClamp/a+b'
check "subtest: entry" "True ./a::TestClamp/a+b=passed" "$(entries sub)"
check "subtest: each part anchored and escaped" 'test -json -count=1 -run ^TestClamp$/^a\+b$ ./a' "$(cat "$FAKE_CALLS")"

run two ./a::TestAdd ./a::TestSub ./a::TestAdd
check "two ids: one call for each distinct id" 2 "$(grep -c . "$FAKE_CALLS")"
check "two ids: both entries" "True ./a::TestAdd=passed ./a::TestSub=failed" "$(entries two)"

run missing ./a::TestMissing
check "no match: exit 0" 0 "$rc"
check "no match: no entry" "True " "$(entries missing)"

mkdir -p "$app/sub"
rc=0
(cd "$app/sub" && GO_BIN="$fake" "$runner" --out "$work/sub.json" --log "$work/sub.log" -- ./a::TestAdd < /dev/null 2>/dev/null) || rc=$?
check "from a subfolder: exit 0" 0 "$rc"
check "from a subfolder: go runs at the top" "$app" "$(cat "$FAKE_CALLS.pwd")"
check "from a subfolder: entry" "True ./a::TestAdd=passed" "$(entries sub)"

outside=$(cd "$(mktemp -d "$work/outside.XXXXXX")" && pwd -P)
rc=0
(cd "$outside" && GO_BIN="$fake" "$runner" --out "$work/outside.json" --log "$work/outside.log" -- ./a::TestAdd < /dev/null 2>/dev/null) || rc=$?
check "outside a git repository: exit 2" 2 "$rc"

# ── Build failure ─────────────────────────────────────────────────────────

events ./b \
    '{"ImportPath":"example.test/b","Action":"build-output","Output":"b.go:3:9: cannot use \"x\"\n"}' \
    '{"ImportPath":"example.test/b","Action":"build-fail"}' \
    '{"Action":"fail","Package":"example.test/b","FailedBuild":"example.test/b"}'
exit_code ./b 1
run broken ./b::TestAdd
check "build failure: exit 0" 0 "$rc"
check "build failure: not compiled" "False " "$(entries broken)"

events ./c '{"Action":"fail","Package":"example.test/c","FailedBuild":"example.test/c"}'
exit_code ./c 1
run broken2 ./c::TestAdd
check "build failure without build-fail: not compiled" "False " "$(entries broken2)"

# ── No result ─────────────────────────────────────────────────────────────

events ./d 'not json'
exit_code ./d 1
run nothing ./d::TestAdd
check "no event and exit 1: exit 3" 3 "$rc"
check "no event and exit 1: no result file" no "$([ -e "$work/nothing.json" ] && echo yes || echo no)"

run refused ./a
check "id without '::': exit 2" 2 "$rc"
check "id without '::': no result file" no "$([ -e "$work/refused.json" ] && echo yes || echo no)"

run empty ./a::
check "id without a test name: exit 2" 2 "$rc"

# ── The command from the project file ─────────────────────────────────────

mkdir -p "$app/.claude"
printf -- '---\ngo_command: FAKE_DIR="$PWD" "%s"\n---\n' "$fake" > "$app/.claude/agentic-delivery.md"
rc=0
: > "$FAKE_CALLS"
(cd "$app" && "$runner" --out "$work/config.json" --log "$work/config.log" -- ./a::TestAdd < /dev/null 2>/dev/null) || rc=$?
check "go_command: exit 0" 0 "$rc"
check "go_command: entry" "True ./a::TestAdd=passed" "$(entries config)"

finish
