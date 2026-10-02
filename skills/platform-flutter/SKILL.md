---
name: platform-flutter
description: The Flutter layer of an agentic-delivery run, with the test tiers, devices, commands, screenshots, and release checks. If the project file says `platform: flutter`, load this skill.
---

# Flutter platform

This skill holds the rules that depend on Flutter. The `run-rules` skill holds the rules for every agent, and the `controller` skill holds the rules for the controller. This skill does not repeat them. It names the commands, the devices, and the skills that those two skills leave to the platform. Each rule gives its reason in one sentence.

## How to read the commands

Each command and each flag in this skill comes from the `--help` text of its tool on a Mac with stable Flutter. Nobody ran them on a Flutter project yet. So each command, flag, or tool behavior carries the mark `(unverified)`. The mark ends its sentence, or the line that leads its list. A run on the Flutter Mac replaces each mark with the measured form. Until then, run the `--help` of the tool before you rely on a flag, because flags change between Flutter versions.

- Write `flutter` as the command. If the project pins a Flutter version, run the `flutter` of that version.
- A device id in this skill is a placeholder: `<simulator-id>`, `<emulator-id>`, or `chrome`. The Devices section of the project file and the ledger hold the real ids.
- `<ledger>` is the ledger folder of the run, and `<slug>` is the slug of the run.

Every command writes its output to its own log file in the ledger folder. This is the form, and each command below uses it:

```
<command> > <ledger>/logs/<step>.log 2>&1
```

Below, `<log>` means that path, with a new `<step>` name for each command. The stall watch and the evidence rules of `run-rules` read logs, and a pipe hides the output until the command ends.

## Test tiers

Use the cheapest tier that can fail on the defect. The tiers, cheapest first:

1. Unit tests prove pure Dart logic, with no widget.
2. Widget tests build one widget with `WidgetTester` and no device. They can tap, drag, enter text, and read the state.
3. Golden tests are widget tests that compare the rendered widget with a saved reference image, through `matchesGoldenFile`.
4. Integration tests run the app on a device, from the folder `integration_test`.

A fact that a widget test can prove does not go to a device. A widget test runs in seconds on the machine, and a device run costs minutes and machine load.

### What an implementer can see

An implementer has no device, as the Devices section of `run-rules` says. These are the tools that let it see and operate a screen:

- A golden test writes a PNG file. Open the file with the Read tool to look at the widget.
- When a golden test fails, it writes the difference images into a `failures` folder beside the test (unverified). Open them to see what moved.
- A widget test operates the widget. `tester.tap`, `tester.drag`, `tester.enterText`, and `tester.pumpAndSettle` are the gestures that you have.

A gesture on a real device is not one of these tools. If a check needs one, write the check for QA. Say what to do, what value to read, and what result means that your code is wrong.

## Expert skills

If a skill in this table is installed, load it for work in its area. These are the generic Flutter skills that a developer can install. If a skill is not installed, say so in the report.

| Area | Skill |
| --- | --- |
| Widget tests | `flutter-add-widget-test` |
| Integration tests, and device checks that become tests | `flutter-add-integration-test` |
| Layout errors, such as an overflow | `flutter-fix-layout-issues` |
| Layouts for several screen sizes | `flutter-build-responsive-layout` |
| Widget previews | `flutter-add-widget-preview` |
| Layers of the app | `flutter-apply-architecture-best-practices` |
| Routing and deep links | `flutter-setup-declarative-routing` |
| Localization | `flutter-setup-localization` |
| Models from JSON | `flutter-implement-json-serialization` |
| Calls to a REST API | `flutter-use-http-package` |

For accessibility and design critique, the controller skill names `accessibility-review` and `design-critique` under Review seats. For a manual QA session, it names `exploratory-testing` in the ship checklist. No Flutter skill covers concurrency, manual check writing, or bug reproduction. For those, the three QA rules of the controller skill apply.

## Devices

The device kinds are the iOS simulator, the Android emulator, and Chrome for the web target. Each ticket creates its own simulator and emulator and deletes them at the end. Two tickets on one device install over each other, as `run-rules` says.

- Put the slug in the name of each device that you create, for example `<slug>-ios`. Then a list of devices shows which ticket owns each one.
- Pass the full id to `-d`. The flag also accepts a name or a prefix of an id, so a short value can resolve to the device of another ticket (unverified).
- Never pass `all` to a `simctl` command. It reaches the devices with a signed-in session that the project file lists, and the devices of other tickets.

