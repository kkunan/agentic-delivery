# What is inside

This page lists the parts of the plugin, what each one costs in tokens, and the state of each platform layer.

```text
commands/feature.md      the pipeline, started with /feature
agents/                  implementer, reviewer, qa-reviewer, kmp-implementer, kmp-reviewer
skills/run-rules/        the rules that every agent follows
skills/controller/       the rules for the session that runs the pipeline
skills/product-owner/    the rules for an optional Product Owner session
skills/platform-*/       one platform layer in each folder: flutter, ios, go, node, kmp
templates/               the project file template
hooks/                   the start-up pointer and the retro reminder
output-styles/lean.md    the optional lean output style
lessons.md               the story behind each rule
docs/superpowers/specs/  the design of the plugin
docs/superpowers/plans/  the plan that builds it
scripts/                 ready check, stall watch, device claim, screenshot settle, mutation runner
tests/                   a test file for each script
```

## Skills, command, and agents

| Name | What it is | When it loads |
| --- | --- | --- |
| `/feature` (listed as `agentic-delivery:feature`) | The command that runs the pipeline | You run it |
| `agentic-delivery:controller` | The rules that only the controller follows: dispatch, review seats, estimates, stall watch, tracker steps, ship, merge, report, and retro | Step 0 of `/feature`, and again after a compaction |
| `agentic-delivery:run-rules` | The rules that every agent follows | Step 0 of `/feature`, and at the start of every dispatched task and review |
| `agentic-delivery:product-owner` | The rules for an optional Product Owner session: ready ticket, grooming, sprint planning, and replan | The Product Owner session loads it at start, and again after a compaction |
| `agentic-delivery:product-manager` | The optional Product Manager scope: decision memos, evidence, and privacy | With `po_scope: product`, the Product Owner session loads it after `product-owner` |
| `platform-flutter` | The Flutter layer, with the commands for build and test | For a project with `platform: flutter`, step 0 of `/feature` loads it after the two above. Its commands were measured on Flutter 3.38.9 stable |
| `platform-ios` | The iOS layer, SwiftUI first with UIKit notes | For a project with `platform: ios`, step 0 of `/feature` loads it after the two above. A CI job runs its commands on Xcode 16.4 |
| `platform-go` | The Go layer, for services with an HTTP API | For a project with `platform: go`, step 0 of `/feature` loads it after the two above. A CI job runs its commands on a real Go toolchain |
| `platform-node` | The Node layer, for TypeScript services and for Next.js or React web apps | For a project with `platform: node`, step 0 of `/feature` loads it after the two above. Its commands were measured on four real tickets |
| `platform-kmp` | The Kotlin Multiplatform layer, for shared Kotlin code, Compose Multiplatform apps, and Ktor servers | For a project with `platform: kmp`, step 0 of `/feature` loads it after the two above. Its commands were measured on a sample project. Not measured: the stall watch with KMP, the runner and the `--tests` filter on the Android host and Wasm tasks, and the Chrome fallbacks. The skill lists the rest. |

The plugin also has five agents. The project file names the one for each seat, and the defaults
are these:

- `agentic-delivery:implementer` does one coding task from a brief.
- `agentic-delivery:reviewer` reviews the diff of one task, and the plan.
- `agentic-delivery:qa-reviewer` judges a spec or a plan for testability.

The other two agents are not defaults. A KMP project selects them with `implementer_agent` and
`reviewer_agent`. `agentic-delivery:kmp-implementer` does one coding task in a Kotlin Multiplatform
project, and `agentic-delivery:kmp-reviewer` reviews the diff of one task there.

To use an agent of your team for a seat, set `implementer_agent`, `reviewer_agent`, or `qa_agent`
in the project file. A name that does not exist stops the run, with no fallback.

## Hooks

The plugin has two hooks. Each one adds a short text to the session:

- At the start of a session, a hook adds a pointer to `/feature`. It does so for a project that has
  the project file. It names the skills that the first step loads, and the folder of the plugin
  scripts.
- After a write to a retro file, a hook adds a reminder. The agent must not edit plugin files. It
  proposes each change as a pull request.

## Scripts and tests

The scripts are in `scripts/`. Each one has a test in `tests/`.

- `project-config.sh` reads one key from the front matter of the project file.
- `claim-device.sh` claims a device for one worktree, so that two runs never use the same one, and
  releases it.
- `stall-watch.sh` watches the worktrees, the test processes, and the command logs of a run, and
  reports a stall.
- `ready-check.sh` checks the pull request and the ledger. It says whether the pull request is ready.
  It works with a GitHub pull request through `gh` and with a GitLab merge request through `glab`.
- `settle-screenshot.swift` runs a capture command until the screen stops changing, then saves the
  last frame.
