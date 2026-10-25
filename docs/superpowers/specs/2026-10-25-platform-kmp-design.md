# The Kotlin Multiplatform platform layer: design

Date: 2026-10-25. Status: draft for review.

This file adds a platform layer for Kotlin Multiplatform (KMP) projects to the plugin design in
`2026-10-02-agentic-delivery-design.md`. It does not change the main design file.

## Goal

A team installs the plugin in a KMP repository and runs `/feature` there, as a Flutter, iOS, Go,
or Node team does. The layer is generic KMP with Compose Multiplatform. The rules of one product go
into the project file of that repository, not into the plugin.

The first user is a trip photo story app. Its first version is a Compose web app on the Wasm
target, shared Kotlin logic, and a Ktor server on the JVM. Its Android and iOS apps come later from
the same code.

The layer starts small and grows. Each time a feature of a KMP project needs a command that the
layer does not have, the layer gets that command in a later pull request.

## Decisions

The owner decided these points:

1. The first pull request of the layer includes a small KMP sample project under `tests/`. The
   commands and the mutation runner get measured on that sample before the layer lands.
2. The sample covers four targets: the JVM, Wasm for the browser, Android, and iOS.

The Agentic Coach session gave these rules for a new layer:

3. The layer is one skill, `skills/platform-kmp/SKILL.md`, and one mutation runner,
   `skills/platform-kmp/mutation-runner.sh`. A project selects it with `platform: kmp`. The
   description of the skill ends with "If the project file says `platform: kmp`, load this skill."
4. The skill copies the shape of `platform-go`: project file keys, the rules file, test tiers,
   commands, logs, manual checks, stalled runs, mutation tests, and expert skills. It adds a section
   "Where this layer was used", as `platform-node` does.
5. It takes the Chrome, device, claim, and screenshot parts from `platform-flutter`, and the web
   screen check from `platform-node`.
6. A command gets the mark "(measured: exit N, T seconds)" only after a real run. An unmeasured
   command carries no mark. The README row and `docs/inside.md` say which parts are not measured.
7. A rule that comes from a real incident gets a `lessons.md` entry, and the rule cites it as
   "(lesson: <name>)". No other rule gets an entry.

These are our calls:

8. The plugin ships two KMP agents, `agents/kmp-implementer.md` and `agents/kmp-reviewer.md`.
   The owner asked for them on 2026-10-25. Each one loads `run-rules` and `platform-kmp`, follows
   the general implementer or reviewer of the plugin in full, and adds the KMP rules and the
   expert skills. A KMP project selects them with `implementer_agent:
   agentic-delivery:kmp-implementer` and `reviewer_agent: agentic-delivery:kmp-reviewer`. The
   defaults of the template stay the general agents.
8a. The expert skills are the `kotlin-kmp-claude-agent-skills` collection by Mariano Miani,
    Apache 2.0, at `https://github.com/mmiani/kotlin-kmp-claude-agent-skills`. Only its 15 skills
    get installed, as user skills, from commit `939786cb13b49daacea7d5fb0a10877b6005e6be`. Its own
    agents, hooks, command, and settings run a different pipeline, so they stay out.
9. A new optional key `gradle_command` gives the command that runs Gradle. The default is
   `./gradlew`, because a KMP project carries its own Gradle wrapper. In the skill, `<gradle>`
   stands for this value. It runs through `bash -c` from the top of the worktree, as `go_command`
   does.
10. Every Gradle command in the skill passes `--console=plain`, so that the log grows one line at a
    time. The stall watch reads the size of the log, and the rich console rewrites lines.
11. No CI job in this pull request. The full check needs macOS, Xcode, the Android SDK, and Chrome
    on one runner. A CI job is later work.
12. The skill stands alone. A run loads only `platform-<platform>`, so the skill copies and adapts
    each rule that it takes from the Flutter, Go, and Node layers. It never tells an agent to read
    another layer. Each copied command gets measured again on the KMP sample. A Flutter
    measurement never appears as a KMP measurement.
13. The builder runs every measurement on the owner's Mac, which has Xcode, the Android SDK, Chrome,
    and several JDKs. The marks cite those runs and the evidence that they wrote. The owner does
    not need to run anything by hand before the merge.

What must be measured before the merge (our call):

- Must: the build and the tests of all four targets, the mutation runner verdicts on the JVM test
  task, serving the web app, and the web screenshot.
