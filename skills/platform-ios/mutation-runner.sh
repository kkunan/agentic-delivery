#!/bin/bash
set -u

usage='usage: mutation-runner.sh --out <result.json> --log <log> -- <test target>/<test class>[/<test method>]...'
xcodebuild=${XCODEBUILD_BIN:-xcodebuild}

# ── Arguments ─────────────────────────────────────────────────────────────

if [ $# -lt 5 ] || [ "$1" != --out ] || [ "$3" != --log ] || [ "$5" != -- ]; then
    printf '%s\n' "$usage" >&2
    exit 2
fi
out=$2
log=$4
shift 5

say() {
    printf 'mutation-runner: %s\n' "$*" >> "$log"
    printf 'mutation-runner: %s\n' "$*" >&2
}

refuse() {
    say "REFUSED: $*"
    exit 2
}

: > "$log" || { printf 'mutation-runner: cannot write the log %s\n' "$log" >&2; exit 2; }
rm -f "$out" || { say "cannot remove the old result file $out"; exit 2; }

case "$out" in
    *.json) bundle="${out%.json}.xcresult" ;;
    *) bundle="$out.xcresult" ;;
esac

# ── The project file ──────────────────────────────────────────────────────

top=$(git rev-parse --show-toplevel 2>/dev/null) || refuse "the current directory is not in a git repository"
project_file="$top/.claude/agentic-delivery.md"
[ -f "$project_file" ] || refuse "no project file at $project_file"

key() {
    awk -v k="$1" '
        NR == 1 && $0 != "---" { exit }
        NR > 1 && $0 == "---" { exit }
        NR > 1 {
            i = index($0, ":")
            if (i > 0 && substr($0, 1, i - 1) == k) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v); print v; exit }
        }' "$project_file"
}

workspace=$(key ios_workspace)
scheme=$(key ios_scheme)
plan=$(key ios_test_plan)
[ -n "$workspace" ] || refuse "ios_workspace is empty in $project_file"
[ -n "$scheme" ] || refuse "ios_scheme is empty in $project_file"
case "$workspace" in
    /*) ;;
    *) workspace="$top/$workspace" ;;
esac
case "$workspace" in
    *.xcworkspace) open=(-workspace "$workspace") ;;
    *.xcodeproj) open=(-project "$workspace") ;;
    *) refuse "ios_workspace must end in .xcworkspace or .xcodeproj: $workspace" ;;
esac

# ── The environment ───────────────────────────────────────────────────────

device=${AGENTIC_TEST_DEVICE:-}
derived=${AGENTIC_DERIVED_DATA:-}
[ -n "$device" ] || refuse "set AGENTIC_TEST_DEVICE to the id of the simulator that the run claimed"
[ -n "$derived" ] || refuse "set AGENTIC_DERIVED_DATA to a derived data folder for the mutation runs, outside the ledger folder"
[ -e "$bundle" ] && refuse "the result bundle $bundle already exists; delete it by hand to run again"

# ── The test ids ──────────────────────────────────────────────────────────

ids=()
seen=$'\n'
for id in "$@"; do
    IFS=/ read -r -a parts <<< "$id"
    good=yes
    [ "${#parts[@]}" -eq 2 ] || [ "${#parts[@]}" -eq 3 ] || good=no
    case "$id" in /*|*/|*//*|*[[:space:]]*|*[[:cntrl:]]*|'') good=no ;; esac
    [ "$good" = yes ] || refuse "the test id '$id' is not <test target>/<test class> or <test target>/<test class>/<test method>"
    case "$seen" in *$'\n'"$id"$'\n'*) continue ;; esac
    seen="$seen$id"$'\n'
    ids+=("$id")
done
[ "${#ids[@]}" -gt 0 ] || { say "REFUSED: no test id"; printf '%s\n' "$usage" >&2; exit 2; }

# ── Running the tests ─────────────────────────────────────────────────────

