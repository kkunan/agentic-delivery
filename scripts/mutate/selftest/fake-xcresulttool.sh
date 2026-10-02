#!/usr/bin/env bash
set -u

here=$(cd "$(dirname "$0")" && pwd -P)
[ "${1:-}" = get ] || exit 64
what=$2
shift 2
if [ "$what" = test-results ]; then
    what="test-results-$1"
    shift
fi
[ "${1:-}" = --path ] || exit 64
bundle=$2
if [ ! -f "$bundle/selftest-outcome" ]; then
    echo "Error: File or directory doesn't exist at path: $bundle."
    exit 64
fi
exec /usr/bin/python3 -B "$here/emit.py" "$what" "$(cat "$bundle/selftest-outcome")" "$bundle/selftest-names" "$here/fixtures"
