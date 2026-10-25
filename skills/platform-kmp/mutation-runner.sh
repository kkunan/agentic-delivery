#!/bin/bash
set -u

usage='usage: mutation-runner.sh --out <result.json> --log <log> -- <Gradle test task path>::<class>.<method>...'

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

: > "$log" || { printf 'mutation-runner: cannot write the log %s\n' "$log" >&2; exit 2; }
rm -f "$out" || { say "cannot remove the old result file $out"; exit 2; }

ids=()
tasks=()
seen=$'\n'
seen_tasks=$'\n'
for id in "$@"; do
    case "$id" in
        *::*) ;;
        *) say "REFUSED: the test id '$id' has no '::'. The form is <Gradle test task path>::<class>.<method>"; exit 2 ;;
    esac
    task=${id%%::*}
    if [ -z "$task" ] || [ -z "${id#*::}" ]; then
        say "REFUSED: the test id '$id' needs a task path before '::' and a test filter after it"
        exit 2
    fi
    if ! printf '%s' "$task" | grep -Eq '^:?[A-Za-z0-9_-][A-Za-z0-9_.-]*(:[A-Za-z0-9_-][A-Za-z0-9_.-]*)*$'; then
        say "REFUSED: '$task' is not a Gradle task path such as :shared:jvmTest"
        exit 2
    fi
    case "$seen" in *$'\n'"$id"$'\n'*) continue ;; esac
    seen="$seen$id"$'\n'
    ids+=("$id")
    case "$seen_tasks" in *$'\n'"$task"$'\n'*) ;; *) seen_tasks="$seen_tasks$task"$'\n'; tasks+=("$task") ;; esac
done
[ "${#ids[@]}" -gt 0 ] || { say "REFUSED: no test id"; printf '%s\n' "$usage" >&2; exit 2; }

# ── The Gradle command ────────────────────────────────────────────────────

top=$(git rev-parse --show-toplevel 2>/dev/null) || { say "REFUSED: the current folder is not in a git repository"; exit 2; }

config_value() {
    local file
    file="$top/.claude/agentic-delivery.md"
    [ -f "$file" ] || return 0
    awk -v k="$1" '
        NR == 1 && $0 != "---" { exit }
        NR > 1 && $0 == "---" { exit }
        NR > 1 {
            i = index($0, ":")
            if (i > 0 && substr($0, 1, i - 1) == k) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); print v; exit }
        }' "$file"
}

if [ -n "${GRADLE_BIN:-}" ]; then
    gradle_command=$(printf '%q' "$GRADLE_BIN")
else
    gradle_command=$(config_value gradle_command)
    [ -n "$gradle_command" ] || gradle_command=./gradlew
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/mutation-runner.XXXXXX") || { say "cannot create a work folder"; exit 2; }
trap 'rm -rf "$work"' EXIT

# ── Running the tests ─────────────────────────────────────────────────────

printf '%s\n' "${ids[@]}" > "$work/ids"
records=()
n=0
for task in "${tasks[@]}"; do
    n=$((n + 1))
    path=${task#:}
    module=.
    case "$path" in *:*) module=$(printf '%s' "${path%:*}" | tr : /) ;; esac
    rm -rf "${top:?}/$module/build/test-results/${path##*:}"
    args=()
    for id in "${ids[@]}"; do
        [ "${id%%::*}" = "$task" ] && args+=(--tests "${id#*::}")
    done
    say "$gradle_command $task ${args[*]} --rerun --console=plain"
    (cd "$top" && bash -c "$gradle_command"' "$@"' gradle-command "$task" "${args[@]}" --rerun --console=plain) > "$work/$n.out" 2>&1 < /dev/null
    code=$?
    cat "$work/$n.out" >> "$log"
    records+=("$task" "$top/$module/build/test-results/${path##*:}" "$work/$n.out" "$code")
done

# ── The result file ───────────────────────────────────────────────────────

convert='
import glob, json, os, re, sys
import xml.etree.ElementTree as ET
out, ids_path, args = sys.argv[1], sys.argv[2], sys.argv[3:]
ids = [line.rstrip("\n") for line in open(ids_path)]
compile_failed = re.compile(r"^> Task :([^ :]+:)*compile[^ :]*Kotlin[^ :]* FAILED", re.M)
compiled = True
tests = []
for i in range(0, len(args), 4):
    task, folder, output, code = args[i], args[i + 1], args[i + 2], int(args[i + 3])
    text = open(output, errors="replace").read()
    if compile_failed.search(text):
        compiled = False
        continue
    cases = []
    for path in sorted(glob.glob(os.path.join(folder, "TEST-*.xml"))):
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError:
            continue
        for case in root.iter("testcase"):
            children = [c.tag for c in case]
            if "failure" in children or "error" in children:
                result = "failed"
            elif "skipped" in children:
                result = "skipped"
            else:
                result = "passed"
            full = case.get("classname", "") + "." + case.get("name", "")
            cases.append((full, re.sub(r"\[[^\[\]]*\]$", "", full), result))
    if code != 0 and not cases and "No tests found for given includes" not in text:
        print("no report, no compile failure and no missing-test line for %s, exit %d" % (task, code))
        sys.exit(3)
    for tid in ids:
        if tid.split("::", 1)[0] != task:
            continue
        flt = tid.split("::", 1)[1]
        for full, bare, result in cases:
            if flt in (full, bare):
                tests.append({"id": tid, "result": result})
json.dump({"compiled": compiled, "tests": tests}, open(out, "w"))
'
python3 -c "$convert" "$out" "$work/ids" "${records[@]}" >> "$log" 2>&1
status=$?
[ "$status" -eq 0 ] || say "no result file, exit $status. Read the log $log"
exit "$status"
