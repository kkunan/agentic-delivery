#!/usr/bin/env bash
set -uo pipefail

repo=$(git rev-parse --show-toplevel) || exit 2
cd "$repo" || exit 2

cost_rule_from=2026-09-28

fails=0
report() {
    if [ "$1" = "pass" ]; then
        printf 'PASS  %s\n' "$2"
    else
        printf 'FAIL  %s\n      %s\n' "$2" "$3"
        fails=$((fails + 1))
    fi
}

branch=$(git rev-parse --abbrev-ref HEAD)
case "$branch" in
    feature/*) slug=${branch#feature/} ;;
    *) printf 'FAIL  branch\n      on %s, not a feature/* branch\n' "$branch"; exit 1 ;;
esac

fetch_err=$(git fetch -q origin 2>&1); fetch_rc=$?

pr=$(gh pr view --json number,isDraft,body,baseRefName 2>/dev/null)
pr_base=$(printf '%s' "$pr" | jq -r '.baseRefName // ""' 2>/dev/null)
if [ -n "${READY_CHECK_BASE:-}" ]; then
    base=$READY_CHECK_BASE
    base_from="READY_CHECK_BASE"
elif [ -n "$pr_base" ]; then
    base="origin/$pr_base"
    base_from="the pull request"
else
    base=origin/develop
    base_from="the default; no pull request found"
fi
printf 'base  %s (from %s), %s commits on this branch\n\n' "$base" "$base_from" "$(git rev-list --count --first-parent "$base..HEAD" 2>/dev/null || echo '?')"

# ── 1. base merged into this branch ───────────────────────────────────────
if [ "$fetch_rc" -ne 0 ]; then
    report fail "base merged in" "git fetch origin failed, so $base may be stale: ${fetch_err:-no output}"
elif ! git rev-parse --verify -q "$base" >/dev/null; then
    report fail "base merged in" "$base does not resolve"
elif git merge-base --is-ancestor "$base" HEAD; then
    report pass "base merged in"
else
    behind=$(git rev-list --count "HEAD..$base")
    report fail "base merged in" "$base has $behind commit(s) this branch never merged; merge it and re-run the suite"
fi

# ── 2. tree clean and pushed ──────────────────────────────────────────────
dirty=$(git status --porcelain)
if [ -n "$dirty" ]; then
    report fail "working tree committed" "uncommitted: $(printf '%s' "$dirty" | awk '{printf "%s ", $NF}')"
else
    report pass "working tree committed"
fi

local_head=$(git rev-parse HEAD)
remote_head=$(git rev-parse "origin/$branch" 2>/dev/null || echo none)
if [ "$local_head" = "$remote_head" ]; then
    report pass "branch pushed"
else
    report fail "branch pushed" "local $(git rev-parse --short HEAD) is not origin/$branch"
fi

# ── 3. ledger covers every commit ─────────────────────────────────────────
ledger_dir=""
for d in .superpowers/sdd/*-"$slug"; do
    [ -d "$d" ] && ledger_dir="$d"
done
if [ -z "$ledger_dir" ]; then
    report fail "ledger present" "no .superpowers/sdd/<date>-$slug under $repo; run this where the ledger is"
else
    progress="$ledger_dir/progress.md"
    if [ ! -f "$progress" ]; then
        report fail "ledger present" "$ledger_dir has no progress.md"
    else
        report pass "ledger present"
        missing=""
        while read -r sha; do
            [ -n "$sha" ] || continue
            grep -qF "$sha" "$progress" || missing="$missing $sha"
        done < <(git log --first-parent "$base..HEAD" --format=%h)
        if [ -n "$missing" ]; then
            report fail "ledger names every commit" "absent from progress.md:$missing"
        else
            report pass "ledger names every commit"
        fi

        # ── 4. cost lines, on runs started after the rule ─────────────────
        started=$(basename "$ledger_dir" | cut -c1-10)
        if ! [[ "$started" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            report fail "cost lines" "cannot read a start date from $(basename "$ledger_dir")"
        elif [[ "$started" < "$cost_rule_from" ]]; then
            printf 'SKIP  cost lines\n      ledger started %s, before the rule took effect on %s\n' "$started" "$cost_rule_from"
        else
            cost_lines=$(grep -iE '^[[:space:]]*(- )?cost:' "$progress")
            shape='^[[:space:]]*(- )?cost: [^ ]+ (spec|plan|T[0-9]+[a-z]?|final|ship) tokens=[0-9]+k minutes=[0-9]+ fix_rounds=[0-9]+[[:space:]]*$'
            bad=$(printf '%s\n' "$cost_lines" | grep -vE "$shape" | grep -v '^$')
            absent=""
            for phase in spec plan final; do
                printf '%s\n' "$cost_lines" | grep -qE "cost: [^ ]+ $phase " || absent="$absent $phase"
            done
            printf '%s\n' "$cost_lines" | grep -qE 'cost: [^ ]+ T[0-9]+[a-z]? ' || absent="$absent T<n>"
            if [ -n "$bad" ]; then
                report fail "cost lines" "not in the shape 'cost: <ticket> <phase> tokens=<n>k minutes=<n> fix_rounds=<n>': $(printf '%s' "$bad" | head -3 | tr '\n' '|')"
            elif [ -n "$absent" ]; then
                report fail "cost lines" "no cost line for:$absent"
            else
                report pass "cost lines ($(printf '%s\n' "$cost_lines" | grep -c .) phases)"
            fi
        fi
    fi

    # ── 5. QA session log, with no un-run check ───────────────────────────
    qa_log=$(ls "$ledger_dir"/qa-session-log*.md 2>/dev/null | head -1)
    if [ -z "$qa_log" ]; then
        report fail "QA session log" "no qa-session-log*.md in $ledger_dir"
    else
        tally=$(grep -iE '^tally:' "$qa_log" | tail -1)
        if [ -z "$tally" ]; then
            report fail "QA tally line" "$qa_log has no line starting 'tally:'. It must end with: tally: N checks, N run, 0 unrun, 0 waived"
        else
            set -- $(printf '%s' "$tally" | tr -cd '0-9 ' | tr -s ' ')
            total=${1:-x}; run=${2:-x}; unrun=${3:-x}; waived=${4:-x}
            if [ "$total" = x ] || [ "$waived" = x ]; then
                report fail "QA tally line" "cannot read four numbers from: $tally"
            elif [ "$unrun" != 0 ]; then
                report fail "every manual check ran" "$unrun unrun ($tally)"
            elif [ "$waived" != 0 ]; then
                waivers=$(grep -iE '^[[:space:]]*(- )?waiver: [^ ]+ by (the )?owner on [0-9]{4}-[0-9]{2}-[0-9]{2}' "$progress" 2>/dev/null)
                granted=$(printf '%s' "$waivers" | grep -c .)
                if [ "$granted" -lt "$waived" ]; then
                    report fail "no check waived" "$waived waived, $granted waiver line(s) in progress.md; each needs 'waiver: <check> by owner on <YYYY-MM-DD>: <reason>' ($tally)"
                elif [ $((run + waived)) != "$total" ]; then
                    report fail "every manual check ran" "$run run and $waived waived of $total ($tally)"
                else
                    report pass "every manual check ran or was waived ($run run, $waived waived: $(printf '%s\n' "$waivers" | sed -E 's/.*[Ww][Aa][Ii][Vv][Ee][Rr]: ([^ ]+).*/\1/' | tr '\n' ' '))"
                fi
            elif [ "$run" != "$total" ]; then
                report fail "every manual check ran" "$run of $total run ($tally)"
            else
                report pass "every manual check ran ($total checks)"
            fi
        fi
    fi
