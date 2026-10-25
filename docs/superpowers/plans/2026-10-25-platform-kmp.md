# Kotlin Multiplatform Platform Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `platform: kmp` to agentic-delivery, with a skill, a mutation runner, and a small KMP sample that measures both before the layer lands.

**Architecture:** The mutation runner comes first, test-driven against a fake Gradle command, so it needs no toolchain. Then a small KMP sample with four targets gets built under `tests/`, and a toolchain check script measures every command on it. The skill gets written last, from those measured runs, and the core files list the new layer at version 0.8.0.

**Tech Stack:** Bash and Python 3 for the runner and the tests, Kotlin Multiplatform with Compose Multiplatform for the sample, Gradle wrapper, Ktor on the JVM, Xcode for the iOS app, the Android SDK, headless Chrome.

**Spec:** `docs/superpowers/specs/2026-10-25-platform-kmp-design.md`

## Global Constraints

- The work stays on the branch `feature/platform-kmp`. One pull request against `main`.
- Every push and every merge needs the owner's yes in the chat. A merge reads CI once, then runs `gh pr merge --merge --match-head-commit <sha>`. Never use `--auto`.
- Before each push, `bash tests/run-all.sh` passes and the name guard hooks pass. Never bypass a hook.
- The plugin version becomes `0.8.0`.
- A command gets the mark "(measured: exit N, T seconds)" only after a real run on this Mac. An unmeasured command carries no mark.
- An item from the "must" or "must try" lists in the spec can land without a mark only when an outside tool blocks it. The skill then states the error and the tool versions.
- The skill stands alone. It never tells an agent to read another platform skill.
- No code comments. Section banners such as `# ── Arguments ───` are allowed, as the Go runner uses them.
- Docs and skill text follow the plain style of the other layers: simple tenses, short sentences, no "should", no semicolons.
- Stop a process only by its own process id, never by name.
- Each version of Kotlin, Compose Multiplatform, the Android Gradle plugin, Gradle, and Ktor comes from its official release page on the day of the build. Never copy a version from memory or from this plan.
- The plugin repository never names the private product that motivated this layer.

## Review Focus

1. Gradle reuses an old test result. A test task that is up to date leaves the old XML report, and the runner reports a verdict for code that did not run. Expect: the runner forces a rerun and removes the old report first. Pinned in Task 1 by `stale report`.
2. A KMP test report names a test with a target suffix, for example `groupsByDay[jvm]`. Expect: the id `...::trip.GroupingTest.groupsByDay` still matches. Pinned in Task 1 by `target suffix`.
3. `gradle_command` holds a space, for example `env JAVA_HOME=/some/jdk ./gradlew`. Expect: the runner runs it through `bash -c`, as the Go runner does. Pinned in Task 1 by `command with a space`.
4. A module sits deeper than one level, for example `:feature:trip:jvmTest`. Expect: the runner reads `feature/trip/build/test-results/jvmTest/`. Pinned in Task 1 by `nested module`.
5. Two worktrees run Gradle at the same time and wait on the shared Gradle home. Expect: the skill tells the stall watch how that wait looks in the log, so the run does not call it a stall. Pinned in Task 3 by a measured run of two builds at once.

---

### Task 1: The mutation runner, against a fake Gradle

**Files:**
- Create: `skills/platform-kmp/mutation-runner.sh` (start from a copy of `skills/platform-go/mutation-runner.sh`)
- Create: `tests/fixtures/kmp/fake-gradle.sh`
- Create: `tests/test-kmp-runner.sh`

