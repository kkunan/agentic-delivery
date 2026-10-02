#!/bin/sh
set -u

LOCKS=${APP_DEVICE_LOCK_DIR:-$HOME/Library/Caches/app-device-locks}

usage() {
    echo "usage: scripts/claim-device.sh --udid <simulator UDID> [--release] [--worktree <path>]" >&2
    exit 2
}

UDID=""
TREE=""
RELEASE=0
while [ $# -gt 0 ]; do
    case "$1" in
        --udid) [ $# -ge 2 ] || usage; UDID=$2; shift 2 ;;
        --worktree) [ $# -ge 2 ] || usage; TREE=$2; shift 2 ;;
        --release) RELEASE=1; shift ;;
        *) usage ;;
    esac
done
[ -n "$UDID" ] || usage

UPPER=$(printf '%s' "$UDID" | tr '[:lower:]' '[:upper:]')
if ! printf '%s' "$UPPER" | grep -Eq '^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$'; then
    echo "claim-device: '$UDID' is not a simulator UDID. Pass exactly one 36-character UDID." >&2
    exit 4
fi

[ -n "$TREE" ] || TREE=$(dirname "$0")/..
if ! TREE=$(cd "$TREE" 2>/dev/null && pwd -P); then
    echo "claim-device: the worktree does not exist." >&2
    exit 4
fi

if ! mkdir -p "$LOCKS" 2>/dev/null; then
    echo "claim-device: cannot create the lock folder $LOCKS." >&2
    exit 3
fi
LOCK="$LOCKS/$UPPER"

holder() {
    [ -f "$LOCK" ] && cat "$LOCK" || true
}

write_lock() {
    ( set -C; printf '%s\n' "$TREE" > "$LOCK" ) 2>/dev/null
}

HOLDER=$(holder)

if [ "$RELEASE" -eq 1 ]; then
    if [ -z "$HOLDER" ]; then
        echo "claim-device: $UPPER is not held."
        exit 0
    fi
    if [ "$HOLDER" != "$TREE" ]; then
        echo "claim-device: $UPPER is held by $HOLDER, not by $TREE. Nothing released." >&2
        exit 5
    fi
    rm -f "$LOCK"
    echo "claim-device: released $UPPER."
    exit 0
fi

if [ -z "$HOLDER" ]; then
    if write_lock; then
        echo "claim-device: $TREE now holds $UPPER."
        exit 0
    fi
    HOLDER=$(holder)
fi

if [ "$HOLDER" = "$TREE" ]; then
    echo "claim-device: $TREE already holds $UPPER."
    exit 0
fi

if [ -n "$HOLDER" ] && [ -d "$HOLDER" ]; then
    echo "claim-device: $UPPER is held by $HOLDER. Create your own device of the same type and runtime, or wait until that ticket releases it." >&2
    exit 5
fi

rm -f "$LOCK"
if write_lock; then
    echo "claim-device: $TREE now holds $UPPER. The last holder, $HOLDER, no longer exists."
    exit 0
fi
echo "claim-device: another worktree claimed $UPPER at the same moment. It is held by $(holder)." >&2
exit 5
