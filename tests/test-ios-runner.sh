#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/lib.sh"
top=$(cd "$here/.." && pwd -P)
runner="$top/skills/platform-ios/mutation-runner.sh"
mutate="$top/scripts/mutate.sh"
fakes="$here/fixtures/ios"

work=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$work"' EXIT
app="$work/app"
export FAKE_CALLS="$work/calls"
export XCODEBUILD_BIN="$fakes/fake-xcodebuild.sh"
export XCRESULTTOOL_BIN="$fakes/fake-xcresulttool.py"
export AGENTIC_TEST_DEVICE=11111111-2222-3333-4444-555555555555
export AGENTIC_DERIVED_DATA="$work/DerivedData"
unset AGENTIC_CONFIGURATION

field() {
    python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2" 2>/dev/null || echo "(no result file)"
}

run() {
    name=$1
    shift
    rc=0
    : > "$FAKE_CALLS"
    (cd "$app" && "$runner" --out "$work/$name.json" --log "$work/$name.log" -- "$@" < /dev/null 2>/dev/null) || rc=$?
}

entries() {
    field "$work/$1.json" 'str(d["compiled"]) + " " + " ".join(t["id"] + "=" + t["result"] for t in d["tests"])'
}

exists() {
    [ -e "$1" ] && echo yes || echo no
}

logged() {
    grep -qF -- "$2" "$work/$1.log" && echo yes || echo no
}

called() {
    grep -qxF -- "ARG $1" "$FAKE_CALLS" && echo yes || echo no
}

pair() {
    grep -A1 -xF -- "ARG $1" "$FAKE_CALLS" | grep -qxF -- "ARG $2" && echo yes || echo no
}

project() {
    printf -- '---\nplatform: ios\n%s\n---\n# notes\nios_scheme: wrong\n' "$1" > "$app/.claude/agentic-delivery.md"
}

marker() {
    printf 'let marker = "%s"\n' "$1" > "$app/Sources/Marker.swift"
}

# ── A scratch project ─────────────────────────────────────────────────────

mkdir -p "$app/.claude" "$app/Sources"
project $'ios_workspace: App.xcworkspace\nios_scheme: App'
printf 'func add(_ a: Int, _ b: Int) -> Int { a + b }\n' > "$app/Sources/Calc.swift"
marker none
(cd "$app" && git init -q . && git add -A && git -c user.name=check -c user.email=check@example.invalid -c commit.gpgsign=false commit -qm app)
check "git commit of the project" 0 $?

# ── Direct calls ──────────────────────────────────────────────────────────

run pass AppTests/CalcTests/testAdd
check "pass: exit 0" 0 "$rc"
check "pass: one entry, passed" "True AppTests/CalcTests/testAdd=passed" "$(entries pass)"
check "pass: the bundle sits beside the result file" yes "$(exists "$work/pass.xcresult")"
check "pass: -workspace from the top of the repository" yes "$(pair -workspace "$app/App.xcworkspace")"
check "pass: -scheme from the front matter" yes "$(pair -scheme App)"
check "pass: the device id in the destination" yes "$(pair -destination "platform=iOS Simulator,id=$AGENTIC_TEST_DEVICE")"
check "pass: -derivedDataPath" yes "$(pair -derivedDataPath "$AGENTIC_DERIVED_DATA")"
check "pass: -resultBundlePath" yes "$(pair -resultBundlePath "$work/pass.xcresult")"
check "pass: test timeouts on" yes "$(pair -test-timeouts-enabled YES)"
check "pass: no diagnostics collection" yes "$(pair -collect-test-diagnostics never)"
check "pass: -only-testing" yes "$(called -only-testing:AppTests/CalcTests/testAdd)"
check "pass: parallel testing off" yes "$(pair -parallel-testing-enabled NO)"
check "pass: no -testPlan without the key" no "$(called -testPlan)"
check "pass: no -configuration without the variable" no "$(called -configuration)"

run two AppTests/CalcTests/testAdd AppTests/OtherTests/testSub AppTests/CalcTests/testAdd
check "two ids: a repeated id runs once" 2 "$(grep -c '^ARG -only-testing:' "$FAKE_CALLS")"
check "two ids: both passed" "True AppTests/CalcTests/testAdd=passed AppTests/OtherTests/testSub=passed" "$(entries two)"

run class AppTests/CalcTests
check "class id: one entry for each test case" "True AppTests/CalcTests=passed AppTests/CalcTests=passed" "$(entries class)"

run absent AppTests/CalcTests/testDoesNotExist
check "absent name: exit 0" 0 "$rc"
check "absent name: no entry" "True " "$(entries absent)"

project $'ios_workspace: App.xcodeproj\nios_scheme: App\nios_test_plan: App'
AGENTIC_CONFIGURATION=UITest run plan AppTests/CalcTests/testAdd
check "xcodeproj: -project" yes "$(pair -project "$app/App.xcodeproj")"
check "xcodeproj: no -workspace" no "$(called -workspace)"
check "test plan key: -testPlan" yes "$(pair -testPlan App)"
check "AGENTIC_CONFIGURATION: -configuration" yes "$(pair -configuration UITest)"
project $'ios_workspace: App.xcworkspace\nios_scheme: App'

# ── Outcomes ──────────────────────────────────────────────────────────────

outcome() {
    marker "MARK_$1"
    run "$2" AppTests/CalcTests/testAdd
}

outcome KILL killed
check "killed: exit 0" 0 "$rc"
check "killed: failed" "True AppTests/CalcTests/testAdd=failed" "$(entries killed)"

