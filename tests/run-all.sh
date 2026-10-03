#!/bin/bash
set -u
unset $(git rev-parse --local-env-vars 2>/dev/null)
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.excludesFile GIT_CONFIG_VALUE_0=/dev/null
here=$(cd "$(dirname "$0")" && pwd -P)
status=0
found=0
for t in "$here"/test-*.sh; do
    [ -e "$t" ] || continue
    found=$((found + 1))
    printf '== %s\n' "$(basename "$t")"
    bash "$t" || status=1
done
[ "$found" -gt 0 ] || { echo "run-all: no test files found, refusing to pass" >&2; exit 2; }
exit "$status"
