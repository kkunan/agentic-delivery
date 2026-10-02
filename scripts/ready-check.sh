#!/usr/bin/env bash
set -uo pipefail

repo=$(git rev-parse --show-toplevel) || exit 2
cd "$repo" || exit 2

reader="$(cd "$(dirname "$0")" && pwd -P)/project-config.sh"

# ── project file values ───────────────────────────────────────────────────
branch_prefix=$(bash "$reader" branch_prefix) || exit $?
base_branch=$(bash "$reader" base_branch) || exit $?
docs_dir=$(bash "$reader" docs_dir) || exit $?
view_globs=$(bash "$reader" view_globs) || exit $?
screenshot_branch=$(bash "$reader" screenshot_branch) || exit $?
docs=$(bash "$reader" docs repo) || exit $?

docs_dir=${docs_dir%/}
case "$docs_dir" in
    /*) ledger_root=$docs_dir ;;
    *)
        if [ "$docs" = private ]; then
            printf 'FAIL  docs_dir\n      docs is private, so docs_dir must be an absolute path, not %s\n' "$docs_dir"
            exit 1
        fi
        ledger_root="$repo/$docs_dir"
        ;;
esac

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
    "$branch_prefix"*) slug=${branch#"$branch_prefix"} ;;
    *) printf 'FAIL  branch\n      on %s, not a %s* branch\n' "$branch" "$branch_prefix"; exit 1 ;;
esac

fetch_err=$(git fetch -q origin 2>&1); fetch_rc=$?

if [ "${READY_CHECK_SKIP_PR:-}" = 1 ]; then
    pr=""
else
    pr=$(gh pr view --json number,isDraft,body,baseRefName 2>/dev/null)
fi
pr_base=$(printf '%s' "$pr" | jq -r '.baseRefName // ""' 2>/dev/null)
if [ -n "${READY_CHECK_BASE:-}" ]; then
    base=$READY_CHECK_BASE
    base_from="READY_CHECK_BASE"
elif [ -n "$pr_base" ]; then
    base="origin/$pr_base"
    base_from="the pull request"
else
    base="origin/$base_branch"
    base_from="base_branch in the project file"
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
for d in "$ledger_root"/*-"$slug"; do
    [ -d "$d" ] && ledger_dir="$d"
done
if [ -z "$ledger_dir" ]; then
    report fail "ledger present" "no $ledger_root/<date>-$slug; check docs_dir in the project file, or run this where the ledger is"
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

        # ── 4. cost lines ─────────────────────────────────────────────────
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
                waivers=$(grep -iE '^[[:space:]]*(- )?waiver: [^ ]+ by (the )?(gate )?owner on [0-9]{4}-[0-9]{2}-[0-9]{2}' "$progress" 2>/dev/null)
                granted=$(printf '%s' "$waivers" | grep -c .)
                if [ "$granted" -lt "$waived" ]; then
                    report fail "no check waived" "$waived waived, $granted waiver line(s) in progress.md; each needs 'waiver: <check> by gate owner on <YYYY-MM-DD>: <reason>' ($tally)"
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
if [ "${READY_CHECK_SKIP_PR:-}" = 1 ]; then
    printf 'SKIP  PR description rewritten\n      READY_CHECK_SKIP_PR=1\n'
    printf 'SKIP  PR links screenshots\n      READY_CHECK_SKIP_PR=1\n'
elif [ -z "$pr" ]; then
    report fail "pull request open" "gh pr view found no PR for $branch"
else
    body=$(printf '%s' "$pr" | jq -r '.body // ""')
    if [ "${#body}" -lt 200 ]; then
        report fail "PR description rewritten" "body is ${#body} characters"
    else
        report pass "PR description rewritten"
    fi
    IFS=',' read -r -a view_patterns <<< "$view_globs"
    views=0
    while read -r changed; do
        [ -n "$changed" ] || continue
        for pattern in "${view_patterns[@]}"; do
            case "$changed" in
                $pattern) views=$((views + 1)); break ;;
            esac
        done
    done < <(git diff --name-only "$base...HEAD")
    if [ "$views" -eq 0 ]; then
        printf 'SKIP  PR links screenshots\n      no file that matches view_globs changed on this branch\n'
    elif printf '%s' "$body" | tr ' ()<>[]"' '\n' | grep -F "/$screenshot_branch/" | grep -qE '^https?://'; then
        report pass "PR links screenshots"
    elif printf '%s' "$body" | grep -qiE '^no screen changed\.'; then
        printf 'PASS  no screenshots, asserted\n      the PR body states no screen changed; that is your claim, not a measurement\n'
    else
        report fail "PR links screenshots" "$views view file(s) changed and the PR body has neither a URL on the $screenshot_branch branch (a link that contains /$screenshot_branch/) nor a line reading: No screen changed."
    fi
fi

printf '\n'
if [ "$fails" -eq 0 ]; then
    printf 'ready-check: pass. Mark the PR ready, then move the ticket to review.\n'
    exit 0
fi
printf 'ready-check: %d failed. The PR is not ready. Fix these, or ask me to waive one.\n' "$fails"
exit 1