- Must try: installing, starting, and capturing the app on an Android emulator and on an iOS
  simulator, and the `--tests` filter on a second target.
- An item from either list can land without a mark only when an outside tool blocks it, for
  example a Kotlin release that does not support the installed Xcode. The skill then states the
  error, the tool versions, and that the item is not measured. The pull request body lists each
  such item, so the owner sees it before saying yes to the merge.

## What the skill holds

### Project file keys

- `gradle_command`, as decision 9 says.
- `java_home`, optional. It names the JDK for Gradle when the default JDK is wrong for the
  project. The builder finds out whether the sample needs it.
- `test_processes`. The builder measures the names during the sample runs. Expect `java` for the
  Gradle and Kotlin daemons, `node` for the browser tests of the Wasm target, and `xcodebuild` for
  the iOS app build.
- `view_globs`. The builder picks globs that match the Compose screen files of the sample, for
  example the files under `composeApp/src/`.

### Test tiers

Cheapest first:

1. Shared logic tests in `commonTest`, run on the JVM. They need no device and no browser.
2. Server tests on the JVM, for example Ktor's test host for an endpoint. No test reaches a live
   host.
3. The same shared tests on the other targets: Android host tests, Wasm browser tests, and iOS
   simulator tests. They catch a difference between targets.
4. A screen check on a device kind: the browser, an Android emulator, or an iOS simulator.

### Commands

For each target, the skill gives the command to build and the command to run the tests. Each
command writes to a log in the ledger folder. The builder finds the exact task names with
`<gradle> tasks --all` on the sample, and does not copy names from memory or from this file. The
skill also gives the command to serve the web app for a screen check, and the command to install
and start the app on an emulator and on a simulator.

The skill states how a test task reuses an old result. Gradle can skip a test task as up to date
and leave the old report in place, so a command that must prove a fact forces a rerun.

### Devices and claims

- Web: the web server port and any browser test port get a claim with `scripts/claim-device.sh`,
  as the Flutter layer claims `web-<web-port>`.
- Android emulator and iOS simulator: the skill copies the device rules and the claim rules of the
  Flutter layer, and adapts them for a Gradle or Xcode build of a KMP app.

### Screenshots

- Web: Compose for the web draws to a canvas, so a text search of the page finds nothing. The
  screen check uses pixels. The capture reuses the Flutter headless Chrome command, with
  `--virtual-time-budget`, and then `scripts/settle-screenshot.swift`. A canvas app can write a
  blank frame before its first draw, and two blank frames match. So the run opens the settled
  frame and makes sure that it shows the screen. The builder also finds out whether headless
  Chrome draws the canvas at all, because Compose draws through WebGL. If it does not, try these
  in order, and keep the first that works: headless Chrome with flags for software WebGL, then a
  visible Chrome window with its own profile, started and stopped by the same capture command.
  Both keep the capture inside `scripts/settle-screenshot.swift`. If neither works, the web
  screenshot lands without a mark, as the merge rules above allow.
- Android and iOS: the capture commands of the Flutter layer for an emulator and a simulator.
- A web screen check that needs data uses a temporary screen with fixture data, as the Node layer
  does. Never commit the temporary screen.

### Logs, API contract, and manual checks

The skill copies the Go layer rules for logs and for the API contract, and adapts them for a Ktor
server. It copies the manual check rules of the Go layer for a server and of the Node layer for a
web screen.

### Stalled runs

Gradle runs as `java`, and Kotlin/Native compiles in a `java` process too. The Flutter layer note
about idle Gradle and Kotlin daemons applies: an idle daemon still adds a little processor time,
so the log size decides a stall. Stop a process only by its own process id. The first build of a
target downloads a large toolchain and writes little to the log for minutes. That is slow, not
stalled, while the process uses the network.

### Expert skills

The section names the collection from decision 8a, in the same way that the Go layer names
`cc-skills-golang`. It gives the install steps for the skills only, with the commit, and lists
the skills for the implementer and for the reviewer, as the two KMP agents list them.

### Where this layer was used

At first, only the sample in `tests/`. Each later pull request adds the projects and runs that
measured a new part.

## The mutation runner

`skills/platform-kmp/mutation-runner.sh` follows the runner contract in the usage text of
`scripts/mutate.sh`. It starts as a copy of `skills/platform-go/mutation-runner.sh`.

