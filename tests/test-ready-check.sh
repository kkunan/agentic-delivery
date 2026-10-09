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
    elif [ "${T_TRACK:-}" != 1 ]; then
        printf 'docs/\nnotes/\n' >> "$repo/.git/info/exclude"
    fi
    [ "$docs" = private ] || ledger="$repo/$docs_dir/2026-10-02-demo"
    printf -- '---\nplatform: flutter\nbase_branch: %s\nbranch_prefix: %s\ndocs: %s\ndocs_dir: %s\nview_globs: %s\nscreenshot_branch: %s\n---\n' \
        "$base" "$prefix" "$docs" "${T_DOCS_DIR_VALUE:-$docs_dir}" "${T_GLOBS:-lib/**/views/**,lib/**/widgets/**}" "${T_SHOTS-screenshots}" > "$repo/.claude/agentic-delivery.md"
    if [ -n "${T_FORGE:-}" ]; then
        awk -v f="$T_FORGE" 'NR == 2 { print "forge: " f } { print }' "$repo/.claude/agentic-delivery.md" > "$repo/.claude/tmp.md"
        mv "$repo/.claude/tmp.md" "$repo/.claude/agentic-delivery.md"
    fi
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
body=$(printf 'x%.0s' $(seq 1 250))
[ -f "$(dirname "$0")/body-extra" ] && body=$(printf '%s\n%s' "$body" "$(cat "$(dirname "$0")/body-extra")")
jq -n --arg b "$body" '{number:1,isDraft:true,baseRefName:"develop",body:$b}'
STUB
    cat > "$root/bin/glab" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >> "$(dirname "$0")/glab-calls"
[ -f "$(dirname "$0")/no-mr" ] && { echo 'no open merge request available for "feature/demo"' >&2; exit 1; }
body=$(printf 'x%.0s' $(seq 1 250))
[ -f "$(dirname "$0")/body-extra" ] && body=$(printf '%s\n%s' "$body" "$(cat "$(dirname "$0")/body-extra")")
jq -n --arg b "$body" '{iid:1,draft:true,target_branch:"develop",source_branch:"feature/demo",description:$b}'
STUB
    chmod +x "$root/bin/gh" "$root/bin/glab"
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

# ── push_policy mr-and-ship: task commits stay local until the ship push ──
build
printf 'two\n' > "$repo/lib/a/data/two.dart"
git_in add -A
git_in commit -q -m "add two"
two=$(git_in rev-parse --short HEAD)
printf 'three\n' > "$repo/lib/a/data/three.dart"
git_in add -A
git_in commit -q -m "add three"
printf 'commit %s add two\ncommit %s add three\n' "$two" "$(git_in rev-parse --short HEAD)" >> "$ledger/progress.md"
run
check "local task commits: exit 1" 1 "$rc"
check "local task commits: branch pushed fails" yes "$(has 'FAIL  branch pushed')"
check "local task commits: the ledger check reads the local commits" yes "$(has 'PASS  ledger names every commit')"
git_in push -q origin feature/demo
run
check "one ship push: exit 0" 0 "$rc"
check "one ship push: branch pushed" yes "$(has 'PASS  branch pushed')"
cleanup

# ── A ledger that git tracks ──────────────────────────────────────────────
T_TRACK=1 build
git_in add -A
git_in commit -q -m "record the ledger"
git_in push -q origin feature/demo
ledger_sha=$(git_in rev-parse --short HEAD)
run
check "tracked ledger: exit 0" 0 "$rc"
check "tracked ledger: ledger names every commit" yes "$(has 'PASS  ledger names every commit')"
printf 'three\n' > "$repo/lib/a/data/three.dart"
printf 'more\n' >> "$ledger/progress.md"
git_in add -A
git_in commit -q -m "add three"
git_in push -q origin feature/demo
run
check "tracked ledger, unnamed code commit: exit 1" 1 "$rc"
check "tracked ledger, unnamed code commit: fails" yes "$(has 'FAIL  ledger names every commit')"
check "tracked ledger, unnamed code commit: names the sha" yes "$(has "$(git_in rev-parse --short HEAD)")"
check "tracked ledger, unnamed code commit: skips the ledger commit" no "$(has "$ledger_sha")"
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

