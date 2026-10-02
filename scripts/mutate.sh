#!/usr/bin/env bash
set -uo pipefail

self_dir=$(cd "$(dirname "$0")" && pwd -P)
source "$self_dir/mutate/run.sh"
source "$self_dir/mutate/report.sh"

usage() {
    cat <<'EOF'
usage: scripts/mutate.sh --manifest <file> --udid <udid> --out <dir>
                         [--derived-data <dir>] [--configuration <name>]

Applies each mutation in <file>, runs the test it names, records a verdict,
reverts it, and makes sure that the file is byte-for-byte original again.
Run it from the worktree whose code it mutates.

<file> is a JSON array. Each entry has exactly these string keys:
  label    letters, digits, . _ -, unique without regard to case
  file     a clean, tracked, regular file, relative to the repository root
  find     text that occurs exactly once in the file
  replace  the text to put in its place
  test     an -only-testing name, for example
           AppTests/ChatScrollGeometryTests/testTheThresholdIs88

--out gets mutant-<label>.xcresult and .log, a baseline bundle and log, and
mutate-summary.txt. --derived-data defaults to <out>/DerivedData.
--configuration is passed to xcodebuild as -configuration.

Exit: 0 every mutation killed; 1 some mutation survived, did not compile or
is an error; 2 refused: no mutation from this run was applied, and a file
restored by recovery is back at its original bytes, unless the saved
original was itself damaged, in which case the message says so and the
file holds those damaged bytes; 3 an apply or a revert failed, or recovery
refused after a signal; 129, 130, 143 interrupted by HUP, INT, TERM after
the file was restored.
EOF
}

main() {
    parse_args "$@"
    take_lock
    freeze_list
    trap 'on_signal 130 INT' INT
    trap 'on_signal 143 TERM' TERM
    trap 'on_signal 129 HUP' HUP
    helper recover "$repo" "$journal" || refuse_after_helper $?
    read_list
    check_bundles
    run_baseline
    local i
    for ((i = 0; i < ${#labels[@]}; i++)); do
        run_mutation "$i"
    done
    report
}

main "$@"
