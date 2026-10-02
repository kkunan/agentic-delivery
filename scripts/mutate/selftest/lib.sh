UDID=AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA
OWNER_UDID=BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB
T_A=AppTests/ATests/testA
T_B=AppTests/ATests/testB
A_SWIFT=$'let threshold = 88\nlet other = 1\nlet word = "aaa"\n'

# ── A throwaway repository per case ───────────────────────────────────────

new_repo() {
    case_dir=$(mktemp -d "${TMPDIR:-/tmp}/mutate-selftest.XXXXXX") || return 1
    case_dir=$(cd "$case_dir" && pwd -P)
    repo="$case_dir/repo"
    out="$case_dir/out"
    mkdir -p "$repo/App.xcworkspace" "$repo/Sources"
    printf '%s' "$A_SWIFT" > "$repo/Sources/A.swift"
    git -C "$repo" init -q
    commit_all init
    export SELFTEST_CALL_LOG="$case_dir/calls.log" SELFTEST_TICKS="$case_dir/ticks" SELFTEST_LIST="$case_dir/list.json"
    : > "$SELFTEST_CALL_LOG"
}

commit_all() {
    git -C "$repo" add -A
    git -C "$repo" -c user.name=selftest -c user.email=selftest@example.invalid commit -q -m "$1"
}

cleanup_case() {
    pkill -KILL -f "$case_dir" 2>/dev/null
    chmod -R u+rw "$case_dir" 2>/dev/null
    rm -rf "$case_dir"
}

mklist() {
    /usr/bin/python3 -B -c '
import json, sys
a = sys.argv[1:]
keys = ("label", "file", "find", "replace", "test")
print(json.dumps([dict(zip(keys, a[i:i + 5])) for i in range(0, len(a), 5)]))
' "$@" > "$case_dir/list.json"
}

# ── Running the runner ────────────────────────────────────────────────────

run_args() {
    ( cd "$repo" && MUTATE_XCODEBUILD="$selftest_dir/fake-xcodebuild.sh" \
        MUTATE_XCRESULTTOOL="$selftest_dir/fake-xcresulttool.sh" \
        "$RUNNER_DIR/mutate.sh" "$@" ) > "$case_dir/stdout" 2> "$case_dir/stderr"
    rc=$?
}

run_runner() {
    run_args --manifest "$case_dir/list.json" --udid "$UDID" --out "$out" "$@"
}

start_runner_bg() {
    cd "$repo" || return 1
    set -m
    env MUTATE_XCODEBUILD="$selftest_dir/fake-xcodebuild.sh" \
        MUTATE_XCRESULTTOOL="$selftest_dir/fake-xcresulttool.sh" \
        "$RUNNER_DIR/mutate.sh" --manifest "$case_dir/list.json" --udid "$UDID" --out "$out" \
        > "$case_dir/stdout" 2> "$case_dir/stderr" &
    runner=$!
    set +m
    cd - > /dev/null
}

wait_for() {
    local limit=$1 n=0
    shift
    until "$@"; do
        n=$((n + 1))
        [ "$n" -ge "$limit" ] && return 1
        sleep 0.1
    done
}

# ── Assertions ────────────────────────────────────────────────────────────

say() {
    printf '%s\n' "$*"
    return 1
}

expect_rc() {
    [ "$rc" -eq "$1" ] || say "exit $rc, expected $1. stderr: $(head -c 400 "$case_dir/stderr")"
}

expect_calls() {
    local n
    n=$(grep -c '^CALL$' "$SELFTEST_CALL_LOG")
    [ "$n" -eq "$1" ] || say "$n xcodebuild calls, expected $1"
}

expect_arg() {
    grep -qxF -- "ARG $1" "$SELFTEST_CALL_LOG" || say "no xcodebuild call had the argument $1"
}

expect_out() {
    grep -qF -- "$1" "$case_dir/stdout" || say "stdout lacks: $1. stdout: $(head -c 400 "$case_dir/stdout")"
}

expect_err() {
    grep -qF -- "$1" "$case_dir/stderr" || say "stderr lacks: $1. stderr: $(head -c 400 "$case_dir/stderr")"
}

expect_no_traceback() {
    ! grep -q Traceback "$case_dir/stderr" || say "a Python traceback reached stderr"
}

expect_clean() {
    [ -z "$(git -C "$repo" status --porcelain)" ] || say "the tree is not clean: $(git -C "$repo" status --porcelain)"
}

journal_dir() {
    echo "$(git -C "$repo" rev-parse --absolute-git-dir)/mutate-in-progress"
}

expect_no_journal() {
    [ ! -e "$(journal_dir)" ] || say "the journal is still there"
}

expect_file() {
    [ "$(cat "$repo/$1")" = "$(printf '%s' "$2")" ] || say "$1 holds: $(head -c 200 "$repo/$1")"
}

sha_of() {
    shasum -a 256 "$1" | cut -d' ' -f1
}
