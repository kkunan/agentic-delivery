# ── The broken copies ─────────────────────────────────────────────────────

mutant_verdict() {
    local row=$1 red=$2 guard=r0_
    [ "$row" -eq 0 ] && guard=r7_
    case " $red " in *" r${row}_"*) ;; *) echo missed; return ;; esac
    case " $red " in *" $guard"*) echo "missed (guard row ${guard%_} also red)"; return ;; esac
    echo caught
}

run_mutant() {
    local index=$1 work=$2 list=$3 built name row red verdict
    built=$(/usr/bin/python3 -B "$selftest_dir/mutants.py" build "$list" "$index" \
        "$work/baseline" "$work/$index" "$RUNNER_FILES") || { echo "BROKEN  copy $index could not be built"; return 1; }
    name=${built%%$'\t'*}
    row=${built#*$'\t'}
    red=$(RUNNER_DIR="$work/$index" run_cases 2>&1 | awk '/^FAIL/ {sub(":", "", $2); print $2}' | tr '\n' ' ')
    verdict=$(mutant_verdict "$row" "$red")
    printf '%-8s %-32s row %-3s red: %s\n' "${verdict%% *}" "$name" "$row" "${red:-none}"
    [ "$verdict" = caught ]
}

build_baseline_copy() {
    local work=$1
    /usr/bin/python3 -B "$selftest_dir/mutants.py" baseline "$RUNNER_DIR" "$work/baseline" "$RUNNER_FILES"
}

print_tree_hashes() {
    local baseline_dir=$1 list=$2 f
    for f in $RUNNER_FILES; do
        printf 'mutants: sha256 %s %s\n' "$(shasum -a 256 "$baseline_dir/$f" | cut -d' ' -f1)" "$f"
    done
    printf 'mutants: sha256 %s %s\n' "$(shasum -a 256 "$list" | cut -d' ' -f1)" "mutate/selftest/mutants.json"
}

run_baseline_check() {
    local baseline_dir=$1 output rc n failed
    output=$(RUNNER_DIR="$baseline_dir" run_cases 2>&1)
    rc=$?
    n=$(printf '%s\n' "$output" | sed -n 's/^selftest: \([0-9]*\) cases,.*/\1/p')
    if [ "$rc" -ne 0 ]; then
        failed=$(printf '%s\n' "$output" | awk '/^FAIL/ {sub(":", "", $2); print $2}')
        printf 'mutants: the unchanged runner fails %s cases; fix that before judging copies:\n' \
            "$(printf '%s\n' "$failed" | grep -c .)"
        printf '%s\n' "$failed"
        return 2
    fi
    printf 'mutants: the unchanged runner passes %s cases\n' "$n"
}

run_mutants() {
    local work list count missed=0 i
    check_runner
    work=$(mktemp -d "${TMPDIR:-/tmp}/mutate-mutants.XXXXXX") || return 2
    list="$work/mutants.json"
    cp -- "$selftest_dir/mutants.json" "$list" || { echo "mutants: cannot freeze the mutants list" >&2; rm -rf "$work"; return 2; }
    count=$(/usr/bin/python3 -B "$selftest_dir/mutants.py" count "$list") || { rm -rf "$work"; return 2; }
    if [ "$count" -eq 0 ]; then
        printf 'mutants: %s has no entries to judge\n' "$selftest_dir/mutants.json" >&2
        rm -rf "$work"
        return 2
    fi
    build_baseline_copy "$work" || { echo "mutants: could not build the unchanged-runner baseline" >&2; rm -rf "$work"; return 2; }
    print_tree_hashes "$work/baseline" "$list"
    run_baseline_check "$work/baseline" || { rm -rf "$work"; return 2; }
    for ((i = 0; i < count; i++)); do
        run_mutant "$i" "$work" "$list" || missed=$((missed + 1))
    done
    rm -rf "$work"
    printf 'mutants: %s copies, %s caught, %s missed\n' "$count" "$((count - missed))" "$missed"
    [ "$missed" -eq 0 ]
}
