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
export AGENTIC_DEVICE_LOCK_DIR="$WORK/locks"

DEVICE=00000000-0000-4000-8000-000000000001
LOCK="$AGENTIC_DEVICE_LOCK_DIR/$DEVICE"

claim() {
    "$CLAIM" "$@" > "$WORK/out" 2> "$WORK/err"
    echo $?
}

held_by() { [ -f "$LOCK" ] && cat "$LOCK" || echo "free"; }

check "a free device is claimed" 0 "$(claim --device $DEVICE --worktree "$WORK/tree-a")"
check "the lock names the claiming worktree" "$WORK/tree-a" "$(held_by)"
check "the holder claims again" 0 "$(claim --device $DEVICE --worktree "$WORK/tree-a")"
check "another live worktree is refused" 5 "$(claim --device $DEVICE --worktree "$WORK/tree-b")"
check "the refusal names the holder" 1 "$(grep -c "held by $WORK/tree-a" "$WORK/err")"
check "a refusal leaves the lock alone" "$WORK/tree-a" "$(held_by)"
check "the same device in lower case is refused" 5 "$(claim --device "$(echo $DEVICE | tr 'A-Z' 'a-z')" --worktree "$WORK/tree-b")"
check "another worktree cannot release it" 5 "$(claim --device $DEVICE --worktree "$WORK/tree-b" --release)"
check "a failed release leaves the lock alone" "$WORK/tree-a" "$(held_by)"
check "the holder releases it" 0 "$(claim --device $DEVICE --worktree "$WORK/tree-a" --release)"
check "a release frees the device" free "$(held_by)"
check "releasing a free device succeeds" 0 "$(claim --device $DEVICE --worktree "$WORK/tree-a" --release)"

claim --device $DEVICE --worktree "$WORK/tree-a" > /dev/null
rmdir "$WORK/tree-a"
check "a removed holder's lock is taken over" 0 "$(claim --device $DEVICE --worktree "$WORK/tree-b")"
check "the takeover names the new holder" "$WORK/tree-b" "$(held_by)"
check "the new holder then refuses a third worktree" 5 "$(claim --device $DEVICE --worktree "$WORK/tree-c")"

check "a device name is refused" 4 "$(claim --device "iPhone 17 Pro" --worktree "$WORK/tree-c")"
check "an emulator id is accepted" 0 "$(claim --device emulator-5554 --worktree "$WORK/tree-c")"
check "chrome is accepted" 0 "$(claim --device chrome --worktree "$WORK/tree-c")"
check "a path in an id is refused" 4 "$(claim --device ../x --worktree "$WORK/tree-c")"
check "a dot-dot id is refused" 4 "$(claim --device .. --worktree "$WORK/tree-c")"
check "a missing worktree is refused" 4 "$(claim --device $DEVICE --worktree "$WORK/no-such-tree")"
check "an unusable lock folder fails closed" 3 "$(AGENTIC_DEVICE_LOCK_DIR=/dev/null/locks claim --device $DEVICE --worktree "$WORK/tree-c")"
check "no arguments exits 2" 2 "$(claim)"
check "a flag without its value exits 2" 2 "$(claim --device)"

echo "claim-device self-test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
