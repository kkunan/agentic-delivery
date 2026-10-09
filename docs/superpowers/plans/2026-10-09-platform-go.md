# Go platform layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `platform-go` layer to the plugin, with a mutation runner, a CI job on a real Go toolchain, and a core change that lets a project with no screens set `view_globs: none`.

**Architecture:** The layer is one skill and one runner, in the shape of the iOS layer. The runner calls `go test -json` once for each test id and converts the events into the result file of `scripts/mutate.sh`. A stub Go command tests the runner on this Mac, and a CI job measures the real toolchain.

**Tech Stack:** bash, python3, Go 1.24 in CI only, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-10-09-platform-go-design.md`

## Global Constraints

- All prose is Simple English: short sentences, active voice, no contractions, no semicolons, no em-dashes, no emoji, no bold in prose.
- No comments in code. Section banners like `# ── Arguments ──` are allowed.
- The repository carries no names of the source project. The private name guard, `$GUARD .`, exits 0.
- `bash tests/run-all.sh` exits 0.
- Every line is necessary: add no rule and no code that no spec item asks for.
- Commit trailer: `Co-Authored-By: Claude <noreply@anthropic.com>`.
- Commit on `feature/platform-go`. Each push to the public repository needs the user's word in chat.
- The lint helper is `$LINT <file>`. Fix every `sentence_over_limit`, `banned_modal`, and `synonym_rotation` hit in new prose.

## Review Focus

1. `view_globs: none` with an empty `screenshot_branch` on GitHub: the ready check passes and skips the screenshot proof. Task 1, step 1.
2. An empty `screenshot_branch` with real view globs still stops the ready check. Task 1, step 1.
3. A build failure gives `compiled: false`, not `killed`. Task 2 with the stub, Task 3 on a real toolchain.
4. A test name that matches nothing gives no entry, so the verdict is `error`. Task 2 and Task 3.
5. A `go_command` with a quoted `$PWD`, as the Docker example has, runs through `bash -c`. Task 2, the project file case.

---

### Task 1: `view_globs: none` in the core

**Files:**
- Modify: `scripts/ready-check.sh` (the `screenshot_branch` read and the loop over changed files)
- Modify: `tests/test-ready-check.sh` (fixture and three cases)
- Modify: `commands/feature.md` (step 0)
- Modify: `skills/controller/SKILL.md` (ship checklist step 5)
- Modify: `templates/agentic-delivery.md` (the `view_globs` bullet)

**Interfaces:**
- Produces: the value `none` for `view_globs`. Tasks 4 and 5 name it.

- [ ] **Step 1: Write the failing tests**

In `tests/test-ready-check.sh`, in `build()`, change the front matter line so that a test can empty `screenshot_branch`. Replace:

```bash
    printf -- '---\nplatform: flutter\nbase_branch: %s\nbranch_prefix: %s\ndocs: %s\ndocs_dir: %s\nview_globs: %s\nscreenshot_branch: screenshots\n---\n' \
        "$base" "$prefix" "$docs" "${T_DOCS_DIR_VALUE:-$docs_dir}" "${T_GLOBS:-lib/**/views/**,lib/**/widgets/**}" > "$repo/.claude/agentic-delivery.md"
```

with:

```bash
    printf -- '---\nplatform: flutter\nbase_branch: %s\nbranch_prefix: %s\ndocs: %s\ndocs_dir: %s\nview_globs: %s\nscreenshot_branch: %s\n---\n' \
        "$base" "$prefix" "$docs" "${T_DOCS_DIR_VALUE:-$docs_dir}" "${T_GLOBS:-lib/**/views/**,lib/**/widgets/**}" "${T_SHOTS-screenshots}" > "$repo/.claude/agentic-delivery.md"
```

Before the final `finish` line, add:

```bash
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
```

- [ ] **Step 2: Run the tests and watch them fail**

Run: `bash tests/test-ready-check.sh 2>&1 | tail -12`
Expected: four FAIL lines, for the two "no screens" checks and the two "no manual checks" checks, because the ready check exits 3 on the empty `screenshot_branch`. The check "empty screenshot_branch with view globs: exit 3" passes, because it pins behavior that works today.

- [ ] **Step 3: Change the ready check**

In `scripts/ready-check.sh`, replace:

```bash
if [ "$forge" = gitlab ]; then
    screenshot_branch=$(bash "$reader" screenshot_branch "") || exit $?
```

with:

```bash
if [ "$forge" = gitlab ] || [ "$view_globs" = none ]; then
    screenshot_branch=$(bash "$reader" screenshot_branch "") || exit $?
```

