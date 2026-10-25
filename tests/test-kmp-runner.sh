#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/lib.sh"
top=$(cd "$here/.." && pwd -P)
runner="$top/skills/platform-kmp/mutation-runner.sh"
fake="$here/fixtures/kmp/fake-gradle.sh"
fixtures="$here/fixtures/kmp"

unset GRADLE_BIN
work=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$work"' EXIT
app="$work/app"
mkdir -p "$app"
git -C "$app" init -q
export FAKE_CALLS="$work/calls"
export FAKE_GRADLE_DIR="$work/gradle"
mkdir -p "$FAKE_GRADLE_DIR"

field() {
    python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2" 2>/dev/null || echo "(no result file)"
}

entries() {
    field "$work/$1.json" 'str(d["compiled"]) + " " + " ".join(t["id"] + "=" + t["result"] for t in d["tests"])'
}

key() {
    printf '%s' "$1" | tr -c 'A-Za-z0-9' '_'
}

fresh() {
    rm -rf "$FAKE_GRADLE_DIR"/* "$app/shared" "$app/server" "$app/feature" "$app/sub" "$app/.claude"
    rm -f "$FAKE_CALLS.pwd" "$FAKE_CALLS.env"
}

report() {
    local task=$1
    shift
    {
        printf '<?xml version="1.0" encoding="UTF-8"?>\n<testsuite name="x" tests="%s">\n' "$#"
        printf '%s\n' "$@"
        printf '</testsuite>\n'
    } > "$FAKE_GRADLE_DIR/$(key "$task").xml"
}

output() {
    printf '%s\n' "$2" > "$FAKE_GRADLE_DIR/$(key "$1").out"
}

exit_code() {
    printf '%s\n' "$2" > "$FAKE_GRADLE_DIR/$(key "$1").rc"
}

run() {
    name=$1
    shift
    rc=0
    : > "$FAKE_CALLS"
    (cd "$app" && GRADLE_BIN="$fake" "$runner" --out "$work/$name.json" --log "$work/$name.log" -- "$@" < /dev/null 2>/dev/null) || rc=$?
}

exists() {
    [ -e "$1" ] && echo yes || echo no
}

# ── Results ───────────────────────────────────────────────────────────────

fresh
report :shared:jvmTest '<testcase name="inside" classname="trip.ClampTest" time="0.1"/>'
run pass :shared:jvmTest::trip.ClampTest.inside
check "pass: exit 0" 0 "$rc"
check "pass: entry" "True :shared:jvmTest::trip.ClampTest.inside=passed" "$(entries pass)"
check "pass: flags" ":shared:jvmTest --tests trip.ClampTest.inside --rerun --console=plain" "$(cat "$FAKE_CALLS")"

fresh
report :shared:jvmTest '<testcase name="inside" classname="trip.ClampTest"><failure message="boom">trace</failure></testcase>'
exit_code :shared:jvmTest 1
run fail :shared:jvmTest::trip.ClampTest.inside
check "fail: exit 0" 0 "$rc"
check "fail: entry" "True :shared:jvmTest::trip.ClampTest.inside=failed" "$(entries fail)"

fresh
report :shared:jvmTest '<testcase name="inside" classname="trip.ClampTest"><error message="boom">trace</error></testcase>'
exit_code :shared:jvmTest 1
run errorel :shared:jvmTest::trip.ClampTest.inside
check "error element: entry" "True :shared:jvmTest::trip.ClampTest.inside=failed" "$(entries errorel)"

fresh
report :shared:jvmTest '<testcase name="inside" classname="trip.ClampTest"><skipped/></testcase>'
run skipped :shared:jvmTest::trip.ClampTest.inside
check "skipped: entry" "True :shared:jvmTest::trip.ClampTest.inside=skipped" "$(entries skipped)"

fresh
report :shared:jvmTest '<testcase name="inside[jvm]" classname="trip.ClampTest"/>'
run suffix :shared:jvmTest::trip.ClampTest.inside
check "target suffix: entry" "True :shared:jvmTest::trip.ClampTest.inside=passed" "$(entries suffix)"

fresh
report :shared:iosSimulatorArm64Test '<testcase name="inside[iosSimulatorArm64]" classname="iosSimulatorArm64Test.trip.ClampTest"/>'
run ios :shared:iosSimulatorArm64Test::trip.ClampTest.inside
check "ios: entry" "True :shared:iosSimulatorArm64Test::trip.ClampTest.inside=passed" "$(entries ios)"

fresh
report :shared:wasmJsBrowserTest '<testcase name="inside[wasmJs, browser, ChromeHeadless155.0.0.0, MacOS10.15.7]" classname="wasmJsBrowserTest.trip.ClampTest"/>'
run wasm :shared:wasmJsBrowserTest::trip.ClampTest.inside
check "wasm: entry" "True :shared:wasmJsBrowserTest::trip.ClampTest.inside=passed" "$(entries wasm)"

fresh
cp "$fixtures/task-name-package.xml" "$FAKE_GRADLE_DIR/$(key :server:test).xml"
run taskpkg :server:test::test.PingTest.ping
check "package named like the task: entry" "True :server:test::test.PingTest.ping=passed" "$(entries taskpkg)"

fresh
report :shared:jvmTest '<testcase name="inside" classname="otherTask.trip.ClampTest"/>'
run otherprefix :shared:jvmTest::trip.ClampTest.inside
check "other prefix: no entry" "True " "$(entries otherprefix)"

fresh
report :shared:jvmTest \
    '<testcase name="inside" classname="trip.ClampTest"/>' \
    '<testcase name="outside" classname="trip.ClampTest"><failure message="x"/></testcase>'
exit_code :shared:jvmTest 1
run two :shared:jvmTest::trip.ClampTest.inside :shared:jvmTest::trip.ClampTest.outside
check "two ids, one task: both entries" "True :shared:jvmTest::trip.ClampTest.inside=passed :shared:jvmTest::trip.ClampTest.outside=failed" "$(entries two)"
check "two ids, one task: one call with two flags" ":shared:jvmTest --tests trip.ClampTest.inside --tests trip.ClampTest.outside --rerun --console=plain" "$(cat "$FAKE_CALLS")"

fresh
report :shared:jvmTest '<testcase name="inside" classname="trip.ClampTest"/>'
report :server:test '<testcase name="ping" classname="srv.PingTest"/>'
run tasks :shared:jvmTest::trip.ClampTest.inside :server:test::srv.PingTest.ping
check "two tasks: two calls" 2 "$(grep -c . "$FAKE_CALLS")"
check "two tasks: both entries" "True :shared:jvmTest::trip.ClampTest.inside=passed :server:test::srv.PingTest.ping=passed" "$(entries tasks)"

fresh
report :shared:jvmTest '<testcase name="inside" classname="trip.ClampTest"/>'
run missing :shared:jvmTest::trip.ClampTest.nothing
check "missing name: exit 0" 0 "$rc"
check "missing name: no entry" "True " "$(entries missing)"

fresh
output :shared:jvmTest 'No tests found for given includes: [trip.ClampTest.inside](--tests filter)'
exit_code :shared:jvmTest 1
run nofound :shared:jvmTest::trip.ClampTest.inside
check "no tests found: exit 0" 0 "$rc"
check "no tests found: no entry" "True " "$(entries nofound)"

# ── Failures ──────────────────────────────────────────────────────────────

fresh
output :shared:jvmTest '> Task :shared:compileKotlinJvm FAILED'
exit_code :shared:jvmTest 1
run broken :shared:jvmTest::trip.ClampTest.inside
check "compile failure: exit 0" 0 "$rc"
check "compile failure: not compiled" "False " "$(entries broken)"

fresh
output :shared:jvmTest 'something went wrong'
exit_code :shared:jvmTest 1
run unknown :shared:jvmTest::trip.ClampTest.inside
check "unknown failure: exit 3" 3 "$rc"
check "unknown failure: no result file" "(no result file)" "$(entries unknown)"

fresh
mkdir -p "$app/shared/build/test-results/jvmTest"
printf '<testsuite><testcase name="inside" classname="trip.ClampTest"/></testsuite>\n' > "$app/shared/build/test-results/jvmTest/TEST-old.xml"
run stale :shared:jvmTest::trip.ClampTest.inside
check "stale report: no entry" "True " "$(entries stale)"
check "stale report: old file removed" no "$(exists "$app/shared/build/test-results/jvmTest/TEST-old.xml")"

fresh
report :feature:trip:jvmTest '<testcase name="c" classname="a.B"/>'
run nested :feature:trip:jvmTest::a.B.c
check "nested module: entry" "True :feature:trip:jvmTest::a.B.c=passed" "$(entries nested)"
check "nested module: report folder" yes "$(exists "$app/feature/trip/build/test-results/jvmTest/TEST-fake.xml")"

fresh
report :shared:jvmTest '<testcase name="inside" classname="trip.ClampTest"/>'
run dup :shared:jvmTest::trip.ClampTest.inside :shared:jvmTest::trip.ClampTest.inside
check "duplicate id: one entry" "True :shared:jvmTest::trip.ClampTest.inside=passed" "$(entries dup)"
check "duplicate id: one flag" ":shared:jvmTest --tests trip.ClampTest.inside --rerun --console=plain" "$(cat "$FAKE_CALLS")"

# ── Refusals ──────────────────────────────────────────────────────────────

fresh
run refused trip.ClampTest.inside
check "refused, no '::': exit 2" 2 "$rc"
check "refused, no '::': log" 1 "$(grep -c '^mutation-runner: REFUSED:' "$work/refused.log")"
check "refused, no '::': no result file" no "$(exists "$work/refused.json")"

run emptypart ::trip.ClampTest.inside
check "refused, empty part: exit 2" 2 "$rc"

run emptyname :shared:jvmTest::
check "refused, empty filter: exit 2" 2 "$rc"

run badpath ':../x:jvmTest::a.B.c'
check "refused, bad task path: exit 2" 2 "$rc"

# ── The command from the project file ─────────────────────────────────────

fresh
mkdir -p "$app/.claude"
report :shared:jvmTest '<testcase name="inside" classname="trip.ClampTest"/>'
printf -- '---\ngradle_command: "%s"\n---\n' "$fake" > "$app/.claude/agentic-delivery.md"
rc=0
: > "$FAKE_CALLS"
(cd "$app" && "$runner" --out "$work/config.json" --log "$work/config.log" -- :shared:jvmTest::trip.ClampTest.inside < /dev/null 2>/dev/null) || rc=$?
check "project file command: exit 0" 0 "$rc"
check "project file command: entry" "True :shared:jvmTest::trip.ClampTest.inside=passed" "$(entries config)"

fresh
mkdir -p "$app/.claude"
report :shared:jvmTest '<testcase name="inside" classname="trip.ClampTest"/>'
printf -- '---\ngradle_command: env FAKE_FLAG=1 %s\n---\n' "$fake" > "$app/.claude/agentic-delivery.md"
rc=0
: > "$FAKE_CALLS"
(cd "$app" && "$runner" --out "$work/spaced.json" --log "$work/spaced.log" -- :shared:jvmTest::trip.ClampTest.inside < /dev/null 2>/dev/null) || rc=$?
check "command with a space: exit 0" 0 "$rc"
check "command with a space: entry" "True :shared:jvmTest::trip.ClampTest.inside=passed" "$(entries spaced)"
check "command with a space: the prefix ran" 1 "$(cat "$FAKE_CALLS.env" 2>/dev/null)"

# ── The working folder ────────────────────────────────────────────────────

fresh
report :shared:jvmTest '<testcase name="inside" classname="trip.ClampTest"/>'
mkdir -p "$app/sub"
: > "$FAKE_CALLS"
rc=0
(cd "$app/sub" && GRADLE_BIN="$fake" "$runner" --out "$work/sub.json" --log "$work/sub.log" -- :shared:jvmTest::trip.ClampTest.inside < /dev/null 2>/dev/null) || rc=$?
check "working folder: exit 0" 0 "$rc"
check "working folder: gradle runs at the top" "$app" "$(cat "$FAKE_CALLS.pwd")"
check "working folder: entry" "True :shared:jvmTest::trip.ClampTest.inside=passed" "$(entries sub)"

finish
