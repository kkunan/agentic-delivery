---
name: platform-flutter
description: The Flutter layer of an agentic-delivery run, with the test tiers, devices, commands, screenshots, and release checks. If the project file says `platform: flutter`, load this skill.
---

# Flutter platform

This skill holds the rules that depend on Flutter. The `run-rules` skill holds the rules for every agent, and the `controller` skill holds the rules for the controller. This skill does not repeat them. It names the commands, the devices, and the skills that those two skills leave to the platform. Each rule gives its reason in one sentence.

## How to read the commands

A run on the Flutter Mac measured each command in this skill. It used Flutter 3.38.9 on the stable channel, with Dart 3.10.8, Xcode 26.6, an Android emulator with an API 36 image, and Chrome 154. The project was a new app from `flutter create`, with the iOS, Android, and web targets and one test for each tier.

- The mark `(measured: exit <code>, <time>)` gives the result of that run. A time is for a small app, so a real project takes longer.
- The mark `(not measured: <reason>)` says why a command did not run. The run downloaded nothing, so a command that needs a download did not run.
- Flags change between Flutter versions. On another version, run the `--help` of the tool before you rely on a flag.

On a new Flutter install, the first `flutter devices` and the first iOS device run download the engine files of that version. So the first run takes longer than the times here.

- Write `flutter` as the command. If the project pins a Flutter version, run the `flutter` of that version.
- A device id in this skill is a placeholder: `<simulator-id>` or `<emulator-id>`. For the web, `-d` takes `chrome`, but you claim a port: `chrome-<driver-port>` for the driver and `web-<web-port>` for the web server. The Devices section of the project file and the ledger hold the real ids.
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

- A golden test writes a PNG file. The path in `matchesGoldenFile` starts from the folder of the test file. Open the file with the Read tool to look at the widget.
- When a golden test fails, it writes four images into a `failures` folder beside the test file: `<name>_masterImage.png`, `<name>_testImage.png`, `<name>_isolatedDiff.png`, and `<name>_maskedDiff.png` (measured: exit 1, 2 seconds). Open them to see what moved. Do not commit the `failures` folder.
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
- Pass the full id to `-d`. The flag also accepts a name or a prefix of an id. In the measured run, a prefix of the name and a prefix of the id each found the new simulator. A device type name that two simulators share found a simulator of another owner.
- Never pass `all` to a `simctl` command. It reaches the devices with a signed-in session that the project file lists, and the devices of other tickets.

### iOS simulator

- List the device types and runtimes: `xcrun simctl list devicetypes > <log> 2>&1` and `xcrun simctl list runtimes > <log> 2>&1` (measured: exit 0, under 1 second each). Each line ends with the id to pass to `create`.
- Create: `xcrun simctl create <slug>-ios "<device-type-id>" "<runtime-id>" > <log> 2>&1` (measured: exit 0, 1 second). The log holds one line, the new id. Write it in the ledger.
- Or clone a prepared base device: `xcrun simctl clone <base-simulator-id> <slug>-ios > <log> 2>&1` (measured: exit 0, under 1 second). The log holds one line, the new id.
- Boot: `xcrun simctl boot <simulator-id> > <log> 2>&1` (measured: exit 0, 1 second). Then wait for the boot: `xcrun simctl bootstatus <simulator-id> > <log> 2>&1` (measured: exit 0, 47 seconds). The last lines of its log say `Finished`. Its help gives no time limit.
- At the end: `xcrun simctl shutdown <simulator-id> > <log> 2>&1`, then `xcrun simctl delete <simulator-id> > <log> 2>&1` (measured: exit 0, 3 seconds and 1 second). The delete also removes the folder of the device.

### Android emulator

The tools `avdmanager` and `emulator` take only the name of the virtual device. The tools `adb` and `flutter` take the id, which is `emulator-<port>` (measured). The name holds the slug, so it cannot resolve to the device of another ticket.

On the Flutter Mac, `adb` is on the `PATH`, but `avdmanager` and `emulator` are not. Run them from `<android-sdk>/cmdline-tools/latest/bin/avdmanager` and `<android-sdk>/emulator/emulator`.

