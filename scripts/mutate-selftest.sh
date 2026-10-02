#!/usr/bin/env bash
set -uo pipefail

scripts_dir=$(cd "$(dirname "$0")" && pwd -P)
selftest_dir="$scripts_dir/mutate/selftest"
RUNNER_DIR=$scripts_dir
RUNNER_FILES="mutate.sh mutate/run.sh mutate/report.sh mutate/mutate.py mutate/manifest.py mutate/journal.py mutate/results.py"
source "$selftest_dir/lib.sh"
source "$selftest_dir/cases-core.sh"
source "$selftest_dir/cases-signals.sh"
source "$selftest_dir/cases-inputs.sh"
source "$selftest_dir/cases-more.sh"
source "$selftest_dir/mutants.sh"

usage() {
    cat <<'USAGE'
usage: scripts/mutate-selftest.sh [--runner <folder>] [--only <prefix>]
       scripts/mutate-selftest.sh [--runner <folder>] --mutants

Runs the cases for scripts/mutate.sh with fake xcodebuild and xcresulttool.
--runner  a folder that holds a copy of the runner: mutate.sh and mutate/*.
          Combines with --mutants, in either order, to judge that folder
--only    run only the cases whose names start with <prefix>, for example r6_.
          Cannot be combined with --mutants
--mutants build each broken copy in mutate/selftest/mutants.json, run the
          cases against it, and fail unless every copy is caught
USAGE
}

check_runner() {
    local f
    for f in $RUNNER_FILES; do
        [ -s "$RUNNER_DIR/$f" ] || { printf 'selftest: the runner folder %s has no %s, or it is empty\n' "$RUNNER_DIR" "$f" >&2; exit 2; }
    done
}

all_cases() {
    declare -F | awk '{print $3}' | grep -E '^r[0-9]+_' | sort -t_ -k1.2n -s
}

run_case() {
    local fn=$1 message
    message=$( (new_repo || exit 1; "$fn"; status=$?; cleanup_case; exit "$status") 2>&1 )
    if [ $? -eq 0 ]; then
        printf 'ok    %s\n' "$fn"
        return 0
    fi
    printf 'FAIL  %s: %s\n' "$fn" "$(printf '%s' "$message" | tr '\n' ' ' | cut -c1-600)"
    return 1
}

run_cases() {
    local prefix=${1:-r} fn total=0 failed=0
    check_runner
    for fn in $(all_cases); do
        case "$fn" in "$prefix"*) ;; *) continue ;; esac
        total=$((total + 1))
        run_case "$fn" || failed=$((failed + 1))
    done
    [ "$total" -gt 0 ] || { echo "selftest: no case matches $prefix" >&2; return 2; }
    printf 'selftest: %s cases, %s passed, %s failed\n' "$total" "$((total - failed))" "$failed"
    [ "$failed" -eq 0 ]
}

main() {
    local only=r only_given=0 want_mutants=0
    while [ $# -gt 0 ]; do
        case "$1" in
            --runner) RUNNER_DIR=${2:-}; shift 2 || exit 2; RUNNER_DIR=$(cd "$RUNNER_DIR" 2>/dev/null && pwd -P) || { echo "selftest: no runner folder" >&2; exit 2; } ;;
            --only) only=${2:-}; only_given=1; shift 2 || exit 2 ;;
            --mutants) want_mutants=1; shift ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; exit 2 ;;
        esac
    done
    if [ "$want_mutants" -eq 1 ]; then
        [ "$only_given" -eq 0 ] || { echo "selftest: --only cannot be combined with --mutants" >&2; exit 2; }
        run_mutants
        exit $?
    fi
    run_cases "$only"
}

main "$@"
