#!/usr/bin/env bash
set -u

here=$(cd "$(dirname "$0")" && pwd -P)
{ echo CALL; printf 'ARG %s\n' "$@"; } >> "$SELFTEST_CALL_LOG"
if IFS= read -r line; then
    printf 'STDIN %s\n' "$line" >> "$SELFTEST_CALL_LOG"
fi

if [ $# -lt 5 ] || [ "$1" != --out ] || [ "$3" != --log ] || [ "$5" != -- ]; then
    echo "fake runner: expected --out <file> --log <file> -- <test-id>..., got: $*" >&2
    exit 64
fi
result=$2
log=$4
shift 5
ids=("$@")
echo "fake runner: $# test id(s)" > "$log"

has() {
    grep -rqF --exclude-dir=.git -- "$1" .
}

baseline_effects() {
    case "$(basename "$result")" in baseline-*) ;; *) return ;; esac
    if has SELFTEST_GROW; then
        grep -rlF --exclude-dir=.git -- SELFTEST_GROW . | while IFS= read -r f; do echo "let again = 88" >> "$f"; done
    fi
    if has SELFTEST_PLANT_K1; then
        echo '{"compiled": true, "tests": []}' > "$(dirname "$result")/mutant-k1.json"
    fi
    if has SELFTEST_REWRITE_LIST; then
        /usr/bin/python3 -B -c '
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
for e in data:
    if e["label"] == "k1":
        e["file"] = "Sources/L.swift"
with open(path, "w") as f:
    json.dump(data, f)
' "$SELFTEST_LIST"
    fi
}

side_effects() {
    baseline_effects
    if has SELFTEST_STUBBORN; then
        trap '' TERM
        sleep 30
    fi
    if has SELFTEST_CORRUPT; then
        echo corrupt > "$(git rev-parse --absolute-git-dir)/mutate-in-progress/original"
    fi
    if has SELFTEST_CHMOD; then
        grep -rlF --exclude-dir=.git -- SELFTEST_CHMOD . | while IFS= read -r f; do chmod +x "$f"; done
    fi
    if has SELFTEST_SLEEP; then
        ( while :; do echo tick >> "$SELFTEST_TICKS"; sleep 0.2; done ) &
        sleep 30
    fi
}

outcome() {
    local marker
    for marker in ERR_NOFILE ERR_JSON ERR_SHAPE NOCOMPILE_STALE NOCOMPILE KILL BASELINE_RED NORUN SKIPPED; do
        has "SELFTEST_$marker" && { echo "$marker"; return; }
    done
    echo PASS
}

known() {
    local id suffix=""
    has SELFTEST_RENAME_FOOBAR && suffix="Bar"
    for id in ${ids[@]+"${ids[@]}"}; do
        case "$id" in
            *doesNotExist*) ;;
            suite/*/*/*) ;;
            suite/*/*) printf '%s\n' "$id$suffix" ;;
        esac
    done
}

side_effects
outcome=$(outcome)
kept=()
while IFS= read -r id; do
    [ -n "$id" ] && kept+=("$id")
done < <(known)
case "$outcome" in
    ERR_*|NOCOMPILE*) ;;
    *) [ "${#kept[@]}" -gt 0 ] || outcome=NORUN ;;
esac
other=0
has SELFTEST_OTHER_FAILS && other=1
case "$outcome" in
    ERR_NOFILE) exit 1 ;;
    ERR_JSON) name=bad-json ;;
    ERR_SHAPE) name=bad-shape ;;
    NOCOMPILE_STALE) name=nocompile-stale ;;
    NOCOMPILE) name=nocompile ;;
    KILL|BASELINE_RED) name=killed ;;
    NORUN) name=norun ;;
    SKIPPED) name=skipped ;;
    PASS) name=pass ;;
esac
/usr/bin/python3 -B "$here/emit.py" "$name" "$here/fixtures" "$result" "$other" ${kept[@]+"${kept[@]}"} || exit 70
case "$outcome" in
    NOCOMPILE*|KILL|BASELINE_RED) exit 1 ;;
esac
exit 0
