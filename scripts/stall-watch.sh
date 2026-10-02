#!/bin/bash
set -uo pipefail

interval=60
idle_after=8
build_after=4
roots=""
procs=""
excludes=""
logs=""
max_polls=0

usage='usage: stall-watch.sh [--interval s] [--idle-after min] [--build-after min] [--roots "<paths>"] [--process <name>]... [--exclude <path>]... [--log <path>]... [--polls n]'

while [ $# -gt 0 ]; do
    case "$1" in
        --interval)    [ $# -ge 2 ] || { printf '%s\n' "$usage" >&2; exit 2; }; interval=$2; shift 2 ;;
        --idle-after)  [ $# -ge 2 ] || { printf '%s\n' "$usage" >&2; exit 2; }; idle_after=$2; shift 2 ;;
        --build-after) [ $# -ge 2 ] || { printf '%s\n' "$usage" >&2; exit 2; }; build_after=$2; shift 2 ;;
        --roots)       [ $# -ge 2 ] || { printf '%s\n' "$usage" >&2; exit 2; }; roots=$2; shift 2 ;;
        --process)     [ $# -ge 2 ] || { printf '%s\n' "$usage" >&2; exit 2; }; procs="$procs $2"; shift 2 ;;
        --exclude)     [ $# -ge 2 ] || { printf '%s\n' "$usage" >&2; exit 2; }; excludes="$excludes
$2"; shift 2 ;;
        --log)         [ $# -ge 2 ] || { printf '%s\n' "$usage" >&2; exit 2; }; logs="$logs
$2"; shift 2 ;;
        --polls)       [ $# -ge 2 ] || { printf '%s\n' "$usage" >&2; exit 2; }; max_polls=$2; shift 2 ;;
        *) printf '%s\n' "$usage" >&2; exit 2 ;;
    esac
done

if [ -z "${procs# }" ]; then
    reader="$(cd "$(dirname "$0")" && pwd -P)/project-config.sh"
    if list=$(bash "$reader" test_processes 2>/dev/null) && [ -n "$list" ]; then
        procs=$(printf '%s' "$list" | tr ',' ' ')
    else
        printf 'stall-watch: no process to watch. Refusing to start.\n' >&2
        printf '  Pass --process <name>, or set test_processes in .claude/agentic-delivery.md.\n' >&2
        exit 2
    fi
fi

if [ -z "$roots" ]; then
    main=$(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2; exit}')
    for _wt in $(git worktree list --porcelain 2>/dev/null | awk '/^worktree /{print $2}'); do
        [ "$_wt" = "${main:-}" ] && continue
        _skip=0
        while IFS= read -r _ex; do
            [ -n "$_ex" ] && [ "$_wt" = "$_ex" ] && _skip=1
        done <<EOF2
$excludes
EOF2
        [ "$_skip" -eq 1 ] || roots="$roots $_wt"
    done
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

first_root=""
for root in $roots; do
    first_root=$root
    break
done

disk_free() {
    df -g "$first_root" 2>/dev/null | awk 'NR == 2 && $4 ~ /^[0-9]+$/ { print $4; found = 1 } END { if (!found) print "?" }'
}

heartbeat() {
    _free=$(disk_free)
    emit "HEARTBEAT $* disk=${_free}G"
    case "$_free" in
        ''|*[!0-9]*) ;;
        *) [ "$_free" -lt 5 ] && emit "DISK LOW ${_free}G" ;;
    esac
}

heartbeat "armed, polling every ${interval}s, watching $live worktree(s): ${roots} processes:${procs}"
polls=0

while :; do
    if [ ! -d "$state" ]; then
        state=$(mktemp -d) || exit 2
        emit "WARN state directory vanished under the watch, recreated at $state"
    fi

    frozen_polls=$(( build_after * 60 / interval ))
    [ "$frozen_polls" -lt 1 ] && frozen_polls=1
    seen_procs=0
    for pname in $procs; do
        for pid in $(pgrep -x "$pname" 2>/dev/null); do
            cpu=$(ps -o time= -p "$pid" 2>/dev/null | tr -d ' ')
            [ -n "$cpu" ] || continue
            seen_procs=$((seen_procs + 1))
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
            if [ "$count" -ge "$frozen_polls" ] && [ ! -f "$state/reported.$pid" ]; then
                emit "BUILD FROZEN $pname pid $pid, cpu total stuck at $cpu across $count polls"
                : > "$state/reported.$pid"
            fi
        done
    done

    n=0
    while IFS= read -r log; do
        [ -n "$log" ] || continue
        n=$((n + 1))
        [ -f "$log" ] || continue
        size=$(stat -f %z "$log" 2>/dev/null)
        [ -n "$size" ] || continue
        f="$state/log.$n"
        prev=""; count=0
        if [ -f "$f" ]; then
            prev=$(sed -n 1p "$f"); count=$(sed -n 2p "$f")
        fi
        if [ "$size" = "$prev" ]; then
            count=$((count + 1))
        else
            count=0
            rm -f "$state/log-reported.$n"
        fi
        printf '%s\n%s\n' "$size" "$count" > "$f"
        if [ "$count" -ge "$frozen_polls" ] && [ ! -f "$state/log-reported.$n" ]; then
            emit "LOG STALLED $log"
            : > "$state/log-reported.$n"
        fi
    done <<EOF3
$logs
EOF3

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

    heartbeat "procs=$seen_procs"

    polls=$((polls + 1))
    [ "$max_polls" -gt 0 ] && [ "$polls" -ge "$max_polls" ] && exit 0

    sleep "$interval" &
    sleep_pid=$!
    wait "$sleep_pid" 2>/dev/null
    sleep_pid=""
done
