---
name: platform-ios
description: The iOS layer for agentic-delivery, SwiftUI first with UIKit notes. If the project file says platform ios, load it.
---

# Platform: iOS

This skill holds the commands and the iOS rules of a run. The `run-rules` skill holds the rules that do not change between platforms. This skill points to a section of `run-rules` and does not repeat it. Each rule here gives its reason in one sentence.

SwiftUI is the default. The section UIKit covers screens that a project still has in UIKit.

## Project file keys

The project file `.claude/agentic-delivery.md` holds four keys for this platform. Every command below uses them and never uses a name that you remember.

- `ios_workspace`: the workspace or project file that every build opens.
- `ios_scheme`: the scheme for builds and tests.
- `ios_test_plan`: the test plan. This key is optional. If the key is absent, do not pass `-testPlan`.
- `ios_runtime`: the simulator runtime for new devices. Its value is a name or an id that `xcrun simctl list runtimes` prints.

In the commands, `<open flag>` stands for one of two forms:

- If `ios_workspace` ends in `.xcworkspace`, pass `-workspace <ios_workspace>`.
- If `ios_workspace` ends in `.xcodeproj`, pass `-project <ios_workspace>`.

If the project has both a workspace and a project file, the project file lists the workspace. A project that links a sibling framework builds only through the workspace.

The project file also holds `test_processes`. For an iOS project, the value is `xcodebuild,xctest`. Set `view_globs` to the patterns of the SwiftUI and UIKit view files. The ready check asks for screenshots only for a change to a file that matches them. The ledger folder is `<docs_dir>/<date>-<slug>/`.

## Test tiers

Use the cheapest tier that can prove the fact. These are the tiers, cheapest first:

1. Unit tests. They run in a fraction of a second once the build is done.
2. Snapshot tests. They show a change to a view without a person reading the screen.
3. UI tests on a simulator. They cost the most, because each run needs a device and a launched app.

If a unit test can prove a fact, do not send the fact to a simulator. If a view holds the logic, move the logic to a plain type with unit tests. `run-rules`, Devices and other sessions, gives the reason.

If a project has no snapshot tier or no UI test target, do not build one as a side effect of a task. A tier is scheduled work with a ticket of its own.

A test plan can run several test targets. To run one tier alone, pass `-testPlan <ios_test_plan>` or `-only-testing:<test target>`. If no test plan exists, only `-only-testing:<test target>` applies.

A UI test or a launch test starts the app on the destination device. If that device holds a signed-in session, the test runs against that account. Section Simulators gives the rule that prevents this.

### When QA runs the suite again

After the base merge, QA looks for a change since the last suite run. These file patterns count: Swift source, project, build configuration, and test plan files. Run this command in the worktree of the run:

```bash
git diff --stat <last suite SHA>..HEAD -- '*.swift' '*.pbxproj' '*.xcconfig' '*.xctestplan'
```

If the output lists a file, run the suite again. If the output is empty, cite the last run. `run-rules`, Checks, gives the rule.

## Simulators

- Each ticket creates its own simulator and deletes it at the end. If two tickets use one booted device, each installs the same bundle id over the other, and neither run can say which build it measured.
- Create a device. Do not clone one. `xcrun simctl clone` refuses a booted source, and the device that you want to copy is booted because another ticket uses it.
- A new device has no keychain, so the app starts signed out. Name the device in the plan header, beside the test-data line.
- Pass a device by its id in every command, never by name. Several runtimes can be installed at once, and a name resolves against whichever runtime `xcodebuild` picks.
- Hold the device for your worktree with the claim script. Run it before the first build or test that uses the device. It refuses a device that another live worktree holds, with exit 5. Always pass `--worktree <worktree path>`. Without it, the script holds the device for the plugin folder, not for your worktree.
- Delete the device at the end of the ticket. Release the claim first.
- A device that holds the live sign-in of a person is not a test device. Never erase it, never uninstall the app from it, and never aim automated tests at it. The project file, in its Devices section, names such devices. The local file `.claude/agentic-delivery.local.md` names the devices of one developer, as the skill `controller` says. `run-rules`, Devices and other sessions, gives the reason.
- At every step, read the boot state again, because the simulator shuts itself down between runs.
- Before you report that a simulator is unavailable, print its runtime and compare it with the deployment target of the app. A device below the deployment target can never take the build, and that is not a refusal by the tool. Then list the other devices of the same model.
- Without parallel testing, `xcodebuild test` runs on the destination itself and does not clone it. If the destination is shut down, the run boots it and shuts it down again.