- A test id has the form `<Gradle test task path>::<class>.<method>`, for example
  `:shared:jvmTest::trip.GroupingTest.groupsByDay`. The class name is fully qualified. The part
  after `::` goes to the `--tests` filter of the task.
- The runner forces each test task to run again, and removes the old report of that task first.
  A stale report gives a false verdict.
- The runner reads the JUnit XML reports that the test task writes. A passed test gives `passed`,
  a failed test gives `failed`, and an ignored test gives `skipped`.
- A compile failure of the module gives `compiled: false`.
- A name that matches no test gives no entry, so the verdict is `error` and the baseline stops.
- The runner reads `gradle_command` from the project file, as the Go runner reads `go_command`.
  A test environment variable can point it at a fake Gradle command, as `GO_BIN` does for Go.

The builder measures at least these verdicts on the sample: `killed`, `survived`,
`did-not-compile`, and a name that matches no test. The JVM test task is required. The builder
also tries one other target, for example the iOS simulator tests, and records whether the
`--tests` filter works there.

## Core changes

- The README platform table gets a KMP row, the platforms badge lists KMP, and the sources note
  gets one line.
- `docs/inside.md` gets a row in the layer table and a line in the folder list. Its agents part
  lists the two KMP agents, and says that a KMP project selects them in the project file.
- `templates/agentic-delivery.md` says in its Agents section that a KMP project can name the two
  KMP agents.
- `templates/agentic-delivery.md` gets one more clause in the `platform` line and in the
  `mutation_runner` line, following the pattern of the Node layer.
- The plugin version moves from 0.7.0 to 0.8.0 in the five places: the README badge, the pins in
  `docs/install.md`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and
  `min_plugin_version` in `templates/agentic-delivery.md`.
- `tests/run-all.sh` runs the new runner test.

The start-up hook reads any platform name, so it needs no change.

## Tests

- `tests/kmp-sample/` is the sample project. It has a shared module with a few tests in
  `commonTest`, a Compose Multiplatform app with one screen for the Wasm, Android, and iOS
  targets, a small Ktor server module on the JVM, and the Xcode project that runs the iOS app. It
  stays as small as these targets allow. It pins the versions of Kotlin, Compose Multiplatform,
  the Android Gradle plugin, Gradle, and Ktor. The builder takes each version from the official
  release page on the day of the build, and the skill names the versions that the runs used.
- `tests/kmp-toolchain/check.sh` copies the sample into an empty work folder, runs the commands of
  the skill and the mutation runner against it, and writes the evidence. It follows
  `tests/go-toolchain/check.sh`. It covers the Gradle build and test commands of all four
  targets, the mutation runner, serving the web app, and the web screenshot. The emulator and
  simulator steps get measured by hand runs with their own evidence, not by this script, so that
  the script stays small. It needs macOS with Xcode, the Android SDK, and Chrome, so it is not
  part of `tests/run-all.sh`.
- `tests/test-kmp-runner.sh` covers each verdict of the runner with a fake Gradle command and
  fixture reports, with no real toolchain. It is part of `tests/run-all.sh`.

## How the work lands

- The work goes on the branch `feature/platform-kmp`, in one pull request against `main`.
- The pull request body starts with "Claude <session name> said: ".
- Before each push, `bash tests/run-all.sh` passes, and the name guard hooks pass. The name guard
  refuses private product names, employer names, and some names for a test environment. Write
  "staging" for a test environment.
- Each push and each merge needs the owner's yes in the chat. A merge reads CI once, then runs
  `gh pr merge --merge --match-head-commit <sha>`. Never use `--auto`, because `main` has no
  required checks and merges at once.

## Out of scope

- A CI job, as decision 11 says.
- On-device UI tests, for example Android instrumented tests and Compose UI tests on a simulator.
  They come when a feature of a real project needs one.
- The Compose desktop target and the Kotlin/JS target. They come if a real project needs one.
- Release builds, signing, and store upload for Android and iOS.
- Deploy commands, for example Firebase Hosting or Cloud Run.

## Left to the builder

- The exact Gradle task names, after `<gradle> tasks --all` on the sample.
- The structure of the sample, inside the limits above.
- The globs in `view_globs`, and the names in `test_processes`, after measured runs.
- Whether `java_home` is needed.
- The wording of each section of the skill, inside the style of the other layers.
