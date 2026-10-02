#!/usr/bin/env bash
set -uo pipefail

self_dir=$(cd "$(dirname "$0")" && pwd -P)
source "$self_dir/mutate/run.sh"
source "$self_dir/mutate/report.sh"

usage() {
    cat <<'EOF'
usage: scripts/mutate.sh --manifest <file> --out <dir> [--runner <path>]

Applies each mutation in <file>, runs the test it names, records a verdict,
reverts it, and makes sure that the file is byte-for-byte original again.
Run it from the worktree whose code it mutates.

<file> is a JSON array. Each entry has exactly these string keys:
  label    letters, digits, . _ -, unique without regard to case
  file     a clean, tracked, regular file, relative to the repository root
  find     text that occurs exactly once in the file
  replace  the text to put in its place
  test     a test id that the runner understands, with no control character

--runner is the platform runner. Without it, the run reads mutation_runner
from .claude/agentic-delivery.md. A relative path starts at the repository
root. The runner is called with stdin from /dev/null, and its stdout and
stderr go to the stderr of this script:
  <runner> --out <result.json> --log <log> -- <test-id>...
It writes the result file:
  {"compiled": true|false,
   "tests": [{"id": "<id>", "result": "passed|failed|skipped"}]}
The baseline calls it once with every test id, on the unmodified tree. Each
mutation calls it with the test id of that mutation. Verdicts:
did-not-compile when compiled is false; killed when the named test failed;
survived when every entry for the named test passed; error in any other
case, for example no result file, invalid JSON, the wrong shape, a named
test that is absent from tests, or a skipped result.

--out gets mutant-<label>.json and .log, baseline-<stamp>.json and .log,
and mutate-summary.txt. A run refuses to start if a result file or log of
one of its labels is already there.

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
    check_evidence
    run_baseline
    local i
    for ((i = 0; i < ${#labels[@]}; i++)); do
        run_mutation "$i"
    done
    report
}

main "$@"