- List the device definitions: `avdmanager list device > <log> 2>&1` (measured: exit 0, 1 second). Each definition has a line `id: <n> or "<device-definition>"`.
- Create: `avdmanager create avd --name <slug>-android --package "<system-image-package>" --device "<device-definition>" > <log> 2>&1` (measured: exit 0, 1 second). The package has the form `system-images;android-<api>;<tag>;<abi>`, from the folders under `<android-sdk>/system-images`.
- Boot, detached: `emulator -avd <slug>-android -port <port> -no-snapshot -no-boot-anim > <log> 2>&1 &` (measured: it booted in 38 seconds). Write its process id, from `$!`, in the ledger. Use a port that no other ticket uses, because the port sets the id. The port is an even number from 5554 to 5584, and the next port must also be free, as `emulator -help-port` says.
- Wait for the device: `adb -s <emulator-id> wait-for-device > <log> 2>&1` (measured: exit 0, 22 seconds). This waits only for the connection, not for the boot. Then poll `adb -s <emulator-id> shell getprop sys.boot_completed` until it prints `1` (measured: it printed `1` 16 seconds later). Do not install before that.
- At the end: `adb -s <emulator-id> emu kill > <log> 2>&1`, then `avdmanager delete avd --name <slug>-android > <log> 2>&1` (measured: exit 0, under 1 second and 2 seconds). The emulator process ended 3 seconds after the kill. For a short time after that, `adb devices` still lists the id as `offline`.

### Chrome

Chrome needs no create or delete step. `flutter devices --device-connection attached > <log> 2>&1` lists it as `chrome` (measured: exit 0, 5 seconds). A web integration test runs through `flutter drive`, which talks to a WebDriver server on `--driver-port`, with the default 4444, as `flutter drive --help` says. Each worktree uses its own driver port and its own `chromedriver`. Two drive runs on one port talk to the same WebDriver server.

- Pick a driver port, and claim it with the claim script as the id `chrome-<driver-port>`. Claim it before you start `chromedriver`. Then no other worktree takes the same port.
- Start `chromedriver` on that port, detached: `chromedriver --port=<driver-port> > <log> 2>&1 &` (not measured: `chromedriver` is not installed). Write its process id, from `$!`, in the ledger.
- After the drive run, stop it by that process id: `kill <chromedriver-pid>` (not measured: `chromedriver` is not installed). Never stop it by name, because a name also matches the `chromedriver` of another worktree.
- `chromedriver` is not part of Flutter, and the Flutter Mac does not have it. The project installs a version that matches the installed Chrome.

### The device claim

Claim each device after it boots and before the first install. Always pass `--worktree`. Without it, the script holds the device for the folder above the script, not for your worktree.

- Claim: `scripts/claim-device.sh --device <simulator-id> --worktree <worktree-path> > <log> 2>&1` (measured: exit 0, under 1 second). Use the same form with `<emulator-id>`, `chrome-<driver-port>`, and `web-<web-port>`. The log says `<worktree-path> now holds <id>`, with the id in capital letters.
- Release: `scripts/claim-device.sh --device <simulator-id> --worktree <worktree-path> --release > <log> 2>&1` (measured: exit 0, under 1 second). The log says `released <id>`.

The exit codes of the claim script:

- 0: the worktree holds the device, or the release is done.
- 5: another worktree holds the device. After a claim, create your own device of the same type and runtime. For a port id, pick another port. After a release, nothing was released.
- 4: the device id or the worktree is not valid.
- 3: the script cannot create its lock folder.
- 2: a usage error.

Release the claim before you delete the device or stop the emulator. A later emulator on the same port gets the same id, and a lock that stays refuses it while your worktree exists.

### Device clean-up and disk

After a device clean-up, remove the empty folders that it left:

- List them: `find ~/Library/Developer/CoreSimulator/Devices ~/.android/avd -mindepth 1 -maxdepth 1 -type d -empty -print > <log> 2>&1` (measured: exit 0, under 1 second). After `simctl delete` and `avdmanager delete`, the log was empty, because both remove their folders.
- Remove each path that the log prints with `rmdir <path>`. `rmdir` refuses a folder that is not empty, with exit 1 and `Directory not empty` (measured), so it cannot remove a live device.

