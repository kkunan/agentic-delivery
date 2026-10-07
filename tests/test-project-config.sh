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
check "push_policy is each-task when the key is missing" "each-task" "$(bash "$cfg" push_policy each-task)"
printf -- '---\nplatform: flutter\npush_policy: mr-and-ship\n---\n' > "$work/.claude/agentic-delivery.md"
check "push_policy is read when the key is present" "mr-and-ship" "$(bash "$cfg" push_policy each-task)"
cp "$here/../templates/agentic-delivery.md" "$work/.claude/agentic-delivery.md"
check "the template sets push_policy to each-task" "each-task" "$(bash "$cfg" push_policy 2>&1)"
printf -- '---\nplatform: flutter\ncomment_prefix:\n---\n' > "$work/.claude/agentic-delivery.md"
out=$(bash "$cfg" comment_prefix ""); check "an empty comment_prefix with an empty default exits 0" 0 $?
check "an empty comment_prefix gives no prefix" "" "$out"
bash "$cfg" comment_prefix >/dev/null 2>&1; check "an empty key with no default fails closed" 3 $?
printf -- '---\nplatform: flutter\n---\n' > "$work/.claude/agentic-delivery.md"
out=$(bash "$cfg" comment_prefix ""); check "a missing comment_prefix with an empty default exits 0" 0 $?
check "a missing comment_prefix gives no prefix" "" "$out"
printf -- '---\nplatform: flutter\ncomment_prefix: Claude said:\n---\n' > "$work/.claude/agentic-delivery.md"
check "a prefix that holds a colon reads whole" "Claude said:" "$(bash "$cfg" comment_prefix "")"
rm "$work/.claude/agentic-delivery.md"
bash "$cfg" platform >/dev/null 2>&1; check "a missing file fails closed" 4 $?
cd /
bash "$cfg" platform >/dev/null 2>&1; check "outside a repository fails closed" 5 $?
rmdir "$work/.claude"; rm -rf "$work/.git"; rmdir "$work"
finish