These are the commands, in the order of a ticket:

```bash
xcrun simctl list runtimes
xcrun simctl list devicetypes
xcrun simctl create <device name> <device type id> <ios_runtime>
scripts/claim-device.sh --device <simulator id> --worktree <worktree path>
xcrun simctl boot <simulator id>
xcrun simctl list devices | grep Booted
scripts/claim-device.sh --device <simulator id> --worktree <worktree path> --release
xcrun simctl delete <simulator id>
```

The `create` command prints the simulator id. Use that id from then on. The `delete` command takes only an id that your own `create` command printed.

## Commands

Every command writes to a log file and to a result bundle. The console says whether tests failed. The result bundle says why, and a reviewer needs it after the run. Put each result bundle in the ledger folder of the run, never in a temporary path.

Each command has these flags and these habits:

- Pass the destination as `platform=iOS Simulator,id=<simulator id>`.
- Give each build configuration its own `-derivedDataPath`. A shared folder makes Xcode print hundreds of "Removed stale file" lines for the products of the other configuration. Those lines hide the products path that proves which configuration built.
- Redirect the output to a log file and read the file. Never pipe a build or a test run to `tail` or `head`. A pipe buffers, so the log looks empty until the command finishes.
- Run the command detached, in the background. Do not use a foreground `sleep`. To wait, poll the log in a background loop.
- Let the stall watch read the run: `scripts/stall-watch.sh --interval 60 --log <log file>`. With no `--process` flag, it watches each name in `test_processes`. Pass one `--log` flag for each command log. Do not dispatch until the first heartbeat line appears. Each heartbeat line ends with `disk=<n>G`, the free space on the disk of the worktree. `controller`, The stall watch, gives the rules.
- For a run that you drive yourself outside a dispatched worktree, watch the log yourself. The stall watch reads only the logs that its `--log` flags name.

Build:

```bash
xcodebuild <open flag> -scheme <ios_scheme> \
  -destination 'platform=iOS Simulator,id=<simulator id>' \
  -derivedDataPath <debug derived data path> \
  build > <log file> 2>&1
```

Test:

```bash
xcodebuild test <open flag> -scheme <ios_scheme> \
  -destination 'platform=iOS Simulator,id=<simulator id>' \
  -derivedDataPath <debug derived data path> \
  -resultBundlePath <docs_dir>/<date>-<slug>/<name>.xcresult \
  -test-timeouts-enabled YES -default-test-execution-time-allowance 30 \
  -collect-test-diagnostics never \
  > <log file> 2>&1
```

If the project file sets `ios_test_plan`, add `-testPlan <ios_test_plan>`. To run one tier, add `-only-testing:<test target>`.

Release build:

```bash
xcodebuild <open flag> -scheme <ios_scheme> -configuration Release \
  -destination 'platform=iOS Simulator,id=<simulator id>' \
  -derivedDataPath <release derived data path> \
  build > <log file> 2>&1
```

If the project names its production configuration differently, use that name after `-configuration`.

These are the reasons for the flags that a reader can want to remove:

- `-test-timeouts-enabled YES -default-test-execution-time-allowance 30`: a deadlocked test then fails. Without it, the test hangs the run.
- `-collect-test-diagnostics never`: by default, a failed run collects a system diagnosis. In one measured run, the wait after a failure was 695.7 seconds, against about 10 seconds without the collection. The flag also discards the screenshots and logs of a failure. If a failure has no other explanation, run again without the flag, on purpose.
- `-resultBundlePath` in the ledger folder: the reviewer needs the bundle after the run, and a temporary path does not last.

If a command in this skill fails because a flag is unknown, read `xcodebuild -help` for the installed version. Do not guess a flag.

### Install from the build you just made

Get the app that you install from the `-derivedDataPath` that you just built into:

```bash
xcrun simctl install <simulator id> <derived data path>/Build/Products/<configuration>-iphonesimulator/<app name>.app
```

Never use `find` to locate an app. A search returns whatever is oldest or first on disk, which is a build of a previous run with the code of a previous branch. If the expected `.app` is not at that path, stop. Do not search for one. `run-rules`, Devices and other sessions, tells the incident.

## Mutation tests

`scripts/mutate.sh` runs the tests through a platform runner, as its usage text says. The iOS runner of this plugin is `skills/platform-ios/mutation-runner.sh`.