An empty folder stays in each later count of devices, and that count must match the devices that exist.

Count device clones. Do not measure their disk size. Clones share blocks. A size figure counts the shared blocks one time for each clone, and the free space changes little after you delete one. The rule to count and not to measure is in the Diagnosis and evidence section of `run-rules`.

- Count the simulators: `xcrun simctl list -j devices > <log> 2>&1`, then `grep -c '"udid"' <log>` (measured: exit 0). The count went up by one after a create and back after the delete.
- Count the emulators: `emulator -list-avds > <log> 2>&1`, then count the lines of the log (measured: exit 0, one name on each line).

## Commands

Run each test command detached, as `run-rules` says under Commands and files.

- Analyze: `flutter analyze > <log> 2>&1` (measured: exit 0, 3 seconds).
- Unit and widget tests: `flutter test --reporter expanded --file-reporter json:<ledger>/results/<step>.json > <log> 2>&1` (measured: exit 0, 2 seconds). The expanded reporter writes one line for each test, so the log grows while the run makes progress. The default reporter rewrites one line, so its log shows little until the end.
- One test file: `flutter test test/<path>_test.dart --reporter expanded > <log> 2>&1` (measured: exit 0, 1 second). One test by name: add `--plain-name "<name>"` (measured: exit 0, 2 seconds). A name that matches no test gives exit 79 and `No tests match`.
- The golden update switch: `flutter test --update-goldens test/<path>_test.dart > <log> 2>&1` (measured: exit 0, 2 seconds).
- Integration tests on a simulator or an emulator: `flutter test integration_test -d <simulator-id> --reporter expanded --file-reporter json:<ledger>/results/<step>.json > <log> 2>&1` (measured on the simulator: exit 0, 114 seconds, with a pod install and a 56-second Xcode build). Use `<emulator-id>` for the emulator (not measured: the Android build needs Gradle 8.14, the Kotlin Gradle plugin 2.2.20, and the Android engine files, and the cache had none of them). At the end of the run, the app is no longer on the device.
- Integration tests on Chrome: `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/<name>_test.dart -d chrome --driver-port=<driver-port> > <log> 2>&1` (not measured: `chromedriver` is not installed). Start the `chromedriver` of the worktree first, as the Chrome section says. `flutter drive --help` says that the browser runs headless by default. The same driver file, with `integrationDriver()` in it, ran the test on the simulator (measured: exit 0, 28 seconds).

The golden update switch overwrites each reference image with whatever renders. Run it only on the test files that the task changes. Open each changed PNG before you commit it, because a defect that renders becomes the new reference.

## A stalled test run

### Symptoms

These processes do the work of a run. `pgrep -x` matched each of these names in the measured run:

- `flutter_tester` runs the unit and widget tests.
- `dartvm` runs the `flutter` tool. The name `dart` matches nothing, because the `dart` command starts `dartvm`.
- On an iOS device run, `xcodebuild` builds the app. On an Android device run, the Gradle build runs in `java` (not measured: the Android build did not run).

A device run has no `flutter_tester`, because the tests run inside the app on the device. Do not watch the app process. On iOS its name is `Runner`, and the app of another ticket has the same name. Do not watch `dartaotruntime` either. It runs the compiler of `flutter test`, and it sits idle after the compile.

In a stalled run, both of these values stay the same across several polls:

- The processor total of the test process: `ps -o time= -p <pid>` (measured: exit 0, it prints a total such as `0:00.24`).
- The size of the log: `stat -f %z <log>` (measured: exit 0, it prints the size in bytes).

These cases look like a stall but are not one:

- `dartvm` sits still while `xcodebuild` or `java` adds processor time. The build does the work at that time.
- The processor total stays at zero while a device boots.

Another Dart program, such as the analysis server of an editor, can also run as `dartvm`. Before you report a frozen `dartvm` process, read its command with `ps -o command= -p <pid>` (measured: exit 0). The command of the `flutter` tool holds the path of its Flutter install.

### Remedies, in order

The controller applies these remedies, or tells the agent of that worktree to apply them. An implementer reports a stall and does not act on it, as its agent file says. Apply them only after the processor total stays frozen for the budget that the controller skill gives to the stall watch.

