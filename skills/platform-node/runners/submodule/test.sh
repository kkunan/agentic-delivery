#!/bin/bash
set -u

usage='usage: test.sh <submodule path> [jest arguments...]'
[ $# -ge 1 ] || { printf '%s\n' "$usage" >&2; exit 2; }
sub=${1%/}
shift

top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "test.sh: run it inside a worktree of a repository that pins the submodule" >&2; exit 2; }
cd "$top" || exit 2
[ -d "$sub" ] || { echo "test.sh: $top has no $sub. Run git submodule update --init first" >&2; exit 2; }
[ -x node_modules/.bin/jest ] || { echo "test.sh: run npm ci in $top first" >&2; exit 2; }

exec node_modules/.bin/jest --coverage=false --testPathIgnorePatterns '/node_modules/' --roots "<rootDir>/$sub" "$@"