A mutation breaks the code on purpose and shows whether a test catches the break. This is an example. The code:

```swift
func isAdult(age: Int) -> Bool {
    return age >= 18
}
```

The test:

```swift
func testAdult() {
    XCTAssertTrue(isAdult(age: 30))
    XCTAssertFalse(isAdult(age: 5))
}
```

The manifest entry changes `>=` to `>`. After the change, the code says that a person of 18 is not an adult:

```json
{"label": "boundary", "file": "Sources/Age.swift",
 "find": "age >= 18", "replace": "age > 18",
 "test": "AppTests/AgeTests/testAdult"}
```

The test still passes, because 30 and 5 give the same answer with both operators. So the verdict is `survived`, and the test does not cover the boundary. Add `XCTAssertTrue(isAdult(age: 18))` to the test, and run the mutation again. The test fails, so the verdict is `killed`. The test now catches the break.

- Copy it into the project as `scripts/mutation-runner.sh`, and commit it. That path is the default of the `mutation_runner` key in the project file. The path of a plugin install differs on each machine, so the key cannot point into the plugin.
- Run `scripts/mutate.sh` from the worktree of the run. The runner reads `ios_workspace`, `ios_scheme`, and `ios_test_plan` from the project file at the top of that worktree.
- Set `AGENTIC_TEST_DEVICE` to the id of the simulator that the run claimed. Every iOS test needs a destination, unit tests too.
- Set `AGENTIC_DERIVED_DATA` to a derived data folder for the mutation runs. Keep it out of the ledger folder. One run without its own folder put 2.1 GB of build products into a ledger. Use the same folder for every call of one run, so that each mutation builds only what changed.
- To test a configuration other than the default of the scheme, set `AGENTIC_CONFIGURATION`. The runner passes it as `-configuration`. Give each configuration its own `AGENTIC_DERIVED_DATA`.
- Other environment variables reach the tests, for example a `TEST_RUNNER_` variable that a UI test reads.

The runner refuses to start without one of the two variables, or with an empty `ios_workspace` or `ios_scheme`. A refusal writes a line in the log, writes no result file, and exits 2. The baseline then stops the run.

A test id is an `-only-testing` name with two or three parts: `<test target>/<test class>` or `<test target>/<test class>/<test method>`, for example `AppTests/CalcTests/testAdd`. For an XCTest method, write the name without `()`. For a Swift Testing function, write the name with `()`, for example `AppTests/CalcSuite/addsTwoNumbers()`. A Swift Testing id without `()` runs no test, and `xcodebuild` still exits 0, so the verdict is `error`. A suite id, without a function name, works for both. A nested Swift Testing suite gives an id with more than three parts. The runner refuses that id, and nobody measured one. The runner calls `xcodebuild test` once with all the ids of the call, and writes the result bundle beside the result file, as `<result file name>.xcresult`. It reads the bundle with `xcrun xcresulttool`. A class id gives one entry for each test case in the class.

Exit 65 from `xcodebuild` means a failed test or a failed build, so the runner never decides from the exit code alone:

- A test name that matches nothing still gives exit 0 and `** TEST SUCCEEDED **`. The runner writes no entry for it, so the verdict is `error`, and the baseline stops the run.
- A failed build with at least one error gives `compiled: false`, so the verdict is `did-not-compile`, not `killed`.
- A failed test gives `failed`, so the verdict is `killed`.
- A skipped test gives `skipped`, so the verdict is `error`.

The runner writes no result file, and exits 3, when the facts disagree or the run did not finish: an exit code other than 0 or 65, no result bundle, a build that is neither a success nor a failure with errors, exit 0 with a failed test, exit 65 with a clean build and no failed test, or a test case result other than passed, failed, or skipped, for example `Expected Failure`. The verdict is then `error`. Read the log of the call.

The source project measured the `xcodebuild` and `xcresulttool` behaviour above with XCTest on Xcode 27.0. In this repository, the CI job "iOS layer on real Xcode" measures it again on each pull request: `tests/ios-xcode/check.sh` runs the commands of this skill and the runner against a small sample app with XCTest and Swift Testing tests. On 2026-10-03, with Xcode 16.4 and an iOS 26.2 simulator on a GitHub `macos-15` runner, a passing test gave `passed`, a misnamed test gave exit 0 and no entry, a skipped test gave `skipped`, and the example above gave `survived`, then `killed`. A type error gave `did-not-compile`. A Swift Testing id with `()` gave `passed`, the same id without `()` gave exit 0 and no entry, and the mutation of the example killed the Swift Testing test. The test `tests/test-ios-runner.sh` covers the cases that a real run cannot cause on purpose, with fake tools that print measured output.

