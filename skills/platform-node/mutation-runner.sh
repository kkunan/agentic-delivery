#!/bin/bash
set -u

usage='usage: mutation-runner.sh --out <result.json> --log <log> -- <spec file>::<full test name>...'

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
seen=$'\n'
for id in "$@"; do
    case "$id" in
        *::*) ;;
        *) say "REFUSED: the test id '$id' has no '::'. The form is <spec file>::<full test name>"; exit 2 ;;
    esac
    if [ -z "${id%%::*}" ] || [ -z "${id#*::}" ]; then
        say "REFUSED: the test id '$id' needs a spec file before '::' and a test name after it"
        exit 2
    fi
    case "$seen" in *$'\n'"$id"$'\n'*) continue ;; esac
    seen="$seen$id"$'\n'
    ids+=("$id")
done
[ "${#ids[@]}" -gt 0 ] || { say "REFUSED: no test id"; printf '%s\n' "$usage" >&2; exit 2; }

top=$(git rev-parse --show-toplevel 2>/dev/null) || { say "REFUSED: the current folder is not in a git repository"; exit 2; }
jest="$top/node_modules/.bin/jest"
[ -x "$jest" ] || { say "REFUSED: $jest is missing. Run npm ci in the worktree first"; exit 2; }

for id in "${ids[@]}"; do
    [ -f "$top/${id%%::*}" ] || { say "REFUSED: the spec file ${id%%::*} does not exist"; exit 2; }
done

config_value() {
    local file
    file="$top/.claude/agentic-delivery.md"
    if [ ! -f "$file" ]; then
        file="$(dirname "$(git -C "$top" rev-parse --path-format=absolute --git-common-dir)")/.claude/agentic-delivery.md"
    fi
    [ -f "$file" ] || return 0
    awk -v k="$1" '
        NR == 1 && $0 != "---" { exit }
        NR > 1 && $0 == "---" { exit }
        NR > 1 {
            i = index($0, ":")
            if (i > 0 && substr($0, 1, i - 1) == k) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); print v; exit }
        }' "$file"
}

config_args=()
jest_config=$(config_value jest_config)
if [ -n "$jest_config" ]; then
    jest_config=${jest_config/#\~/$HOME}
    [ -f "$jest_config" ] || { say "REFUSED: the jest_config file $jest_config does not exist"; exit 2; }
    config_args=(--config "$jest_config")
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/mutation-runner.XXXXXX") || { say "cannot create a work folder"; exit 2; }
trap 'rm -rf "$work"' EXIT

# ── Running the tests, one Jest call for each spec file ───────────────────

files=$(printf '%s\n' "${ids[@]}" | sed 's/::.*//' | sort -u)
pattern='
import re, sys
names = sys.argv[1:]
print("^(" + "|".join(re.escape(n) for n in names) + ")$")
'
records=()
n=0
while IFS= read -r file; do
    n=$((n + 1))
    names=()
    for id in "${ids[@]}"; do
        [ "${id%%::*}" = "$file" ] && names+=("${id#*::}")
    done
    regex=$(python3 -c "$pattern" "${names[@]}")
    say "jest --runTestsByPath $file -t $regex"
    (cd "$top" && "$jest" ${config_args[@]+"${config_args[@]}"} --ci --coverage=false --reporters=default --json --outputFile="$work/$n.json" \
        --runTestsByPath "$file" -t "$regex") >> "$log" 2>&1 < /dev/null
    records+=("$file" "$work/$n.json" "$?")
done <<< "$files"

# ── The result file ───────────────────────────────────────────────────────

convert='
import json, os, sys
out, top, wanted, args = sys.argv[1], sys.argv[2], set(sys.argv[3].split("\n")), sys.argv[4:]
results = {"passed": "passed", "failed": "failed", "pending": "skipped", "skipped": "skipped", "todo": "skipped", "disabled": "skipped"}
compiled = True
tests = []
for i in range(0, len(args), 3):
    file, path, code = args[i], args[i + 1], int(args[i + 2])
    if not os.path.exists(path):
        print("no Jest report for %s, exit %d" % (file, code))
        sys.exit(3)
    report = json.load(open(path))
    for suite in report.get("testResults", []):
        if suite.get("testExecError") or (suite.get("status") == "failed" and not suite.get("assertionResults")):
            compiled = False
            continue
        rel = os.path.relpath(suite["name"], top)
        for a in suite.get("assertionResults", []):
            tid = rel + "::" + a["fullName"]
            if tid in wanted and a["status"] in results:
                tests.append({"id": tid, "result": results[a["status"]]})
json.dump({"compiled": compiled, "tests": tests}, open(out, "w"))
'
python3 -c "$convert" "$out" "$(cd "$top" && pwd -P)" "$(printf '%s\n' "${ids[@]}")" "${records[@]}" >> "$log" 2>&1
status=$?
[ "$status" -eq 0 ] || say "no result file, exit $status. Read the log $log"
exit "$status"
