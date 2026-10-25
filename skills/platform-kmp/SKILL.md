---
name: platform-kmp
description: "The Kotlin Multiplatform layer of an agentic-delivery run, for shared Kotlin code, Compose Multiplatform apps on Wasm, Android, and iOS, and Ktor servers. It holds the test tiers, the commands, the devices, the screenshots, and the mutation runner. If the project file says `platform: kmp`, load this skill."
---

# Kotlin Multiplatform platform

This skill holds the rules that depend on Kotlin Multiplatform (KMP). The `run-rules` skill holds the rules for every agent, and the `controller` skill holds the rules for the controller. This skill does not repeat them. Each rule gives its reason in one sentence.

In this skill, `scripts/...` means the `scripts` folder of the plugin, not a folder of the project. `skills/platform-kmp/...` means the folder of the plugin too. The start-up pointer gives the full path of both. The one exception is `scripts/mutation-runner.sh`, which is a copy in the project, as the Mutation tests section says.

## How to read the commands

The small sample `tests/kmp-sample` of this plugin measured each command that carries a mark. The runs were on the Mac of the owner on 2026-10-25, with these versions:

- Kotlin 2.4.21, Compose Multiplatform 1.12.2, Android Gradle plugin (AGP) 9.3.1, Gradle 9.7.0, and Ktor 3.6.0. The sample pins them in its version catalog.
- JetBrains Runtime 17.0.9 on arm64 as the JDK, on macOS 26.6.2 on arm64.
- Xcode 27.1 (27A9275). The compatibility guide of Kotlin 2.4.21 lists Xcode 26.4. The builds and the simulator tests ran with no version warning, but Xcode 27.1 is newer than the listed one.
- Google Chrome 155.0.8059.86, which also ran the Wasm browser tests as ChromeHeadless 155.
- Android emulator 37.1.11.0, `adb` 37.0.1, and the system image `system-images;android-35;google_apis;arm64-v8a`.
- iOS simulator runtime 27.0 with the device type iPhone 17.

The sample has four Gradle modules: `shared` (logic and tests), `composeApp` (one Compose screen), `androidApp`, and `server` (Ktor). It also has an Xcode project in `iosApp`. The Android and iOS device runs used the sample from the worktree of the plugin.

- The mark `(measured: exit <code>, <time>)` gives the result of that run. A time is for a small app with warm caches, so a real project takes longer. A command with no mark was not measured, and the text says so.
- A cold first build takes much longer. The first run of each target downloads a toolchain. In the sample, the first iOS simulator test run took 70 seconds against 6 warm. The first Wasm browser test run took 84 seconds against 5. The first link of the iOS framework took 110 seconds. Gradle downloads Node and Yarn for Wasm. Kotlin/Native downloads its compiler and LLVM into `~/.konan`. The first Android build installed an Android platform and build tools into the Android SDK folder.
- Versions change the task names and the flags. On another version, run `<gradle> tasks --all` before you rely on a task name.

In the commands below, `<gradle>` stands for the value of `gradle_command`. `<ledger>` is the ledger folder of the run. Every command writes its output to its own log file in the ledger folder. This is the form, and each command below uses it:

```
<command> > <ledger>/logs/<step>.log 2>&1
```

Create the `logs`, `results`, and `screens` folders in the ledger folder before the first redirect, because a redirect to a missing folder fails. Below, `<log>` means that path, with a new `<step>` name for each command. The stall watch and the evidence rules of `run-rules` read logs, and a pipe hides the output until the command ends.

## Project file keys

- `platform` is `kmp`. `mutation_runner` keeps its default, `scripts/mutation-runner.sh`.
- `gradle_command` is the command that runs Gradle. The default is `./gradlew`, because a KMP project carries its own Gradle wrapper. The value runs through `bash -c` from the top of the worktree. On a Mac with a default JDK that is wrong for Gradle, it carries the JDK, for example `env JAVA_HOME=<java_home> ./gradlew`. The mutation runner reads only this key. So the JDK must be inside this value, or the runner uses the wrong one. If the worktree has no project file, the runner reads the project file of the main checkout.
- `java_home` is required. It is the path of an arm64 JDK, version 17 or later. On the measured Mac, a run with `JAVA_HOME` empty used the default JDK, which is an x86_64 JDK. The Gradle log said `current host is X64`. Kotlin/Native then chose the `macos_x64` host, and `:shared:iosSimulatorArm64Test` printed `SKIPPED` and `is disabled ... cannot run on the current host (macos-x86_64)`. Gradle still ended with `BUILD SUCCESSFUL` and exit 0. The probe ran `:shared:jvmTest :shared:iosSimulatorArm64Test --rerun-tasks` (measured: exit 0, 139 seconds). So a wrong JDK can skip the iOS tests with no failure. Agents read `java_home` and copy the path into `gradle_command` and into the command line of `xcodebuild`. No script reads the key.
- `test_processes` is `java,node,webpack,xcodebuild`. `java` runs the Gradle client, the Gradle daemon, and the Kotlin compile daemon. `node` appeared in the window of the Wasm browser tests. `webpack` runs the dev server of a web serve, and `node` does not match it. `xcodebuild` runs the iOS app build. The Stalled runs section gives the detail. Do not add `Google Chrome`, because the Chrome of the developer has the same name.
- `view_globs` lists the files of the screens. For the layout of the sample, it is `composeApp/src/**`. Add the folders of any other module that holds a screen. A shared logic module has no screen.
- `implementer_agent` is `agentic-delivery:kmp-implementer`, and `reviewer_agent` is `agentic-delivery:kmp-reviewer`. They load this skill. A project that keeps the general agents can leave both keys at their defaults.

This is the front matter of a KMP project:

```
platform: kmp
gradle_command: env JAVA_HOME=<java_home> ./gradlew
java_home: <java_home>
test_processes: java,node,webpack,xcodebuild
view_globs: composeApp/src/**
implementer_agent: agentic-delivery:kmp-implementer
reviewer_agent: agentic-delivery:kmp-reviewer
```

Show the JDK with `<java_home>/bin/java -XshowSettings:properties -version`. The line `os.arch = aarch64` means arm64.

## The rules file of the repository

