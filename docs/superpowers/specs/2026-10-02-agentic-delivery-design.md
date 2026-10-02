# agentic-delivery: design

Date: 2026-10-02. Status: draft for the owner's review.

## Goal

Package the agentic feature workflow from an existing iOS project, the source project, as a Claude Code plugin that other
projects can install. The first target is a Flutter project that a team works on. Later targets can be
a backend project or the product process as a whole. They are out of scope for this spec.

## Decisions

These decisions come from the brainstorm on 2026-10-02.

1. The export is a Claude Code plugin that you install one time. It is not a starter folder or a
   written playbook.
2. The source project does not move to the plugin. It keeps its own rule files. When its retro produces a
   generic fix, the process session copies the fix to the plugin as a pull request.
3. The Flutter app ships to iOS, Android, and the web. Agent runs use a different Mac from the source project.
   On that Mac, agents can use the iOS simulator, the Android emulator, and Chrome.
4. Several developers use the plugin, each with their own Claude Code. Rules live in files that git
   tracks. Personal habits stay in each person's user settings.
5. The team owns rule changes. A rule change is a pull request to the plugin repository, and the team
   reviews it.
6. The ticket tracker is the team's own tool. The project file describes the tracker steps in plain words,
   so that any tracker works.
7. The plugin is one plugin with platform folders inside it, not one plugin for each platform.
8. The plugin ships an optional lean writing mode.
9. A project can keep its specs, plans, ledgers, and retros out of the repository.

## Layout

The plugin repository holds these parts:

- `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, so that the repository is also a
  marketplace that a team adds one time.
- `commands/feature.md`: the pipeline. The steps are brainstorm, spec, spec review, plan, plan review,
  gate, tasks, final review, ship, and retro. It names no platform and no tracker.
- `agents/implementer.md`, `agents/reviewer.md`, `agents/qa-reviewer.md`. Each agent loads the platform
  skill that the project file names.
- `skills/run-rules/`: the ledger, the cost lines, review findings, evidence habits, and the rules for
  checks.
- `skills/controller/`: dispatch, review seats, plan review, the stall watch, the ship checklist, the
  merge step, and the retro.
- `skills/platform-flutter/`: the Flutter layer. The next section describes it.
- `output-styles/lean.md`: the lean writing mode.
- `hooks`: a start-up pointer, and the retro notice.
- `scripts/`: the ready check, the stall watch, the mutation runner, and the device claim, each with
  its self-test.
- `lessons.md`: the reason for each rule, as short lessons with no project names.

A session loads a skill at the step that needs it. The start-up hook gives only a short pointer that
says which skill to load at which step. On the source project, the always-loaded rules cost about 12,000 tokens in
each session and each helper, and copies loaded again after each compaction. The plugin avoids that
cost by design.

## The project file

Each project adds `.claude/agentic-delivery.md`, which git tracks. It holds these fields:

- `platform`: `flutter` for the first target.
- `min_plugin_version`: the lowest plugin version that the project needs. A session on an older version
  gets a warning at start.
- Branches: the base branch for features, the release branch, and the merge method.
- Gate: who approves a plan. The default is the developer who runs the feature.
- Tracker steps: how to start a ticket, post a comment, and close it. If agents cannot reach the
  tracker, the run writes the comment text into its report, and the developer posts it.
- Documents: `repo` or `private`. With `private`, specs, plans, ledgers, and retros go to a folder
  beside the repository, not inside it, because a folder that git ignores does not appear in a new
  worktree. Every worktree reaches that folder by its full path. The ready check reads the ledger from
  the place that this field names.
- Devices: the simulator, emulator, and browser to test on, by id.
- Accounts: the test account, the host it reaches, and what the run can do with it.
- Ask-first areas: the files and actions that need the developer's word, for example signing, secrets,
  and a new dependency.

## The Flutter layer

The skill `platform-flutter` holds these rules:

- Test tiers, cheapest first: unit tests, widget tests, golden tests, and integration tests on a device.
  A golden test compares a widget with a saved reference image. A fact that a widget test can prove
  does not go to a device.
- Devices: each ticket creates its own iOS simulator and Android emulator and deletes them at the end.
  Chrome serves the web target. The device claim script holds each device for one worktree. Commands
  pass a device by id, never by name.
- Commands: analyze, unit and widget tests, the golden update switch, and integration tests on a
  device. Each command writes to a log file, and the stall watch reads those logs.
- Screenshots: capture only after two frames match, on each device kind.
- Release checks: build release mode for each target. A debug build does not stand for a release build.

The exact commands and flags come from the Flutter documentation and from a run on the Flutter Mac.
This spec does not state them from memory.

## The lean writing mode

`output-styles/lean.md` is optional, and each developer turns it on for themselves. It holds short
rules in the plugin's own words: plain sentence rules in the spirit of Simple English, and the
anti-filler rules that unslop checks for. The rules shape the first draft. No step runs a second pass
over the text, because on the source project a second pass cost more than it saved. Nobody measured a token saving
for this mode yet, so the plugin does not claim one.

## How a team uses it

1. A developer runs the feature command in a session at the project root.
2. The developer approves the plan. That is the one gate for the feature.
3. The run writes its ledger, its cost lines, and its retro to the place that the project file names.
4. A retro item that changes a rule becomes a pull request to the plugin repository.
5. The team reviews the pull request, merges it, and raises the plugin version.

## How the plugin is built

1. Sort each rule of the source project's files into one of three places: the core, the iOS layer, or a
   project fact. Only the core goes into the plugin.
2. Write each core rule with its reason, but without the source project's names, dates, or devices.
3. Port the scripts without iOS paths, together with their self-tests.
4. Write the Flutter layer from the documentation, then run each command on the Flutter Mac.

The source project keeps its own files. The plugin never edits them.

## How the plugin is tested

1. The plugin installs and loads cleanly in a new session.
2. Each script passes its self-test, including a run against a copy that is broken on purpose.
3. One small feature on the Flutter project runs as a pilot. Its retro compares the cost with the
   estimate and lists what the plugin missed. The pilot runs on the Flutter Mac.

## Out of scope

- A backend layer and a product-process layer.
- An iOS layer for the plugin, because the source project keeps its own files.

## Open items

- The plugin name. "agentic-delivery" is a working name.
- Whether Flutter is installed on the source project's Mac. Nobody checked. The pilot does not depend on it.
