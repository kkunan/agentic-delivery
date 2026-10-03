# agentic-delivery Implementation Plan, from Task 7

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the agentic-delivery plugin: the project file, the generic scripts, the hooks, the lean writing mode, the install test, the Flutter layer, and the mutation runner contract.

**Architecture:** One plugin repository that is also its own marketplace. Rules load as skills at the step that needs them. A start-up hook gives only a short pointer. Each project adds one tracked project file whose front matter the scripts read. Platform knowledge lives in one skill folder for each platform. Flutter is the first.

**Tech Stack:** The Claude Code plugin format, shell scripts for the macOS bash 3.2, Python 3.9 for helpers, and Swift for the screenshot settle script.

**Spec:** `docs/superpowers/specs/2026-10-02-agentic-delivery-design.md`

## Done before this plan

Tasks 1 to 6 are done. The repository has the manifests and the test helpers. It has the rule skills `run-rules` and `controller`, and `lessons.md`. It has the feature command, the three agents, and the process scripts with their tests. `bash tests/run-all.sh` passes. The scripts still hold source-specific values, and Tasks 8 to 11 and 19 make them generic.

## Global Constraints

- Never push without the owner's word in chat for that push.
- The repository is public. Write generic text only: no client names, device ids, hosts, accounts, or ticket numbers.
- Prose passes the Simple English lint with 0 hits. If the simple-english plugin is installed, run its `evals/ste_lint.py <file>` and read `violations_total`.
- Shell scripts run on the macOS `/bin/bash` 3.2: no associative arrays, no `${var,,}`, no `mapfile`. A script that starts with `#!/bin/sh` stays POSIX.
- No comments in code. Section banners such as `# ── Running tests ──────` are allowed.
- Commit trailer: `Co-Authored-By: Claude <noreply@anthropic.com>`.
- Project file path in a user project: `.claude/agentic-delivery.md`.
- Plugin name: `agentic-delivery`. First version: `0.1.0`.
- Before each commit, run `bash tests/run-all.sh` and `claude plugin validate .`.

---

## Phase 1: the core, continued

### Task 7: The project file and its reader

**Files:**
- Create: `templates/agentic-delivery.md`, `scripts/project-config.sh`, `tests/test-project-config.sh`

**Interfaces:**
- Produces: `project-config.sh <key> [default]`. It reads the front matter between the first two `---` lines of `.claude/agentic-delivery.md` at the top of the current git repository. It prints the value and exits 0. A missing key with a default prints the default and exits 0. A missing key with no default exits 3. A missing project file exits 4. Outside a git repository it exits 5. The keys:
  - `platform`, `min_plugin_version`
  - `base_branch`, `branch_prefix`, `protected_branches`
  - `docs`, `docs_dir`
  - `view_globs`, `test_processes`, `screenshot_branch`
  - `implementer_agent`, `reviewer_agent`, `qa_agent`

- [ ] **Step 1: Write the failing test**

```bash
#!/bin/bash
set -u
here=$(cd "$(dirname "$0")" && pwd -P)
. "$here/lib.sh"
cfg="$here/../scripts/project-config.sh"
work=$(mktemp -d)
git -C "$work" init -q
mkdir -p "$work/.claude"
printf -- '---\nplatform: flutter\nbase_branch: develop\n---\n# notes\nplatform: wrong\n' > "$work/.claude/agentic-delivery.md"
cd "$work"
check "reads a key" "flutter" "$(bash "$cfg" platform)"
check "ignores the body" "develop" "$(bash "$cfg" base_branch)"
check "a default fills a missing key" "feature/" "$(bash "$cfg" branch_prefix feature/)"
bash "$cfg" docs_dir >/dev/null 2>&1; check "a missing key fails closed" 3 $?
rm "$work/.claude/agentic-delivery.md"
bash "$cfg" platform >/dev/null 2>&1; check "a missing file fails closed" 4 $?
cd /
bash "$cfg" platform >/dev/null 2>&1; check "outside a repository fails closed" 5 $?
rmdir "$work/.claude"; rm -rf "$work/.git"; rmdir "$work"
finish
```