If the repository has a rules file for agents, such as `AGENTS.md` or `CLAUDE.md`, every agent reads it before it writes or reviews code. It beats the brief, because the team of the repository reviews it. If a sample in the brief breaks it, follow the file and say so in the report.

## Test tiers

Use the cheapest tier that can prove the fact. These are the tiers, cheapest first:

1. Shared logic tests in `commonTest`, written with `kotlin.test` and run on the JVM. They need no device and no browser.
2. Server tests on the JVM. A Ktor endpoint is tested through the `testApplication` test host. No test reaches a live host, because a live host holds real data.
3. The same shared tests on the other targets: the Android host tests, the Wasm browser tests, and the iOS simulator tests. They catch a difference between targets. A change in a shared source set reaches every target of its module, so run this tier before you report.
4. A screen check on a device kind: the browser, an Android emulator, or an iOS simulator.

A fact that a shared test can prove does not go to a screen. A JVM test runs in seconds, and a device run costs minutes and machine load. The rule of `run-rules` applies: put logic where a test can assert it. A screen holds no business logic, so a test in `commonTest` reaches it without a screen.

A Compose UI test is allowed by the rules of the KMP agents. No such test ran in the measurements of this layer, so this skill gives no command for one.

## Commands

Run each command from the top of the worktree, in the background mode of the shell tool, as `run-rules` says. Every Gradle command passes `--console=plain`, so that the log grows one line at a time. The stall watch reads the size of the log, and the rich console rewrites lines.

### Rules for every Gradle command

- If the inputs did not change, Gradle can skip a test task, and the old report stays in place. A command that must prove a fact forces a rerun: add `--rerun` to the one task. The mutation runner does this. Its baseline call is `<gradle> :shared:jvmTest --tests trip.ClampTest.inside --rerun --console=plain`. Use `--rerun-tasks` for a full rerun. It also reruns the compile tasks and the downloads.
- To run one test, add `--tests "<class>.<method>"` to the task, with the fully qualified class name. The filter was measured on the JVM tasks, and on the iOS task (the runner passed `--tests trip.ClampTest.inside` to `:shared:iosSimulatorArm64Test` and only `inside[iosSimulatorArm64]` ran). It was not measured on the Android host and Wasm tasks.
- A test report is at `<module>/build/test-results/<task name>/TEST-*.xml`. A command that must prove that tests ran reads it: it counts `tests`, `failures`, `errors`, and `skipped`. Exit 0 alone proves nothing, as the JDK rule above shows.
- A check of the iOS tests also fails on these lines in the Gradle log: `> Task :shared:iosSimulatorArm64Test SKIPPED`, `> Task :shared:iosSimulatorArm64Test NO-SOURCE`, and any line with `is disabled`. The check in `tests/kmp-toolchain/check.sh` uses `grep -E '^> Task :shared:iosSimulatorArm64Test (SKIPPED|NO-SOURCE)|is disabled'` on the log, and it expects `tests=2 failed=0 skipped=0` in the report.
- The word `SKIPPED` is not a failure by itself. A task with nothing to do prints it, for example `:shared:checkKotlinGradlePluginConfigurationErrors`. In the Xcode build, `embedAndSignAppleFrameworkForXcode` printed `SKIPPED` and the framework still linked. A check looks for the line of one named task.
- A separate `export` does not persist between the tool calls of an agent. Put each environment variable on the same command line, as `env <NAME>=<value> <command>`. The rules below do this.
- Never run `./gradlew --stop`. It stops every daemon of that Gradle version for the user, and daemons of other tickets die with it. Stop a process only by its own process id, as `run-rules` says. See the next section.
- Never run a task that publishes, uploads, deploys, signs, or installs on a real device.

### Gradle daemons

The Gradle client, the Gradle daemon, and the Kotlin compile daemon all run as `java`. A daemon outlives the command that started it.

- Measured technique, a private daemon registry: put `env GRADLE_OPTS="${GRADLE_OPTS:+$GRADLE_OPTS }-Dorg.gradle.daemon.registry.base=<folder>"` in front of every Gradle command, as in `env GRADLE_OPTS="${GRADLE_OPTS:+$GRADLE_OPTS }-Dorg.gradle.daemon.registry.base=<folder>" <gradle> :shared:jvmTest --console=plain`. The form appends to the `GRADLE_OPTS` that the user already has, and it does not replace it. Use a folder that only this run uses, with no space in its path, because the options split at spaces. Put it in front of the `scripts/mutate.sh` call too, because the runner inherits the environment. Gradle then registers its daemons in `<folder>/<gradle version>/`, in files named `daemon-<pid>.out.log`. The daemons of this run do not reuse the idle daemon of another ticket, and other tickets do not reuse them. At the end of the run, stop only the Gradle daemons of the registry, and nothing else. Read the process ids from those file names. A file stays after its daemon exits, and the system can give the same id to another process later. So before each `kill <pid>`, run `ps -o command= -p <pid>`. Stop the process only if the command holds `GradleDaemon`. If `ps` prints nothing or another command, skip the id. On 2026-10-25, `ps -o command=` of a Gradle 9.7.0 daemon in such a registry held `GradleDaemon`, and its child held `KotlinCompileDaemon`. The check `tests/kmp-toolchain/check.sh` measured the registry: it set the variable once for all its Gradle commands and ended with no Gradle or Kotlin daemon left (measured: exit 0, 38 checks passed, 0 failed). That run also stopped the child processes of each daemon. The script now follows the rule of this skill and leaves the Kotlin compile daemon to exit on its own. Nobody ran the check again after that change. The one-line form was not measured on its own.
- Without a private registry, never stop a Gradle daemon. Another worktree can start a daemon during your run. A daemon ends on its idle timeout. Stopping a daemon needs the private registry.
- Never stop the Kotlin compile daemon. It is shared. In a measured run, the Gradle daemon of one build used the Kotlin compile daemon that another build had started, so a stop can kill the compile of a concurrent ticket. The compile daemon ends on its own idle timeout.

### Build and test

These commands ran in the sample, with `env JAVA_HOME=<JBR 17> ./gradlew` as `<gradle>`. The task names come from `<gradle> tasks --all` on the sample.

