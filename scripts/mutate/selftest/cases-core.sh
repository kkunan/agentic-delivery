# ── Row 0: a kill is killed and a pass is survived ────────────────────────

r0_kill_alone() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 0 && expect_calls 2 && expect_out "killed  k1  Sources/A.swift  $T_A" \
        && expect_out "mutate: 1 mutations, 1 killed, 0 survived, 0 did-not-compile, 0 error" \
        && expect_clean && expect_no_journal
}

r0_survivor_alone() {
    mklist s1 Sources/A.swift "= 1" "= 2" "$T_B"
    run_runner
    expect_rc 1 && expect_calls 2 && expect_out "survived  s1  Sources/A.swift  $T_B" \
        && [ "$(awk '/^survived:/ { getline; print; exit }' "$case_dir/stdout")" = "  s1  Sources/A.swift  $T_B" ] \
        && expect_clean && expect_no_journal \
        || say "the line after survived: is not the group listing for s1"
}

summary_as_golden() {
    sed "s#$selftest_dir/#<selftest>/#" "$out/mutate-summary.txt"
}

r0_summary_golden() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A" \
        s1 Sources/A.swift "= 1" "= 2" "$T_B"
    run_runner
    expect_rc 1 && summary_as_golden | cmp -s - "$selftest_dir/golden-summary.txt" \
        || say "mutate-summary.txt differs from golden-summary.txt: $(summary_as_golden | diff - "$selftest_dir/golden-summary.txt")"
}

r0_unnamed_failure_is_not_a_kill() {
    mklist s1 Sources/A.swift "= 1" "= 1 // SELFTEST_OTHER_FAILS" "$T_A"
    run_runner
    expect_rc 1 && expect_out "survived  s1  Sources/A.swift  $T_A" && expect_clean
}

# ── Row 1: an existing result file or log is refused ──────────────────────

r1_existing_result_file() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    mkdir -p "$out" && echo '{}' > "$out/mutant-k1.json"
    run_runner
    expect_rc 2 && expect_err "$out/mutant-k1.json" && expect_calls 0 && expect_clean
}

r1_existing_log() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    mkdir -p "$out" && echo old > "$out/mutant-k1.log"
    run_runner
    expect_rc 2 && expect_err "$out/mutant-k1.log" && expect_calls 0 && expect_clean
}

r1_partial_rerun() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 0 || return 1
    mklist k2 Sources/A.swift "= 1" "= 1 // SELFTEST_KILL" "$T_B"
    run_runner
    expect_rc 0 && expect_calls 4 && expect_out "killed  k2"
}

# ── Row 2: every revert is checked ────────────────────────────────────────

r2_corrupt_saved_original() {
    mklist c1 Sources/A.swift "= 88" "= 88 // SELFTEST_CORRUPT" "$T_A" \
        k2 Sources/A.swift "= 1" "= 1 // SELFTEST_KILL" "$T_B"
    run_runner
    expect_rc 3 && expect_calls 2 && expect_err "is damaged" && [ -e "$(journal_dir)" ] \
        || say "exit $rc, the journal is gone, or the second mutation ran"
}

r2_mode_restored() {
    mklist m1 Sources/A.swift "= 88" "= 88 // SELFTEST_CHMOD" "$T_A"
    run_runner
    expect_rc 1 && expect_clean && [ ! -x "$repo/Sources/A.swift" ] || say "the file mode was not restored"
}

# ── Row 3: a compile failure is not a kill ────────────────────────────────

r3_did_not_compile() {
    mklist n1 Sources/A.swift "= 88" "= 88 // SELFTEST_NOCOMPILE" "$T_A"
    run_runner
    expect_rc 1 && expect_out "did-not-compile  n1" \
        && expect_out "mutate: 1 mutations, 0 killed, 0 survived, 1 did-not-compile, 0 error" && expect_clean
}

r3_did_not_compile_beats_a_failure() {
    mklist n1 Sources/A.swift "= 88" "= 88 // SELFTEST_NOCOMPILE_STALE" "$T_A"
    run_runner
    expect_rc 1 && expect_out "did-not-compile  n1" \
        && expect_out "mutate: 1 mutations, 0 killed, 0 survived, 1 did-not-compile, 0 error" && expect_clean
}

# ── Row 4: the text must occur exactly once ───────────────────────────────

r4_zero_matches() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A" \
        z2 Sources/A.swift "= 77" "= 78" "$T_A"
    run_runner
    expect_rc 2 && expect_err "occurs 0 times" && expect_calls 0 && expect_clean
}

r4_two_matches() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A" \
        t2 Sources/A.swift "let " "var " "$T_A"
    run_runner
    expect_rc 2 && expect_err "occurs 3 times" && expect_calls 0 && expect_clean
}

r4_overlapping() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A" \
        o2 Sources/A.swift "aa" "bb" "$T_A"
    run_runner
    expect_rc 2 && expect_err "occurs 2 times" && expect_calls 0 && expect_clean
}

# ── Row 5: uncommitted target files are refused ───────────────────────────

r5_unstaged() {
    printf 'let threshold = 88\nlet other = 1\nlet word = "aaa"\n// edit\n' > "$repo/Sources/A.swift"
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 2 && expect_err "uncommitted" && expect_calls 0
}

r5_staged() {
    printf 'let threshold = 88\nlet other = 1\nlet word = "aaa"\n// edit\n' > "$repo/Sources/A.swift"
    git -C "$repo" add Sources/A.swift
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 2 && expect_err "uncommitted" && expect_calls 0
}

r5_untracked() {
    printf 'let x = 88\n' > "$repo/Sources/B.swift"
    mklist k1 Sources/B.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 2 && expect_err "not tracked" && expect_calls 0
}

# ── Rows 1 and 2: paths that only a changing tree reaches ─────────────────

r1_result_file_appears_mid_run() {
    printf '%s// SELFTEST_PLANT_K1\n' "$A_SWIFT" > "$repo/Sources/A.swift" && commit_all plant
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 1 && expect_calls 1 && expect_out "(result file appeared before the call)" && expect_clean
}

r2_apply_refuses_a_file_that_changed() {
    printf '%s// SELFTEST_GROW\n' "$A_SWIFT" > "$repo/Sources/A.swift" && commit_all grow
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 3 && expect_calls 1 && expect_err "STOPPED during apply of k1" \
        && expect_err "no longer occurs exactly once" && expect_no_journal
}