### iOS simulator

- List the device types and runtimes: `xcrun simctl list devicetypes > <log> 2>&1` and `xcrun simctl list runtimes > <log> 2>&1` (unverified).
- Create: `xcrun simctl create <slug>-ios "<device-type-id>" "<runtime-id>" > <log> 2>&1` (unverified). Read the new id from the log, and write it in the ledger.
- Or clone a prepared base device: `xcrun simctl clone <base-simulator-id> <slug>-ios > <log> 2>&1` (unverified).
- Boot: `xcrun simctl boot <simulator-id> > <log> 2>&1` (unverified). Then wait for the boot: `xcrun simctl bootstatus <simulator-id> > <log> 2>&1` (unverified).
- At the end: `xcrun simctl shutdown <simulator-id> > <log> 2>&1`, then `xcrun simctl delete <simulator-id> > <log> 2>&1` (unverified).

### Android emulator

The tools `avdmanager` and `emulator` take only the name of the virtual device. The tools `adb` and `flutter` take the id, which is `emulator-<port>` (unverified). The name holds the slug, so it cannot resolve to the device of another ticket.

- List the device definitions: `avdmanager list device > <log> 2>&1` (unverified).
- Create: `avdmanager create avd --name <slug>-android --package "<system-image-package>" --device "<device-definition>" > <log> 2>&1` (unverified).
- Boot, detached: `emulator -avd <slug>-android -port <port> -no-snapshot -no-boot-anim > <log> 2>&1` (unverified). Use a port that no other ticket uses, because the port sets the id.
- Wait for the device: `adb -s <emulator-id> wait-for-device > <log> 2>&1` (unverified).
- At the end: `adb -s <emulator-id> emu kill > <log> 2>&1`, then `avdmanager delete avd --name <slug>-android > <log> 2>&1` (unverified).

### Chrome

Chrome needs no create or delete step. `flutter devices --device-connection attached > <log> 2>&1` lists it as `chrome` (unverified). A web integration test runs through `flutter drive`, which talks to a WebDriver server on `--driver-port`, with the default 4444 (unverified). Each worktree uses its own driver port and its own `chromedriver`. Two drive runs on one port talk to the same WebDriver server.

- Pick a driver port, and claim it with the claim script as the id `chrome-<driver-port>`. Then no other worktree takes the same port.
- Start `chromedriver` on that port, detached: `chromedriver --port=<driver-port> > <log> 2>&1 &` (unverified). Write its process id, from `$!`, in the ledger.
- After the drive run, stop it by that process id: `kill <chromedriver-pid>` (unverified). Never stop it by name, because a name also matches the `chromedriver` of another worktree.
- `chromedriver` is not part of Flutter, and the Flutter Mac does not have it yet. The project installs a version that matches the installed Chrome (unverified).

### The device claim

Claim each device after it boots and before the first install. Always pass `--worktree`. Without it, the script holds the device for the folder above the script, not for your worktree.

- Claim: `scripts/claim-device.sh --device <simulator-id> --worktree <worktree-path> > <log> 2>&1` (unverified). Use the same form with `<emulator-id>`, `chrome-<driver-port>`, and `web-<web-port>`.
- Release: `scripts/claim-device.sh --device <simulator-id> --worktree <worktree-path> --release > <log> 2>&1` (unverified).

The exit codes of the claim script:

- 0: the worktree holds the device, or the release is done.
- 5: another worktree holds the device. After a claim, create your own device of the same type and runtime. For a port id, pick another port. After a release, nothing was released.
- 4: the device id or the worktree is not valid.
- 3: the script cannot create its lock folder.
- 2: a usage error.

Release the claim before you delete the device or stop the emulator. A later emulator on the same port gets the same id, and a lock that stays refuses it while your worktree exists.

### Device clean-up and disk

After a device clean-up, remove the empty folders that it left:

- List them: `find ~/Library/Developer/CoreSimulator/Devices ~/.android/avd -mindepth 1 -maxdepth 1 -type d -empty -print > <log> 2>&1` (unverified).
- Remove each path that the log prints with `rmdir <path>` (unverified). `rmdir` refuses a folder that is not empty, so it cannot remove a live device.

