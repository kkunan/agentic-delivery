# ── Row 6: signals, and recovery after a hard kill ────────────────────────

ticking() {
    [ -s "$SELFTEST_TICKS" ]
}

runner_gone() {
    ! kill -0 "$runner" 2>/dev/null
}

start_sleeping_mutation() {
    mklist s1 Sources/A.swift "= 88" "= 88 // SELFTEST_SLEEP" "$T_A"
    start_runner_bg
    wait_for 100 ticking || { kill -KILL "$runner"; say "the fake xcodebuild never started"; }
}

ticks_stopped() {
    local before after
    before=$(wc -c < "$SELFTEST_TICKS")
    sleep 0.6
    after=$(wc -c < "$SELFTEST_TICKS")
    [ "$before" -eq "$after" ] || say "the fake's grandchild kept writing after the runner exited"
}

signal_case() {
    local sig=$1 expected=$2
    start_sleeping_mutation || return 1
    kill "-$sig" "$runner"
    wait_for 50 runner_gone || { kill -KILL "$runner"; say "the runner did not exit within 5 s of $sig"; return 1; }
    wait "$runner"
    rc=$?
    expect_rc "$expected" && expect_err "INTERRUPTED by $sig" && expect_clean && expect_no_journal \
        && ticks_stopped && { ! pgrep -f "$case_dir" > /dev/null || say "a fake process is still running"; }
}

r6_term() {
    signal_case TERM 143 \
        && { ! grep -qF 'earlier run' "$case_dir/stderr" || say "the trap's recovery falsely says the mutation was left by an earlier run"; }
}

r6_int() {
    signal_case INT 130
}

r6_hup() {
    signal_case HUP 129
}

r6_kill_then_restart() {
    start_sleeping_mutation || return 1
    kill -KILL "$runner"
    wait "$runner" 2>/dev/null
    pkill -KILL -f "$case_dir" 2>/dev/null
    [ -e "$(journal_dir)/record" ] || say "no journal after the hard kill" || return 1
    run_runner
    expect_rc 2 && expect_out "is dead; taking over" \
        && expect_out "RECOVERED: restored Sources/A.swift from mutation s1" \
        && expect_err "$out/mutant-s1.log" && expect_clean && expect_no_journal
}

# ── Row 6: the recovery table, set up by hand ─────────────────────────────

write_record() {
    printf '{"label": "%s", "file": "%s", "original": "%s", "mutated": "%s"}' "$@" > "$(journal_dir)/record"
}

setup_mutated_journal() {
    local j original
    j=$(journal_dir)
    mkdir "$j" && cp -p "$repo/Sources/A.swift" "$j/original"
    original=$(sha_of "$repo/Sources/A.swift")
    printf 'let threshold = 89\nlet other = 1\nlet word = "aaa"\n' > "$repo/Sources/A.swift"
    write_record gone Sources/A.swift "$original" "$(sha_of "$repo/Sources/A.swift")"
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
}

r6_recover_unfinished() {
    mkdir "$(journal_dir)" && cp "$repo/Sources/A.swift" "$(journal_dir)/original"
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 0 && expect_out "RECOVERED: removed an unfinished journal" && expect_no_journal
}

r6_recover_mutated() {
    setup_mutated_journal
    run_runner
    expect_rc 0 && expect_out "RECOVERED: restored Sources/A.swift from mutation gone" \
        && expect_clean && expect_no_journal
}

r6_recover_already_original() {
    setup_mutated_journal
    git -C "$repo" checkout -q -- Sources/A.swift
    run_runner
    expect_rc 0 && expect_out "RECOVERED: Sources/A.swift was already original" && expect_no_journal
}

r6_recover_damaged() {
    setup_mutated_journal
    echo junk > "$(journal_dir)/original"
    run_runner
    expect_rc 2 && expect_err "is damaged" && expect_calls 0 && [ -e "$(journal_dir)/record" ] \
        || say "the journal was removed"
}

r6_recover_neither() {
    setup_mutated_journal
    echo "hand edit" > "$repo/Sources/A.swift"
    run_runner
    expect_rc 2 && expect_err "matches neither" && expect_calls 0 && expect_file Sources/A.swift "hand edit" \
        && [ -e "$(journal_dir)/record" ] || say "the journal was removed"
}

# ── Row 6: a child that ignores TERM, and a helper that crashes ───────────

called_twice() {
    [ "$(grep -c '^CALL$' "$SELFTEST_CALL_LOG")" -ge 2 ]
}

r6_stubborn_child_is_killed() {
    export MUTATE_STOP_POLLS=5
    mklist s1 Sources/A.swift "= 88" "= 88 // SELFTEST_STUBBORN" "$T_A"
    start_runner_bg
    wait_for 100 called_twice || { kill -KILL "$runner"; say "the fake xcodebuild never started"; return 1; }
    sleep 0.5
    kill -TERM "$runner"
    wait_for 50 runner_gone || { kill -KILL "$runner"; say "the runner did not exit within 5 s of TERM"; return 1; }
    wait "$runner"
    rc=$?
    expect_rc 143 && expect_clean && expect_no_journal \
        && { ! pgrep -f "$case_dir" > /dev/null || say "a fake process is still running"; }
}

r6_helper_crash_refuses() {
    mkdir "$(journal_dir)" && cp "$repo/Sources/A.swift" "$(journal_dir)/original"
    printf '{"label": "x", "file": "Sources/A.swift"}' > "$(journal_dir)/record"
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_runner
    expect_rc 2 && expect_err "the helper failed with exit 5" && expect_calls 0
}