1. Clean the device clones. Count the devices first. Then shut down and delete each device of a finished ticket that the list printed and that no claim holds. Then remove the empty folders. Leftover devices load the machine and slow every boot and every run.
2. Kill and relaunch. Kill only the process ids of your own run, with `kill <pid>` (measured: exit 0). Run the same command again with a new log file. A hung test process does not recover, and the new log keeps the evidence of the dead run.
3. Make sure that the device still runs. Do not use `bootstatus` here, because it waits until the device boots, and on a stopped device it never returns. For a simulator, run `xcrun simctl list devices > <log> 2>&1`, and the line with `<simulator-id>` must show `(Booted)` (measured). For an emulator, `adb -s <emulator-id> get-state > <log> 2>&1` must print `device` (measured). The id must also appear in `flutter devices` (measured for both kinds). If the device stopped, boot it again and relaunch. A run that waits on a stopped device looks exactly like a hung run.

The rule for two dead runs in a row is in the Diagnosis and evidence section of `run-rules`.

### The stall watch

Arm one watch for each name in `test_processes`, as the controller skill says:

- `scripts/stall-watch.sh --process flutter_tester --interval 60 > <log> 2>&1`
- `scripts/stall-watch.sh --process dartvm --interval 60 > <log> 2>&1`
- `scripts/stall-watch.sh --process xcodebuild --interval 60 > <log> 2>&1`

In the measured run, a watch on `flutter_tester` and `dartvm` during `flutter test` wrote `HEARTBEAT procs=2` on each poll (measured: exit 0). A watch on `dart` wrote `procs=0`. Read the log for a heartbeat line before you dispatch. During a test run, `pgrep -lx flutter_tester` prints the id and the name of each match (measured). The template holds the names of this run. Measure them again on your machine, and put them in the project file.

## Screenshots

Capture only after two frames match, on each device kind. Use the settle script with the capture command of the device kind:

```
scripts/settle-screenshot.swift --capture "<capture command>" --out <ledger>/screens/<screen>-<kind>.png > <log> 2>&1
```

`<kind>` is `ios`, `android`, or `web`. The capture commands:

- iOS simulator: `xcrun simctl io <simulator-id> screenshot {out}` (measured: exit 0, 3 seconds, settled after one comparison). Install and start the app first. At the end of an integration test run, the app is no longer on the device.
- Android emulator: `flutter screenshot -d <emulator-id> -o {out}` (measured: exit 0, 14 seconds, settled after one comparison). Each capture starts the `flutter` tool. `adb -s <emulator-id> exec-out screencap -p > {out}` is faster (measured: exit 0, 7 seconds).
- Chrome: `'<chrome-binary>' --headless --user-data-dir=<profile-dir> --screenshot={out} --window-size=<width>,<height> http://localhost:<web-port>/ & p=\$!; i=0; while [ ! -s {out} ] && [ \$i -lt 30 ]; do sleep 1; i=\$((i+1)); done; sleep 1; kill \$p; [ -s {out} ]` (measured on a static page: exit 0, 7 seconds, settled after one comparison).

Notes on the Chrome capture:

- Headless Chrome writes the frame in about one second, but then it does not exit. In the measured run it was still alive after 219 seconds. So the command starts Chrome in the background, waits up to 30 seconds for the file, and stops that Chrome by its own process id.
- The capture command sits inside double quotes, so write each `$` as `\$`, as shown. Put single quotes around the Chrome path, because it holds spaces.
- `<profile-dir>` is an empty folder of the worktree. A separate profile keeps headless Chrome away from the profile of a Chrome window that is open.
- The shell joins `--screenshot=` and the quoted path into one argument.

For the Chrome capture, claim the port as `web-<web-port>` first. Then serve the app with its own log, detached: `flutter run -d web-server --web-port <web-port> > <log> 2>&1 &` (not measured: the web SDK of Flutter 3.38.9 was not in the cache). `--web-port` is a hidden option that only `flutter run -v --help` shows (measured). `flutter devices --show-web-server-device` lists the `web-server` device (measured: exit 0, 8 seconds). Write the process id of the server in the ledger, and stop it by that id after the capture. This capture shows the page after it loads, not a state that a test reached by interaction. Two blank frames also match, so open the settled frame and make sure that it shows the screen. A page from `flutter run` was not measured, so nobody knows yet whether Chrome writes the frame before Flutter draws its first frame.