args=(test "${open[@]}" -scheme "$scheme"
    -destination "platform=iOS Simulator,id=$device"
    -derivedDataPath "$derived" -resultBundlePath "$bundle"
    -parallel-testing-enabled NO -collect-test-diagnostics never
    -test-timeouts-enabled YES -default-test-execution-time-allowance 30)
[ -n "$plan" ] && args+=(-testPlan "$plan")
[ -n "${AGENTIC_CONFIGURATION:-}" ] && args+=(-configuration "$AGENTIC_CONFIGURATION")
for id in "${ids[@]}"; do args+=("-only-testing:$id"); done

say "running ${#ids[@]} test id(s) on $device"
"$xcodebuild" "${args[@]}" >> "$log" 2>&1 < /dev/null
code=$?
say "xcodebuild exit $code"

# ── The result file ───────────────────────────────────────────────────────

convert=$(cat <<'EOF'
import json, os, subprocess, sys

PREFIX = "test://com.apple.xcode/"
RESULTS = {"Passed": "passed", "Failed": "failed", "Skipped": "skipped"}
out, bundle, code, tool = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
ids = sys.argv[5:]


def stop(message):
    sys.stderr.write(message + "\n")
    sys.exit(3)


def get(*what):
    cmd = ([tool] if tool else ["xcrun", "xcresulttool"]) + ["get", *what, "--path", bundle]
    p = subprocess.run(cmd, capture_output=True)
    if p.returncode != 0:
        stop("xcresulttool get %s exited %d" % (" ".join(what), p.returncode))
    try:
        return json.loads(p.stdout)
    except ValueError:
        stop("xcresulttool get %s printed invalid JSON" % " ".join(what))


def write(compiled, tests):
    tmp = out + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump({"compiled": compiled, "tests": tests}, f)
        f.write("\n")
    os.replace(tmp, out)


def index(node, found):
    url = node.get("nodeIdentifierURL", "")
    if url.startswith(PREFIX):
        parts = url[len(PREFIX):].split("/", 1)
        if len(parts) == 2:
            found.setdefault(parts[1], []).append(node)
    for child in node.get("children", []):
        index(child, found)


def cases(node):
    here = [node] if node.get("nodeType") == "Test Case" else []
    return here + [c for child in node.get("children", []) for c in cases(child)]


def built():
    build = get("build-results")
    status, errors = build.get("status"), build.get("errorCount")
    if status == "failed" and type(errors) is int and errors >= 1:
        if code != 65:
            stop("the build failed with %d errors, but xcodebuild exited %d" % (errors, code))
        return False
    if status != "succeeded" or errors != 0:
        stop("the build is %r with %r errors, which is neither a build nor a compile failure" % (status, errors))
    return True


def entries():
    found = {}
    for node in get("test-results", "tests").get("testNodes", []):
        index(node, found)
    tests = []
    for test_id in ids:
        for case in [c for node in found.get(test_id, []) for c in cases(node)]:
            result = RESULTS.get(case.get("result"))
            if result is None:
                stop("%s has a test case with the result %r, which the contract has no word for" % (test_id, case.get("result")))
            tests.append({"id": test_id, "result": result})
    return tests


if code not in (0, 65):
    stop("xcodebuild exited %d, so the run did not finish" % code)
if not os.path.isdir(bundle):
    stop("xcodebuild wrote no result bundle at %s" % bundle)
if not built():
    write(False, [])
    sys.exit(0)
tests = entries()
failed = any(t["result"] == "failed" for t in tests)
if code == 0 and failed:
    stop("xcodebuild exited 0, but a named test failed")
if code == 65 and not failed:
    stop("xcodebuild exited 65, but the build succeeded and no named test failed")
write(True, tests)
EOF
)

python3 -c "$convert" "$out" "$bundle" "$code" "${XCRESULTTOOL_BIN:-}" "${ids[@]}" >> "$log" 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
    say "no result file: the conversion stopped with exit $rc"
    exit 3
fi
say "wrote $out"
exit 0