# ── Lite mode ledgers ─────────────────────────────────────────────────────
lite_ledger() {
    {
        printf 'commit %s add one\n' "$(git_in rev-parse --short HEAD)"
        printf '%s\n' "$@"
    } > "$ledger/progress.md"
}
build
lite_ledger 'mode: lite' 'cost: T-1 build tokens=10k minutes=5 fix_rounds=0' 'cost: T-1 final tokens=10k minutes=5 fix_rounds=0'
run
check "lite: exit 0" 0 "$rc"
check "lite: says lite mode" yes "$(has 'NOTE  lite mode')"
check "lite: cost lines pass" yes "$(has 'PASS  cost lines (2 phases)')"
lite_ledger 'mode: lite' 'cost: T-1 build tokens=10k minutes=5 fix_rounds=0'
run
check "lite, no final line: exit 1" 1 "$rc"
check "lite, no final line: names final" yes "$(has 'no cost line for: final')"
lite_ledger 'cost: T-1 build tokens=10k minutes=5 fix_rounds=0' 'cost: T-1 final tokens=10k minutes=5 fix_rounds=0'
run
check "build and final with no mode line: exit 1" 1 "$rc"
check "build and final with no mode line: names the full phases" yes "$(has 'no cost line for: spec plan T<n>')"
lite_ledger 'We did not use mode: lite here.' 'cost: T-1 build tokens=10k minutes=5 fix_rounds=0' 'cost: T-1 final tokens=10k minutes=5 fix_rounds=0'
run
check "mode words inside a sentence: not lite" no "$(has 'NOTE  lite mode')"
check "mode words inside a sentence: exit 1" 1 "$rc"
lite_ledger 'mode: lite' 'cost: T-1 build tokens=10k minutes=5 fix_rounds=0' 'cost: T-1 final tokens=10k minutes=5 fix_rounds=0' 'cost: T-1 review tokens=1k minutes=1 fix_rounds=0'
run
check "lite with an unknown phase: fails the shape" yes "$(has 'not in the shape')"
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

T_DOCS=private T_DOCS_DIR_VALUE='~/private-notes' build
HOME=$root run
check "private docs, docs_dir under ~/: exit 0" 0 "$rc"
check "private docs, docs_dir under ~/: ledger present" yes "$(has 'PASS  ledger present')"
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
check "view change: failure names the screenshot branch" yes "$(has '/screenshots/')"

printf 'https://example.test/o/r/blob/screenshots/x/a.png\n' > "$root/bin/body-extra"
run_with_pr
check "screenshot link: exit 0" 0 "$rc"
check "screenshot link: passes" yes "$(has 'PASS  PR links screenshots')"

printf '[shot](https://example.test/o/r/blob/other/x/a.png)\n' > "$root/bin/body-extra"
run_with_pr
check "link on another branch: exit 1" 1 "$rc"
check "link on another branch: fails" yes "$(has 'FAIL  PR links screenshots')"

printf 'screenshots/x/a.png\n' > "$root/bin/body-extra"
run_with_pr
check "path without a URL: fails" yes "$(has 'FAIL  PR links screenshots')"

printf 'No screen changed.\n' > "$root/bin/body-extra"
run_with_pr
check "no screen changed line: exit 0" 0 "$rc"
check "no screen changed line: passes as asserted" yes "$(has 'PASS  no screenshots, asserted')"
cleanup

T_GLOBS='lib/**/views/**, lib/**/widgets/**' build
mkdir -p "$repo/lib/a/widgets"
printf 'widget\n' > "$repo/lib/a/widgets/card.dart"
git_in add -A
git_in commit -q -m "add a widget"
git_in push -q origin feature/demo
write_ledger "$(git_in log --first-parent develop..HEAD --format=%h | tr '\n' ' ')"
run_with_pr
check "space after a comma in view_globs: counts the view file" yes "$(has '1 view file(s) changed')"
cleanup

build
run_with_pr
check "no view change: exit 0" 0 "$rc"
check "no view change: screenshot check skips" yes "$(has 'SKIP  PR links screenshots')"
cleanup

