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
docs=$(bash "$reader" docs repo) || exit $?
forge=$(bash "$reader" forge auto) || exit $?

# ── forge: github or gitlab ───────────────────────────────────────────────
if [ "$forge" = auto ]; then
    origin_url=$(git config --get remote.origin.url 2>/dev/null)
    host=${origin_url#*://}
    host=${host#*@}
    host=${host%%[:/]*}
    case "$host" in
        *gitlab*) forge=gitlab ;;
        *) forge=github ;;
    esac
fi
case "$forge" in
    github) pr_word=PR; pr_name="pull request"; pr_cli=gh; pr_cmd="gh pr view" ;;
    gitlab) pr_word=MR; pr_name="merge request"; pr_cli=glab; pr_cmd="glab mr view" ;;
    *) printf 'FAIL  forge\n      forge must be github or gitlab, not %s\n' "$forge"; exit 1 ;;
esac

# GitLab takes images uploaded to the merge request, so the branch is optional there.
if [ "$forge" = gitlab ]; then
    screenshot_branch=$(bash "$reader" screenshot_branch "") || exit $?
else
    screenshot_branch=$(bash "$reader" screenshot_branch) || exit $?
fi

docs_dir=${docs_dir%/}
case "$docs_dir" in
    "~/"*) docs_dir="$HOME/${docs_dir#\~/}" ;;
