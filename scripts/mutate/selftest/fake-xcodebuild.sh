#!/usr/bin/env bash
set -u

{ echo CALL; printf 'ARG %s\n' "$@"; } >> "$SELFTEST_CALL_LOG"

bundle=""
names=()
while [ $# -gt 0 ]; do
    case "$1" in
        -resultBundlePath) bundle=$2; shift 2 ;;
        -only-testing:*) names+=("${1#-only-testing:}"); shift ;;
        *) shift ;;
    esac
done

if [ -e "$bundle" ]; then
    echo "xcodebuild: error: Existing file at -resultBundlePath \"$bundle\""
    exit 64
fi

has() {
    grep -rqF --exclude-dir=.git -- "$1" .
}

baseline_effects() {
    case "$(basename "$bundle")" in baseline-*) ;; *) return ;; esac
    if has SELFTEST_GROW; then
        grep -rlF --exclude-dir=.git -- SELFTEST_GROW . | while IFS= read -r f; do echo "let again = 88" >> "$f"; done
    fi
    if has SELFTEST_PLANT_K1; then
        mkdir -p "$(dirname "$bundle")/mutant-k1.xcresult"
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
    for marker in ERR_EXIT64 ERR_NOBUNDLE65 ERR_BUILD_FAILED_EXIT0 NOCOMPILE KILL BASELINE_RED ERR_EXIT0_FAILED NORUN SKIPPED ERR_TOOL ERR_JSON ERR_FIELD; do
        has "SELFTEST_$marker" && { echo "$marker"; return; }
    done
    echo PASS
}

runnable() {
    local name suffix=""
    has SELFTEST_RENAME_FOOBAR && suffix="Bar"
    for name in ${names[@]+"${names[@]}"}; do
        case "$name" in
            *DoesNotExist*) ;;
            AppTests/*/*/*|AppUITests/*/*/*) ;;
            AppTests/*|AppUITests/*) printf '%s\n' "$name$suffix" ;;
        esac
    done
}

side_effects
result=$(outcome)
kept=$(runnable)
case "$result" in
    ERR_*|NOCOMPILE) ;;
    *) [ -n "$kept" ] || result=NORUN ;;
esac
case "$result" in
    ERR_EXIT64) exit 64 ;;
    ERR_NOBUNDLE65) exit 65 ;;
esac
mkdir -p "$bundle"
case "$result" in
    NOCOMPILE|ERR_BUILD_FAILED_EXIT0) echo nocompile ;;
    KILL|BASELINE_RED) echo killed ;;
    ERR_EXIT0_FAILED) echo killed ;;
    NORUN) echo norun ;;
    SKIPPED) echo skipped ;;
    ERR_TOOL) echo tool-fail ;;
    ERR_JSON) echo bad-json ;;
    ERR_FIELD) echo no-field ;;
    PASS) echo pass ;;
esac > "$bundle/selftest-outcome"
printf '%s\n' "$kept" > "$bundle/selftest-names"
case "$result" in
    NOCOMPILE|KILL|BASELINE_RED) exit 65 ;;
esac
exit 0