The script replaces `{out}` with the path of the frame, and it quotes that path for the shell. Do not put quotes around `{out}`. A second pair of quotes puts quote characters into the path, and the script then finds no file.

The exit codes of the settle script:

- 0: the screen settled, and the `--out` file holds the frame.
- 1: the screen never settled. The `--out` file holds the last frame, so do not attach it as proof. Read the region that the error output names.
- 2: a usage error or a capture error. The error output names the cause.

The default tolerance is 0.001, as a fraction of the pixels. If exit 1 names a tall narrow region, it is usually a text caret. Dismiss the keyboard, or move the focus out of the field, and capture again. Raise `--tolerance` only for a screen that must show a focused field. Set it just above the fraction that the message printed, and divide its percentage by 100 to get that fraction. A tolerance larger than the caret lets a real change pass as settled. If exit 1 names a large region, the screen still animates or loads, so raise `--attempts` and not the tolerance.

## Release checks

Build release mode for each target that the project ships. A debug build does not stand for a release build, as the Checks section of `run-rules` says.

- iOS: `flutter build ios --release --no-codesign > <log> 2>&1` (measured: exit 0, 34 seconds). The log ends with `Built build/ios/iphoneos/Runner.app`. Signing needs the signing identity of the team, and a run does not use an account that the project file does not name.
- Android: `flutter build apk --release > <log> 2>&1`. For a store build, use `flutter build appbundle --release > <log> 2>&1` (not measured: the Android build needs Gradle 8.14, the Kotlin Gradle plugin 2.2.20, and the Android engine files, and the cache had none of them).
- Web: `flutter build web --release > <log> 2>&1` (not measured: the web SDK of Flutter 3.38.9 was not in the cache).

The iOS simulator does not run a release build. `flutter build ios --simulator` makes a debug build in `build/ios/iphonesimulator/Runner.app` (measured: exit 0, 24 seconds). With `--release`, it stops with exit 1 and `Release mode is not supported for simulators` (measured). So check the iOS release build on a real device, and write that check for QA.

Install the build from the path that the build log prints, not from a search, as `run-rules` says.

- On the iOS simulator: `xcrun simctl install <simulator-id> <app-path> > <log> 2>&1`, then `xcrun simctl launch <simulator-id> <bundle-id> > <log> 2>&1` (measured: exit 0, 1 second each). `flutter install --use-application-binary` does not take the `.app` folder of a simulator build: it stops with exit 1 and says that the binary does not exist (measured).
- A release APK on the emulator: `flutter install --release -d <emulator-id> --use-application-binary=<apk-path> > <log> 2>&1` (not measured: the Android build did not run).

## QA: a change since the last suite run

After the base merge, QA looks for a change since the last suite run, as the Checks section of `run-rules` says. These paths count:

- Source: `lib` and `assets`.
- Build configuration: `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `l10n.yaml`, `build.yaml`, and the folders `ios`, `android`, and `web`.
- Test plan: `test`, `integration_test`, `test_driver`, and `dart_test.yaml`.

The command (measured: exit 0 on the new app):

```
git diff --name-only <last-suite-commit> HEAD -- lib assets pubspec.yaml pubspec.lock analysis_options.yaml l10n.yaml build.yaml ios android web test integration_test test_driver dart_test.yaml > <log> 2>&1
```

Take `<last-suite-commit>` from the ledger entry of the last suite run. Commit the merge first, because `git diff` between two commits does not see a file that is not committed.

- A positive result is a line with a file path. Then QA runs the suite again. In the measured run, one commit changed a file in `lib` and `README.md`. The log held only the path in `lib`.
- An empty log with exit 0 means no change. Then QA cites the last run.
- Any other exit status means that the command did not answer, for example a commit that does not exist. That case gave exit 128 and `fatal: bad object` (measured). Then QA runs the suite again, so that the check fails closed.