esac
case "$docs_dir" in
    /*) ledger_root=$docs_dir ;;
    *)
        if [ "$docs" = private ]; then
            printf 'FAIL  docs_dir\n      docs is private, so docs_dir must be an absolute path or start with ~/, not %s\n' "$docs_dir"
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

# The pull request or merge request, as {base, body}, or empty.
pr=""
pr_err=""
if [ "${READY_CHECK_SKIP_PR:-}" != 1 ]; then
    if ! command -v "$pr_cli" >/dev/null 2>&1; then
        pr_err="$pr_cli is not installed or not on PATH"
    else
        err_file=$(mktemp)
        if [ "$forge" = gitlab ]; then
            raw=$(glab mr view --output json 2>"$err_file") &&
                pr=$(printf '%s' "$raw" | jq -c '{base: (.target_branch // ""), body: (.description // "")}' 2>/dev/null)
        else
            raw=$(gh pr view --json body,baseRefName 2>"$err_file") &&
                pr=$(printf '%s' "$raw" | jq -c '{base: (.baseRefName // ""), body: (.body // "")}' 2>/dev/null)
        fi
        [ -n "$pr" ] || pr_err="$pr_cmd found no $pr_name for $branch: $(head -1 "$err_file" | grep . || echo no output)"
        rm -f "$err_file"
    fi
fi
pr_base=$(printf '%s' "$pr" | jq -r '.base' 2>/dev/null)
if [ -n "${READY_CHECK_BASE:-}" ]; then
    base=$READY_CHECK_BASE
    base_from="READY_CHECK_BASE"
elif [ -n "$pr_base" ]; then
    base="origin/$pr_base"
    base_from="the $pr_name"
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
        ledger_rel=""
        case "$ledger_dir" in
            "$repo"/*) ledger_rel=${ledger_dir#"$repo"/} ;;
        esac
        missing=""
        while read -r sha full; do
            [ -n "$sha" ] || continue
            grep -qF "$sha" "$progress" && continue
            if [ -n "$ledger_rel" ]; then
                paths=$(git diff --name-only "$full^" "$full" 2>/dev/null)
                outside=$(printf '%s\n' "$paths" | awk -v p="$ledger_rel/" 'NF && index($0, p) != 1')
                [ -n "$paths" ] && [ -z "$outside" ] && continue
            fi
            missing="$missing $sha"
        done < <(git log --first-parent "$base..HEAD" --format='%h %H')
        if [ -n "$missing" ]; then
            report fail "ledger names every commit" "absent from progress.md:$missing"
        else
            report pass "ledger names every commit"
        fi

        # ── 4. cost lines ─────────────────────────────────────────────────
        cost_lines=$(grep -iE '^[[:space:]]*(- )?cost:' "$progress")
        shape='^[[:space:]]*(- )?cost: [^ ]+ (spec|plan|T[0-9]+[a-z]?|build|final|ship) tokens=[0-9]+k minutes=[0-9]+ fix_rounds=[0-9]+[[:space:]]*$'
        bad=$(printf '%s\n' "$cost_lines" | grep -vE "$shape" | grep -v '^$')
        absent=""
        if grep -qiE '^[[:space:]]*(- )?mode: lite[[:space:]]*$' "$progress"; then
            printf 'NOTE  lite mode\n      progress.md has a line reading mode: lite, so build and final replace spec, plan and T<n>\n'
            required="build final"
        else
            required="spec plan final"
        fi
        for phase in $required; do
            printf '%s\n' "$cost_lines" | grep -qE "cost: [^ ]+ $phase " || absent="$absent $phase"
        done
        if [ "$required" != "build final" ]; then
            printf '%s\n' "$cost_lines" | grep -qE 'cost: [^ ]+ T[0-9]+[a-z]? ' || absent="$absent T<n>"
        fi
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

# ── 6. pull request or merge request ──────────────────────────────────────
if [ "${READY_CHECK_SKIP_PR:-}" = 1 ]; then
    printf 'SKIP  %s description rewritten\n      READY_CHECK_SKIP_PR=1\n' "$pr_word"
    printf 'SKIP  %s links screenshots\n      READY_CHECK_SKIP_PR=1\n' "$pr_word"
elif [ -z "$pr" ]; then
    report fail "$pr_name open" "$pr_err"
else
    body=$(printf '%s' "$pr" | jq -r '.body')
    if [ "${#body}" -lt 200 ]; then
        report fail "$pr_word description rewritten" "body is ${#body} characters"
    else
        report pass "$pr_word description rewritten"
    fi
    IFS=',' read -r -a view_patterns <<< "$view_globs"
    views=0
    while read -r changed; do
        [ -n "$changed" ] || continue
        for pattern in "${view_patterns[@]}"; do
            pattern=${pattern#"${pattern%%[![:space:]]*}"}
            pattern=${pattern%"${pattern##*[![:space:]]}"}
            [ -n "$pattern" ] || continue
            case "$changed" in
                $pattern) views=$((views + 1)); break ;;
            esac
        done
    done < <(git diff --name-only "$base...HEAD")
    if [ "$views" -eq 0 ]; then
        printf 'SKIP  %s links screenshots\n      no file that matches view_globs changed on this branch\n' "$pr_word"
    else
        links=$(printf '%s' "$body" | tr ' ()<>[]"' '\n')
        branch_link=no
        upload_link=no
        branch_hint=""
        if [ -n "$screenshot_branch" ] && printf '%s\n' "$links" | grep -F "/$screenshot_branch/" | grep -qE '^https?://'; then
            branch_link=yes
        fi
        # An image uploaded to a GitLab merge request: /uploads/<32 hex>/<file>, relative or full.
        if [ "$forge" = gitlab ] && printf '%s\n' "$links" | grep -qE '(^|/)uploads/[0-9a-f]{32}/[^/]+$'; then
            upload_link=yes
        fi
        if [ -n "$screenshot_branch" ]; then
            branch_hint="a URL on the $screenshot_branch branch (a link that contains /$screenshot_branch/)"
        fi
        if [ "$forge" = gitlab ]; then
            wanted="an image uploaded to the merge request (a link that contains /uploads/<hash>/)${screenshot_branch:+, nor $branch_hint,}"
        else
            wanted=$branch_hint
        fi
        if [ "$branch_link" = yes ] || [ "$upload_link" = yes ]; then
            report pass "$pr_word links screenshots"
        elif printf '%s' "$body" | grep -qiE '^no screen changed\.'; then
            printf 'PASS  no screenshots, asserted\n      the %s body states no screen changed; that is your claim, not a measurement\n' "$pr_word"
        else
            report fail "$pr_word links screenshots" "$views view file(s) changed and the $pr_word body has neither $wanted nor a line reading: No screen changed."
        fi
    fi
fi

printf '\n'
if [ "$fails" -eq 0 ]; then
    printf 'ready-check: pass. Mark the %s ready, then move the ticket to review.\n' "$pr_word"
    exit 0
fi
printf 'ready-check: %d failed. The %s is not ready. Fix these, or ask me to waive one.\n' "$fails" "$pr_word"
exit 1
