#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/lib.sh"
script="$here/../scripts/ready-check.sh"

root=""
repo=""
ledger=""
out=""
rc=0

git_in() { git -C "$repo" -c user.name=tester -c user.email=tester@example.test -c commit.gpgsign=false "$@"; }

# ── Fixture ───────────────────────────────────────────────────────────────
build() {
    local docs=${T_DOCS:-repo} prefix=${T_PREFIX:-feature/} base=${T_BASE:-develop} docs_dir=${T_DOCS_DIR:-docs/features}
    root=$(mktemp -d)
    repo="$root/repo"
    mkdir -p "$repo/.claude" "$root/bin"
    git init -q --bare "$root/origin.git"
    git init -q "$repo"
    git_in symbolic-ref HEAD "refs/heads/$base"
    git_in remote add origin "$root/origin.git"
    if [ "$docs" = private ]; then
        docs_dir="$root/private-notes"
        ledger="$docs_dir/2026-10-02-demo"
    else
        printf 'docs/\nnotes/\n' >> "$repo/.git/info/exclude"
        ledger="$repo/$docs_dir/2026-10-02-demo"
    fi
    printf -- '---\nplatform: flutter\nbase_branch: %s\nbranch_prefix: %s\ndocs: %s\ndocs_dir: %s\nview_globs: lib/**/views/**,lib/**/widgets/**\n---\n' \
        "$base" "$prefix" "$docs" "${T_DOCS_DIR_VALUE:-$docs_dir}" > "$repo/.claude/agentic-delivery.md"
    printf 'start\n' > "$repo/README.txt"
    git_in add -A
    git_in commit -q -m "start"
    git_in push -q origin "$base"
    git_in checkout -q -b "${prefix}demo"
    mkdir -p "$repo/lib/a/data"
    printf 'one\n' > "$repo/lib/a/data/one.dart"
    git_in add -A
    git_in commit -q -m "add one"
    git_in push -q origin "${prefix}demo"
    write_ledger "$(git_in rev-parse --short HEAD)"
    cat > "$root/bin/gh" <<'STUB'
#!/bin/bash
printf 'called\n' >> "$(dirname "$0")/gh-calls"
printf '{"number":1,"isDraft":true,"baseRefName":"develop","body":"%s"}\n' "$(printf 'x%.0s' $(seq 1 250))"
STUB
    chmod +x "$root/bin/gh"
}

write_ledger() {
    mkdir -p "$ledger"
    {
        printf 'commit %s add one\n' "$1"
        printf 'cost: T-1 spec tokens=10k minutes=5 fix_rounds=0\n'
        printf 'cost: T-1 plan tokens=10k minutes=5 fix_rounds=0\n'
        printf 'cost: T-1 T1 tokens=10k minutes=5 fix_rounds=0\n'
        printf 'cost: T-1 final tokens=10k minutes=5 fix_rounds=0\n'
    } > "$ledger/progress.md"
    printf 'tally: 8 checks, 8 run, 0 unrun, 0 waived\n' > "$ledger/qa-session-log.md"
}

run() {
    local nobase=0
    [ "${1:-}" = nobase ] && nobase=1
    if [ "$nobase" = 1 ]; then
        out=$(cd "$repo" && env -u READY_CHECK_BASE READY_CHECK_SKIP_PR=1 PATH="$root/bin:$PATH" bash "$script" 2>&1)
    else
        out=$(cd "$repo" && READY_CHECK_BASE="origin/${T_BASE:-develop}" READY_CHECK_SKIP_PR=1 PATH="$root/bin:$PATH" bash "$script" 2>&1)
    fi
    rc=$?
}

run_with_pr() {
    out=$(cd "$repo" && READY_CHECK_BASE="origin/develop" PATH="$root/bin:$PATH" bash "$script" 2>&1)
    rc=$?
}

has() { printf '%s\n' "$out" | grep -qF -- "$1" && echo yes || echo no; }

cleanup() {
    [ -n "$root" ] && [ -d "$root" ] && rm -rf "$root"
    root=""
}

# ── A complete ledger ─────────────────────────────────────────────────────
build
run
check "complete: exit 0" 0 "$rc"
check "complete: base merged in" yes "$(has 'PASS  base merged in')"
check "complete: tree committed" yes "$(has 'PASS  working tree committed')"
check "complete: branch pushed" yes "$(has 'PASS  branch pushed')"
check "complete: ledger present" yes "$(has 'PASS  ledger present')"
check "complete: ledger names every commit" yes "$(has 'PASS  ledger names every commit')"
check "complete: cost lines" yes "$(has 'PASS  cost lines')"
check "complete: every manual check ran" yes "$(has 'PASS  every manual check ran')"
check "complete: both PR checks skip" 2 "$(printf '%s\n' "$out" | grep -c '^SKIP  PR ')"
check "complete: gh is not called" no "$([ -e "$root/bin/gh-calls" ] && echo yes || echo no)"
cleanup

