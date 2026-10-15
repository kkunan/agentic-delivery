#!/bin/bash
set -euo pipefail

usage() { echo "usage: push-screenshots.sh --folder <name> --from <dir> [--remote <name>]" >&2; exit 2; }

folder=""; from=""; remote=origin
while [ $# -gt 0 ]; do
    case $1 in
        --folder) [ $# -ge 2 ] || usage; folder=$2; shift 2 ;;
        --from) [ $# -ge 2 ] || usage; from=$2; shift 2 ;;
        --remote) [ $# -ge 2 ] || usage; remote=$2; shift 2 ;;
        *) usage ;;
    esac
done
[ -n "$folder" ] && [ -n "$from" ] || usage
case $folder in
    .|..|*[!A-Za-z0-9._-]*) echo "push-screenshots: the folder name must be one plain path part, not '$folder'" >&2; exit 2 ;;
esac

here=$(cd "$(dirname "$0")" && pwd -P)
branch=$(bash "$here/project-config.sh" screenshot_branch "")
[ -n "$branch" ] || { echo "push-screenshots: screenshot_branch is empty in the project file" >&2; exit 3; }

shopt -s nullglob
shots=("$from"/*.png)
[ ${#shots[@]} -gt 0 ] || { echo "push-screenshots: no .png file in $from" >&2; exit 3; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export GIT_INDEX_FILE="$work/index"

set +e
line=$(git ls-remote --exit-code --heads "$remote" "refs/heads/$branch")
rc=$?
set -e
tip=""
if [ $rc -eq 0 ]; then
    tip=${line%%[[:space:]]*}
    git fetch -q "$remote" "refs/heads/$branch"
    git cat-file -e "$tip^{commit}" || { echo "push-screenshots: the fetch did not bring $tip" >&2; exit 1; }
    if git cat-file -e "$tip:$folder" 2>/dev/null; then
        echo "push-screenshots: $folder already exists on $branch" >&2
        exit 3
    fi
    git read-tree "$tip"
elif [ $rc -ne 2 ]; then
    echo "push-screenshots: cannot read $remote" >&2
    exit 1
fi

for f in "${shots[@]}"; do
    blob=$(git hash-object -w -- "$f")
    git update-index --add --cacheinfo "100644,$blob,$folder/$(basename "$f")"
done
tree=$(git write-tree)
c=$(git commit-tree "$tree" ${tip:+-p "$tip"} -m "$folder screenshots")
c=$(git rev-parse --verify --quiet "$c^{commit}") || c=""
[ -n "$c" ] || { echo "refused: no commit id, and a push of an empty id deletes the branch" >&2; exit 1; }
parent=$(git rev-parse --verify --quiet "$c^" || true)
[ "$parent" = "$tip" ] || { echo "refused: the commit does not sit on the remote tip" >&2; exit 1; }

git push -q "$remote" "$c:refs/heads/$branch"
echo "pushed $c to $branch: ${#shots[@]} files in $folder/"
