# ── Row 7: how the runner is called ───────────────────────────────────────

call_log_shape() {
    sed -e "s#$out/#<out>/#" -e 's#baseline-[0-9]*-[0-9]*-[0-9]*\.#baseline-<stamp>.#' "$SELFTEST_CALL_LOG"
}

expected_call() {
    local result=$1
    shift
    printf 'CALL\nARG --out\nARG <out>/%s.json\nARG --log\nARG <out>/%s.log\nARG --\n' "$result" "$result"
    printf 'ARG %s\n' "$@"
}

r7_contract_call() {
    mklist s1 Sources/A.swift "= 1" "= 2" "$T_A" \
        s2 Sources/A.swift '"aaa"' '"aab"' "$T_B" \
        s3 Sources/A.swift "= 88" "= 89" "$T_A"
    run_runner
    local want
    want=$(expected_call baseline-"<stamp>" "$T_A" "$T_B"; expected_call mutant-s1 "$T_A"; \
        expected_call mutant-s2 "$T_B"; expected_call mutant-s3 "$T_A")
    expect_rc 1 && [ "$(call_log_shape)" = "$want" ] && [ -f "$out/mutant-s3.json" ] && [ -f "$out/mutant-s3.log" ] \
        && ls "$out"/baseline-*.json "$out"/baseline-*.log > /dev/null \
        || say "the runner calls differ from the contract: $(call_log_shape | tr '\n' ' ')"
}

r7_stdin_is_null() {
    mklist s1 Sources/A.swift "= 1" "= 2" "$T_A"
    run_runner
    expect_rc 1 && expect_calls 2 && ! grep -q '^STDIN' "$SELFTEST_CALL_LOG" \
        || say "a runner call read from the stdin of mutate.sh"
}

# ── Row 8: the baseline ───────────────────────────────────────────────────

r8_red_on_the_clean_tree() {
    printf 'let threshold = 88 // SELFTEST_BASELINE_RED\n' > "$repo/Sources/A.swift"
    commit_all red
    mklist k1 Sources/A.swift "= 88" "= 89" "$T_A"
    run_runner
    expect_rc 2 && expect_err "$T_A: failed on the unmodified tree" && expect_calls 1 && expect_clean
}

r8_does_not_compile_on_the_clean_tree() {
    printf 'let threshold = 88 // SELFTEST_NOCOMPILE\n' > "$repo/Sources/A.swift"
    commit_all nocompile
    mklist k1 Sources/A.swift "= 88" "= 89" "$T_A"
    run_runner
    expect_rc 2 && expect_err "did not compile on the unmodified tree" && expect_calls 1
}

r8_no_result_file_on_the_clean_tree() {
    printf 'let threshold = 88 // SELFTEST_ERR_NOFILE\n' > "$repo/Sources/A.swift"
    commit_all nofile
    mklist k1 Sources/A.swift "= 88" "= 89" "$T_A"
    run_runner
    expect_rc 2 && expect_err "no result file, runner exit 1" && expect_calls 1
}

r8_misnamed() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A" \
        k2 Sources/A.swift "= 1" "= 1 // SELFTEST_KILL" "suite/a_test/doesNotExist"
    run_runner
    expect_rc 2 && expect_err "suite/a_test/doesNotExist: no test ran" && expect_calls 1
}

r8_suffix_of_a_real_id() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A" \
        k2 Sources/A.swift "= 1" "= 1 // SELFTEST_KILL" "a_test/one"
    run_runner
    expect_rc 2 && expect_err "a_test/one: no test ran" && expect_calls 1
}

r8_id_with_an_extra_part() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A" \
        k2 Sources/A.swift "= 1" "= 1 // SELFTEST_KILL" "extra/$T_A"
    run_runner
    expect_rc 2 && expect_err "extra/$T_A: no test ran" && expect_calls 1
}

r8_all_skipped() {
    printf 'let threshold = 88 // SELFTEST_SKIPPED\n' > "$repo/Sources/A.swift"
    commit_all skipped
    mklist k1 Sources/A.swift "= 88" "= 89" "$T_A"
    run_runner
    expect_rc 2 && expect_err "$T_A: no test passed (skipped)" && expect_calls 1
}

r8_prefix_of_a_real_id() {
    printf 'let threshold = 88 // SELFTEST_RENAME_FOOBAR\n' > "$repo/Sources/A.swift"
    commit_all rename_foobar
    mklist k1 Sources/A.swift "= 88" "= 89" "suite/a_test/foo"
    run_runner
    expect_rc 2 && expect_err "suite/a_test/foo: no test ran" && expect_calls 1
}

# ── Row 9: the error verdict ──────────────────────────────────────────────

error_case() {
    local reason=$2
    mklist e1 Sources/A.swift "= 88" "= 88 // SELFTEST_$1" "$T_A"
    run_runner
    expect_rc 1 && expect_out "  e1  Sources/A.swift  $T_A  (" && expect_out "$reason" \
        && expect_clean && expect_no_journal
}

r9_missing_test() { error_case NORUN "$T_A is absent from tests"; }
r9_no_file() { error_case ERR_NOFILE "no result file, runner exit 1"; }
r9_invalid_json() { error_case ERR_JSON "the result file is not valid JSON"; }
r9_wrong_shape() { error_case ERR_SHAPE "the result file has the wrong shape: compiled is not true or false"; }
r9_skipped() { error_case SKIPPED "$T_A: skipped"; }

# ── Row 10: target files ──────────────────────────────────────────────────

target_refused() {
    mklist x1 "$1" "= 88" "= 89" "$T_A"
    run_runner
    expect_rc 2 && expect_err "$2" && expect_calls 0
}

r10_outside() {
    printf 'let threshold = 88\n' > "$case_dir/outside.swift"
    target_refused ../outside.swift "outside the repository"
}

r10_ignored() {
    printf 'ignored.swift\n' > "$repo/.gitignore" && commit_all ignore
    printf 'let threshold = 88\n' > "$repo/ignored.swift"
    target_refused ignored.swift "not tracked"
}

r10_directory() {
    target_refused Sources "not a regular file"
}

r10_symbolic_link() {
    ln -s A.swift "$repo/Sources/L.swift" && commit_all link
    target_refused Sources/L.swift "symbolic link"
}

r10_the_runner_itself() {
    mkdir -p "$repo/scripts/mutate"
    cp "$RUNNER_DIR/mutate.sh" "$repo/scripts/" && cp "$RUNNER_DIR"/mutate/*.sh "$RUNNER_DIR"/mutate/*.py "$repo/scripts/mutate/"
    commit_all runner
    mklist x1 scripts/mutate.sh "set -uo pipefail" "set -u" "$T_A"
    ( cd "$repo" && scripts/mutate.sh --manifest "$case_dir/list.json" --runner "$FAKE_RUNNER" --out "$out" ) \
        < "$case_dir/stdin" > "$case_dir/stdout" 2> "$case_dir/stderr"
    rc=$?
    expect_rc 2 && expect_err "one of the files of mutate.sh" && expect_calls 0 && expect_clean
}