**Interfaces:**
- Consumes: the runner contract in the usage text of `scripts/mutate.sh`.
- Produces: `skills/platform-kmp/mutation-runner.sh --out <result.json> --log <log> -- <Gradle test task path>::<class>.<method>...`
  - It reads `gradle_command` from the front matter of `.claude/agentic-delivery.md` at the top of the git repository. The default is `./gradlew`. The environment variable `GRADLE_BIN` overrides it, for the tests only.
  - It groups the ids by task. For each task it removes `<module dir>/build/test-results/<task name>/`, then runs `<gradle> <task path> --tests <filter> [--tests <filter>...] --rerun --console=plain` through `bash -c`, from the top of the repository. `<module dir>` is the task path without its last part, with `:` turned into `/`, for example `:feature:trip:jvmTest` gives `feature/trip`.
  - It reads every `TEST-*.xml` in that folder. A `testcase` with `classname` C and `name` N matches the id `C.N`. A name with one trailing `[<target>]` part also matches, for example `groupsByDay[jvm]`. A `failure` or `error` child gives `failed`, a `skipped` child gives `skipped`, and no child gives `passed`.
  - Output that holds a line `> Task :<module>:compile<anything>Kotlin<anything> FAILED` gives `compiled: false`.
  - Output that holds `No tests found for given includes` gives no entry for that task's ids, and the runner still writes the result file.
  - A non-zero exit with no report, no compile failure, and no "No tests found" line gives no result file and exit 3, as the Go runner does.
  - An id without `::`, or with an empty part, gives exit 2 with a `REFUSED:` line in the log.

The fake Gradle, `tests/fixtures/kmp/fake-gradle.sh`, appends its arguments to `$FAKE_CALLS` and its working folder to `$FAKE_CALLS.pwd`. It takes the first argument as the task path. If `$FAKE_GRADLE_DIR/<key>.xml` exists, it copies it to the report folder of that task as `TEST-fake.xml`. If `$FAKE_GRADLE_DIR/<key>.out` exists, it prints it. It exits with the number in `$FAKE_GRADLE_DIR/<key>.rc`, or 0. `<key>` is the task path with every character that is not a letter or a digit turned into `_`, as the fake Go does.

- [ ] **Step 1: Write the failing tests in `tests/test-kmp-runner.sh`**

Follow the structure of `tests/test-go-runner.sh`: source `tests/lib.sh`, make a temporary git repository, define `entries`, `run`, and fixture helpers, and end with `finish`. Write one block for each case:

```bash
run pass :shared:jvmTest::trip.ClampTest.inside
check "pass: exit 0" 0 "$rc"
check "pass: entry" "True :shared:jvmTest::trip.ClampTest.inside=passed" "$(entries pass)"
check "pass: flags" ":shared:jvmTest --tests trip.ClampTest.inside --rerun --console=plain" "$(cat "$FAKE_CALLS")"
```

The cases and their expected `entries` output:

| Case | Fixture | Expected |
|---|---|---|
| `pass` | testcase with no child | `True <id>=passed` |
| `fail` | `<failure>` child | `True <id>=failed` |
| `error element` | `<error>` child | `True <id>=failed` |
| `skipped` | `<skipped/>` child | `True <id>=skipped` |
| `target suffix` | `name="inside[jvm]"` | `True <id>=passed` |
| `two ids, one task` | two testcases | both entries, and one call with two `--tests` flags |
| `two tasks` | ids on `:shared:jvmTest` and `:server:test` | two calls, both entries |
| `missing name` | report without that testcase | `True ` with no entry for the id, exit 0 |
| `no tests found` | no XML, `.out` holds `No tests found for given includes`, rc 1 | `True ` with no entry, exit 0 |
| `compile failure` | no XML, `.out` holds `> Task :shared:compileKotlinJvm FAILED`, rc 1 | `False ` |
| `unknown failure` | no XML, no matching line, rc 1 | `(no result file)`, exit 3 |
| `stale report` | a `TEST-old.xml` already in the report folder, fake writes nothing, rc 0 | no entry, and `TEST-old.xml` is gone |
| `nested module` | id `:feature:trip:jvmTest::a.B.c` | the fake wrote under `feature/trip/build/test-results/jvmTest/`, entry present |
| `duplicate id` | the same id twice | one entry, one `--tests` flag |
| `refused, no ::` | id `trip.ClampTest.inside` | exit 2, log holds `REFUSED:` |
| `refused, empty part` | id `::trip.ClampTest.inside` | exit 2 |
| `project file command` | no `GRADLE_BIN`, project file says `gradle_command: <fake>` | the fake ran |
| `command with a space` | project file says `gradle_command: env FAKE_FLAG=1 <fake>` | the fake ran, and it saw `FAKE_FLAG=1` |
| `working folder` | run from a subfolder of the repository | `$FAKE_CALLS.pwd` is the top of the repository |