# ── GitLab, through a stub for glab ───────────────────────────────────────
add_view() {
    mkdir -p "$repo/lib/a/views"
    printf 'view\n' > "$repo/lib/a/views/page.dart"
    git_in add -A
    git_in commit -q -m "add a view"
    git_in push -q origin feature/demo
    write_ledger "$(git_in log --first-parent develop..HEAD --format=%h | tr '\n' ' ')"
}

T_FORGE=gitlab build
add_view
run_with_pr
check "gitlab: glab is called" yes "$([ -e "$root/bin/glab-calls" ] && echo yes || echo no)"
check "gitlab: glab asks for json" yes "$(grep -qF 'mr view --output json' "$root/bin/glab-calls" && echo yes || echo no)"
check "gitlab: gh is not called" no "$([ -e "$root/bin/gh-calls" ] && echo yes || echo no)"
check "gitlab: description passes" yes "$(has 'PASS  MR description rewritten')"
check "gitlab: no screenshot link fails" yes "$(has 'FAIL  MR links screenshots')"
check "gitlab: final line says MR" yes "$(has 'The MR is not ready')"
printf 'https://gitlab.example.test/o/r/-/raw/screenshots/x/a.png\n' > "$root/bin/body-extra"
run_with_pr
check "gitlab screenshot link: exit 0" 0 "$rc"
check "gitlab screenshot link: passes" yes "$(has 'PASS  MR links screenshots')"
check "gitlab screenshot link: says mark the MR ready" yes "$(has 'Mark the MR ready')"
touch "$root/bin/no-mr"
run_with_pr
check "gitlab, no merge request: exit 1" 1 "$rc"
check "gitlab, no merge request: fails" yes "$(has 'FAIL  merge request open')"
check "gitlab, no merge request: passes on the glab message" yes "$(has 'no open merge request available')"
cleanup

# ── GitLab: an image uploaded to the merge request ────────────────────────
upload='/uploads/0123456789abcdef0123456789abcdef/home.png'
T_FORGE=gitlab build
add_view
printf '![home](%s)\n' "$upload" > "$root/bin/body-extra"
run_with_pr
check "gitlab relative upload: exit 0" 0 "$rc"
check "gitlab relative upload: passes" yes "$(has 'PASS  MR links screenshots')"
printf '![home](https://gitlab.example.test/-/project/7%s)\n' "$upload" > "$root/bin/body-extra"
run_with_pr
check "gitlab full upload URL: passes" yes "$(has 'PASS  MR links screenshots')"
printf '![home](/uploads/not-a-hash/home.png)\n' > "$root/bin/body-extra"
run_with_pr
check "gitlab upload without a hash: fails" yes "$(has 'FAIL  MR links screenshots')"
check "gitlab failure: names the upload form" yes "$(has 'an image uploaded to the merge request')"
check "gitlab failure: names the screenshot branch too" yes "$(has 'a URL on the screenshots branch')"
cleanup

T_FORGE=gitlab build
grep -v '^screenshot_branch:' "$repo/.claude/agentic-delivery.md" > "$repo/.claude/tmp.md"
mv "$repo/.claude/tmp.md" "$repo/.claude/agentic-delivery.md"
add_view
run_with_pr
check "gitlab, no screenshot_branch: the check runs" yes "$(has 'FAIL  MR links screenshots')"
check "gitlab, no screenshot_branch: no branch in the message" no "$(has 'a URL on the')"
printf '![home](%s)\n' "$upload" > "$root/bin/body-extra"
run_with_pr
check "gitlab, no screenshot_branch, upload: exit 0" 0 "$rc"
cleanup

build
add_view
printf '![home](%s)\n' "$upload" > "$root/bin/body-extra"
run_with_pr
check "github, gitlab upload link: does not count" yes "$(has 'FAIL  PR links screenshots')"
check "github failure: no upload form in the message" no "$(has 'uploaded')"
grep -v '^screenshot_branch:' "$repo/.claude/agentic-delivery.md" > "$repo/.claude/tmp.md"
mv "$repo/.claude/tmp.md" "$repo/.claude/agentic-delivery.md"
run_with_pr
check "github, no screenshot_branch: reader stops" 3 "$rc"
cleanup

