#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/lib.sh"
cfg="$here/../scripts/project-config.sh"
work=$(mktemp -d)
git -C "$work" init -q
mkdir -p "$work/.claude"
printf -- '---\nplatform: flutter\nbase_branch: develop\n---\n# notes\nplatform: wrong\n' > "$work/.claude/agentic-delivery.md"
cd "$work"
check "reads a key" "flutter" "$(bash "$cfg" platform)"
check "ignores the body" "develop" "$(bash "$cfg" base_branch)"
check "a default fills a missing key" "feature/" "$(bash "$cfg" branch_prefix feature/)"
bash "$cfg" docs_dir >/dev/null 2>&1; check "a missing key fails closed" 3 $?
rm "$work/.claude/agentic-delivery.md"
bash "$cfg" platform >/dev/null 2>&1; check "a missing file fails closed" 4 $?
cd /
bash "$cfg" platform >/dev/null 2>&1; check "outside a repository fails closed" 5 $?
rmdir "$work/.claude"; rm -rf "$work/.git"; rmdir "$work"
finish
