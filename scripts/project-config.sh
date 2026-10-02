#!/bin/bash
set -u
[ $# -ge 1 ] || { echo "usage: project-config.sh <key> [default]" >&2; exit 2; }
key=$1
top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "project-config: not in a git repository" >&2; exit 5; }
file="$top/.claude/agentic-delivery.md"
[ -f "$file" ] || { echo "project-config: no project file at $file" >&2; exit 4; }
value=$(awk -v k="$key" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    NR > 1 {
        i = index($0, ":")
        if (i > 0 && substr($0, 1, i - 1) == k) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); print v; exit }
    }' "$file")
if [ -n "$value" ]; then
    printf '%s\n' "$value"
elif [ $# -ge 2 ]; then
    printf '%s\n' "$2"
else
    echo "project-config: no '$key' in $file" >&2
    exit 3
fi
