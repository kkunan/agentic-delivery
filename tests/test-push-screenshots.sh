#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/lib.sh"
push="$here/../scripts/push-screenshots.sh"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git init -q --bare "$work/remote.git"
git init -q "$work/repo"
repo=$work/repo
mkdir -p "$repo/.claude" "$work/shots" "$work/empty"
printf -- '---\nscreenshot_branch: shots\n---\n' > "$repo/.claude/agentic-delivery.md"
git -C "$repo" remote add origin "$work/remote.git"
printf 'a' > "$work/shots/home-light.png"
printf 'b' > "$work/shots/home-dark.png"
printf 'c' > "$work/shots/notes.txt"

run() { (cd "$repo" && GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t bash "$push" "$@") > "$work/out" 2> "$work/err"; echo $?; }
tip() { git --git-dir="$work/remote.git" rev-parse --verify --quiet refs/heads/shots || echo none; }
files() { git --git-dir="$work/remote.git" ls-tree -r --name-only refs/heads/shots | tr '\n' ' '; }

check "no branch on the remote: exit 0" 0 "$(run --folder 01-a --from "$work/shots")"
check "first push makes the branch with the pngs only" "01-a/home-dark.png 01-a/home-light.png " "$(files)"
first=$(tip)
check "first push has no parent" "" "$(git --git-dir="$work/remote.git" rev-parse --verify --quiet "$first^" || true)"

check "second push: exit 0" 0 "$(run --folder 02-b --from "$work/shots")"
check "second push keeps the old folder" "01-a/home-dark.png 01-a/home-light.png 02-b/home-dark.png 02-b/home-light.png " "$(files)"
check "second push sits on the old tip" "$first" "$(git --git-dir="$work/remote.git" rev-parse "$(tip)^")"
second=$(tip)

check "existing folder: exit 3" 3 "$(run --folder 01-a --from "$work/shots")"
check "existing folder: branch unchanged" "$second" "$(tip)"
check "no png: exit 3" 3 "$(run --folder 03-c --from "$work/empty")"
check "no png: branch unchanged" "$second" "$(tip)"
check "folder with a slash: exit 2" 2 "$(run --folder ../x --from "$work/shots")"
check "folder dot dot: exit 2" 2 "$(run --folder .. --from "$work/shots")"
check "missing folder: exit 2" 2 "$(run --from "$work/shots")"
check "unreachable remote: exit 1" 1 "$(run --folder 04-d --from "$work/shots" --remote "$work/nothing.git")"
check "bad input: branch unchanged" "$second" "$(tip)"

printf -- '---\nscreenshot_branch:\n---\n' > "$repo/.claude/agentic-delivery.md"
check "empty screenshot_branch: exit 3" 3 "$(run --folder 05-e --from "$work/shots")"
check "empty screenshot_branch: branch unchanged" "$second" "$(tip)"

finish