- [ ] **Step 2: Run the tests and make sure that they fail**

Run: `bash tests/test-kmp-runner.sh`
Expected: FAIL lines, because `skills/platform-kmp/mutation-runner.sh` does not exist.

- [ ] **Step 3: Write `tests/fixtures/kmp/fake-gradle.sh` and `skills/platform-kmp/mutation-runner.sh`**

Keep the argument checks, `say`, `config_value`, and the `bash -c` call of the Go runner. Replace the Go parts with the behavior in the Interfaces block. Parse the XML with Python's `xml.etree.ElementTree`. Make both files executable.

- [ ] **Step 4: Run the tests and make sure that they pass**

Run: `bash tests/test-kmp-runner.sh`
Expected: the last line says `0 failed`, exit 0.

- [ ] **Step 5: Run the whole suite**

Run: `bash tests/run-all.sh`
Expected: exit 0. `test-kmp-runner.sh` appears in the list, because `run-all.sh` runs every `tests/test-*.sh`.

- [ ] **Step 6: Commit**

```bash
git add skills/platform-kmp/mutation-runner.sh tests/fixtures/kmp/fake-gradle.sh tests/test-kmp-runner.sh
git commit -m "Add the KMP mutation runner and its tests"
```

### Task 2: The KMP sample with four targets

**Files:**
- Create: `tests/kmp-sample/` with these parts:
  - `settings.gradle.kts`, `build.gradle.kts`, `gradle.properties`, `gradle/libs.versions.toml`, the Gradle wrapper (`gradlew`, `gradle/wrapper/gradle-wrapper.properties`, `gradle/wrapper/gradle-wrapper.jar`), and `.gitignore` for `build/`, `.gradle/`, `.kotlin/`, and `local.properties`.
  - `shared/`: a Kotlin Multiplatform module with the targets `jvm`, `wasmJs` (browser), `androidTarget`, `iosSimulatorArm64`, and `iosArm64`.
  - `composeApp/`: a Compose Multiplatform app with one screen, for `wasmJs`, Android, and iOS.
  - `server/`: a Ktor server on the JVM with one endpoint.
  - `iosApp/`: the Xcode project that shows the Compose screen.

**Interfaces:**
- Produces, for Tasks 3 to 5:
  - `shared/src/commonMain/kotlin/trip/Clamp.kt`: `fun clamp(v: Int, lo: Int, hi: Int): Int`, with the same body as the Go layer example: return `lo` below the range, `hi` above it, and `v` inside.
  - `shared/src/commonTest/kotlin/trip/ClampTest.kt`: class `trip.ClampTest` with the tests `below` and `inside`, and no test above the range. A mutation of the `hi` branch then survives, as in the Go layer example.
  - `server/src/main/kotlin/trip/Server.kt`: `fun Application.module()`, with `GET /health` that answers status 200 and the body `ok`.
  - `server/src/test/kotlin/trip/ServerTest.kt`: class `trip.ServerTest` with the test `healthAnswersOk`, through Ktor's test host.
  - The screen of `composeApp` shows the text `Sample` and the result of `clamp(15, 0, 10)` on a solid background color, so a screenshot proves that the app drew.

- [ ] **Step 1: Look up the versions**