Replace:

```bash
    done < <(git diff --name-only "$base...HEAD")
```

with:

```bash
    done < <([ "$view_globs" = none ] || git diff --name-only "$base...HEAD")
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `bash tests/test-ready-check.sh 2>&1 | tail -3`
Expected: `N passed, 0 failed`.

- [ ] **Step 5: Change the documents**

In `commands/feature.md`, step 0, replace:

```
   is empty or missing, stop. The one exception is `screenshot_branch` on GitLab, which can stay empty,
   because a merge request takes uploaded images.
```

with:

```
   is empty or missing, stop. The one exception is `screenshot_branch` on GitLab, which can stay empty,
   because a merge request takes uploaded images. A project with no screens sets `view_globs` to
   `none`, and its `screenshot_branch` can also stay empty.
```

In `skills/controller/SKILL.md`, at the end of ship checklist step 5, after `so that each capture waits for the screen to settle.`, add:

```
 If `view_globs` is `none`, the project has no screens, so skip this step.
```

In `templates/agentic-delivery.md`, at the end of the `view_globs` bullet, after `use `lib/views/**,lib/**/views/**`.`, add:

```
 A project with no screens, such as a service, sets `none`. Then the ready check asks for no screenshots, and `screenshot_branch` can stay empty.
```

- [ ] **Step 6: Lint, guard, test, and commit**

Run: `$LINT` on the three documents, `$GUARD .`, and `bash tests/run-all.sh`. Expected: no new lint hit of the named kinds, and both commands exit 0.

```bash
git add scripts/ready-check.sh tests/test-ready-check.sh commands/feature.md skills/controller/SKILL.md templates/agentic-delivery.md
git commit -m "Let a project with no screens set view_globs to none

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 2: The Go mutation runner

**Files:**
- Create: `skills/platform-go/mutation-runner.sh`
- Create: `tests/fixtures/go/fake-go.sh`
- Create: `tests/test-go-runner.sh`

**Interfaces:**
- Produces: `skills/platform-go/mutation-runner.sh --out <result.json> --log <log> -- <package>::<test name>...`, the contract of `scripts/mutate.sh`. It reads `GO_BIN` from the environment, or `go_command` from `.claude/agentic-delivery.md` at the top of the current git repository, with the default `go`. Exit 2 on a refused input, exit 3 when a call ran no test and showed no build failure.

- [ ] **Step 1: Write the stub Go command**

Create `tests/fixtures/go/fake-go.sh`, and make it executable:

```bash
#!/bin/bash
printf '%s\n' "$*" >> "$FAKE_CALLS"
pkg=${!#}
key=$(printf '%s' "$pkg" | tr -c 'A-Za-z0-9' '_')
[ -f "$FAKE_GO_DIR/$key.jsonl" ] && cat "$FAKE_GO_DIR/$key.jsonl"
exit "$(cat "$FAKE_GO_DIR/$key.rc" 2>/dev/null || echo 0)"
```

- [ ] **Step 2: Write the failing tests**

Create `tests/test-go-runner.sh`:

```bash
#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/lib.sh"
top=$(cd "$here/.." && pwd -P)
runner="$top/skills/platform-go/mutation-runner.sh"
fake="$here/fixtures/go/fake-go.sh"

work=$(cd "$(mktemp -d)" && pwd -P)
trap 'rm -rf "$work"' EXIT
app="$work/app"
mkdir -p "$app"
git -C "$app" init -q
export FAKE_CALLS="$work/calls"
export FAKE_GO_DIR="$work/go"
mkdir -p "$FAKE_GO_DIR"

field() {
    python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print(eval(sys.argv[2]))' "$1" "$2" 2>/dev/null || echo "(no result file)"
}

entries() {
    field "$work/$1.json" 'str(d["compiled"]) + " " + " ".join(t["id"] + "=" + t["result"] for t in d["tests"])'
}

events() {
    local key
    key=$(printf '%s' "$1" | tr -c 'A-Za-z0-9' '_')
    shift
    printf '%s\n' "$@" > "$FAKE_GO_DIR/$key.jsonl"
}

exit_code() {
    local key
    key=$(printf '%s' "$1" | tr -c 'A-Za-z0-9' '_')
    printf '%s\n' "$2" > "$FAKE_GO_DIR/$key.rc"
}

run() {
    name=$1
    shift
    rc=0
    : > "$FAKE_CALLS"
    (cd "$app" && GO_BIN="$fake" "$runner" --out "$work/$name.json" --log "$work/$name.log" -- "$@" < /dev/null 2>/dev/null) || rc=$?
}

# ── Results ───────────────────────────────────────────────────────────────

events ./a \
    '{"Action":"run","Package":"example.test/a","Test":"TestAdd"}' \
    '{"Action":"pass","Package":"example.test/a","Test":"TestAdd"}' \
    '{"Action":"fail","Package":"example.test/a","Test":"TestSub"}' \
    '{"Action":"skip","Package":"example.test/a","Test":"TestSkip"}' \
    '{"Action":"pass","Package":"example.test/a","Test":"TestClamp/a+b"}' \
    '{"Action":"fail","Package":"example.test/a"}'
exit_code ./a 1

run pass ./a::TestAdd
check "pass: exit 0" 0 "$rc"
check "pass: entry" "True ./a::TestAdd=passed" "$(entries pass)"
check "pass: the call" "test -json -count=1 -run ^TestAdd$ ./a" "$(cat "$FAKE_CALLS")"

run fail ./a::TestSub
check "fail: entry" "True ./a::TestSub=failed" "$(entries fail)"

run skip ./a::TestSkip
check "skip: entry" "True ./a::TestSkip=skipped" "$(entries skip)"

run sub './a::TestClamp/a+b'
check "subtest: entry" "True ./a::TestClamp/a+b=passed" "$(entries sub)"
check "subtest: each part anchored and escaped" 'test -json -count=1 -run ^TestClamp$/^a\+b$ ./a' "$(cat "$FAKE_CALLS")"

run two ./a::TestAdd ./a::TestSub ./a::TestAdd
check "two ids: one call for each distinct id" 2 "$(grep -c . "$FAKE_CALLS")"
check "two ids: both entries" "True ./a::TestAdd=passed ./a::TestSub=failed" "$(entries two)"

run missing ./a::TestMissing
check "no match: exit 0" 0 "$rc"
check "no match: no entry" "True " "$(entries missing)"

# ── Build failure ─────────────────────────────────────────────────────────

events ./b \
    '{"ImportPath":"example.test/b","Action":"build-output","Output":"b.go:3:9: cannot use \"x\"\n"}' \
    '{"ImportPath":"example.test/b","Action":"build-fail"}' \
    '{"Action":"fail","Package":"example.test/b","FailedBuild":"example.test/b"}'
exit_code ./b 1
run broken ./b::TestAdd
check "build failure: exit 0" 0 "$rc"
check "build failure: not compiled" "False " "$(entries broken)"

events ./c '{"Action":"fail","Package":"example.test/c","FailedBuild":"example.test/c"}'
exit_code ./c 1
run broken2 ./c::TestAdd
check "build failure without build-fail: not compiled" "False " "$(entries broken2)"

# ── No result ─────────────────────────────────────────────────────────────

events ./d 'not json'
exit_code ./d 1
run nothing ./d::TestAdd
check "no event and exit 1: exit 3" 3 "$rc"
check "no event and exit 1: no result file" no "$([ -e "$work/nothing.json" ] && echo yes || echo no)"

run refused ./a
check "id without '::': exit 2" 2 "$rc"
check "id without '::': no result file" no "$([ -e "$work/refused.json" ] && echo yes || echo no)"

run empty ./a::
check "id without a test name: exit 2" 2 "$rc"

# ── The command from the project file ─────────────────────────────────────

mkdir -p "$app/.claude"
printf -- '---\ngo_command: FAKE_DIR="$PWD" "%s"\n---\n' "$fake" > "$app/.claude/agentic-delivery.md"
rc=0
: > "$FAKE_CALLS"
(cd "$app" && "$runner" --out "$work/config.json" --log "$work/config.log" -- ./a::TestAdd < /dev/null 2>/dev/null) || rc=$?
check "go_command: exit 0" 0 "$rc"
check "go_command: entry" "True ./a::TestAdd=passed" "$(entries config)"

finish
```

- [ ] **Step 3: Run the tests and watch them fail**

Run: `bash tests/test-go-runner.sh 2>&1 | tail -5`
Expected: FAIL lines, because the runner does not exist. Every `entries` value reads `(no result file)`.

- [ ] **Step 4: Write the runner**

Create `skills/platform-go/mutation-runner.sh`, and make it executable:

```bash
#!/bin/bash
set -u

usage='usage: mutation-runner.sh --out <result.json> --log <log> -- <package>::<test name>...'

# ── Arguments ─────────────────────────────────────────────────────────────

if [ $# -lt 5 ] || [ "$1" != --out ] || [ "$3" != --log ] || [ "$5" != -- ]; then
    printf '%s\n' "$usage" >&2
    exit 2
fi
out=$2
log=$4
shift 5

say() {
    printf 'mutation-runner: %s\n' "$*" >> "$log"
    printf 'mutation-runner: %s\n' "$*" >&2
}

: > "$log" || { printf 'mutation-runner: cannot write the log %s\n' "$log" >&2; exit 2; }
rm -f "$out" || { say "cannot remove the old result file $out"; exit 2; }

ids=()
seen=$'\n'
for id in "$@"; do
    case "$id" in
        *::*) ;;
        *) say "REFUSED: the test id '$id' has no '::'. The form is <package>::<test name>"; exit 2 ;;
    esac
    if [ -z "${id%%::*}" ] || [ -z "${id#*::}" ]; then
        say "REFUSED: the test id '$id' needs a package before '::' and a test name after it"
        exit 2
    fi
    case "$seen" in *$'\n'"$id"$'\n'*) continue ;; esac
    seen="$seen$id"$'\n'
    ids+=("$id")
done
[ "${#ids[@]}" -gt 0 ] || { say "REFUSED: no test id"; printf '%s\n' "$usage" >&2; exit 2; }

# ── The Go command ────────────────────────────────────────────────────────

config_value() {
    local file
    file="$(git rev-parse --show-toplevel 2>/dev/null)/.claude/agentic-delivery.md"
    [ -f "$file" ] || return 0
    awk -v k="$1" '
        NR == 1 && $0 != "---" { exit }
        NR > 1 && $0 == "---" { exit }
        NR > 1 {
            i = index($0, ":")
            if (i > 0 && substr($0, 1, i - 1) == k) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); print v; exit }
        }' "$file"
}

if [ -n "${GO_BIN:-}" ]; then
    go_command=$(printf '%q' "$GO_BIN")
else
    go_command=$(config_value go_command)
    [ -n "$go_command" ] || go_command=go
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/mutation-runner.XXXXXX") || { say "cannot create a work folder"; exit 2; }
trap 'rm -rf "$work"' EXIT

# ── Running the tests ─────────────────────────────────────────────────────

anchor='import re, sys; print("/".join("^" + re.escape(p) + "$" for p in sys.argv[1].split("/")))'
records=()
n=0
for id in "${ids[@]}"; do
    n=$((n + 1))
    pkg=${id%%::*}
    pattern=$(python3 -c "$anchor" "${id#*::}")
    say "$go_command test -json -count=1 -run $pattern $pkg"
    bash -c "$go_command"' "$@"' go-command test -json -count=1 -run "$pattern" "$pkg" > "$work/$n.jsonl" 2>> "$log" < /dev/null
    records+=("$id" "$work/$n.jsonl" "$?")
done

# ── The result file ───────────────────────────────────────────────────────

convert='
import json, sys
out, args = sys.argv[1], sys.argv[2:]
results = {"pass": "passed", "fail": "failed", "skip": "skipped"}
compiled = True
tests = []
for i in range(0, len(args), 3):
    tid, path, code = args[i], args[i + 1], int(args[i + 2])
    name = tid.split("::", 1)[1]
    events = []
    for line in open(path):
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if isinstance(event, dict):
            events.append(event)
    if any(e.get("Action") == "build-fail" or e.get("FailedBuild") for e in events):
        compiled = False
        continue
    if code != 0 and not any(e.get("Test") for e in events):
        print("no test event and no build failure for %s, exit %d" % (tid, code))
        sys.exit(3)
    for e in events:
        if e.get("Test") == name and e.get("Action") in results:
            tests.append({"id": tid, "result": results[e["Action"]]})
json.dump({"compiled": compiled, "tests": tests}, open(out, "w"))
'
python3 -c "$convert" "$out" "${records[@]}" >> "$log" 2>&1
status=$?
[ "$status" -eq 0 ] || say "no result file, exit $status. Read the log $log"
exit "$status"
```

- [ ] **Step 5: Run the tests and watch them pass**

Run: `chmod +x skills/platform-go/mutation-runner.sh tests/fixtures/go/fake-go.sh && bash tests/test-go-runner.sh 2>&1 | tail -3`
Expected: `N passed, 0 failed`.

- [ ] **Step 6: Mutate the runner**

Change `e.get("Action") == "build-fail" or e.get("FailedBuild")` to `e.get("Action") == "build-fail"`, run the test, and see "build failure without build-fail: not compiled" fail. Restore it, and see green. Change `sys.exit(3)` to `pass`, and see "no event and exit 1: exit 3" fail. Restore it. Run `git diff skills/platform-go/mutation-runner.sh` and make sure that it shows only the new file. Record both runs in the ledger.