outcome NOCOMPILE nocompile
check "compile failure: exit 0" 0 "$rc"
check "compile failure: compiled false, no entry" "False " "$(entries nocompile)"

outcome SKIP skipped
check "skipped: skipped" "True AppTests/CalcTests/testAdd=skipped" "$(entries skipped)"

for case in EXPECTED:expected:'which the contract has no word for' \
    EXIT70:exit70:'xcodebuild exited 70' \
    NOBUNDLE:nobundle:'wrote no result bundle' \
    NOCOMPILE_EXIT0:nocompile0:'but xcodebuild exited 0' \
    BUILD_ODD:buildodd:'neither a build nor a compile failure' \
    EXIT0_FAILED:exit0failed:'exited 0, but a named test failed' \
    EXIT65_PASSED:exit65passed:'exited 65, but the build succeeded' \
    TOOL_FAIL:toolfail:'xcresulttool get build-results exited 1' \
    BAD_JSON:badjson:'printed invalid JSON'; do
    IFS=: read -r mark name why <<< "$case"
    outcome "$mark" "$name"
    check "$name: exit 3" 3 "$rc"
    check "$name: no result file" no "$(exists "$work/$name.json")"
    check "$name: the log says why" yes "$(logged "$name" "$why")"
done
marker none

# ── Refusals ──────────────────────────────────────────────────────────────

refused() {
    check "$1: exit 2" 2 "$rc"
    check "$1: no result file" no "$(exists "$work/$2.json")"
    check "$1: xcodebuild not called" 0 "$(grep -c CALL "$FAKE_CALLS")"
    check "$1: the log says why" yes "$(logged "$2" "$3")"
}

AGENTIC_TEST_DEVICE= run nodevice AppTests/CalcTests/testAdd
refused "no device" nodevice "set AGENTIC_TEST_DEVICE"

AGENTIC_DERIVED_DATA= run noderived AppTests/CalcTests/testAdd
refused "no derived data" noderived "set AGENTIC_DERIVED_DATA"

for case in onepart:AppTests fourparts:AppTests/A/B/C emptypart:AppTests//testAdd trailing:AppTests/CalcTests/ space:'AppTests/Calc Tests/testAdd'; do
    name=${case%%:*}
    run "$name" "${case#*:}"
    refused "test id $name" "$name" "is not <test target>/<test class>"
done

run noid
check "no test id: exit 2" 2 "$rc"

project 'ios_workspace: App.xcworkspace'
run noscheme AppTests/CalcTests/testAdd
refused "no ios_scheme" noscheme "ios_scheme is empty"

project $'ios_workspace: App\nios_scheme: App'
run badworkspace AppTests/CalcTests/testAdd
refused "a workspace without its extension" badworkspace "must end in .xcworkspace or .xcodeproj"

rm "$app/.claude/agentic-delivery.md"
run noproject AppTests/CalcTests/testAdd
refused "no project file" noproject "no project file"
(cd "$app" && git checkout -q -- .claude/agentic-delivery.md)

mkdir "$work/old.xcresult"
touch "$work/old.xcresult/keep"
run old AppTests/CalcTests/testAdd
refused "an old bundle" old "already exists"
check "an old bundle: left in place" yes "$(exists "$work/old.xcresult/keep")"

rc=0
(cd "$app" && "$runner" --out "$work/usage.json" -- AppTests/CalcTests/testAdd < /dev/null > /dev/null 2>&1) || rc=$?
check "usage error: exit 2" 2 "$rc"

# ── Through mutate.sh ─────────────────────────────────────────────────────

cat > "$work/list.json" <<'EOF'
[
 {"label": "survives", "file": "Sources/Calc.swift", "find": "a + b", "replace": "b + a", "test": "AppTests/CalcTests/testAdd"},
 {"label": "killed", "file": "Sources/Marker.swift", "find": "none", "replace": "MARK_KILL", "test": "AppTests/CalcTests/testAdd"},
 {"label": "nocompile", "file": "Sources/Marker.swift", "find": "none", "replace": "MARK_NOCOMPILE", "test": "AppTests/CalcTests/testAdd"},
 {"label": "absent", "file": "Sources/Calc.swift", "find": "a + b", "replace": "a - b", "test": "AppTests/CalcTests/testDoesNotExist"},
 {"label": "unfinished", "file": "Sources/Marker.swift", "find": "none", "replace": "MARK_EXIT70", "test": "AppTests/CalcTests/testAdd"}
]
EOF
rc=0
(cd "$app" && "$mutate" --runner "$runner" --manifest "$work/list.json" --out "$work/mutate" > "$work/mutate.out" 2> "$work/mutate.err") || rc=$?
check "mutate: exit 2, the baseline refuses the absent test" 2 "$rc"
check "mutate: the refusal names it" yes "$(grep -qF 'AppTests/CalcTests/testDoesNotExist: no test ran' "$work/mutate.err" && echo yes || echo no)"

python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); json.dump([e for e in d if e["label"] != "absent"], open(sys.argv[1], "w"))' "$work/list.json"
rc=0
(cd "$app" && "$mutate" --runner "$runner" --manifest "$work/list.json" --out "$work/mutate2" > "$work/mutate.out" 2> "$work/mutate.err") || rc=$?
check "mutate: exit 1" 1 "$rc"
check "mutate: verdicts" "survived survives
killed killed
did-not-compile nocompile
error unfinished" "$(awk 'NR >= 2 && NR <= 5 { print $1, $2 }' "$work/mutate.out")"
check "mutate: tree clean" "" "$(cd "$app" && git status --porcelain)"

finish
