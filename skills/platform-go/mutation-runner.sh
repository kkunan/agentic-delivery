#!/bin/bash
set -u

usage='usage: mutation-runner.sh --out <result.json> --log <log> -- <package>::<test name>...'

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
        *) say "REFUSED: the test id '$id' has no '::'. The form is <package>::<test name>"; exit 2 ;;
    esac
    if [ -z "${id%%::*}" ] || [ -z "${id#*::}" ]; then
        say "REFUSED: the test id '$id' needs a package before '::' and a test name after it"
        exit 2
    fi
    case "$seen" in *$'\n'"$id"$'\n'*) continue ;; esac
    seen="$seen$id"$'\n'
    ids+=("$id")
done
[ "${#ids[@]}" -gt 0 ] || { say "REFUSED: no test id"; printf '%s\n' "$usage" >&2; exit 2; }

# ── The Go command ────────────────────────────────────────────────────────

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

if [ -n "${GO_BIN:-}" ]; then
    go_command=$(printf '%q' "$GO_BIN")
else
    go_command=$(config_value go_command)
    [ -n "$go_command" ] || go_command=go
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/mutation-runner.XXXXXX") || { say "cannot create a work folder"; exit 2; }
trap 'rm -rf "$work"' EXIT

# ── Running the tests ─────────────────────────────────────────────────────

anchor='import re, sys; print("/".join("^" + re.escape(p) + "$" for p in sys.argv[1].split("/")))'
records=()
n=0
for id in "${ids[@]}"; do
    n=$((n + 1))
    pkg=${id%%::*}
    pattern=$(python3 -c "$anchor" "${id#*::}")
    say "$go_command test -json -count=1 -run $pattern $pkg"
    (cd "$top" && bash -c "$go_command"' "$@"' go-command test -json -count=1 -run "$pattern" "$pkg") > "$work/$n.jsonl" 2>> "$log" < /dev/null
    records+=("$id" "$work/$n.jsonl" "$?")
done

# ── The result file ───────────────────────────────────────────────────────

convert='
import json, sys
out, args = sys.argv[1], sys.argv[2:]
results = {"pass": "passed", "fail": "failed", "skip": "skipped"}
compiled = True
tests = []
for i in range(0, len(args), 3):
    tid, path, code = args[i], args[i + 1], int(args[i + 2])
    name = tid.split("::", 1)[1]
    events = []
    for line in open(path):
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if isinstance(event, dict):
            events.append(event)
    if any(e.get("Action") == "build-fail" or e.get("FailedBuild") for e in events):
        compiled = False
        continue
    if code != 0 and not any(e.get("Test") for e in events):
        print("no test event and no build failure for %s, exit %d" % (tid, code))
        sys.exit(3)
    for e in events:
        if e.get("Test") == name and e.get("Action") in results:
            tests.append({"id": tid, "result": results[e["Action"]]})
json.dump({"compiled": compiled, "tests": tests}, open(out, "w"))
'
python3 -c "$convert" "$out" "${records[@]}" >> "$log" 2>&1
status=$?
[ "$status" -eq 0 ] || say "no result file, exit $status. Read the log $log"
exit "$status"