- [ ] **Step 2:** Run `bash tests/test-project-config.sh` and expect failures, because the script does not exist.

- [ ] **Step 3: Write the reader**

```bash
#!/bin/bash
set -u
[ $# -ge 1 ] || { echo "usage: project-config.sh <key> [default]" >&2; exit 2; }
key=$1
top=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "project-config: not in a git repository" >&2; exit 5; }
file="$top/.claude/agentic-delivery.md"
[ -f "$file" ] || { echo "project-config: no project file at $file" >&2; exit 4; }
value=$(awk -v k="$key" '
    NR == 1 && $0 != "---" { exit }
    NR > 1 && $0 == "---" { exit }
    NR > 1 {
        i = index($0, ":")
        if (i > 0 && substr($0, 1, i - 1) == k) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); print v; exit }
    }' "$file")
if [ -n "$value" ]; then
    printf '%s\n' "$value"
elif [ $# -ge 2 ]; then
    printf '%s\n' "$2"
else
    echo "project-config: no '$key' in $file" >&2
    exit 3
fi
```

- [ ] **Step 4:** Run the test and expect `6 passed, 0 failed`.
- [ ] **Step 5:** Write the template. Its front matter holds every key with a Flutter example value. Its body holds five sections in prose, each with an instruction for the team to fill in: `## Tracker steps`, `## Devices`, `## Accounts`, `## Ask-first areas`, and `## Agents`. The agents section says how to name a custom agent for a seat. It also says that the brief still makes that agent load the run rules and the platform skill. The `docs` key explains `repo` and `private`, and that `private` needs an absolute `docs_dir` beside the repository.
- [ ] **Step 6:** Lint the template, and commit.

### Task 8: The device claim

**Files:**
- Create: `scripts/claim-device.sh`, `tests/test-claim-device.sh`

- [x] **Step 1:** Done. `scripts/claim-device.sh` and `tests/test-claim-device.sh` are in the repository, and the test passes 21 of 21.
- [ ] **Step 2:** Rename the variable `APP_DEVICE_LOCK_DIR` to `AGENTIC_DEVICE_LOCK_DIR` in both files. Change the default folder to `$HOME/Library/Caches/agentic-delivery/device-locks`.
- [ ] **Step 3:** Replace `--udid` with `--device`. Replace the UDID check with this rule: the id is 1 to 64 characters from `A-Z a-z 0-9 . _ -`, and it is not `.` or `..`. The id becomes a file name, so the rule stops a path in an id. The error message names the rule.
- [ ] **Step 4:** Add three checks to the test before you change the script: `emulator-5554` is accepted with exit 0, `chrome` is accepted with exit 0, and `../x` is refused with exit 4. Run the test and see the first two fail against the copied script.
- [ ] **Step 5:** Change the script, run the test, and expect every check to pass.
- [ ] **Step 6:** Commit.

### Task 9: The stall watch

**Files:**
- Create: `scripts/stall-watch.sh`, `tests/test-stall-watch.sh`

**Interfaces:**
- Produces: `stall-watch.sh [--interval s] [--idle-after min] [--build-after min] [--roots "<paths>"] [--process <name>]... [--exclude <path>]... [--polls n]`. With no `--process`, it reads `test_processes` from the project file as a comma list. With neither, it refuses to start with exit 2. `--polls n` stops after n polls, for tests. Each heartbeat line ends with `disk=<n>G`, the free space on the volume of the first root. Below 5 GB free it also prints `DISK LOW <n>G`.

- [ ] **Step 1: Write the failing test.** It copies `/bin/sleep` to `$work/fake_tester`, starts it with `"$work/fake_tester" 30 &`, and runs the watch with `--process fake_tester --roots "$work/root" --interval 1 --build-after 0 --polls 3`. It checks that the output has a line with `BUILD FROZEN`. It runs the watch with no `--process` in a repository with no project file and checks exit 2. It runs the watch with `--roots /nonexistent` and checks exit 2. It checks that a `HEARTBEAT` line contains `disk=`. It kills the fake process by its own PID and removes only the paths it created.
- [ ] **Step 2:** Run it against the current `scripts/stall-watch.sh` and see the process and disk checks fail.
- [ ] **Step 3:** Change the script: the `--process` loop replaces `pgrep -x xcodebuild`, the `.tooling` exclusion becomes `--exclude`, add `--polls`, and add the disk figure from `df -g "$first_root"`. A `--build-after 0` gives one frozen poll.
- [ ] **Step 4:** Run the test and expect every check to pass. Commit.

