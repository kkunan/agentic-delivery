python=/usr/bin/python3
child=""
step="start"
current_label="-"
labels=()
files=()
tests=()

refuse() {
    printf 'mutate: REFUSED: %s\n' "$*" >&2
    exit 2
}

helper() {
    "$python" -B "$self_dir/mutate/mutate.py" "$@"
}

refuse_after_helper() {
    [ "$1" -eq 4 ] && exit 2
    printf 'mutate: the helper failed with exit %s\n' "$1" >&2
    exit 2
}

# ── Arguments ─────────────────────────────────────────────────────────────

parse_args() {
    manifest=""; out=""; runner=""
    while [ $# -gt 0 ]; do
        case "$1" in
            --manifest) manifest=${2:-}; shift 2 || refuse "--manifest needs a value" ;;
            --out) out=${2:-}; shift 2 || refuse "--out needs a value" ;;
            --runner) runner=${2:-}; shift 2 || refuse "--runner needs a value"; [ -n "$runner" ] || refuse "--runner needs a value" ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; refuse "unknown argument $1" ;;
        esac
    done
    check_args
}

check_args() {
    [ -n "$manifest" ] || refuse "--manifest is required"
    [ -n "$out" ] || refuse "--out is required"
    repo=$(git rev-parse --show-toplevel 2>/dev/null) || refuse "the current directory is not in a git worktree"
    repo=$(cd "$repo" && pwd -P)
    gitdir=$(git rev-parse --absolute-git-dir) || refuse "cannot find the git folder"
    find_runner
    mkdir -p "$out" || refuse "cannot create $out"
    out=$(cd "$out" && pwd -P)
    journal="$gitdir/mutate-in-progress"
}

