#!/bin/bash
set -u

{ echo CALL; printf 'ARG %s\n' "$@"; } >> "$FAKE_CALLS"

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
    grep -rqF --exclude-dir=.git -- "$1" Sources
}

outcome() {
    local marker
    for marker in EXIT70 NOBUNDLE NOCOMPILE_EXIT0 NOCOMPILE BUILD_ODD KILL EXIT0_FAILED EXIT65_PASSED SKIP EXPECTED TOOL_FAIL BAD_JSON; do
        has "MARK_$marker" && { echo "$marker"; return; }
    done
    echo PASS
}

kept() {
    local name
    for name in ${names[@]+"${names[@]}"}; do
        case "$name" in
            *DoesNotExist*) ;;
            AppTests/*) printf '%s\n' "$name" ;;
        esac
    done
}

result=$(outcome)
case "$result" in
    EXIT70) exit 70 ;;
    NOBUNDLE) exit 65 ;;
esac
mkdir -p "$bundle"
printf '%s\n' "$result" > "$bundle/fake-outcome"
kept > "$bundle/fake-names"
case "$result" in
    NOCOMPILE_EXIT0|SKIP|EXPECTED|EXIT0_FAILED|TOOL_FAIL|BAD_JSON) exit 0 ;;
    NOCOMPILE|BUILD_ODD|KILL|EXIT65_PASSED) exit 65 ;;
esac
exit 0
