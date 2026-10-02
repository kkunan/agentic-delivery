# ── Row 7: the device ─────────────────────────────────────────────────────

r7_no_udid() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_args --manifest "$case_dir/list.json" --out "$out"
    expect_rc 2 && expect_err "--udid is required" && expect_calls 0
}

r7_owner_device() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_args --manifest "$case_dir/list.json" --udid "$OWNER_UDID" --out "$out"
    expect_rc 2 && expect_err "owner's manual device" && expect_calls 0
}

r7_owner_device_lower_case() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A"
    run_args --manifest "$case_dir/list.json" --udid "$(printf '%s' "$OWNER_UDID" | tr '[:upper:]' '[:lower:]')" --out "$out"
    expect_rc 2 && expect_err "owner's manual device" && expect_calls 0
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
    expect_rc 2 && expect_err "xcodebuild exited 65" && expect_err "the build did not succeed" && expect_calls 1
}

r8_misnamed() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A" \
        k2 Sources/A.swift "= 1" "= 1 // SELFTEST_KILL" "AppTests/ATests/testDoesNotExist"
    run_runner
    expect_rc 2 && expect_err "AppTests/ATests/testDoesNotExist: no test ran" && expect_calls 1
}

r8_name_without_target() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A" \
        k2 Sources/A.swift "= 1" "= 1 // SELFTEST_KILL" "ATests/testA"
    run_runner
    expect_rc 2 && expect_err "ATests/testA: no test ran" && expect_calls 1
}

r8_name_with_an_extra_component() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A" \
        k2 Sources/A.swift "= 1" "= 1 // SELFTEST_KILL" "App/$T_A"
    run_runner
    expect_rc 2 && expect_err "App/$T_A: no test ran" && expect_calls 1
}

r8_name_with_parentheses() {
    mklist k1 Sources/A.swift "= 88" "= 88 // SELFTEST_KILL" "$T_A()"
    run_runner
    expect_rc 2 && expect_err "must name its target" && expect_calls 0
}

r8_all_skipped() {
    printf 'let threshold = 88 // SELFTEST_SKIPPED\n' > "$repo/Sources/A.swift"
    commit_all skipped
    mklist k1 Sources/A.swift "= 88" "= 89" "$T_A"
    run_runner
    expect_rc 2 && expect_err "$T_A: no test passed" && expect_calls 1
}

r8_prefix_of_a_real_name() {
    printf 'let threshold = 88 // SELFTEST_RENAME_FOOBAR\n' > "$repo/Sources/A.swift"
    commit_all rename_foobar
    mklist k1 Sources/A.swift "= 88" "= 89" "AppTests/ATests/testFoo"
    run_runner
    expect_rc 2 && expect_err "AppTests/ATests/testFoo: no test ran" && expect_calls 1
}

# ── Row 9: the error verdict ──────────────────────────────────────────────

error_case() {
    local reason=$2
    mklist e1 Sources/A.swift "= 88" "= 88 // SELFTEST_$1" "$T_A"
    run_runner
    expect_rc 1 && expect_out "  e1  Sources/A.swift  $T_A  (" && expect_out "$reason" \
        && expect_clean && expect_no_journal
}

r9_norun() { error_case NORUN "tests total 0"; }
r9_exit_64() { error_case ERR_EXIT64 "no result bundle, exit 64"; }
r9_exit_65_no_bundle() { error_case ERR_NOBUNDLE65 "no result bundle, exit 65"; }
r9_exit_0_with_a_failure() { error_case ERR_EXIT0_FAILED "exit 0, build succeeded/0, tests total 1 failed 1"; }
r9_tool_fails() { error_case ERR_TOOL "xcresulttool get build-results exited 64"; }
r9_invalid_json() { error_case ERR_JSON "printed invalid JSON"; }
r9_missing_field() { error_case ERR_FIELD "tests total None"; }
r9_all_skipped() { error_case SKIPPED "tests total 1 failed 0 passed 0"; }

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
    ( cd "$repo" && MUTATE_XCODEBUILD="$selftest_dir/fake-xcodebuild.sh" MUTATE_XCRESULTTOOL="$selftest_dir/fake-xcresulttool.sh" \
        scripts/mutate.sh --manifest "$case_dir/list.json" --udid "$UDID" --out "$out" ) > "$case_dir/stdout" 2> "$case_dir/stderr"
    rc=$?
    expect_rc 2 && expect_err "runner's own files" && expect_calls 0 && expect_clean
}