## Stalled runs

Diagnose a stalled run by processor time, not by clock time. Read the processor time total of the `xcodebuild` process twice, a few minutes apart. A hung build sits near zero percent, and its total is frozen. One hang ran for 8 minutes and 51 seconds of clock time and used 6.5 seconds of processor time. A build with no processor time for a long span can still finish. Make sure that the total is frozen before you call a run dead. `run-rules`, Diagnosis and evidence, gives the rule.

Before you blame the branch, examine the machine. Count the simulator clones in the clone store. An old machine can hold more than a hundred orphaned clones.

If a run is dead, try these remedies in this order:

1. Reap the clone store.
2. Kill the run and start it again.
3. Make sure that the target device is still booted.

Do not conclude that the machine is broken until you tried all three. Two consecutive dead builds mean escalation, not a third attempt. Stop, say what you tried and what the processor evidence was, and give the problem back to the gate owner.

Every command-line `xcodebuild test` can leave a cloned device in `~/Library/Developer/XCTestDevices`, and nothing removes them. Reap the store before the first test run of a session, and again after a stall. Reap only while no test process is alive, because a reap during a live run kills that run. This one command does both:

```bash
pgrep -x xcodebuild >/dev/null || pgrep -x xctest >/dev/null || xcrun simctl --set ~/Library/Developer/XCTestDevices delete all
```

- Match the process name with `-x`, never the command text with `-f`. A shell whose command text names `xcodebuild` matches `-f` and blocks the reap forever.
- `delete all` can leave empty folders. Remove those too, and only the paths that your own `ls` printed.
- Do not quote a disk figure for the clone store, and do not reap to free space. The clones share blocks with the base runtime, and `du` counts a shared block once for each clone. In one measurement, a reap changed the `du` figure from 20G to 2.4G and freed no real disk.
- The reason to reap is not proven. The belief is that a large store makes the clone boot slow or endless. Reap because it costs little. If a run stalls with a reaped store, or runs clean with a large store, write it in the ledger.

## Screenshots

A task that touches a view is not done until someone renders the screen and looks at it. `run-rules`, Tests and fixtures, gives the rule. Take the capture with the settle script, and do not write your own settle loop:

```bash
scripts/settle-screenshot.swift --capture "xcrun simctl io <simulator id> screenshot {out}" --out <path>
```

The script runs the capture command until two consecutive frames match. It replaces `{out}` with the frame path in shell quotes, so do not put quotes around `{out}`. It writes the settled frame to `--out` and fails fast instead of hanging.

- Exit 0 means that the screen settled.
- Exit 1 means that the screen never settled. The error output names the region that kept moving and its size. The file at `--out` holds the last frame.
- Exit 2 means a usage error or a capture error.
- A tall narrow region is a text caret. Dismiss the keyboard or raise `--tolerance`.
- A large region means that the screen still animates or loads. Raise `--attempts`.
- The default tolerance ignores the clock in the status bar. For an exact match, pass `--tolerance 0`.
- Downscale the image with any image tool on the machine before you read it, because a full-size capture is large.
- If a screen is certainly static, `xcrun simctl io <simulator id> screenshot <path>` is also correct.

A capture taken during a scroll or an animation can cost a whole fix round. Nobody can tell a clipping defect from a moving screen.

If the project records snapshots, record the new screen in each appearance that the app supports and at the largest text size. The pull request screenshots follow `run-rules`, Review findings.

## Release checks

A Debug build does not stand for a Release build, because the two compile different code. Any fact that a check reads about shipped behavior needs a measurement in the Release configuration. `run-rules`, Checks, gives the rule and the reason.

- Build the Release configuration with the Release build command, in its own derived data folder.
- Measure the passing value, the failing value, and any control value in that configuration.
- A code path under a compile condition such as `DEBUG` exists in only one of the two builds. A Debug build prints whole reply bodies to the console. Make sure that the logging of requests, replies, and personal data sits behind that condition.
- A Release build can sign in with the same identity as a Debug build and reach production. Never run a Release build against a device that holds a live session, and never use it to read or change production data.
- If the project has another build configuration for UI tests, pass it with `-configuration` on the command line. A test plan has no key that selects a build configuration.