T_FORGE=gitlab build
out=$(cd "$repo" && env -u READY_CHECK_BASE PATH="$root/bin:$PATH" bash "$script" 2>&1); rc=$?
check "gitlab base from the MR: names the target branch" yes "$(has 'base  origin/develop (from the merge request)')"
cleanup

T_FORGE=gitlab build
run
check "gitlab, skip: exit 0" 0 "$rc"
check "gitlab, skip: both MR checks skip" 2 "$(printf '%s\n' "$out" | grep -c '^SKIP  MR ')"
check "gitlab, skip: glab is not called" no "$([ -e "$root/bin/glab-calls" ] && echo yes || echo no)"
cleanup

# ── The forge, from the origin URL ────────────────────────────────────────
for url in git@gitlab.com:o/r.git https://gitlab.example.test/o/r.git ssh://git@gitlab.example.test:2222/o/r.git; do
    build
    git_in config "url.$root/origin.git.insteadOf" "$url"
    git_in remote set-url origin "$url"
    run_with_pr
    check "origin $url: glab is called" yes "$([ -e "$root/bin/glab-calls" ] && echo yes || echo no)"
    check "origin $url: exit 0" 0 "$rc"
    cleanup
done

build
git_in config "url.$root/origin.git.insteadOf" "git@github.com:o/gitlab-tools.git"
git_in remote set-url origin "git@github.com:o/gitlab-tools.git"
run_with_pr
check "github origin with gitlab in the path: gh is called" yes "$([ -e "$root/bin/gh-calls" ] && echo yes || echo no)"
check "github origin with gitlab in the path: glab is not called" no "$([ -e "$root/bin/glab-calls" ] && echo yes || echo no)"
cleanup

T_FORGE=github build
git_in config "url.$root/origin.git.insteadOf" "git@gitlab.com:o/r.git"
git_in remote set-url origin "git@gitlab.com:o/r.git"
run_with_pr
check "forge key wins over the origin URL: gh is called" yes "$([ -e "$root/bin/gh-calls" ] && echo yes || echo no)"
cleanup

T_FORGE=bitbucket build
run
check "unknown forge: exit 1" 1 "$rc"
check "unknown forge: names the value" yes "$(has 'forge must be github or gitlab, not bitbucket')"
check "unknown forge: no check ran" no "$(has 'PASS')"
cleanup

# ── A forge CLI that is not installed ─────────────────────────────────────
T_FORGE=gitlab build
rm "$root/bin/glab"
out=$(cd "$repo" && READY_CHECK_BASE=origin/develop PATH="$root/bin:/usr/bin:/bin" bash "$script" 2>&1); rc=$?
if PATH=/usr/bin:/bin command -v glab >/dev/null 2>&1; then
    printf 'note: glab is in /usr/bin or /bin, so the missing glab case cannot run here\n'
else
    check "no glab: exit 1" 1 "$rc"
    check "no glab: says glab is not installed" yes "$(has 'glab is not installed or not on PATH')"
fi
cleanup

# ── A project with no screens ─────────────────────────────────────────────
T_GLOBS=none T_SHOTS= build
mkdir -p "$repo/lib/a/views"
printf 'view\n' > "$repo/lib/a/views/page.dart"
git_in add -A
git_in commit -q -m "add a file in a views folder"
git_in push -q origin feature/demo
write_ledger "$(git_in log --first-parent develop..HEAD --format=%h | tr '\n' ' ')"
run_with_pr
check "no screens: exit 0" 0 "$rc"
check "no screens: the screenshot proof skips" yes "$(has 'SKIP  PR links screenshots')"
printf 'tally: 0 checks, 0 run, 0 unrun, 0 waived\n' > "$ledger/qa-session-log.md"
run_with_pr
check "no manual checks: exit 0" 0 "$rc"
check "no manual checks: passes" yes "$(has 'PASS  every manual check ran (0 checks)')"
cleanup

T_SHOTS= build
run
check "empty screenshot_branch with view globs: exit 3" 3 "$rc"
cleanup

finish
