#!/bin/sh
set -u

CLAIM=$(cd "$(dirname "$0")/../scripts" && pwd)/claim-device.sh
PASS=0
FAIL=0

check() {
    NAME=$1; EXPECTED=$2; ACTUAL=$3
    if [ "$EXPECTED" = "$ACTUAL" ]; then
        PASS=$((PASS + 1))
        echo "ok   $NAME"
    else
        FAIL=$((FAIL + 1))
        echo "FAIL $NAME: expected [$EXPECTED], got [$ACTUAL]"
    fi
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
WORK=$(cd "$WORK" && pwd -P)
mkdir -p "$WORK/tree-a" "$WORK/tree-b" "$WORK/tree-c"
export APP_DEVICE_LOCK_DIR="$WORK/locks"

DEVICE=00000000-0000-4000-8000-000000000001
LOCK="$APP_DEVICE_LOCK_DIR/$DEVICE"

claim() {
    "$CLAIM" "$@" > "$WORK/out" 2> "$WORK/err"
    echo $?
}

held_by() { [ -f "$LOCK" ] && cat "$LOCK" || echo "free"; }

check "a free device is claimed" 0 "$(claim --udid $DEVICE --worktree "$WORK/tree-a")"
check "the lock names the claiming worktree" "$WORK/tree-a" "$(held_by)"
check "the holder claims again" 0 "$(claim --udid $DEVICE --worktree "$WORK/tree-a")"
check "another live worktree is refused" 5 "$(claim --udid $DEVICE --worktree "$WORK/tree-b")"
check "the refusal names the holder" 1 "$(grep -c "held by $WORK/tree-a" "$WORK/err")"
check "a refusal leaves the lock alone" "$WORK/tree-a" "$(held_by)"
check "the same device in lower case is refused" 5 "$(claim --udid "$(echo $DEVICE | tr 'A-Z' 'a-z')" --worktree "$WORK/tree-b")"
check "another worktree cannot release it" 5 "$(claim --udid $DEVICE --worktree "$WORK/tree-b" --release)"
check "a failed release leaves the lock alone" "$WORK/tree-a" "$(held_by)"
check "the holder releases it" 0 "$(claim --udid $DEVICE --worktree "$WORK/tree-a" --release)"
check "a release frees the device" free "$(held_by)"
check "releasing a free device succeeds" 0 "$(claim --udid $DEVICE --worktree "$WORK/tree-a" --release)"

claim --udid $DEVICE --worktree "$WORK/tree-a" > /dev/null
rmdir "$WORK/tree-a"
check "a removed holder's lock is taken over" 0 "$(claim --udid $DEVICE --worktree "$WORK/tree-b")"
check "the takeover names the new holder" "$WORK/tree-b" "$(held_by)"
check "the new holder then refuses a third worktree" 5 "$(claim --udid $DEVICE --worktree "$WORK/tree-c")"

check "a device name is refused" 4 "$(claim --udid "iPhone 17 Pro" --worktree "$WORK/tree-c")"
check "booted is refused" 4 "$(claim --udid booted --worktree "$WORK/tree-c")"
check "a missing worktree is refused" 4 "$(claim --udid $DEVICE --worktree "$WORK/no-such-tree")"
check "an unusable lock folder fails closed" 3 "$(APP_DEVICE_LOCK_DIR=/dev/null/locks claim --udid $DEVICE --worktree "$WORK/tree-c")"
check "no arguments exits 2" 2 "$(claim)"
check "a flag without its value exits 2" 2 "$(claim --udid)"

echo "claim-device self-test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
