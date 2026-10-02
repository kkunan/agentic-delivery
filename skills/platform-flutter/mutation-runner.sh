#!/bin/bash
set -u

usage='usage: mutation-runner.sh --out <result.json> --log <log> -- <test file>::<full test name>...'
flutter=${FLUTTER_BIN:-flutter}

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
        *) say "REFUSED: the test id '$id' has no '::'. The form is <test file>::<full test name>"; exit 2 ;;
    esac
    file=${id%%::*}
    name=${id#*::}
    if [ -z "$file" ] || [ -z "$name" ]; then
        say "REFUSED: the test id '$id' needs a test file before '::' and a test name after it"
        exit 2
    fi
    case "$file" in
        test/*|./test/*) ;;
        *)
            if [ -z "${AGENTIC_TEST_DEVICE:-}" ]; then
                say "REFUSED: the test file $file is outside test/, so it runs on a device. Set AGENTIC_TEST_DEVICE to the id of the device of this run"
                exit 2
            fi
            ;;
    esac
    case "$seen" in *$'\n'"$id"$'\n'*) continue ;; esac
    seen="$seen$id"$'\n'
    ids+=("$id")
done
[ "${#ids[@]}" -gt 0 ] || { say "REFUSED: no test id"; printf '%s\n' "$usage" >&2; exit 2; }

work=$(mktemp -d "${TMPDIR:-/tmp}/mutation-runner.XXXXXX") || { say "cannot create a work folder"; exit 2; }
trap 'rm -rf "$work"' EXIT

# ── Running the tests ─────────────────────────────────────────────────────

records=()
n=0
for id in "${ids[@]}"; do
    file=${id%%::*}
    name=${id#*::}
    n=$((n + 1))
    if [ ! -f "$file" ]; then
        say "the test file $file does not exist, so $id is absent"
        records+=("$id" "$file" "$name" "-")
        continue
    fi
    report="$work/$n.json"
    device=()
    case "$file" in
        test/*|./test/*) ;;
        *) device=(-d "$AGENTIC_TEST_DEVICE") ;;
    esac
    say "running $id"
    "$flutter" test "$file" ${device[@]+"${device[@]}"} "--plain-name=$name" --reporter expanded "--file-reporter" "json:$report" >> "$log" 2>&1 < /dev/null
    say "flutter test exit $? for $id"
    records+=("$id" "$file" "$name" "$report")
done

# ── The result file ───────────────────────────────────────────────────────

convert=$(cat <<'EOF'
import json, os, sys

out = sys.argv[1]
args = sys.argv[2:]
compiled = True
tests = []
for i in range(0, len(args), 4):
    test_id, test_file, name, report = args[i:i + 4]
    if report == "-":
        continue
    try:
        with open(report, encoding="utf-8") as f:
            events = [json.loads(line) for line in f if line.strip()]
    except (OSError, ValueError) as e:
        sys.stderr.write("no readable reporter output for %s: %s\n" % (test_id, e))
        sys.exit(3)
    if not any(e.get("type") == "done" for e in events):
        sys.stderr.write("the reporter output for %s has no done event\n" % test_id)
        sys.exit(3)
    want = os.path.realpath(test_file)
    suites = {}
    started = {}
    for e in events:
        kind = e.get("type")
        if kind == "suite":
            suites[e["suite"]["id"]] = os.path.realpath(e["suite"].get("path") or "")
        elif kind == "testStart":
            started[e["test"]["id"]] = e["test"]
        elif kind == "testDone":
            t = started.get(e.get("testID"))
            if t is None:
                continue
            if not t.get("groupIDs"):
                if e.get("result") != "success":
                    compiled = False
                continue
            if e.get("hidden") or t.get("name") != name or suites.get(t.get("suiteID")) != want:
                continue
            if e.get("skipped"):
                result = "skipped"
            elif e.get("result") == "success":
                result = "passed"
            else:
                result = "failed"
            tests.append({"id": test_id, "result": result})
tmp = out + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump({"compiled": compiled, "tests": tests}, f)
    f.write("\n")
os.replace(tmp, out)
EOF
)

python3 -c "$convert" "$out" "${records[@]}" >> "$log" 2>&1
rc=$?
if [ "$rc" -ne 0 ]; then
    say "no result file: the conversion stopped with exit $rc"
    exit 3
fi
say "wrote $out"
exit 0