Open the official release pages of Kotlin, Compose Multiplatform, the Android Gradle plugin, Gradle, and Ktor. Pick the newest stable release of each that the Compose Multiplatform compatibility page lists as working together. Write them into `gradle/libs.versions.toml`, and note the page and the date of each one for the skill.

- [ ] **Step 2: Make the Gradle wrapper**

No global Gradle exists on this Mac. Download the Gradle distribution zip of the chosen version from `services.gradle.org` into an empty folder outside the repository. Make sure that its SHA-256 matches the checksum that gradle.org publishes. Use it to run `gradle wrapper --gradle-version <version> --distribution-type bin` in `tests/kmp-sample/`. Set `distributionSha256Sum` in `gradle-wrapper.properties`.

- [ ] **Step 3: Write the modules**

Write the files that the Interfaces block names, and the smallest Gradle and Xcode setup that builds them. Use the JDK that the chosen Kotlin and Android Gradle plugin versions require. If the default JDK is wrong, note that the skill needs the `java_home` key.

- [ ] **Step 4: List the tasks**

Run: `cd tests/kmp-sample && ./gradlew tasks --all --console=plain > <work>/tasks.log 2>&1`
Expected: exit 0. The log lists a test task for each target of `shared`, the `server` test task, and the build tasks of `composeApp` for Wasm, Android, and the iOS framework. Record the exact names for Task 3.

- [ ] **Step 5: Run the JVM tests once**

Run: `cd tests/kmp-sample && ./gradlew :shared:jvmTest :server:test --console=plain > <work>/jvm.log 2>&1`
Expected: exit 0, and the reports under `shared/build/test-results/jvmTest/` and `server/build/test-results/test/` hold `trip.ClampTest` and `trip.ServerTest`.

- [ ] **Step 6: Make sure that nothing built is staged**

Run: `git status --short tests/kmp-sample`
Expected: only source, Gradle setup, wrapper, and Xcode project files. No `build/`, `.gradle/`, `.kotlin/`, or `local.properties`.

- [ ] **Step 7: Commit**

```bash
git add tests/kmp-sample
git commit -m "Add a small KMP sample with JVM, Wasm, Android, and iOS targets"
```

### Task 3: The toolchain check and the measured runs

**Files:**
- Create: `tests/kmp-toolchain/check.sh`

**Interfaces:**
- Consumes: the task names from Task 2 Step 4, the runner from Task 1, `scripts/settle-screenshot.swift`, and `scripts/claim-device.sh`.
- Produces: `tests/kmp-toolchain/check.sh <empty work folder>`. It writes its evidence under `<work>/evidence/`: one log for each command, with the exit code and the time in seconds, the runner result files, and the screenshot. It ends with `finish` from `tests/lib.sh`, and exits 0 only if every check passed. Task 5 cites these numbers.

- [ ] **Step 1: Write the script**

Follow `tests/go-toolchain/check.sh`. Copy `tests/kmp-sample` to `<work>/sample`, write `.claude/agentic-delivery.md` there with `gradle_command: ./gradlew`, and commit it in a new git repository. Then check, in this order:

1. The build and the tests of each target, each with `--console=plain`: shared JVM tests, server tests, shared Wasm browser tests, Android host tests, the Android debug build, iOS simulator tests, and the iOS framework link. Each check expects exit 0.
2. The runner baseline on `:shared:jvmTest::trip.ClampTest.inside` and `:server:test::trip.ServerTest.healthAnswersOk`: both `passed`.
3. The runner verdicts, through `scripts/mutate.sh` with a manifest: the `hi` branch mutation gives `survived`, a mutation of the `lo` branch gives `killed`, a mutation that breaks the syntax gives `did-not-compile`, and the id `:shared:jvmTest::trip.ClampTest.nothing` gives `error` at the baseline.
4. The `--tests` filter on a second target: the runner on the iOS simulator test task with `trip.ClampTest.inside`. Record whether the filter works there. A failure here does not fail the script, because the spec lists it as "must try".
5. Serving the web app: claim `web-<port>` with `scripts/claim-device.sh`, start the production web run task of `composeApp` detached with its own log, wait for the "served at" line, and record the time.
6. The web screenshot: capture with the Flutter headless Chrome command and `scripts/settle-screenshot.swift`. If the frame is blank, try `--enable-unsafe-swiftshader`, then a visible Chrome window with its own profile, as the spec says. Stop the server and Chrome by their process ids. Release the claim.