- [ ] **Step 7: Guard, test, and commit**

Run: `$GUARD .` and `bash tests/run-all.sh`. Expected: both exit 0.

```bash
git add skills/platform-go/mutation-runner.sh tests/fixtures/go/fake-go.sh tests/test-go-runner.sh
git commit -m "Add the Go mutation runner with stub tests

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 3: The CI job on a real Go toolchain

**Files:**
- Create: `tests/go-module/go.mod`, `tests/go-module/calc.go`, `tests/go-module/calc_test.go`
- Create: `tests/go-toolchain/check.sh`
- Modify: `.github/workflows/tests.yml` (a new job)

**Interfaces:**
- Consumes: the runner from Task 2.
- Produces: the measured facts that Task 4 writes into the skill: the Go version, the verdicts, and the build failure form.

- [ ] **Step 1: Write the sample module**

`tests/go-module/go.mod`:

```
module example.test/sample

go 1.24
```

`tests/go-module/calc.go`:

```go
package sample

func Add(a, b int) int {
	return a + b
}

func Clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
```

`tests/go-module/calc_test.go`:

```go
package sample

import "testing"

func TestAdd(t *testing.T) {
	if got := Add(2, 3); got != 5 {
		t.Fatalf("Add(2, 3) = %d, want 5", got)
	}
}

