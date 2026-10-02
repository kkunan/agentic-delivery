# The iOS platform layer: design

Date: 2026-10-02. Status: draft for review in its own pull request.

This file adds one platform layer to the plugin design in
`2026-10-02-agentic-delivery-design.md`. It does not change that file. After the review, the main
design can absorb this file, or keep it beside the main design.

## Goal

Add a platform layer for native iOS apps, with SwiftUI as the default user interface framework and
notes for UIKit screens. The workflow comes from a native iOS project, so most of the rules and two
of the scripts exist already.

## Decisions

1. The layer is one skill, `skills/platform-ios/SKILL.md`. A project selects it with `platform: ios`.
2. SwiftUI is the default. A section covers UIKit screens that a project still has.
3. The layer adds four project file keys, and builds every command from them:
   - `ios_workspace`: the workspace or project file that every build opens
   - `ios_scheme`: the scheme for builds and tests
   - `ios_test_plan`: the test plan, if the project uses one
   - `ios_runtime`: the simulator runtime that new devices use
4. The mutation runner keeps its current Xcode result parser as the iOS adapter of the runner
   contract in the main plan.
5. The capture command for the screenshot settle script on iOS is the simulator screenshot command.

## What the skill holds

- Test tiers, cheapest first: unit tests, snapshot tests, and UI tests on a simulator. A fact that a
  unit test can prove does not go to a simulator.
- Simulators: each ticket creates its own simulator for `ios_runtime` and deletes it at the end. A
  command passes a simulator by id, never by name. The device claim script holds a simulator for one
  worktree.
- Commands: build, test, and archive with `xcodebuild`, built from the four keys. Each command writes
  to a log file and to a result bundle in the run's ledger folder.
- Stalled runs: the ordered remedies, the processor-time test, and the cleanup of the simulator
  clones that each test run leaves behind.
- Screenshots: the settle script with the simulator capture command, and the advice on tolerance and
  the text caret.
- Release checks: build the Release configuration. A Debug build does not stand for a Release build.
- Code rules for SwiftUI and UIKit that held in the source project, without its names.
- The expert skills that the agents load for iOS work, by role.

## Tests

- The skill passes the Simple English lint with 0 hits.
- The plugin validator passes.
- Each command in the skill names only project file keys, never an app, a scheme, or a device.

## Out of scope

- Moving the source project to the plugin. It keeps its own files.
- The project file reader and the template changes for the four keys. The main plan owns the project
  file, so its Task 7 adds them.
- The runner adapter code. The main plan's Phase 3 adds it.
