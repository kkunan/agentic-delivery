#!/usr/bin/env bash
set -uo pipefail

interval=60
idle_after=8
build_after=4
roots=""

while [ $# -gt 0 ]; do
    case "$1" in
        --interval)   interval=$2; shift 2 ;;
        --idle-after) idle_after=$2; shift 2 ;;
        --build-after) build_after=$2; shift 2 ;;
        --roots)      roots=$2; shift 2 ;;
        *) printf 'usage: stall-watch.sh [--interval s] [--idle-after min] [--build-after min] [--roots glob]\n' >&2; exit 2 ;;
    esac
done

if [ -z "$roots" ]; then
    main=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')
    roots=$(git worktree list --porcelain 2>/dev/null \
        | awk '/^worktree /{print $2}' \
        | grep -v -x -F "${main:-/dev/null}" \
        | grep -v '/\.tooling$' \
        | tr '\n' ' ')
fi

live=0
for root in $roots; do
    [ -d "$root" ] && live=$((live + 1))
done
if [ "$live" -eq 0 ]; then
    printf 'stall-watch: no worktree to watch. Refusing to start.\n' >&2
    printf '  Pass --roots, or run where `git worktree list` sees the run'"'"'s worktrees.\n' >&2
    printf '  A watch over nothing reports nothing and reads as covered.\n' >&2
    exit 2
fi

state=$(mktemp -d) || exit 2
sleep_pid=""
stop() {
    [ -n "$sleep_pid" ] && kill "$sleep_pid" 2>/dev/null
    emit "STOPPED by a signal, state directory removed"
    rm -rf "$state"
    exit 0
}
trap 'rm -rf "$state"' EXIT
trap stop INT TERM HUP

emit() { printf '%s %s\n' "$(date '+%H:%M:%S')" "$*"; }

working_in() {
    _root=$1
    for _pid in $(pgrep -f "$_root" 2>/dev/null); do
        _cwd=$(lsof -n -P -b -a -d cwd -F n -p "$_pid" 2>/dev/null | sed -n 's/^n//p' | head -1)
        [ -n "$_cwd" ] || continue
        case "$_cwd" in
            "$_root"|"$_root"/*) printf '%s' "$_pid"; return 0 ;;
        esac
    done
    return 0
}

emit "HEARTBEAT armed, polling every ${interval}s, watching $live worktree(s): ${roots}"

while :; do
    if [ ! -d "$state" ]; then
        state=$(mktemp -d) || exit 2
        emit "WARN state directory vanished under the watch, recreated at $state"
    fi

    seen_build=0
    for pid in $(pgrep -x xcodebuild 2>/dev/null); do
        cpu=$(ps -o time= -p "$pid" 2>/dev/null | tr -d ' ')
        [ -n "$cpu" ] || continue
        seen_build=1
        f="$state/build.$pid"
        prev=""; count=0
        if [ -f "$f" ]; then
            prev=$(sed -n 1p "$f"); count=$(sed -n 2p "$f")
        fi
        if [ "$cpu" = "$prev" ]; then
            count=$((count + 1))
        else
            count=0
            rm -f "$state/reported.$pid"
        fi
        printf '%s\n%s\n' "$cpu" "$count" > "$f"
        frozen_polls=$(( build_after * 60 / interval ))
        [ "$frozen_polls" -lt 1 ] && frozen_polls=1
        if [ "$count" -ge "$frozen_polls" ] && [ ! -f "$state/reported.$pid" ]; then
            emit "BUILD FROZEN pid $pid, cpu total stuck at $cpu across $count polls"
            : > "$state/reported.$pid"
        fi
    done

    for root in $roots; do
        [ -d "$root" ] || continue
        name=$(basename "$root")
        touched=$(find "$root" -type f -mmin -"$idle_after" -not -path '*/.git/*' 2>/dev/null | head -1)
        busy=$(working_in "$root")
        if [ -z "$touched" ] && [ -z "$busy" ]; then
            if [ ! -f "$state/idle.$name" ]; then
                emit "AGENT IDLE $name, no file written and no process for ${idle_after}m"
                : > "$state/idle.$name"
            fi
        else
            rm -f "$state/idle.$name"
        fi
    done

    emit "HEARTBEAT builds=$seen_build"

    sleep "$interval" &
    sleep_pid=$!
    wait "$sleep_pid" 2>/dev/null
    sleep_pid=""
done