An empty folder stays in each later count of devices, and that count must match the devices that exist.

Count device clones. Do not measure their disk size. Clones share blocks. A size figure counts the shared blocks one time for each clone, and the free space changes little after you delete one. The rule to count and not to measure is in the Diagnosis and evidence section of `run-rules`.

- Count the simulators: `xcrun simctl list -j devices > <log> 2>&1`, then `grep -c '"udid"' <log>` (unverified).
- Count the emulators: `emulator -list-avds > <log> 2>&1`, then count the lines of the log (unverified).

## Commands

Run each test command detached, as `run-rules` says under Commands and files.

- Analyze: `flutter analyze > <log> 2>&1` (unverified).
- Unit and widget tests: `flutter test --reporter expanded --file-reporter json:<ledger>/results/<step>.json > <log> 2>&1` (unverified). The expanded reporter writes one line for each test, so the log grows while the run makes progress.
- One test file: `flutter test test/<path>_test.dart --reporter expanded > <log> 2>&1` (unverified). One test by name: add `--plain-name "<name>"` (unverified).
- The golden update switch: `flutter test --update-goldens test/<path>_test.dart > <log> 2>&1` (unverified).
- Integration tests on a simulator or an emulator: `flutter test integration_test -d <simulator-id> --reporter expanded --file-reporter json:<ledger>/results/<step>.json > <log> 2>&1` (unverified). Use `<emulator-id>` for the emulator.
- Integration tests on Chrome: `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/<name>_test.dart -d chrome --driver-port=<driver-port> > <log> 2>&1` (unverified). Start the `chromedriver` of the worktree first, as the Chrome section says. The drive command runs the browser headless by default (unverified).

The golden update switch overwrites each reference image with whatever renders. Run it only on the test files that the task changes. Open each changed PNG before you commit it, because a defect that renders becomes the new reference.

## A stalled test run

### Symptoms

These processes do the work of a run (unverified):

- `flutter_tester` runs the unit and widget tests.
- `dart` runs the `flutter` tool.
- On a device run, `xcodebuild` builds the iOS app and `java` runs the Gradle build of the Android app.

In a stalled run, both of these values stay the same across several polls:

- The processor total of the test process: `ps -o time= -p <pid>` (unverified).
- The size of the log: `stat -f %z <log>` (unverified).

These cases look like a stall but are not one:

- `dart` sits still while `xcodebuild` or `java` adds processor time. The build does the work at that time.
- The processor total stays at zero while a device boots.

The name `dart` also matches the analysis server of an editor, which sits idle for a long time. Before you report a frozen `dart` process, read its command with `ps -o command= -p <pid>` (unverified).

### Remedies, in order

The controller applies these remedies, or tells the agent of that worktree to apply them. An implementer reports a stall and does not act on it, as its agent file says. Apply them only after the processor total stays frozen for the budget that the controller skill gives to the stall watch.

1. Clean the device clones. Count the devices first. Then shut down and delete each device of a finished ticket that the list printed and that no claim holds. Then remove the empty folders. Leftover devices load the machine and slow every boot and every run.
2. Kill and relaunch. Kill only the process ids of your own run, with `kill <pid>` (unverified). Run the same command again with a new log file. A hung test process does not recover, and the new log keeps the evidence of the dead run.
3. Make sure that the device still runs. Do not use `bootstatus` here, because it waits until the device boots, and on a stopped device it never returns. For a simulator, run `xcrun simctl list devices > <log> 2>&1`, and the line with `<simulator-id>` must show `(Booted)` (unverified). For an emulator, `adb -s <emulator-id> get-state > <log> 2>&1` must print `device` (unverified). The id must also appear in `flutter devices` (unverified). If the device stopped, boot it again and relaunch. A run that waits on a stopped device looks exactly like a hung run.

The rule for two dead runs in a row is in the Diagnosis and evidence section of `run-rules`.

### The stall watch

Arm one watch for each name in `test_processes`, as the controller skill says:

- `scripts/stall-watch.sh --process flutter_tester --interval 60 > <log> 2>&1` (unverified).
- `scripts/stall-watch.sh --process dart --interval 60 > <log> 2>&1` (unverified).

Read the log for a heartbeat line before you dispatch. The value of `test_processes` in the template is a placeholder. During a test run, `pgrep -lx flutter_tester` prints the id and the name of each match (unverified). Put the names that you measure in the project file.