- Gradle version: `<gradle> --version --console=plain > <log> 2>&1` (measured: exit 0, 1 second).
- Task list: `<gradle> tasks --all --console=plain > <log> 2>&1` (measured: exit 0, 1 second warm, 35 seconds on the first run).
- Shared JVM tests: `<gradle> :shared:jvmTest --console=plain > <log> 2>&1` (measured: exit 0, 14 seconds). The report folder is `shared/build/test-results/jvmTest`.
- Ktor server tests: `<gradle> :server:test --console=plain > <log> 2>&1` (measured: exit 0, 3 seconds). The report folder is `server/build/test-results/test`.
- Shared Android host tests: `<gradle> :shared:testAndroidHostTest --console=plain > <log> 2>&1` (measured: exit 0, 3 seconds).
- Shared Wasm browser tests: `<gradle> :shared:wasmJsBrowserTest --console=plain > <log> 2>&1` (measured: exit 0, 13 seconds). They start a headless Chrome, so Chrome must be installed.
- Shared iOS simulator tests: `<gradle> :shared:iosSimulatorArm64Test --console=plain > <log> 2>&1` (measured: exit 0, 16 seconds). Run the check from the rules above. The measured run created no simulator for this task.
- Android debug app: `<gradle> :androidApp:assembleDebug --console=plain > <log> 2>&1` (measured: exit 0, 13 seconds). The APK is `androidApp/build/outputs/apk/debug/androidApp-debug.apk`.
- iOS framework: `<gradle> :composeApp:linkDebugFrameworkIosSimulatorArm64 --console=plain > <log> 2>&1` (measured: exit 0, 14 seconds). The framework is `composeApp/build/bin/iosSimulatorArm64/debugFramework/ComposeApp.framework`.
- Web distribution: `<gradle> :composeApp:wasmJsBrowserDistribution --console=plain > <log> 2>&1` (measured: exit 0, 28 seconds). The files are in `composeApp/build/dist/wasmJs/productionExecutable`.
- iOS app in Xcode: see the iOS simulator section. The Xcode build phase calls Gradle.
- Android install: see the Android emulator section.

Structure that AGP 9 forces, and that the sample uses: a shared module applies `com.android.kotlin.multiplatform.library`, and its Android test task is `:shared:testAndroidHostTest`. The Android app is a separate module, `androidApp`, with the plugin `com.android.application`. The KMP Gradle plugin is not compatible with `com.android.application` and `com.android.library` in one module under AGP 9. The older `androidTarget` and `testDebugUnitTest` names do not apply here.

### When QA runs the suite again

After the base merge, QA looks for a change since the last suite run, as `run-rules`, Checks, says. These paths count:

- Source and resources: every Kotlin file, and every file under a `src` folder. That covers the source sets, `resources`, `composeResources`, `res`, `assets`, and the Android manifests. It also covers a `src` folder at the top.
- Build files: the `.kts` and `.gradle` files, the `.toml` files of the top `gradle` folder, every `gradle.properties`, `gradle/wrapper`, the ProGuard files (`.pro`), and the files in `webpack.config.d`, at the top and in a module. A version catalog in another folder is not covered. A file whose name ends in `gradle.properties` also counts.
- Every file in the `iosApp` folder, which holds the Xcode project and the Swift files.

Run this command in the worktree of the run, from the top of the Gradle build:

```
git diff --name-only <last-suite-commit> HEAD -- '*.kt' '*.kts' '*.gradle' '*.pro' '*gradle.properties' 'gradle/*.toml' 'gradle/wrapper' 'iosApp' 'src' '*/src/*' 'webpack.config.d' '*/webpack.config.d/*' > <log> 2>&1
```

Take `<last-suite-commit>` from the ledger entry of the last suite run. Commit the merge first, because `git diff` between two commits does not see a file that is not committed.

- A line with a path means a change. Then QA runs the suite again. The runs below used this command on a copy of the sample. A change to a Kotlin file and to `README.md` listed only the Kotlin file (measured: exit 0, 0 seconds). A second change touched files in `composeResources`, `res`, `assets`, and `resources`, an Android manifest, and a top `src` file. The command listed all six and left out `README.md` (measured: exit 0, 0 seconds). A third change touched a nested `build.gradle`, a nested `gradle.properties`, a `.toml` file in the top `gradle` folder, a ProGuard file, a file in a top `webpack.config.d` folder, and `README.md`. The command listed the first five and left out `README.md` (measured: exit 0, 0 seconds).
- An empty log with exit 0 means no change. Then QA cites the last run (measured: a range from `HEAD` to `HEAD` gave an empty log, exit 0, 0 seconds).
- Any other exit status means that the command did not answer, for example a commit that does not exist. That case gave exit 128 and `fatal: bad object` (measured: exit 128, 0 seconds). Then QA runs the suite again, so that the check fails closed.

### Ktor server

- Test an endpoint with `testApplication`, and run the JVM server tests first: `<gradle> :server:test`. For one test, add `--tests "<class>.<method>"`. A test name in backticks with spaces works with the runner (measured, see the Mutation tests section).
- Each new or changed endpoint has a test with the status and the body. No test reaches a live host.
- The agents `kmp-implementer` and `kmp-reviewer` carry the Ktor rules for errors and visibility. This skill does not repeat them.
- Running the server by hand with `:server:run` was not measured. A manual server run is not a check of this layer.

## Devices and claims

The device kinds are the browser for the Wasm target, the Android emulator, and the iOS simulator. A ticket creates its own emulator and simulator and deletes them at the end. Two tickets on one device install over each other, as `run-rules` says. `run-rules` also says who holds a device. This section gives the commands.

- Put the slug in the name of each device that you create, for example `<slug>-android` and `<slug>-ios`. Then a list of devices shows which ticket owns each one.
- Pass the full id to every tool that takes an id: `adb`, `ANDROID_SERIAL`, `simctl`, and the claim script. The tools `avdmanager` and `emulator` take the name of the virtual device, which holds the slug.
- Never pass `all` to a `simctl` command. It reaches the devices with a signed-in session and the devices of other tickets.
- `<android-sdk>` is the Android SDK folder, `$HOME/Library/Android/sdk` on the measured Mac. `adb` is at `<android-sdk>/platform-tools/adb`, `avdmanager` at `<android-sdk>/cmdline-tools/latest/bin/avdmanager`, and `emulator` at `<android-sdk>/emulator/emulator`.