find_runner() {
    if [ -z "$runner" ]; then
        runner=$(bash "$self_dir/project-config.sh" mutation_runner 2>/dev/null) && [ -n "$runner" ] \
            || refuse "no runner: pass --runner <path>, or set mutation_runner in $repo/.claude/agentic-delivery.md"
    fi
    case "$runner" in
        /*) ;;
        *) runner="$repo/$runner" ;;
    esac
    [ -f "$runner" ] || refuse "the runner $runner is not a file"
    [ -x "$runner" ] || refuse "the runner $runner is not executable"
}

# ── The lock ──────────────────────────────────────────────────────────────

take_lock() {
    lock="$gitdir/mutate.lock"
    if mkdir "$lock" 2>/dev/null; then
        printf '%s' "$out" > "$lock/out"
        echo $$ > "$lock/pid"
        trap release_lock EXIT
        return
    fi
    [ -f "$lock/pid" ] || refuse "$lock exists and holds no pid; delete it if no run is starting"
    local holder old_out
    holder=$(cat "$lock/pid")
    kill -0 "$holder" 2>/dev/null && refuse "another run, pid $holder, holds $lock"
    printf 'mutate: pid %s is dead; taking over %s\n' "$holder" "$lock"
    if [ -f "$lock/out" ]; then
        old_out=$(cat "$lock/out")
        printf 'mutate: if that run was killed hard, its runner can still run: pgrep -f %s\n' "$old_out"
    else
        printf "mutate: if that run was killed hard, its runner can still run, but the old run's output folder is unknown\n"
    fi
    printf '%s' "$out" > "$lock/out"
    echo $$ > "$lock/pid"
    trap release_lock EXIT
}

release_lock() {
    [ "$(cat "$lock/pid" 2>/dev/null)" = "$$" ] && rm -rf "$lock"
}

# ── Freezing the list ─────────────────────────────────────────────────────

freeze_list() {
    local err
    err=$(cp -f -- "$manifest" "$lock/list.json" 2>&1) || refuse "cannot read the list $manifest: $err"
    manifest="$lock/list.json"
}

# ── The list and the evidence ─────────────────────────────────────────────

read_list() {
    local listing label file test
    listing=$(helper validate "$manifest" "$repo" "$self_dir") || refuse_after_helper $?
    while IFS=$'\t' read -r label file test; do
        labels+=("$label"); files+=("$file"); tests+=("$test")
    done <<< "$listing"
}

check_evidence() {
    local label found=""
    for label in "${labels[@]}"; do
        [ -e "$out/mutant-$label.json" ] && found="$found $out/mutant-$label.json"
        [ -e "$out/mutant-$label.log" ] && found="$found $out/mutant-$label.log"
    done
    [ -z "$found" ] || refuse "these already exist; delete them by hand to re-run:$found"
}

# ── Running the runner ────────────────────────────────────────────────────

run_tests() {
    local result=$1 log=$2
    shift 2
    set -m
    "$runner" --out "$result" --log "$log" -- "$@" < /dev/null >&2 &
    child=$!
    set +m
    wait "$child"
    test_exit=$?
    child=""
}

distinct_tests() {
    local t seen=$'\n'
    for t in "${tests[@]}"; do
        case "$seen" in *$'\n'"$t"$'\n'*) ;; *) seen="$seen$t"$'\n'; printf '%s\n' "$t" ;; esac
    done
}

run_baseline() {
    local stamp names=() name problems
    stamp=$(date +%Y%m%d-%H%M%S)-$$
    [ -e "$out/baseline-$stamp.json" ] && refuse "$out/baseline-$stamp.json already exists"
    [ -e "$out/baseline-$stamp.log" ] && refuse "$out/baseline-$stamp.log already exists"
    while IFS= read -r name; do names+=("$name"); done < <(distinct_tests)
    step="baseline"
    run_tests "$out/baseline-$stamp.json" "$out/baseline-$stamp.log" "${names[@]}"
    problems=$(helper baseline "$test_exit" "$out/baseline-$stamp.json" "${names[@]}")
    [ $? -eq 0 ] || refuse "the baseline did not pass on the unmodified tree:"$'\n'"$problems"
    printf 'baseline: %s test id(s) passed on the unmodified tree\n' "${#names[@]}"
}

# ── One mutation ──────────────────────────────────────────────────────────

run_mutation() {
    local i=$1 result
    current_label=${labels[$i]}
    result="$out/mutant-$current_label.json"
    if [ -e "$result" ]; then
        record "$i" error "result file appeared before the call"
        return
    fi
    step="apply"
    helper apply "$manifest" "$repo" "$journal" "$current_label" || stop_run "apply failed"
    step="test"
    run_tests "$result" "$out/mutant-$current_label.log" "${tests[$i]}"
    step="revert"
    helper recover "$repo" "$journal" --quiet || stop_run "the revert did not restore ${files[$i]}"
    step="verdict"
    local said
    said=$(helper verdict "$test_exit" "$result" "${tests[$i]}") || said=$'error\tthe verdict helper failed'
    record "$i" "${said%%$'\t'*}" "${said#*$'\t'}"
}

stop_run() {
    printf 'mutate: STOPPED during %s of %s: %s\n' "$step" "$current_label" "$1" >&2
    [ "$step" = apply ] && helper recover "$repo" "$journal" --interrupted >&2
    exit 3
}

# ── Signals ───────────────────────────────────────────────────────────────

stop_child() {
    [ -n "$child" ] || return 0
    kill -TERM -- "-$child" 2>/dev/null
    local waited=0 polls=${MUTATE_STOP_POLLS:-50}
    while kill -0 "$child" 2>/dev/null && [ "$waited" -lt "$polls" ]; do
        sleep 0.2
        waited=$((waited + 1))
    done
    kill -KILL -- "-$child" 2>/dev/null
    wait "$child" 2>/dev/null
    child=""
}

on_signal() {
    local code=$1 name=$2 said
    trap '' INT TERM HUP
    stop_child
    said=$(helper recover "$repo" "$journal" --interrupted) || {
        printf 'mutate: INTERRUPTED by %s during %s of %s, and recovery refused\n' "$name" "$step" "$current_label" >&2
        exit 3
    }
    printf 'mutate: INTERRUPTED by %s during %s of %s: %s\n' "$name" "$step" "$current_label" "${said:-nothing to restore}" >&2
    exit "$code"
}