func TestClamp(t *testing.T) {
	t.Run("low", func(t *testing.T) {
		if got := Clamp(-1, 0, 10); got != 0 {
			t.Fatalf("Clamp(-1, 0, 10) = %d, want 0", got)
		}
	})
	t.Run("inside", func(t *testing.T) {
		if got := Clamp(5, 0, 10); got != 5 {
			t.Fatalf("Clamp(5, 0, 10) = %d, want 5", got)
		}
	})
}
```

- [ ] **Step 2: Write the check script**

Create `tests/go-toolchain/check.sh`, and make it executable:

```bash
#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/../lib.sh"
top=$(cd "$here/../.." && pwd -P)
[ $# -eq 1 ] || { echo "usage: tests/go-toolchain/check.sh <empty work folder>" >&2; exit 2; }
command -v go > /dev/null || { echo "check: go is not on PATH" >&2; exit 2; }
mkdir -p "$1" && work=$(cd "$1" && pwd -P) || exit 2
app="$work/sample"
ev="$work/evidence"
runner="$top/skills/platform-go/mutation-runner.sh"
mkdir -p "$ev"

say() {
    printf '\n== %s\n' "$*"
}

entries() {
    python3 -c 'import json, sys; d = json.load(open(sys.argv[1])); print(str(d["compiled"]) + " " + " ".join(t["id"] + "=" + t["result"] for t in d["tests"]))' "$1" 2>/dev/null || echo "(no result file)"
}

# ── The sample module ─────────────────────────────────────────────────────

go version | tee "$ev/go-version.txt"
cp -R "$top/tests/go-module" "$app"
mkdir -p "$app/.claude"
printf -- '---\ngo_command: go\n---\n' > "$app/.claude/agentic-delivery.md"
git -C "$app" init -q
git -C "$app" add -A
git -C "$app" -c user.name=ci -c user.email=ci@example.test commit -q -m sample

# ── The commands of the skill ─────────────────────────────────────────────

say "go test, go vet, gofmt"
rc=0; (cd "$app" && go test -count=1 ./... > "$ev/test.log" 2>&1) || rc=$?
check "go test: exit 0" 0 "$rc"
rc=0; (cd "$app" && go vet ./... > "$ev/vet.log" 2>&1) || rc=$?
check "go vet: exit 0" 0 "$rc"
check "gofmt through go run: lists nothing" "" "$(cd "$app" && go run cmd/gofmt -l . 2> "$ev/gofmt.err")"
printf 'package sample\nfunc  Bad( ) int { return 1 }\n' > "$app/bad.go"
check "gofmt through go run: lists a bad file" "bad.go" "$(cd "$app" && go run cmd/gofmt -l . 2>> "$ev/gofmt.err")"
rm "$app/bad.go"

# ── The runner ────────────────────────────────────────────────────────────

say "runner"
(cd "$app" && "$runner" --out "$ev/ids.json" --log "$ev/ids.log" -- .::TestAdd .::TestClamp/low .::TestMissing < /dev/null)
check "runner: entries" "True .::TestAdd=passed .::TestClamp/low=passed" "$(entries "$ev/ids.json")"

cp "$app/calc.go" "$work/calc.go.orig"
printf 'func Broken() int { return "x" }\n' >> "$app/calc.go"
(cd "$app" && go test -json -count=1 . > "$ev/build-fail.jsonl" 2>&1)
(cd "$app" && "$runner" --out "$ev/broken.json" --log "$ev/broken.log" -- .::TestAdd < /dev/null)
check "runner: a build failure is not compiled" "False " "$(entries "$ev/broken.json")"
cp "$work/calc.go.orig" "$app/calc.go"

# ── Through mutate.sh ─────────────────────────────────────────────────────

say "mutate.sh"
cat > "$work/manifest.json" <<'EOF'
[
 {"label": "survives", "file": "calc.go", "find": "return hi", "replace": "return lo", "test": ".::TestClamp"},
 {"label": "killed", "file": "calc.go", "find": "return a + b", "replace": "return a - b", "test": ".::TestAdd"},
 {"label": "nocompile", "file": "calc.go", "find": "return a + b", "replace": "return a + \"b\"", "test": ".::TestAdd"}
]
EOF
rc=0
(cd "$app" && "$top/scripts/mutate.sh" --manifest "$work/manifest.json" --out "$ev/mutate" --runner "$runner" > "$ev/mutate.out" 2> "$ev/mutate.err") || rc=$?
cat "$ev/mutate.out"
check "mutate: exit 1, one survivor" 1 "$rc"
check "mutate: verdicts" "survived survives
killed killed
did-not-compile nocompile" "$(awk 'NR >= 2 && NR <= 4 { print $1, $2 }' "$ev/mutate.out")"
check "mutate: tree clean" "" "$(cd "$app" && git status --porcelain)"

finish
```

- [ ] **Step 3: Add the CI job**

In `.github/workflows/tests.yml`, after the `xcode` job, add:

```yaml
  go:
    name: Go layer on a real toolchain
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version-file: tests/go-module/go.mod
          cache: false

      - name: Run the Go commands and the mutation runner
        run: bash tests/go-toolchain/check.sh "$RUNNER_TEMP/go-toolchain"

      - name: Keep the evidence
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: go-toolchain-evidence
          path: ${{ runner.temp }}/go-toolchain/evidence
          if-no-files-found: warn
```

- [ ] **Step 4: Run the stub suite and commit**

Run: `$GUARD .` and `bash tests/run-all.sh`. Expected: both exit 0. `run-all.sh` runs only `tests/test-*.sh`, so it skips the check script.

```bash
git add tests/go-module tests/go-toolchain .github/workflows/tests.yml
git commit -m "Add a CI job that runs the Go layer on a real toolchain

Co-Authored-By: Claude <noreply@anthropic.com>"
```

- [ ] **Step 5: Measure on CI**

Ask the user in chat for the word to push. After the yes, push the branch in the background and open a draft pull request against `main`. The body starts with `Claude Agentic Process Manager said: `. Read the result of the job "Go layer on a real toolchain" with `gh run view --log` on its run. Record in the ledger: the `go version` line, each check line, and whether `build-fail.jsonl` holds a `build-fail` event. If a check fails, fix the cause in Task 2 or Task 3, commit, and push again under the same word.

### Task 4: The skill

**Files:**
- Create: `skills/platform-go/SKILL.md`

**Interfaces:**
- Consumes: `none` from Task 1, the runner contract from Task 2, and the measured facts from Task 3.

- [ ] **Step 1: Write the skill**

Create `skills/platform-go/SKILL.md` with this content. In the last paragraph of the section Mutation tests, put the facts from the Task 3 ledger in place of the two values in angle brackets: the date of the CI run and the `go version` line.

````markdown
---
name: platform-go
description: "The Go layer of an agentic-delivery run, for services with an HTTP API, with the test tiers, commands, contract and log rules, and the mutation runner. If the project file says `platform: go`, load this skill."
---

# Go platform

This skill holds the rules that depend on Go. The `run-rules` skill holds the rules for every agent, and the `controller` skill holds the rules for the controller. This skill does not repeat them. Each rule gives its reason in one sentence.

## Project file keys

- `go_command` is the command that runs Go. It is optional, and the default is `go`. A team without a local toolchain can run Go in a container, for example `docker run --rm -v "$PWD":/src -w /src golang:1.25-alpine go`. In the commands below, `<go>` stands for this value. The value runs through `bash -c` from the top of the worktree, so `$PWD` and quotes in it work.
- `test_processes` is `go`. If `go_command` runs a container, it is `docker`.
- `view_globs` is `none`, because a service has no screens. Then `screenshot_branch` can stay empty, and the ship step takes no screenshots.

## The rules file of the repository

If the repository has a rules file for agents, such as `AGENTS.md` or `agent.md`, every agent reads it before it writes or reviews code. It beats the brief, because the team of the repository reviews it. If a sample in the brief breaks it, follow the file and say so in the report.

## Test tiers

Use the cheapest tier that can prove the fact. These are the tiers, cheapest first:

1. Unit tests with fakes. A fake is a struct in the test file that implements an interface of the domain, as the existing tests do. These tests need no network and no database.
2. Handler tests with `net/http/httptest`. They prove the status, the headers, and the body of an endpoint without a server.
3. Tests against a real dependency, such as a database. If the repository has none, do not build one as a side effect of a task. It is scheduled work with a ticket of its own.

No test reaches a live host, because a live host holds real data.

## Commands

Run each command from the top of the worktree, and write its output to a log in the ledger folder:

```bash
<go> test -count=1 ./...
```

```bash
<go> vet ./...
```

```bash
<go> run cmd/gofmt -l .
```

`-count=1` turns off the test cache, so the result comes from this tree. The format check must print nothing. It runs `gofmt` through `<go>`, so it works in a container too.

After the base merge, QA looks for a change since the last suite run:

```bash
git diff --stat <last suite SHA>..HEAD -- '*.go' go.mod go.sum
```

If the output lists a file, run the suite again. If the output is empty, cite the last run.

## API contract

- A request without a new field works as before. Write a test for that case, and name it in the report, because a client that users did not update still sends the old request.
- For each new or changed field, a test covers the field when it is present, absent, and of the wrong type, and over its size limit if it has one.
- The project file can have a section API clients. It names each client repository, the branch to read, and the place of its request and response types. The reviewer reads each changed field there with `git show <branch>:<path>`, and compares the JSON key, the type, whether the field is optional, and the size limit. A mismatch is Important.
- Generated API docs change with the code. If the repository generates them, for example with swaggo/swag, regenerate them with the generator version that `go.mod` names. If you cannot run the generator, edit the generated files by hand to match, and say so in the report.

## Logs

A log line, an error string, and a response body never hold a request body, a token, a secret, or a user value. A log line names the event and the error. The project file can name more fields, for example health values. The reviewer reads every new or changed log line, and a user value in one is Critical.

## Manual checks

A service run has no manual checks, unless the repository can start the service with fakes on this machine. Then each check is one request, with its expected status and body. With no checks, the QA log ends with `tally: 0 checks, 0 run, 0 unrun, 0 waived`, and the ready check accepts it.

## Stalled runs

`go test` stops a test that runs past its timeout, 10 minutes by default, and prints the stack of each goroutine. The stall watch reads the size of each log. A frozen log with a live `go` process is a stall to report, not a process to stop.

## Mutation tests

`scripts/mutate.sh` runs the tests through a platform runner, as its usage text says. The Go runner of this plugin is `skills/platform-go/mutation-runner.sh`. Copy it into the project as `scripts/mutation-runner.sh`, and commit it. That path is the default of the `mutation_runner` key.

A test id has the form `<package>::<test name>`, for example `./internal/usecase::TestSendMessage`. The package is a path that `go test` accepts, such as `.` or `./internal/usecase`. A subtest keeps its slash, for example `.::TestClamp/low`. Go replaces each space in a subtest name with `_`, so write the name as `go test -v` prints it.

The runner calls `<go> test -json -count=1 -run <pattern> <package>` once for each test id. The pattern anchors each part of the name. The verdicts:

- A passing test gives `passed`, and a failing test gives `failed`, so the verdict is `killed`.
- A skipped test gives `skipped`, so the verdict is `error`.
- A package that does not build gives `compiled: false`, so the verdict is `did-not-compile`.
- A name that matches no test gives no entry, so the verdict is `error`, and the baseline stops the run.
- A call that exits with an error and shows neither a test nor a build failure gives no result file and exit 3. Read the log of the call.

This is an example. The code:

```go
func Clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
```

The test checks a value below the range and a value inside it. The manifest entry changes `return hi` to `return lo`:

```json
{"label": "high", "file": "calc.go", "find": "return hi", "replace": "return lo", "test": ".::TestClamp"}
```

The test still passes, because no case goes above the range. So the verdict is `survived`. Add a subtest with a value above the range, and run the mutation again. The verdict is then `killed`.

In this repository, the CI job "Go layer on a real toolchain" runs `tests/go-toolchain/check.sh` on each pull request. It runs the commands of this skill and the runner against a small sample module. On <date>, with <go version line>, a passing test gave `passed`, a test name that matches nothing gave no entry, a type error gave `did-not-compile`, and the example above gave `survived`. The test `tests/test-go-runner.sh` covers the other cases with a stub Go command. Do not set `GO_BIN` in a run, because only the tests use it.

## Expert skills

The skills below come from the `cc-skills-golang` plugin. Install it in Claude Code with these two commands:

```bash
/plugin marketplace add samber/cc
```

```bash
/plugin install cc-skills-golang@samber
```

If the task is in the territory of a skill, load the skill. If a skill conflicts with the rules file of the repository, the rules file wins. Say in the report that you diverged. If a skill is not installed, say so and continue without it.

Implementer:

- `golang-testing` for tests and fakes.
- `golang-error-handling` for errors.
- `golang-security` for input, secrets, and logs.
- `golang-observability` for what a log line may hold.
- `golang-database` for a change to database code.
- `golang-swagger` for generated API docs.
- `golang-project-layout` and `golang-structs-interfaces` for packages and interfaces.
- `golang-code-style` and `golang-naming` for style.
- `golang-troubleshooting` for a test that fails for a cause that is not clear.

Reviewer:

- `golang-testing` to judge whether the tests are adequate.
- `golang-security` and `golang-observability` for input, secrets, and logs.
- `golang-error-handling` for errors.
- `golang-swagger` for generated API docs.
- `golang-project-layout` for the layers.
````

- [ ] **Step 2: Lint and guard**

Run: `$LINT skills/platform-go/SKILL.md` and fix each hit of the named kinds. Run `$GUARD .`. Expected: exit 0.

- [ ] **Step 3: Commit**

```bash
git add skills/platform-go/SKILL.md
git commit -m "Add the Go platform skill

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 5: Template, README, and version 0.4.0

**Files:**
- Modify: `templates/agentic-delivery.md` (the `platform` and `mutation_runner` bullets)
- Modify: `README.md` (tree, skill table, platform table)
- Modify: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `templates/agentic-delivery.md` (version)

- [ ] **Step 1: The template**

In the `platform` bullet, replace `and the value `ios` loads the skill `platform-ios`.` with:

```
the value `ios` loads the skill `platform-ios`, and the value `go` loads the skill `platform-go`.
```

At the end of the same bullet, add:

```
 For a Go project, the skill `platform-go` explains the optional key `go_command`, and says what `test_processes` and `view_globs` hold.
```

In the `mutation_runner` bullet, replace `and the iOS adapter is `skills/platform-ios/mutation-runner.sh`.` with:

```
the iOS adapter is `skills/platform-ios/mutation-runner.sh`, and the Go adapter is `skills/platform-go/mutation-runner.sh`.
```

- [ ] **Step 2: The README**

In the tree under What is inside, replace `one platform layer in each folder: flutter, ios` with `one platform layer in each folder: flutter, ios, go`.

In the skills table, after the `platform-ios` row, add:

```
| `platform-go` | The Go layer, for services with an HTTP API | For a project with `platform: go`, step 0 of `/feature` loads it after the two above. A CI job runs its commands on a real Go toolchain |
```

In the platform table, replace the row `| Backend services | APIs and workers | Not started |` with:

```
| Go | Services with an HTTP API | Rules written. It has the mutation runner. A CI job runs its commands and the runner on a real Go toolchain. No real feature used it yet. |
```

- [ ] **Step 3: Bump the version**

Run: `grep -rn "0\.3\.0" .claude-plugin README.md templates`
Change each hit to `0.4.0`, including the tag examples. Make sure that the grep finds no hit afterwards.

- [ ] **Step 4: Lint, guard, test, and commit**

Run `$LINT` on the two documents, `$GUARD .`, and `bash tests/run-all.sh`. Expected: both commands exit 0.

```bash
git add templates/agentic-delivery.md README.md .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "Describe the Go layer and bump the version to 0.4.0

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 6: Final review and pull request

- [ ] **Step 1: Run every check**

Run `bash tests/run-all.sh` and `$GUARD .`. Expected: both exit 0. The CI job of Task 3 passes on the last push.

- [ ] **Step 2: Whole-branch review**

Dispatch one reviewer over `git diff main...feature/platform-go` with the spec, this plan, and the Review Focus list. Fix each Critical and Important finding, and commit.

- [ ] **Step 3: Push and mark ready**

Push under the user's word from Task 3, step 5, or ask again if that word covered only the measurement push. Rewrite the pull request body: the behavior before and after, the checks, and the Minor follow-ups. Mark it ready. Merge only after the user says merge.