- `push-screenshots.sh` adds a folder of screenshots to the screenshot branch in one new commit on
  the remote tip. It never forces a push. It refuses an empty commit id and a folder that already
  exists.
- `mutate.sh` applies each mutation from a manifest, runs the test that must catch it, records the
  verdict, and restores the file. A platform runner runs the tests. The Flutter runner is
  `skills/platform-flutter/mutation-runner.sh`, and the iOS runner is
  `skills/platform-ios/mutation-runner.sh`.

## Lean mode

The plugin ships an optional output style named `lean`, in `output-styles/lean.md`. It asks for
short replies: the answer first, no filler, one word for one meaning. Each developer turns it on for
themselves, through the output style setting of Claude Code. No step of the pipeline needs it.

Nobody measured a token saving for this mode, so the plugin makes no claim of one.

## Token cost

The figures come from `claude plugin details agentic-delivery`, run on plugin version 0.1.0 after a
local install. That run was before the platform skills existed, so the figures do not include them.
The tool says that its counts are estimates.

- Always on: about 250 tokens in every session, as measured before the platform skills existed.
  This is the name and description of each skill and agent.
- Paid on invoke, each time the item fires:

| Item | Always on | On invoke |
| --- | --- | --- |
| `run-rules` | about 40 | about 6.3k |
| `controller` | about 60 | about 8.6k |
| `reviewer` | about 40 | about 1.3k |
| `qa-reviewer` | about 50 | about 1.3k |
| `implementer` | about 40 | about 1.6k |
| `feature` | about 30 | about 1.7k |

Step 0 of `/feature` loads one platform skill, so each run pays its size on top of the table. By
`wc -c`, the `platform-flutter` skill is 31,357 characters long, the `platform-ios` skill is
25,420 characters long, and the `platform-kmp` skill is 52,031 characters long. Nobody measured any of
them with `claude plugin details`. The name and
description of each one also add to the always-on figure.

The tool does not count hook output. The start-up hook adds its pointer to a session in a project
that has the project file. With `platform: flutter`, the pointer is 326 characters long, plus the
length of the path of the plugin folder. If the `platform` key is empty, the pointer only says
that the project file has no platform and that `/feature` asks for each empty key.

## Platforms

The core works with any project: the pipeline, the rules, the ledger, the reviews, and the retro do
not depend on a platform. A platform layer adds the commands to build, test, run devices, and take
screenshots. Without a layer, the agents have the rules but no platform commands.

| Platform | Targets | Status |
|---|---|---|
| Flutter | iOS, Android, web | Written. Two runs on Flutter 3.38.9 stable measured its commands. It has the mutation runner. |
| Native iOS | iOS, SwiftUI first, with UIKit notes | Rules written. It has the mutation runner. A CI job runs its commands and the runner against a sample app on Xcode 16.4. No real feature used it yet. |
| Native Android | Android | Not started |
| Go | Services with an HTTP API | Rules written. It has the mutation runner. A CI job runs its commands and the runner on a real Go toolchain. No real feature used it yet. |
| Node | TypeScript services such as NestJS, and Next.js or React web apps | Written from real runs on four tickets in October 2026, which measured its commands. It has the mutation runner. No CI job runs it yet. |
| Kotlin Multiplatform | Shared Kotlin code, Compose Multiplatform apps on Wasm, Android, and iOS, and Ktor servers | Rules written. A sample app measured its commands on one Mac on 2026-10-25: the JVM, Android host, iOS simulator, and Wasm browser tests, the Wasm screen by pixels, and the Android emulator and iOS simulator screens. The mutation runner ran on real Gradle for the JVM, server, and iOS test tasks. Fixture tests cover the iOS and Wasm tasks. No CI job runs it, and no real project used it yet. |
| Other web front ends | Browsers | Not started |

A platform layer is one skill in `skills/platform-<name>/`. To add one, follow the shape of the
Flutter layer, and propose it as a pull request.

## Status and releases

The Flutter layer is written, and two runs on Flutter 3.38.9 stable measured its commands. The iOS
layer comes from a native iOS project that ran more than 30 tickets through earlier versions of this
workflow and its scripts. A CI job runs the layer's commands and its mutation runner on Xcode 16.4
against a sample app. It runs on each pull request that changes the iOS layer or a script that the
job runs. The rest of the plugin is in place and has tests. The maintainer runs features through
the plugin every day on Flutter work, and also ran Node and React tasks with it. No whole team has run a pilot yet.

Each version gets a tag, such as `v0.8.0`, for a team to pin. On each push to `main`, the workflow
`tag-release.yml` reads the version in `.claude-plugin/plugin.json`. If the tag does not exist, the
workflow creates it. It never moves a tag that exists.