### The device claim

Claim each device after it boots and before the first install. Always pass `--worktree`. Without it, the script holds the device for the folder above the script, not for your worktree.

- Claim: `scripts/claim-device.sh --device <id> --worktree <worktree-path> > <log> 2>&1`. The id is `emulator-<port>` for an emulator, the simulator id for a simulator, and `web-<web-port>` for a web server port. Claim a web port before you start the server.
- Release: `scripts/claim-device.sh --device <id> --worktree <worktree-path> --release > <log> 2>&1`.
- The claim and the release of an emulator id ended with exit 0 in 0 seconds each (measured: exit 0, 0 seconds). The same holds for a simulator id. The claim and the release of `web-<web-port>` ended with exit 0 in the run of the check. That run did not record their times, so they carry no time.

The exit codes of the claim script:

- 0: the worktree holds the device, or the release is done.
- 5: another worktree holds the device. After a claim, create your own device of the same type and runtime. For a port id, pick another port. After a release, nothing was released.
- 4: the device id or the worktree is not valid.
- 3: the script cannot create its lock folder.
- 2: a usage error.

Release the claim before you delete the device or stop the emulator. A later emulator on the same port gets the same id, and a lock that stays refuses it while your worktree exists.

### Web

The web server port gets a claim, `web-<web-port>`. Pick a port that nothing listens on, with `lsof -nP -iTCP:<port> -sTCP:LISTEN`. The default port of the dev server is 8080, and another program held it on the measured Mac. The dev server also opens a browser tab by default. That is a tab in the browser of the developer.

The Wasm browser tests, `:shared:wasmJsBrowserTest`, need no claim. Two pairs of builds ran them at the same time, and all four builds ended with exit 0 and `BUILD SUCCESSFUL`. The pair started together took 50 seconds each. The pair started 8 seconds apart took 79 and 80 seconds (measured: exit 0 in 50, 50, 79, and 80 seconds). The data does not show which port the tests used.

So a serve needs one file in the Compose module, `composeApp/webpack.config.d/serve.js`, with this content:

```
config.devServer = config.devServer || {};
config.devServer.port = <web-port>;
config.devServer.host = "localhost";
config.devServer.open = false;
```

The Kotlin Gradle plugin reads the port from this file only. It has no Gradle option for it. Do not commit a file that holds a port that is only for one run. Remove it after the serve, or keep it out of the commit.

- Serve, detached, with its own log: `<gradle> :composeApp:wasmJsBrowserProductionRun --console=plain > <log> 2>&1 &`. Write the process id from `$!` in the ledger (measured: the log printed `[webpack-dev-server] Loopback: http://localhost:<web-port>/` after 36 seconds, and `webpack 5.108.1 compiled with 3 warnings` after 36 seconds, and `curl` gave status 200). The task never ends by itself. After webpack compiles, the log stops growing, so never pass this log to the stall watch with `--log`.
- The server that listens on the port is a process named `webpack`, a child of the Gradle daemon. `pgrep -x webpack` matches it. `pgrep -x node` does not.
- Stop it after the capture: `kill <pid>`, with the id from `$!` (measured: the process ended, the `webpack` listener ended with it, and the port was free). If the listener stays, find it with `lsof -nP -t -iTCP:<port> -sTCP:LISTEN`. Before you stop that id, run `ps -o comm=,ppid= -p <pid>`. Stop it only if the name is `webpack` and the parent id is the id of a Gradle daemon of this run, which is a file `daemon-<parent id>.out.log` in the private registry. Another program can listen on the port, and it is not yours to stop. In the measured serve, the listener was `webpack` and its parent was a daemon of the registry of the run (measured: the listener was `webpack`, and its parent id matched a file `daemon-<id>.out.log` of the registry). Never stop it by name.
- Then release the claim.

### Android emulator

The tools `avdmanager` and `emulator` take the name of the virtual device. The tools `adb` and Gradle take the id, which is `emulator-<port>`. The name holds the slug, so it cannot resolve to the device of another ticket.

- The Android Gradle plugin needs the path of the Android SDK. It comes from `ANDROID_HOME`, or from `sdk.dir` in `local.properties`. The sample has no `local.properties`, and the check script does not set `ANDROID_HOME`. So the measured runs relied on the shell environment of the session. The measurements do not show which variable the plugin read.

- Create: `echo no | env JAVA_HOME=<java_home> <android-sdk>/cmdline-tools/latest/bin/avdmanager create avd -n <slug>-android -k "system-images;android-35;google_apis;arm64-v8a" -d pixel_8 > <log> 2>&1` (measured: exit 0, 1 second). The `echo no` answers the question about a custom hardware profile. The tool also prints many lines `Error: Could not load devices from .../devices.xml` for old images, and it still ends with exit 0. The error lines are noise. Exit 0 is the result.
- Claim `emulator-<port>` with the port from the next step.
- Boot, detached and headless: `<android-sdk>/emulator/emulator -avd <slug>-android -port <port> -no-window -no-audio -no-boot-anim -no-snapshot-save -gpu swiftshader_indirect > <log> 2>&1 &`. Write its process id, from `$!`, in the ledger. Use an even port from 5554 to 5584 that no other ticket uses. The next port must also be free. The port sets the id. Keep to this range as a rule. The range was not measured here (the measured run used 5580). Headless `-no-window` worked, and screenshots through `exec-out screencap` need no window (measured: `sys.boot_completed` was `1` 33 seconds after the launch).
- Wait in a background loop on `<android-sdk>/platform-tools/adb -s emulator-<port> shell getprop sys.boot_completed` until it prints `1`. Do not install before that.
- Install: `env ANDROID_SERIAL=emulator-<port> JAVA_HOME=<java_home> GRADLE_OPTS="${GRADLE_OPTS:+$GRADLE_OPTS }-Dorg.gradle.daemon.registry.base=<folder>" ./gradlew :androidApp:installDebug --console=plain > <log> 2>&1` (measured: exit 0, 27 seconds, with warm caches). The measured run did not carry the `GRADLE_OPTS` part, so this form was not measured on its own. With `gradle_command`, put `ANDROID_SERIAL=emulator-<port>` in front of the command. Always set `ANDROID_SERIAL`. Without it, `installDebug` installs on every connected device, including a real phone. The log said `Installed on 1 device.`
- Start: `adb -s emulator-<port> shell am start -W -n <applicationId>/<activity class> > <log> 2>&1` (measured: exit 0, 6 seconds, `LaunchState: COLD`). The component takes the full class name. In the sample, the application id is `trip.sample` and the class is `trip.androidapp.MainActivity`, because the class sits under the namespace of the module.
- At the end: release the claim, then `adb -s emulator-<port> emu kill > <log> 2>&1` (measured: exit 0, 0 seconds, and the emulator process ended within 2 seconds), then `env JAVA_HOME=<java_home> <android-sdk>/cmdline-tools/latest/bin/avdmanager delete avd -n <slug>-android > <log> 2>&1` (measured: the log said `AVD '<slug>-android' deleted.`, 3 seconds).