## SwiftUI

These rules held in a real project. Each one became a defect more than once.

- Follow the architecture document of the project before you add a new SwiftUI surface. Do not invent a second pattern beside the first one.
- If the project sets main actor as the default isolation, be deliberate about what leaves the main actor and why. Do not scatter `Task { }` to silence a warning.
- Every new screen has a state matrix: loading, empty, error, and populated. Name the view that renders each state and the condition that selects it. If the spec wrote a requirement for a sibling screen, it applies here too.
- If a guard stops something from flashing, ask what the screen renders during the suppressed window. "Nothing" is not an answer.
- A brand color that fails WCAG AA on its background is a fill and icon color only. Text and titles use the darker text token. A tint on a button is a text color, because the title takes its color from the tint.
- Contrast and touch size must pass the same criteria on every screen that the diff adds or changes. Keyboard order, landmarks, and focus rules from web guides do not apply here.
- Keep logic out of the view. A view that holds scroll arithmetic, validation, or routing cannot be tested without a device. Move it to a plain type, then test it.
- Make sure that at least one test asserts on the object as constructed. If every test calls a configure step first, the unconfigured state is untested. If every run starts from a warm cache, the cold path is untested. `run-rules`, Tests and fixtures, gives the rule.
- Take every color, spacing value, and font size from the design system of the project, and name where it came from. Do not invent a value.
- If a skill or a guide targets a newer OS than the deployment target, the deployment target wins. Say in the report that you diverged.

## UIKit

- Layout in code: never add a constraint at the same priority as one that it can compete with. If two constraints on one axis can be satisfied only if one yields, give them different priorities. Say in the commit message which one is meant to yield. Equal priorities resolve in an arbitrary way. A reviewer rejects them, and the current look of the screen does not change that.
- A button configuration colors its title from the tint. A tint on a button is therefore a text color, and the contrast rule above applies to it.
- A screen that mixes UIKit and SwiftUI follows the pattern that the surrounding screens use for navigation. Do not add a third mechanism.
- Replace a UIKit screen only in a task that the plan names. Do not rewrite it as a side effect of a bug fix.

## Expert skills

The skills below come from the `apple-skills` plugin and from the skills that the project vendors. If the task is in the territory of a skill, load the skill. Do not work from memory.

These skills target a newer OS than many projects ship. If a skill conflicts with the deployment target or with the conventions of the project, the project wins. Say in the report that you diverged. Do not edit a vendored skill.

Implementer:

- `apple-skills:testing` for characterization tests, test-driven work on a feature or a bug fix, test contracts, and snapshot setup.
- `apple-skills:swift` for concurrency and memory, including isolation questions.
- `apple-skills:swiftui` for data flow, layout, and text editing.
- `apple-skills:ios` for navigation and migration patterns.
- `apple-skills:performance` for a task where something is slow and not wrong.

Reviewer:

- `apple-skills:testing` to judge whether tests are adequate and not only present.
- `apple-skills:ios` for the accessibility audit and for navigation and migration patterns.
- `apple-skills:swift` for concurrency and memory.
- `apple-skills:swiftui` for data flow and layout.
- `accessibility-review` for a diff that adds or changes UI. Use its contrast and touch-target criteria. Its Operable section is written for the web, so skip it.
- `design-critique` for a diff that changes how a screen looks. It needs a screenshot or a ticket image. It has no iOS content, so use it for hierarchy, emphasis, and spacing only.
- `test-case-management` for the anatomy and the linting rules of manual checks. Skip its tool payload sections.
- `exploratory-testing` to judge whether a QA session had a charter or was improvised.

QA:

- `exploratory-testing` for each manual session, with a charter, a time box, and a written session log.
- `test-case-management` for the anatomy and linting rules only. Ignore its tool payload sections and its tool API reference. No test management tool is connected unless the project file says so.
- `bug-reproduction` for a defect that arrives without reliable steps.
- `apple-skills:testing` for test design.
- `flow-walkthrough`, from `apple-skills`, to drive a flow in the simulator with a screenshot at each step.

If the project has a QA context file or a design context file, read it on the branch in front of you before you start. It states what the test setup can do now, and it translates web assumptions into iOS terms. The reviewer must not fault a diff for infrastructure that does not exist yet, and must not excuse a diff for infrastructure that does.

`controller`, QA skills, gives the three rules that hold for every platform.