## Screenshots

Capture only after two frames match, on each device kind. Use the settle script with the capture command of the device kind (unverified):

```
scripts/settle-screenshot.swift --capture "<capture command>" --out <ledger>/screens/<screen>-<kind>.png > <log> 2>&1
```

`<kind>` is `ios`, `android`, or `web`. The capture commands (unverified):

- iOS simulator: `xcrun simctl io <simulator-id> screenshot {out}` (unverified).
- Android emulator: `flutter screenshot -d <emulator-id> -o {out}` (unverified).
- Chrome: `'<chrome-binary>' --headless --screenshot={out} --window-size=<width>,<height> http://localhost:<web-port>/` (unverified). The script quotes the path, and the shell joins `--screenshot=` and the quoted path into one argument. Put single quotes around the Chrome path, because it holds spaces and the capture command sits inside double quotes.

For the Chrome capture, serve the app first with its own log, detached: `flutter run -d web-server --web-port <web-port> > <log> 2>&1 &` (unverified). `--web-port` is a hidden option that only `flutter run -v --help` shows. The hidden `--show-web-server-device` lists the `web-server` device (unverified). Claim the port as `web-<web-port>`. Write the process id of the server in the ledger, and stop it by that id after the capture. This capture shows the page after it loads, not a state that a test reached by interaction. Two blank frames also match, so open the settled frame and make sure that it shows the screen. A run on the Flutter Mac measures this path.

The script replaces `{out}` with the path of the frame, and it quotes that path for the shell. Do not put quotes around `{out}`. A second pair of quotes puts quote characters into the path, and the script then finds no file.

The exit codes of the settle script:

- 0: the screen settled, and the `--out` file holds the frame.
- 1: the screen never settled. The `--out` file holds the last frame, so do not attach it as proof. Read the region that the error output names.
- 2: a usage error or a capture error. The error output names the cause.

The default tolerance is 0.001, as a fraction of the pixels. If exit 1 names a tall narrow region, it is usually a text caret. Dismiss the keyboard, or move the focus out of the field, and capture again. Raise `--tolerance` only for a screen that must show a focused field. Set it just above the fraction that the message printed, and divide its percentage by 100 to get that fraction. A tolerance larger than the caret lets a real change pass as settled. If exit 1 names a large region, the screen still animates or loads, so raise `--attempts` and not the tolerance.

## Release checks

Build release mode for each target that the project ships. A debug build does not stand for a release build, as the Checks section of `run-rules` says.

- iOS: `flutter build ios --release --no-codesign > <log> 2>&1` (unverified). Signing needs the signing identity of the team, and a run does not use an account that the project file does not name.
- Android: `flutter build apk --release > <log> 2>&1` (unverified). For a store build, use `flutter build appbundle --release > <log> 2>&1` (unverified).
- Web: `flutter build web --release > <log> 2>&1` (unverified).

The flag `--simulator` changes the default build mode to debug (unverified). A simulator build is a debug build unless the command also passes `--release`.

Install the build from the path that the build log prints, not from a search, as `run-rules` says. To install a release APK on the emulator: `flutter install --release -d <emulator-id> --use-application-binary=<apk-path> > <log> 2>&1` (unverified). Nobody measured yet whether the iOS simulator runs a release build.

## QA: a change since the last suite run

After the base merge, QA looks for a change since the last suite run, as the Checks section of `run-rules` says. These paths count:

- Source: `lib` and `assets`.
- Build configuration: `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `l10n.yaml`, `build.yaml`, and the folders `ios`, `android`, and `web`.
- Test plan: `test`, `integration_test`, `test_driver`, and `dart_test.yaml`.

The command (unverified):

```
git diff --name-only <last-suite-commit> HEAD -- lib assets pubspec.yaml pubspec.lock analysis_options.yaml l10n.yaml build.yaml ios android web test integration_test test_driver dart_test.yaml > <log> 2>&1
```

Take `<last-suite-commit>` from the ledger entry of the last suite run. Commit the merge first, because `git diff` between two commits does not see a file that is not committed.

- A positive result is a line with a file path. Then QA runs the suite again.
- An empty log with exit 0 means no change. Then QA cites the last run.
- Any other exit status means that the command did not answer, for example a commit that does not exist. Then QA runs the suite again, so that the check fails closed.