The measured image has API 35 and no Google Play. Only this image was measured.

### iOS simulator

- List the runtimes with their device types: `xcrun simctl list runtimes -j > <log> 2>&1`. Read `supportedDeviceTypes` for the runtime before you pick a pair. The `-j` form of this command has no log in the evidence, so it carries no mark. The runtime iOS 27.1 listed only the device type `iPhone Duo` on the measured Mac. `xcrun simctl create <slug>-ios com.apple.CoreSimulator.SimDeviceType.iPhone-17 com.apple.CoreSimulator.SimRuntime.iOS-27-1` stopped with `Incompatible device` (measured: exit 147, 0 seconds).
- Create: `xcrun simctl create <slug>-ios com.apple.CoreSimulator.SimDeviceType.iPhone-17 com.apple.CoreSimulator.SimRuntime.iOS-27-0 > <log> 2>&1` (measured: exit 0, 1 second). The log holds one line, the new id. Write it in the ledger. An app built with the iOS 27.1 SDK ran on this 27.0 simulator.
- Claim the id.
- Boot and wait: `{ xcrun simctl boot <simulator-id> && xcrun simctl bootstatus <simulator-id> -b; } > <log> 2>&1` (measured: exit 0, 57 seconds, with three simulators of other tickets booted). The braces send the output of the boot step to the log too, so a boot error is not lost. The measured run ran the two steps in this order. The log ends with `Finished`.
- Build the app. The Xcode build phase of the sample calls `./gradlew :composeApp:embedAndSignAppleFrameworkForXcode`. The Gradle in that phase uses the `JAVA_HOME` of the process that runs `xcodebuild`. Put an arm64 JDK and the registry options on the same command line: `cd iosApp && env JAVA_HOME=<java_home> GRADLE_OPTS="${GRADLE_OPTS:+$GRADLE_OPTS }-Dorg.gradle.daemon.registry.base=<folder>" xcodebuild -project iosApp.xcodeproj -scheme iosApp -configuration Debug -destination 'id=<simulator-id>' -derivedDataPath <build-dir> build > <log> 2>&1` (measured: exit 0, 68 seconds, and the log ends with `** BUILD SUCCEEDED **`). The measured run exported the variable and ran `xcodebuild` on one line. A separate `xcodebuild` run with `GRADLE_OPTS` exported registered the daemon of the Xcode phase in the private registry (measured: exit 0, 41 seconds). That run used the destination `generic/platform=iOS Simulator` and the plain form of the variable, so this exact command was not measured on its own. Use a `<build-dir>` that your run creates.
- Three warnings in that build log are harmless. One is an `ld: warning`: an object file of `ComposeApp` was built for iOS simulator 18.5 and linked at 17.0, which is the deployment target. The second is the note that the `Compile Kotlin Framework` phase runs on every build. The third is a note that metadata extraction was skipped. Do not read `SKIPPED` of `embedAndSignAppleFrameworkForXcode` in the inner Gradle log as a failure. Read the end of the `xcodebuild` log.
- Install from the path that the build printed, not from a search: `xcrun simctl install <simulator-id> <build-dir>/Build/Products/Debug-iphonesimulator/iosApp.app > <log> 2>&1` (measured: exit 0, 13 seconds).
- Start: `xcrun simctl launch <simulator-id> <bundle-id> > <log> 2>&1` (measured: exit 0, 4 seconds). The bundle id of the sample is `trip.sample`.
- At the end: release the claim, then `xcrun simctl shutdown <simulator-id> > <log> 2>&1` (measured: exit 0, 4 seconds), then `xcrun simctl delete <simulator-id> > <log> 2>&1` (measured: 1 second, and `xcrun simctl list devices` then showed no device with the slug).

The screen check uses this simulator. The task `:shared:iosSimulatorArm64Test` ran in the measurements without a simulator that the run had created.

### Count, not size

Count device clones, with `xcrun simctl list devices` and `<android-sdk>/cmdline-tools/latest/bin/avdmanager list avd -c`. Do not measure their disk size, as the Diagnosis section of `run-rules` says. After the delete, `ls ~/.android/avd` listed only the other AVDs (measured).

## Screenshots

Capture only after two frames match, on each device kind. Use the settle script with the capture command of the device kind:

```
scripts/settle-screenshot.swift --capture "<capture command>" --out <ledger>/screens/<screen>-<kind>.png > <log> 2>&1
```

`<kind>` is `web`, `android`, or `ios`. The capture commands:

- iOS simulator: `xcrun simctl io <simulator-id> screenshot {out}` (measured: exit 0, 7 seconds, settled after one comparison). Install and start the app first.
- Android emulator: `<android-sdk>/platform-tools/adb -s emulator-<port> exec-out screencap -p > {out}` (measured: exit 0, 10 seconds, settled after one comparison). The script quotes `{out}`, so the redirect works.
- Chrome, headless: `'<chrome-binary>' --headless --user-data-dir=<profile-dir> --virtual-time-budget=5000 --screenshot={out} --window-size=<width>,<height> http://localhost:<web-port>/ & p=\$!; i=0; while [ ! -s {out} ] && [ \$i -lt 30 ]; do sleep 1; i=\$((i+1)); done; sleep 1; kill \$p; [ -s {out} ]` (measured: exit 0, 10 seconds, settled after one comparison, with Chrome 155, a window of 600 by 800, and the production run of the dev server). The Chrome binary on a Mac is `/Applications/Google Chrome.app/Contents/MacOS/Google Chrome`.