- [ ] **Step 2: Run it**

Run: `bash tests/kmp-toolchain/check.sh "$(mktemp -d)"`
Expected: the last line says `0 failed`. Open the screenshot and make sure that it shows the `Sample` screen, not a blank frame.

- [ ] **Step 3: Measure the stall signals**

During one run, record the process names with `pgrep -lx java`, `pgrep -lx node`, and `pgrep -lx xcodebuild`. Then start two Gradle builds of two copies of the sample at the same time, and record what the log of the second build shows while it waits. These go into the `test_processes` and Stalled runs parts of the skill.

- [ ] **Step 4: Commit**

```bash
git add tests/kmp-toolchain/check.sh
git commit -m "Add the KMP toolchain check"
```

### Task 4: The emulator and simulator runs, by hand

**Files:** none in the repository. The evidence goes to a work folder outside the repository. Task 5 cites it.

**Interfaces:**
- Consumes: the sample from Task 2 and `scripts/claim-device.sh`, `scripts/settle-screenshot.swift`.
- Produces: for each device kind, the commands with their exit codes and times, and a settled screenshot of the `Sample` screen, or the error and the tool versions when an outside tool blocks the run.

- [ ] **Step 1: Android emulator**

Create and boot an emulator, and claim it with `scripts/claim-device.sh --device <emulator-id> --worktree <path>`. Install with the `composeApp` install task for the debug variant, start the app with `adb -s <emulator-id> shell am start`, and capture with `adb -s <emulator-id> exec-out screencap -p` through the settle script. Record each command, exit code, and time. Release the claim, stop the emulator, and delete it.

- [ ] **Step 2: iOS simulator**

Create and boot a simulator, and claim it. Build `iosApp` for that simulator with `xcodebuild`, install it with `xcrun simctl install`, start it with `xcrun simctl launch`, and capture with `xcrun simctl io <simulator-id> screenshot` through the settle script. Record each command, exit code, and time. Release the claim, shut down the simulator, and delete it.

- [ ] **Step 3: Make sure that both screenshots show the screen**

Open both frames. Each must show `Sample` and the clamp result. If an outside tool blocked a run, record the error and the versions instead.

### Task 5: The skill

**Files:**
- Create: `skills/platform-kmp/SKILL.md`

**Interfaces:**
- Consumes: the evidence of Tasks 3 and 4, the versions from Task 2 Step 1, and the runner behavior of Task 1.
- Produces: a skill with this front matter:

```yaml
---
name: platform-kmp
description: "The Kotlin Multiplatform layer of an agentic-delivery run, for shared Kotlin code, Compose Multiplatform apps on Wasm, Android, and iOS, and Ktor servers. It holds the test tiers, the commands, the devices, the screenshots, and the mutation runner. If the project file says `platform: kmp`, load this skill."
---
```

- [ ] **Step 1: Write the sections**

In this order: Project file keys (`gradle_command`, `java_home` if Task 2 needed it, `test_processes` and `view_globs` from Task 3), The rules file of the repository, Test tiers, Commands, Devices and claims, Screenshots, Logs and API contract, Manual checks, Stalled runs, Mutation tests, Expert skills, Where this layer was used. Copy and adapt each rule that the spec takes from the Go, Flutter, and Node layers. Give each command the mark "(measured: exit N, T seconds)" from the evidence. Leave a command without a mark only under the rule in Global Constraints, and state the error and the versions there. Name the versions that the runs used.