fi

# ── 6. pull request ───────────────────────────────────────────────────────
if [ -z "$pr" ]; then
    report fail "pull request open" "gh pr view found no PR for $branch"
else
    body=$(printf '%s' "$pr" | jq -r '.body // ""')
    if [ "${#body}" -lt 200 ]; then
        report fail "PR description rewritten" "body is ${#body} characters"
    else
        report pass "PR description rewritten"
    fi
    swift=$(git diff --name-only "$base...HEAD" | grep -cE '\.swift$' || true)
    if [ "$swift" -eq 0 ]; then
        printf 'SKIP  PR links screenshots\n      no Swift source changed on this branch\n'
    elif printf '%s' "$body" | grep -q 'assets/screenshots'; then
        report pass "PR links screenshots"
    elif printf '%s' "$body" | grep -qiE '^no screen changed\.'; then
        printf 'PASS  no screenshots, asserted\n      the PR body states no screen changed; that is your claim, not a measurement\n'
    else
        report fail "PR links screenshots" "$swift Swift file(s) changed and the PR body has neither an assets/screenshots URL nor a line reading: No screen changed."
    fi
fi

printf '\n'
if [ "$fails" -eq 0 ]; then
    printf 'ready-check: pass. Mark the PR ready, then move the ticket to review.\n'
    exit 0
fi
printf 'ready-check: %d failed. The PR is not ready. Fix these, or ask me to waive one.\n' "$fails"
exit 1