### Task 10: The ready check

**Files:**
- Create: `scripts/ready-check.sh`, `tests/test-ready-check.sh`

- [x] **Step 1:** Done. `scripts/ready-check.sh` is in the repository.
- [ ] **Step 2:** Replace each fixed value with a project file key:
  - the branch prefix `feature/` with `branch_prefix`
  - `origin/develop` with `origin/<base_branch>`
  - `.superpowers/sdd` with `docs_dir`
  - the Swift file count with a count of changed files that match `view_globs`

   When `docs` is `private`, the ledger folder is `<docs_dir>/<date>-<slug>`.
- [ ] **Step 3:** Remove the fixed cost-rule start date. Every ledger needs the cost lines. Remove the word "Swift" from the screenshot message. Change the waiver pattern so that it accepts the form in the `controller` skill: `waiver: <check> by gate owner on <yyyy-mm-dd>: <reason>`. The current pattern accepts only `by owner` and `by the owner`.
- [ ] **Step 4: Write the test.** It builds a throwaway repository with a bare remote and a project file. The repository has a feature branch, a ledger with `progress.md`, and a QA log. The test does not need GitHub. It sets `READY_CHECK_BASE` and a new variable, `READY_CHECK_SKIP_PR=1`. That variable makes the two pull request checks print `SKIP`. Cases: a complete ledger passes the ledger, cost, and QA checks. A commit absent from `progress.md` fails "ledger names every commit". A missing `final` cost line fails "cost lines". A tally with 1 unrun fails "every manual check ran". A deleted ledger folder fails "ledger present". A missing project file exits non-zero with the reader's message.
- [ ] **Step 5:** Run the test, fix until it passes, then break the script on purpose: comment out the cost line check, run the test, expect a failure, and restore the line. Commit.

### Task 11: The screenshot settle script

**Files:**
- Create: `scripts/settle-screenshot.swift`, `tests/test-settle-screenshot.sh`

- [x] **Step 1:** Done. `scripts/settle-screenshot.swift` is in the repository.
- [ ] **Step 2:** Replace the fixed `xcrun simctl io <udid> screenshot` call with `--capture "<command>"`. The script runs the command through `/bin/sh -c` with `{out}` replaced by the frame path. The comparison and the exit codes stay.
- [ ] **Step 3: Write the test.** A capture command that copies one fixed PNG gives exit 0. A capture command that alternates between two different PNGs gives exit 1 and names a region on stderr. A capture command that writes nothing gives exit 1 or 2 and never 0. Make the two PNGs with `sips` from a solid color, or commit two 8 by 8 PNG fixtures.
- [ ] **Step 4:** Run the test and expect every case to pass. Commit.

### Task 12: The hooks

**Files:**
- Create: `hooks/hooks.json`, `hooks/session-start.sh`, `hooks/retro-notice.sh`, `tests/test-hooks.sh`
- Modify: `.claude-plugin/plugin.json`. If `claude plugin validate .` finds `hooks/hooks.json` by itself, skip this file.

- [ ] **Step 1:** `hooks.json` wires `SessionStart` with matcher `startup|clear|compact` to `bash "${CLAUDE_PLUGIN_ROOT}/hooks/session-start.sh"`, and `PostToolUse` with matcher `Write|Edit` to `bash "${CLAUDE_PLUGIN_ROOT}/hooks/retro-notice.sh"`.
- [ ] **Step 2:** With no project file in the current repository, `session-start.sh` prints nothing and exits 0. With a project file, it prints this JSON shape, with the text escaped for JSON:

```json
{"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": "<text>"}}
```

  The text is at most 600 characters. It names the three skills and the step that loads each one. The project file can ask for a higher version than the `version` in `plugin.json`. In that case, the text starts with `agentic-delivery <v> is older than this project needs (<min>). Update the plugin.`

- [ ] **Step 3:** `retro-notice.sh` reads the hook input JSON from stdin with `python3`. When `tool_input.file_path` is inside `<docs_dir>/retros/` or under `docs/superpowers/retros/`, it prints a `PostToolUse` additional context that says: propose each rule change as a pull request to the plugin repository. Otherwise it prints nothing.
- [ ] **Step 4: Write the test.** No project file gives empty output. A project file with `min_plugin_version: 9.0.0` gives text that starts with the warning. A normal project file gives valid JSON, checked with `python3 -m json.tool`, and the text is at most 600 characters. A retro path gives the notice. A source path gives nothing.
- [ ] **Step 5:** Run the tests and the plugin validator. Commit.

### Task 13: The lean writing mode

**Files:**
- Create: `output-styles/lean.md`

- [ ] **Step 1:** Write the front matter with `name: lean` and a one-line description.
- [ ] **Step 2:** Write the rules in our own words. Do not copy text from the simple-english plugin or the unslop skill. The rules:
  - Start with the answer.
  - No openers or closers, and no announcing a step.
  - Say each thing once.
  - Short sentences in active voice.
  - One word for one meaning.
  - No filler words, and no hedging of a checked fact.
  - No em-dashes or emoji.

  Keep the file under 2,500 characters.
- [ ] **Step 3:** Lint, and commit.

### Task 14: README and the token figure

**Files:**
- Modify: `README.md`

- [ ] **Step 1:** Run `claude plugin details` on the local install from Task 15 Step 2, and record its projected token cost.
- [ ] **Step 2:** Write the README with these parts:
  - what the plugin does
  - the install commands that Task 15 ran
  - the project file
  - each skill, and the step that loads it
  - the scripts and their tests
  - the lean mode
  - the measured token figure
- [ ] **Step 3:** Lint, and commit.

### Task 15: Install test

- [ ] **Step 1:** In a new folder under the scratchpad, run `git init` and copy `templates/agentic-delivery.md` to `.claude/agentic-delivery.md`.
- [ ] **Step 2:** Add the local repository as a marketplace and install the plugin, with the `claude plugin marketplace` and `claude plugin install` subcommands. Read `claude plugin marketplace --help` first for the exact form, and record the commands that worked.
- [ ] **Step 3:** Start a session in the test folder. Make sure that the start-up pointer appears, that `/feature` is listed, and that the three agents are listed.
- [ ] **Step 3b:** Add a small agent to the test folder's agents folder, and name it in `implementer_agent`. Run the first dispatch of `/feature` far enough to see which agent it starts. Make sure that it starts the custom agent. Then set the key to a name that does not exist, and make sure that the run stops and names the key.
- [ ] **Step 4:** Uninstall the plugin and remove the marketplace. Delete only the folder that Step 1 created.

---

## Phase 2: the Flutter layer

### Task 16: The platform-flutter skill

**Files:**
- Create: `skills/platform-flutter/SKILL.md`

- [ ] **Step 1:** Write the front matter. The description says: if the project file says `platform: flutter`, load this skill.
- [ ] **Step 2:** Write the sections from the spec: test tiers, devices, commands, screenshots, release checks. Add four rules that the `run-rules` skill left to the platform:
  - the ordered remedies for a stalled test run: clean the device clones, kill and relaunch, and make sure that the device is still running
  - the screenshot tolerance and the text caret advice for `settle-screenshot.swift`
  - the removal of empty folders after a device clean-up
  - a disk figure for device clones is not reliable, because the clones share blocks
- [ ] **Step 3:** Mark each command and flag `unverified` until Task 17 runs it.
- [ ] **Step 4:** Lint, and commit.

### Task 17: Verify the Flutter commands on the Flutter Mac

This task runs on the Flutter Mac, not on this Mac.