Notes on the Chrome capture:

- Compose for the web draws to a canvas. A text search of the page finds nothing, so it proves nothing. The screen check reads pixels. In the measured run, headless Chrome drew the canvas on the first try. The frame had 0.997 of its pixels in the background color of the sample screen, and 755 white pixels of text. A check of this kind names the color and the count. Open the settled frame too, and make sure that it shows the screen.
- A canvas app can write a blank frame before its first draw, and two blank frames match. So the settle script can report a settled screen that is blank. Use `--virtual-time-budget=5000`, then open the frame. In an earlier probe of the sample, a page whose `body` had a height of 0 drew nothing. The fix was `html, body { width: 100%; height: 100%; margin: 0 }` in the `index.html` of the app.
- Headless Chrome does not always exit after it writes the frame. So the command starts Chrome in the background, waits up to 30 seconds for the file, and stops that Chrome by its own process id.
- The capture command sits inside double quotes, so write each `$` as `\$`, as shown. Put single quotes around the Chrome path, because it holds spaces.
- `<profile-dir>` is an empty folder of the worktree. A separate profile keeps headless Chrome away from the profile of a Chrome window that is open.
- If a Chrome process stays after the capture, find it by its `--user-data-dir=<profile-dir>` with `pgrep -f`, and stop it by its id.
- Two fallbacks exist for a blank canvas, and neither one was needed. Try them in order. The first is headless Chrome with `--enable-unsafe-swiftshader` for software WebGL. The builder tried it once by hand on the sample and it drew the screen, but no log was kept. The second is a visible Chrome window with its own profile, started and stopped by the capture command. The `--screenshot` flag of Chrome works only headless, so this fallback needs a different capture command. It also needs the Screen Recording permission of macOS. The visible window is not measured.

The script replaces `{out}` with the path of the frame, and it quotes that path for the shell. Do not put quotes around `{out}`. A second pair of quotes puts quote characters into the path, and the script then finds no file.

The exit codes of the settle script:

- 0: the screen settled, and the `--out` file holds the frame.
- 1: the screen never settled. The `--out` file holds the last frame, so do not attach it as proof. Read the region that the error output names.
- 2: a usage error or a capture error. The error output names the cause.

The default tolerance is 0.001, as a fraction of the pixels. If exit 1 names a large region, the screen still animates or loads, so raise `--attempts` and not the tolerance. Raise `--tolerance` only for a screen that must show a focused field, and set it just above the fraction that the message printed.

A screen check that needs data uses a temporary screen with fixture data. Never commit the temporary screen. The ship step deletes it before the final build.

## Logs and API contract

Logs of a Ktor server:

- A log line, an error string, and a response body never hold a request body, a token, a secret, or a user value. A log line names the event and the error. The project file can name more fields. The reviewer reads every new or changed log line, and a user value in one is Critical.

API contract:

- A request without a new field works as before. Write a test for that case, and name it in the report, because a client that users did not update still sends the old request. A web build in a browser cache and an old app on a phone are such clients.
- Each new or changed field gets three tests: the field is present, the field is absent, and the field has the wrong type. If the field has a size limit, a test also covers a value over the limit. Run these tests through `testApplication`.
- A request or response type that sits in `commonMain` is the contract of the server and of every client target at once. A change to it reaches every target. Run the tier 3 tests of the module that holds it.
- The project file can have a section API clients. It names each client repository, the branch to read, and the place of its request and response types. The reviewer reads each changed field there with `git show <branch>:<path>`. It compares the JSON key, the type, whether the field is optional, and the size limit. A mismatch is Important.

## Manual checks

- A server run has no manual checks, unless the repository can start the server with fakes on this machine. Never start the server with a development, staging, or production configuration, because that reaches real data and real hosts. Then each check is one request, with its expected status and body. With no checks, the QA log ends with `tally: 0 checks, 0 run, 0 unrun, 0 waived`, and the ready check accepts it.
- A web screen check serves the app as the Web section says, and it names the page, the fixture, and the expected pixel result. The screen is a canvas. So the expected result is a color at a place in the frame, or a count of pixels of one color. It is never a text. It names the value on a correct tree and the value on the defect that it excludes. A run never signs in to an account.
- A check on an emulator or a simulator names the device kind, the screen, and the same kind of pixel result.

## Stalled runs

Measured process names, from a `pgrep -x` sample every 5 seconds during the check, and from two builds at once:

- `java` runs the Gradle client, the Gradle daemon, and the Kotlin compile daemon. In an `xcodebuild` run, the Gradle client of the run-script phase and its daemon run as `java` too. Any Java program, such as an editor or Android Studio, also runs as `java`. Before you report a frozen `java` process, read its command with `ps -o command= -p <pid>`. The command of a Gradle daemon holds the path of the Gradle folder.
- `node` ran during the window of the Wasm browser tests. The command of that process was not read, so this skill does not claim that it is the test runner. Other programs on the machine also run as `node`.
- `webpack` is the dev server of a web serve. Watch `webpack` and not `node` during a serve.
- `xcodebuild` runs the iOS app build. Other tickets run `xcodebuild` too.
- A Chrome process runs during the Wasm browser tests and during a capture. The name `Google Chrome` also matches the browser of the developer, so do not watch it.
- The simulator app and the emulator process are not test processes. Do not watch them.

Do not judge a Gradle build by the processor total of `java` alone. A daemon stays alive after the build and keeps its process. The size of the log decides: `stat -f %z <log>` prints it in bytes. The Gradle log ends with the line `> Task <name>` of the task that started last. A task with a long job leaves that line in place.

What a quiet log looks like, and what is not a stall:

- The first build of a target downloads a large toolchain and writes little to the log for minutes. That is slow, not stalled, while the process uses the network.
- A log can stay still on one task line. In the measured runs the longest still span was 15 seconds. The default of `--build-after` in `scripts/stall-watch.sh` is 4 minutes.
- Two worktrees can run Gradle at the same time on one machine. They share the Gradle user home with its downloads and caches. Two measured pairs of builds ran the same three tasks. Started together, both ended with exit 0 in 50 seconds. The second build of the other pair started 8 seconds after the first. Those two ended with exit 0 in 79 and 80 seconds. The log of the later build shows this:
  - It starts with `Starting a Gradle Daemon, 1 busy Daemon could not be reused, use --status for details`. That line is normal. It does not report an error.
  - It stays at that first line for 15 seconds.
  - Later it stays at one task line. It stayed at `> Task :kotlinWasmKotlinNpmCachesSetup` for 7 seconds while the other build ran `:kotlinWasmNpmInstall`. It stayed at `> Task :kotlinWasmNpmInstall` for 14 seconds. Gradle printed no lock line and no wait line at any point. The log only stops growing on the last task line.
  - Both builds ended with `BUILD SUCCESSFUL`.
  - The measured data does not name the resource that the build waited for. A still log of this kind is not a stall until the log size stays the same past the `--build-after` budget of the watch.
- The processor total stays at zero while a device boots.

The remedies come in this order. Apply them only after the processor total and the log size stay frozen for the budget of the stall watch. The controller skill gives that budget:

1. Clean the device clones. Count the devices first, with `xcrun simctl list devices` for simulators and `<android-sdk>/cmdline-tools/latest/bin/avdmanager list avd -c` for emulators. Then shut down and delete each device of a finished ticket that the list printed and that no claim holds.
2. Kill and relaunch. Kill only the process ids of your own run, with `kill <pid>`. Run the same command again with a new log file. A hung process does not recover, and the new log keeps the evidence of the dead run.
3. Make sure that the device still runs. For a simulator, `xcrun simctl list devices` must show `(Booted)` on the line of the id. For an emulator, `adb -s emulator-<port> get-state` must print `device`. Do not use `bootstatus` here, because it waits and on a stopped device it never returns. These two checks were not run in the measurements of this layer.

An implementer reports a stall and does not act on it, as its agent file says.

### The stall watch

Arm one watch that takes every name in `test_processes`, as the controller skill says. Pass one `--log` flag for each command log of the run, and not the log of the watch or the log of a dev server. Use one of these two forms:

- With no `--process` flag, the script reads `test_processes` by itself: `scripts/stall-watch.sh --interval 60 --log <command-log> > <log> 2>&1`
- With one `--process` flag for each name: `scripts/stall-watch.sh --process java --process node --process webpack --process xcodebuild --interval 60 --log <command-log> > <log> 2>&1`

No run of the watch on a KMP build was measured. Read the log of the watch for a heartbeat line before you dispatch, as the controller skill says. The names above came from `pgrep -x` samples, not from the watch.

## Mutation tests

`scripts/mutate.sh` runs the tests through a platform runner, as its usage text says. The KMP runner of this plugin is `skills/platform-kmp/mutation-runner.sh`. Copy it into the project as `scripts/mutation-runner.sh`, and commit it. That path is the default of the `mutation_runner` key. Run `scripts/mutate.sh` from the top of the worktree, where `gradlew` is, with a clean tree, as its usage text says. The runner takes the top of the git repository as the Gradle root. So a project with `gradlew` in a subfolder gets no test entry, and the baseline refuses the run.

A test id has the form `<Gradle task path>::<class>.<method>`. The class name is fully qualified. For example: `:shared:jvmTest::trip.ClampTest.inside`. A name in backticks works with its spaces, for example `:server:test::trip.ServerTest.health answers ok for a plain request` (measured: the baseline of the runner ended with exit 0 in 6 seconds. The name went to Gradle as one `--tests` argument, and the result file gave `passed`).

The runner reads `gradle_command` from the project file, and then it calls `<gradle> <task> --tests <filter>... --rerun --console=plain` once for each task, from the top of the worktree. It removes the old report folder of the task first, so a stale report cannot give a false verdict. It reads `<module>/build/test-results/<task name>/TEST-*.xml`. Two details of the report names are handled:

- A report of the iOS and Wasm tasks prefixes the class name with the task name, for example `iosSimulatorArm64Test.trip.ClampTest`. The runner removes the prefix.
- A test name on a non-JVM target can end with one bracket suffix, for example `inside[iosSimulatorArm64]` and `inside[wasmJs, browser, ChromeHeadless155.0.0.0, MacOS10.15.7]`. The runner accepts one trailing bracket suffix.

The verdicts:

- A passing test gives `passed`, so the verdict is `survived`. A failing test gives `failed`, so the verdict is `killed`.
- An ignored test gives `skipped`, so the verdict is `error`.
- A module that does not compile gives `compiled: false`, so the verdict is `did-not-compile`. The runner finds it in the line `> Task ...compile...Kotlin... FAILED` of the log.
- A test id that matches no test gives no entry. `scripts/mutate.sh` then refuses the run at the baseline, before any mutation: exit 2, `the baseline did not pass on the unmodified tree`, and `<id>: no test ran` (measured: exit 2, 3 seconds). It is a refusal and not an `error` verdict, because the baseline runs on the unmodified tree first.
- A call that exits with an error and shows no report, no compile failure, and no `No tests found for given includes` line gives no result file and exit 3. Read the log of the call.
- A bad task path, an id without `::`, and an id with an empty part give exit 2 before any test runs.

Do not set `GRADLE_BIN` in a run, because only the tests of the runner use it.

This is an example. The code:

```kotlin
fun clamp(v: Int, lo: Int, hi: Int): Int {
    if (v < lo) {
        return lo
    }
    if (v > hi) {
        return hi
    }
    return v
}
```

`ClampTest` has the tests `below` and `inside`, and no test above the range. This manifest has three entries:

```json
[
 {"label": "hi-survives", "file": "shared/src/commonMain/kotlin/trip/Clamp.kt", "find": "return hi", "replace": "return lo", "test": ":shared:jvmTest::trip.ClampTest.inside"},
 {"label": "lo-killed", "file": "shared/src/commonMain/kotlin/trip/Clamp.kt", "find": "return lo", "replace": "return hi", "test": ":shared:jvmTest::trip.ClampTest.below"},
 {"label": "nocompile", "file": "shared/src/commonMain/kotlin/trip/Clamp.kt", "find": "return v", "replace": "return v +", "test": ":shared:jvmTest::trip.ClampTest.inside"}
]
```

The command: `scripts/mutate.sh --manifest <manifest> --out <ledger>/results/mutate --runner scripts/mutation-runner.sh > <log> 2>&1` (measured: exit 1, 14 seconds). The baseline passed. The first mutation gave `survived`, because no test goes above the range. The second gave `killed`, and the third gave `did-not-compile`. The tracked files were unchanged afterwards. To kill the first mutation, add a test with a value above the range, and run the mutation again. The verdict is then `killed`.

A mutation of `commonMain` code that is checked through `:shared:jvmTest` proves the tests of the JVM target only. A mutation checked through the iOS task or the Wasm task proves the tests of that target.

Where the runner was measured with a real Gradle call: the JVM task `:shared:jvmTest`, the JVM task `:server:test`, and the iOS task. For the iOS task, `mutation-runner.sh --out <result> --log <runner log> -- :shared:iosSimulatorArm64Test::trip.ClampTest.inside` ran only `inside[iosSimulatorArm64]` and gave `passed` (measured: exit 0, 4 seconds). The Wasm browser task and the Android host task were not run through the runner. The test `tests/test-kmp-runner.sh` covers the report names of the iOS and Wasm tasks with a fake Gradle command and fixture reports. It does not run a real toolchain.

## Expert skills

The skills below come from the `kotlin-kmp-claude-agent-skills` collection by Mariano Miani, under the Apache License 2.0, at `https://github.com/mmiani/kotlin-kmp-claude-agent-skills`. Use the commit `939786cb13b49daacea7d5fb0a10877b6005e6be`. Install its 15 skills as user skills with these steps:

1. Clone the repository into an empty folder.
2. Check out the commit: `git -C <folder> checkout 939786cb13b49daacea7d5fb0a10877b6005e6be`.
3. Copy the skills: `mkdir -p ~/.claude/skills && cp -R <folder>/skills/kotlin-* ~/.claude/skills/`.

The owner of the machine installs the skills before a run. An agent never installs them. Install nothing else from the collection. Its agents, hooks, command, and settings stay out, because they run a different pipeline.

A KMP project selects the two agents of this plugin with `implementer_agent` and `reviewer_agent`. They load this skill and list the expert skills below. If the task is in the territory of a skill, load the skill. If a skill conflicts with the project, its rules file, or the agent file, the project wins. Say in the report that you diverged. If a skill is not installed, say so and continue without it.

Implementer:

- `kotlin-project-feature-implementation` for any feature work.
- `kotlin-testing-kmp` for every test that you write.
- `kotlin-platform-kmp-bridges` for source sets and `expect` and `actual`.
- `kotlin-ui-compose-multiplatform` and `kotlin-ui-adaptive-resources` for a screen.
- `kotlin-navigation-compose-multiplatform` for navigation.
- `kotlin-project-state-management` for a state holder.
- `kotlin-data-kmp-data-layer` for a repository or a data source.
- `kotlin-build-kmp-gradle-governance` and `kotlin-project-modularization` for a build or module change.
- `kotlin-project-bugfix` for a bug, and `kotlin-kmp-refactor-safety` for a refactor.

Reviewer:

- `kotlin-kmp-code-review` for every review.
- `kotlin-project-architecture-review` and `kotlin-project-modularization` for layers and modules.
- `kotlin-testing-kmp` to judge whether the tests are adequate.
- `kotlin-platform-kmp-bridges` for source sets and `expect` and `actual`.
- `kotlin-ui-compose-multiplatform`, `kotlin-ui-adaptive-resources`, and `kotlin-navigation-compose-multiplatform` for screens and navigation.
- `kotlin-project-state-management` and `kotlin-data-kmp-data-layer` for state and data.
- `kotlin-build-kmp-gradle-governance` for a build change.
- `kotlin-kmp-refactor-safety` for a refactor.

The collection holds one more skill, `kotlin-platform-app-links-and-deep-links`. The two agents do not list it, and it is part of the 15 that the steps install.

## Where this layer was used

At first, only the sample `tests/kmp-sample` of this plugin, on 2026-10-25, with the versions above. No project uses this layer yet. Each later pull request adds the projects and runs that measured a new part.

Measured on the sample:

- Build and tests of all four targets, and the Android debug build, the iOS framework link, and the web distribution.
- The mutation runner through `scripts/mutate.sh` on the JVM test task: `killed`, `survived`, `did-not-compile`, and the baseline refusal for a name that matches no test. The `--tests` filter on the iOS simulator task.
- Serving the web app, and the headless Chrome screenshot of it.
- Install, start, and capture of the app on an Android emulator, and build, install, start, and capture on an iOS simulator.

The script `tests/kmp-toolchain/check.sh` runs the Gradle, runner, serve, and web capture steps against a copy of the sample. It needs macOS, Xcode, the Android SDK, and Chrome. The emulator and simulator runs were hand runs with their own logs. The sample run of the check passed 38 of 38 checks (measured: exit 0), before the change that leaves the Kotlin compile daemon running. No CI job runs it.

Not measured:

- The `--tests` filter on the Android host and Wasm tasks, and the runner on those two tasks with a real Gradle call.
- The headless software-WebGL fallback with a log, and the visible Chrome window fallback.
- A Compose UI test, an Android instrumented test, a real device, a release build, signing, and any deploy.
- The `:server:run` task and a manual run of the server.
- The stall watch on a KMP build, and the device checks of remedy 3.
- Android system images other than API 35, and iOS runtimes other than 27.0.
- The stop of the Gradle daemons of the private registry with the `ps` check, and the effect of stopping a shared Kotlin compile daemon on a concurrent build. The skill never stops that daemon.

Nothing in the must and must-try lists of the design was blocked by an outside tool.
