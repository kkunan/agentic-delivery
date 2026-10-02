#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/lib.sh"
guard=${AGENTIC_PRIVATE:-$here/../../agentic-delivery-private}/name-guard.sh
[ -x "$guard" ] || { echo "SKIP name guard: no private folder on this machine"; exit 0; }
work=$(mktemp -d)
printf 'clean text\n' > "$work/clean.md"
printf 'leak: %s\n' "$(printf 'TkVNIEFJ' | base64 -d)" > "$work/dirty.md"
"$guard" "$work/clean.md" >/dev/null; check "a clean file passes" 0 $?
"$guard" "$work/dirty.md" >/dev/null; check "a named file fails" 1 $?
"$guard" >/dev/null 2>&1; check "no path is refused" 2 $?
rm -f "$work/clean.md" "$work/dirty.md"
rmdir "$work"
finish