- [ ] **Step 1:** Run `flutter --version`, `flutter test --help`, `flutter drive --help`, and `flutter devices`, and save the output.
- [ ] **Step 2:** Run each command in the skill once on a real project. Record the exit code and the log file. Replace each `unverified` mark with the measured form. Remove a command that does not exist.
- [ ] **Step 3:** Record the process names of a running test with `ps`, and put them into the template's `test_processes` example.
- [ ] **Step 4:** Record a capture command for each device kind that Task 11's `--capture` can run: the iOS simulator, the Android emulator, and Chrome.
- [ ] **Step 5:** Commit the measured skill.

### Task 18: The pilot

- [ ] **Step 1:** The Flutter team picks one small feature, adds the project file, and runs `/feature`.
- [ ] **Step 2:** The retro compares cost and time with the estimate. It lists each missing rule and each wrong rule in the plugin.
- [ ] **Step 3:** Each rule change from the retro becomes a pull request to the plugin repository.

---

## Phase 3: the mutation runner

### Task 19: Runner contract and core port

**Files:**
- Create: `scripts/mutate.sh`, `scripts/mutate/` (`run.sh`, `report.sh`, `mutate.py`, `manifest.py`, `journal.py`, `results.py`), `scripts/mutate-selftest.sh`, `scripts/mutate/selftest/`

**Interfaces:**
- Produces: the runner contract. `mutate.sh` calls `<runner> --out <result.json> --log <log> -- <test-id>...`. The runner writes `{"compiled": true|false, "tests": [{"id": "<id>", "result": "passed|failed|skipped"}]}`. A missing or invalid result file gives the verdict `error`.

- [x] **Step 1:** Done. The runner and its self-test are in the repository. `tests/test-mutate-selftest.sh` runs the self-test, which passes 80 of 80.
- [ ] **Step 2:** Rewrite `results.py` to read the contract file. The verdicts:
  - `did-not-compile`: `compiled` is false.
  - `killed`: a named test failed.
  - `survived`: every named test passed.
  - `error`: any other case.

  A baseline problem is a named test that did not run, did not pass, or failed.
- [ ] **Step 3:** Replace `run_tests` in `run.sh` with the runner call. The runner comes from `--runner` or from the project file key `mutation_runner`. Remove the workspace and scheme names.
- [ ] **Step 4:** Remove the fake `xcodebuild` and the fake `xcresulttool` from the self-test. Add one fake runner that writes a contract file for each scenario. Rewrite the fixtures in the contract shape.
- [ ] **Step 5:** Run the self-test and `--mutants`, and expect every broken copy to be caught.
- [ ] **Step 6:** Commit.

### Task 20: Flutter runner adapter

This task runs on the Flutter Mac.

- [ ] **Step 1:** Write `skills/platform-flutter/mutation-runner.sh`. It runs the named tests with the reporter and name filter flags that Task 17 measured, and converts the reporter output into the contract file.
- [ ] **Step 2:** Test it on a real project: one passing test gives `passed`, one test broken on purpose gives `failed`, and a syntax error gives `compiled: false`.
- [ ] **Step 3:** Commit.

### Task 21: iOS runner adapter

The iOS design, decision 4, keeps the Xcode result parser of the source project as the iOS adapter. Task 19 removed that parser from the core, so this task adds it back as an adapter.

- [x] **Step 1:** Write `skills/platform-ios/mutation-runner.sh`. It runs `xcodebuild test` once with an `-only-testing` flag for each test id, reads the result bundle with `xcresulttool`, and converts it into the contract file. It reads `ios_workspace`, `ios_scheme`, and `ios_test_plan` from the project file, and takes the simulator and the derived data folder from `AGENTIC_TEST_DEVICE` and `AGENTIC_DERIVED_DATA`.
- [x] **Step 2:** Write `tests/test-ios-runner.sh`, with a fake `xcodebuild` and a fake `xcresulttool` that print the captured output in `tests/fixtures/ios/`. The test passes 108 of 108. Each of 13 broken copies of the runner turned it red.
- [ ] **Step 3:** Test it on a real project on a Mac: one passing test gives `passed`, one test broken on purpose gives `failed`, and a compile error gives `compiled: false`. Record the Xcode version.
- [x] **Step 4:** Commit.

---