- [ ] **Step 2: Search for an expert skill set**

Search for an installable skill set for Kotlin, KMP, or Compose Multiplatform. If one exists, name it with its install commands and the skills for the implementer and the reviewer, as the Go layer does. If none exists, the section says so.

- [ ] **Step 3: Make sure that the skill stands alone**

Run: `grep -n 'platform-flutter\|platform-go\|platform-node\|platform-ios' skills/platform-kmp/SKILL.md`
Expected: no line that tells an agent to read or load another layer.

- [ ] **Step 4: Make sure that every mark has evidence**

For each "(measured:" in the skill, find the log in the evidence with the same exit code and time.

- [ ] **Step 5: Commit**

```bash
git add skills/platform-kmp/SKILL.md
git commit -m "Add the Kotlin Multiplatform platform skill"
```

### Task 6: List the layer and move to 0.8.0

**Files:**
- Modify: `README.md:6` (version badge), `README.md:9` (platforms badge), `README.md:119-125` (platform table), `README.md:155-162` (sources note)
- Modify: `docs/inside.md:11` (folder line), `docs/inside.md` layer table near line 34, platforms table near line 126
- Modify: `templates/agentic-delivery.md:3` (`min_plugin_version`), `:37` (`platform` clause), `:52` (`mutation_runner` clause)
- Modify: `docs/install.md:13` and `:27` (pins)
- Modify: `.claude-plugin/plugin.json:5`, `.claude-plugin/marketplace.json:13`

**Interfaces:**
- Consumes: the measured state from Task 5. The README row and `docs/inside.md` say which parts are not measured.

- [ ] **Step 1: Make the edits**

- The version is `0.8.0` in the five places: the README badge, both pins in `docs/install.md`, `plugin.json`, `marketplace.json`, and `min_plugin_version`. Also change "version 0.7.0" in the README sources note to "version 0.8.0".
- The platforms badge adds `KMP` after `Node`.
- The README table gets a row for Kotlin Multiplatform apps, with its real state, for example "Commands and mutation runner measured on a sample project". The sources note gets one line about the sample run and its date.
- `docs/inside.md` adds `kmp` to the folder line, a `platform-kmp` row in the layer table, and a KMP row in the platforms table, both in the style of the Node rows.
- The template `platform` line adds "and the value `kmp` loads the skill `platform-kmp`", and a sentence that the skill `platform-kmp` explains the optional key `gradle_command` and says what `test_processes` and `view_globs` hold. The `mutation_runner` line adds the KMP adapter `skills/platform-kmp/mutation-runner.sh`.

- [ ] **Step 2: Make sure that no old version is left**

Run: `grep -rn "0\.7\.0" README.md docs/install.md .claude-plugin templates`
Expected: no output.

- [ ] **Step 3: Run the suite**

Run: `bash tests/run-all.sh`
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add README.md docs/inside.md docs/install.md templates/agentic-delivery.md .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "List the KMP layer and bump to 0.8.0"
```

### Task 7: The pull request

**Files:** none.

- [ ] **Step 1: Final checks**

Run: `bash tests/run-all.sh` and `git log --oneline main..HEAD`
Expected: exit 0, and the commits of Tasks 1, 2, 3, 5, and 6 on top of the design commit.

- [ ] **Step 2: Ask the owner for the push**

Show the commit list and each item that landed without a mark. Wait for a clear yes.

- [ ] **Step 3: Push and open the pull request**

After the yes, push `feature/platform-kmp` and open one pull request against `main`. The body starts with `Claude AI photo story sharing product said: `, lists what got measured and what did not, and ends with the attribution line that the session gives.

- [ ] **Step 4: Ask the owner for the merge**

Read CI once. Show the result. After a clear yes, run `gh pr merge --merge --match-head-commit <sha>`.
