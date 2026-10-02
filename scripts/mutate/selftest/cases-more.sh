# ── Row 11: the lock ──────────────────────────────────────────────────────

r11_live_lock() {
    local lock
    lock="$(git -C "$repo" rev-parse --absolute-git-dir)/mutate.lock"
    mkdir "$lock" && echo $$ > "$lock/pid"
    mkdir "$(journal_dir)" && cp "$repo/Sources/A.swift" "$(journal_dir)/original"
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 2 && expect_err "another run, pid $$, holds" && expect_calls 0 && [ -e "$(journal_dir)/original" ] \
        || say "the journal of the live run was touched"
}

r11_dead_lock() {
    local lock dead
    lock="$(git -C "$repo" rev-parse --absolute-git-dir)/mutate.lock"
    /usr/bin/true & dead=$!
    wait "$dead"
    mkdir "$lock" && echo "$dead" > "$lock/pid"
    printf '%s' "$case_dir/old-run/DerivedData" > "$lock/derived"
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 0 && expect_out "pid $dead is dead; taking over" \
        && expect_out "pgrep -f $case_dir/old-run/DerivedData" && [ ! -e "$lock" ] \
        || say "the lock was not released, or the hint did not name the old run's derived data"
}

r11_lock_without_pid() {
    mkdir "$(git -C "$repo" rev-parse --absolute-git-dir)/mutate.lock"
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 2 && expect_err "holds no pid" && expect_calls 0
}

r11_dead_lock_stale_list() {
    local lock dead
    lock="$(git -C "$repo" rev-parse --absolute-git-dir)/mutate.lock"
    /usr/bin/true & dead=$!
    wait "$dead"
    mkdir "$lock" && echo "$dead" > "$lock/pid"
    echo stale > "$lock/list.json" && chmod 444 "$lock/list.json"
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 0 && expect_out "pid $dead is dead; taking over" \
        && expect_out "the old run's derived data is unknown" && [ ! -e "$lock" ] \
        || say "a stale read-only list.json blocked the takeover, or the hint did not say the old run's derived data is unknown"
}

r11_lock_released_after_a_run() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 0 && [ ! -e "$(git -C "$repo" rev-parse --absolute-git-dir)/mutate.lock" ] || say "the lock is still there"
}

# ── Row 12: the list is read strictly ─────────────────────────────────────

list_refused() {
    run_runner
    expect_rc 2 && expect_err "$1" && expect_calls 0 && expect_no_traceback
}

r12_duplicate_key() {
    printf '[{"label": "a", "file": "Sources/A.swift", "find": "zz", "find": "= 88", "replace": "= 89", "test": "%s"}]' "$T_A" > "$case_dir/list.json"
    list_refused "occurs twice"
}

r12_labels_differ_only_in_case() {
    mklist A Sources/A.swift "= 88" "= 89" "$T_A" a Sources/A.swift "= 1" "= 2" "$T_A"
    list_refused "without regard to case"
}

r12_unknown_key() {
    printf '[{"label": "a", "file": "Sources/A.swift", "find": "= 88", "replce": "= 89", "test": "%s"}]' "$T_A" > "$case_dir/list.json"
    list_refused "exactly the keys"
}

r12_missing_key() {
    printf '[{"label": "a", "file": "Sources/A.swift", "find": "= 88", "replace": "= 89"}]' > "$case_dir/list.json"
    list_refused "exactly the keys"
}

r12_value_not_a_string() {
    printf '[{"label": "a", "file": "Sources/A.swift", "find": "= 88", "replace": 89, "test": "%s"}]' "$T_A" > "$case_dir/list.json"
    list_refused "is not a string"
}

r12_label_with_a_slash() {
    mklist a/b Sources/A.swift "= 88" "= 89" "$T_A"
    list_refused "label"
}

r12_test_name_with_a_space() {
    mklist a Sources/A.swift "= 88" "= 89" "AppTests/ATests/test A"
    list_refused "must name its target"
}

r12_file_name_with_a_tab() {
    mklist a "Sources/A"$'\t'".swift" "= 88" "= 89" "$T_A"
    list_refused "tab or a newline"
}

r12_label_too_long() {
    mklist "$(printf 'a%.0s' $(seq 101))" Sources/A.swift "= 88" "= 89" "$T_A"
    list_refused "at most 100 long"
}

r12_missing_file() { list_refused "cannot read the list"; }
r12_empty_file() { : > "$case_dir/list.json"; list_refused "cannot read the list"; }
r12_empty_array() { echo '[]' > "$case_dir/list.json"; list_refused "at least one entry"; }
r12_invalid_json() { echo '[{' > "$case_dir/list.json"; list_refused "cannot read the list"; }

r12_unreadable_file() {
    mklist k1 Sources/A.swift "= 88" "= 89" "$T_A"
    chmod 000 "$case_dir/list.json"
    list_refused "cannot read the list"
}

r12_lone_surrogate() {
    printf '[{"label": "a", "file": "Sources/A.swift", "find": "= 88", "replace": "\\ud800", "test": "%s"}]' "$T_A" > "$case_dir/list.json"
    list_refused "UTF-8"
}

r12_list_frozen_at_the_start() {
    printf '%s// SELFTEST_REWRITE_LIST\n' "$A_SWIFT" > "$repo/Sources/A.swift"
    ln -s A.swift "$repo/Sources/L.swift"
    commit_all rewrite_list
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 0 && expect_out "killed  k1  Sources/A.swift  $T_A" && expect_clean && [ -L "$repo/Sources/L.swift" ] \
        || say "the list was not frozen at the start; rc=$rc"
}

# ── Row 13: configuration, and the fake-tools label ───────────────────────

r13_configuration() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner --configuration UITest
    expect_rc 0 && [ "$(grep -c -x 'ARG -configuration' "$SELFTEST_CALL_LOG")" -eq 2 ] && expect_arg UITest \
        || say "-configuration UITest did not reach both calls"
}

r13_fake_tools_label() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    [ "$(head -1 "$out/mutate-summary.txt")" = "FAKE TOOLS: this run did not use the real xcodebuild or xcresulttool" ] \
        && expect_out "FAKE TOOLS: this run did not use the real xcodebuild or xcresulttool" \
        || say "the summary does not start with the FAKE TOOLS line"
}

# ── Row 14: byte-exact on awkward files ───────────────────────────────────

byte_exact() {
    local before
    before=$(sha_of "$repo/$1")
    mklist b1 "$1" "$2" "$3 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 0 && [ "$(sha_of "$repo/$1")" = "$before" ] && expect_clean || say "$1 is not byte-identical after the run"
}

r14_crlf() {
    printf 'let threshold = 88\r\nlet other = 1\r\n' > "$repo/Sources/C.swift" && commit_all crlf
    byte_exact Sources/C.swift $'88\r\nlet other' $'88\r\nlet other'
}

r14_no_final_newline() {
    printf 'let threshold = 88' > "$repo/Sources/N.swift" && commit_all nonewline
    byte_exact Sources/N.swift "= 88" "= 88"
}

r14_two_final_newlines() {
    printf 'let threshold = 88\n\n' > "$repo/Sources/T.swift" && commit_all twonewlines
    byte_exact Sources/T.swift "= 88" "= 88"
}

r14_space_in_the_path() {
    mkdir -p "$repo/With Space" && printf 'let threshold = 88\n' > "$repo/With Space/S.swift" && commit_all space
    byte_exact "With Space/S.swift" "= 88" "= 88"
}

r14_label_named_baseline() {
    mklist baseline Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 0 && [ -d "$out/mutant-baseline.xcresult" ] || say "the mutation labelled baseline did not get its own bundle"
}