# ── A commit the ledger does not name ─────────────────────────────────────
build
printf 'two\n' > "$repo/lib/a/data/two.dart"
git_in add -A
git_in commit -q -m "add two"
git_in push -q origin feature/demo
run
check "unnamed commit: exit 1" 1 "$rc"
check "unnamed commit: fails" yes "$(has 'FAIL  ledger names every commit')"
check "unnamed commit: names the sha" yes "$(has "$(git_in rev-parse --short HEAD)")"
cleanup

# ── A missing final cost line ─────────────────────────────────────────────
build
grep -v ' final ' "$ledger/progress.md" > "$ledger/progress.tmp"
mv "$ledger/progress.tmp" "$ledger/progress.md"
run
check "no final cost line: exit 1" 1 "$rc"
check "no final cost line: fails" yes "$(has 'FAIL  cost lines')"
check "no final cost line: names final" yes "$(has 'no cost line for: final')"
cleanup

# ── A tally with one unrun check ──────────────────────────────────────────
build
printf 'tally: 8 checks, 7 run, 1 unrun, 0 waived\n' > "$ledger/qa-session-log.md"
run
check "unrun check: exit 1" 1 "$rc"
check "unrun check: fails" yes "$(has 'FAIL  every manual check ran')"
cleanup

# ── Waivers, in the form the controller skill writes ──────────────────────
build
printf 'tally: 8 checks, 7 run, 0 unrun, 1 waived\n' > "$ledger/qa-session-log.md"
run
check "waived without a line: fails" yes "$(has 'FAIL  no check waived')"
check "waived without a line: hint is the gate owner form" yes "$(has 'by gate owner on <YYYY-MM-DD>')"
printf 'waiver: M1 by gate owner on 2026-10-02: no device free\n' >> "$ledger/progress.md"
run
check "gate owner waiver: exit 0" 0 "$rc"
check "gate owner waiver: passes" yes "$(has 'PASS  every manual check ran or was waived')"
sed -i.bak 's/by gate owner/by owner/' "$ledger/progress.md"; rm "$ledger/progress.md.bak"
run
check "owner waiver: still accepted" 0 "$rc"
cleanup

# ── A deleted ledger folder ───────────────────────────────────────────────
build
rm -rf "$ledger"
run
check "no ledger: exit 1" 1 "$rc"
check "no ledger: fails" yes "$(has 'FAIL  ledger present')"
cleanup

# ── A missing project file, and a missing key ─────────────────────────────
build
rm "$repo/.claude/agentic-delivery.md"
run
check "no project file: non-zero exit" 4 "$rc"
check "no project file: reader message" yes "$(has 'project-config: no project file at')"
check "no project file: no check ran" no "$(has 'PASS')"
cleanup

build
grep -v '^view_globs:' "$repo/.claude/agentic-delivery.md" > "$repo/.claude/tmp.md"
mv "$repo/.claude/tmp.md" "$repo/.claude/agentic-delivery.md"
run
check "no view_globs: non-zero exit" 3 "$rc"
check "no view_globs: reader message names the key" yes "$(has "project-config: no 'view_globs' in")"
check "no view_globs: no check ran" no "$(has 'PASS')"
cleanup

# ── A branch outside the prefix ───────────────────────────────────────────
build
git_in checkout -q -b fix/other
run
check "wrong prefix: exit 1" 1 "$rc"
check "wrong prefix: names the prefix" yes "$(has 'not a feature/* branch')"
cleanup

# ── Values read from the project file ─────────────────────────────────────
T_PREFIX=task/ T_BASE=integration T_DOCS_DIR=notes build
run nobase
check "custom values: exit 0" 0 "$rc"
check "custom values: base from the file" yes "$(has 'base  origin/integration')"
check "custom values: ledger under docs_dir" yes "$(has 'PASS  ledger present')"
check "custom values: ledger names every commit" yes "$(has 'PASS  ledger names every commit')"
cleanup

T_DOCS=private build
run
check "private docs: exit 0" 0 "$rc"
check "private docs: ledger present" yes "$(has 'PASS  ledger present')"
check "private docs: ledger is outside the repository" no "$([ -e "$repo/docs" ] && echo yes || echo no)"
cleanup

T_DOCS=private T_DOCS_DIR_VALUE=relative/notes build
run
check "private docs, relative docs_dir: exit 1" 1 "$rc"
check "private docs, relative docs_dir: says absolute" yes "$(has 'must be an absolute path')"
cleanup

# ── The view files, through a stub for gh ─────────────────────────────────
build
mkdir -p "$repo/lib/a/views"
printf 'view\n' > "$repo/lib/a/views/page.dart"
git_in add -A
git_in commit -q -m "add a view"
git_in push -q origin feature/demo
write_ledger "$(git_in log --first-parent develop..HEAD --format=%h | tr '\n' ' ')"
run_with_pr
check "view change: gh is called" yes "$([ -e "$root/bin/gh-calls" ] && echo yes || echo no)"
check "view change: exit 1" 1 "$rc"
check "view change: counts the view files" yes "$(has '1 view file(s) changed')"
check "view change: no Swift in the message" no "$(has 'Swift')"
cleanup

build
run_with_pr
check "no view change: exit 0" 0 "$rc"
check "no view change: screenshot check skips" yes "$(has 'SKIP  PR links screenshots')"
cleanup

finish
