# Agentic Delivery

A Claude Code plugin for a spec-driven feature pipeline. It has one plan gate, reviewed tasks, a ledger, and a retro. Platform layers hold the build and test rules for each kind of project.

The core is ready. The Flutter layer is the skill `platform-flutter`. Two runs on Flutter 3.38.9 stable measured its commands. The skill also holds the Flutter runner for `scripts/mutate.sh`.

## What it does

A developer runs `/feature` with a short description of the feature. The plugin then works through these stages:

1. Brainstorm the feature with the developer and write a spec.
2. Open a branch and a draft pull request.
3. Review the spec with two seats, a reviewer and a QA agent.
4. Write a plan and review it.
5. Stop at the one gate. The developer approves the plan.
6. Run the plan task by task. Each task has a coding agent and a review.
7. Run the ship checklist, mark the pull request ready, and hand off.
8. Write a retro, then wait for the word to merge.

The design is in `docs/superpowers/specs/`.

## Install

Add the repository as a marketplace, then install the plugin from it:

```
claude plugin marketplace add <path or GitHub repo>
claude plugin install agentic-delivery@agentic-delivery
```

For the first command, give a path to a local clone, or the GitHub form `kkunan/agentic-delivery`. The option `--scope local`, `--scope project`, or `--scope user` on each command picks where Claude Code stores the setting: your own local settings for this project, the settings file that the team shares in the repository, or your settings for every project.

Run `claude plugin list` to check that `agentic-delivery` shows as enabled.

## The project file

Each project that uses the plugin has a file at `.claude/agentic-delivery.md`. It holds the facts of that project. These are the platform, the branch names, and the folders for the ledger and the retro. They also include the screen patterns, the test processes, and the agent for each seat. The plugin never guesses these values.

To start, copy `templates/agentic-delivery.md` from the plugin to `.claude/agentic-delivery.md` in your repository. The template explains each key. It also has sections for the tracker steps, the devices, and the accounts. A last section lists the areas that need a word from the gate owner. Fill them in for your team. Write the place to find a sign-in, never the sign-in itself, and no device ids.

The plugin reads the front matter with `scripts/project-config.sh`. If the file is missing, `/feature` stops and offers to copy the template.

## Skills, command, and agents

| Name | What it is | When it loads |
| --- | --- | --- |
| `/feature` (listed as `agentic-delivery:feature`) | The command that runs the pipeline | You run it |
| `agentic-delivery:controller` | The rules that only the controller follows: dispatch, review seats, estimates, stall watch, tracker steps, ship, merge, report, and retro | Step 0 of `/feature`, and again after a compaction |
| `agentic-delivery:run-rules` | The rules that every agent follows | Step 0 of `/feature`, and at the start of every dispatched task and review |
| `platform-flutter` | The Flutter layer, with the commands for build and test | Step 0 of `/feature`, after the two above. Its commands were measured on Flutter 3.38.9 stable |

The plugin also has three agents. The project file names the one for each seat, and the defaults are these:

- `agentic-delivery:implementer` does one coding task from a brief.
- `agentic-delivery:reviewer` reviews the diff of one task, and the plan.
- `agentic-delivery:qa-reviewer` judges a spec or a plan for testability.

To use an agent of your team for a seat, set `implementer_agent`, `reviewer_agent`, or `qa_agent` in the project file. A name that does not exist stops the run, with no fallback.

## Hooks

The plugin has two hooks. Each one adds a short text to the session:

- At the start of a session, a hook adds a pointer to `/feature`. It does so for a project that has the project file. It names the skills that the first step loads.
- After a write to a retro file, a hook adds a reminder. The agent must not edit plugin files. It proposes each change as a pull request.

## Scripts and tests

The scripts are in `scripts/`. Each one has a test in `tests/`.

- `project-config.sh` reads one key from the front matter of the project file.
- `claim-device.sh` claims a device for one worktree, so that two runs never use the same one, and releases it.
- `stall-watch.sh` watches the worktrees and the test processes of a run, and reports a stall.
- `ready-check.sh` checks the pull request and the ledger. It says whether the pull request is ready.
- `settle-screenshot.swift` runs a capture command until the screen stops changing, then saves the last frame.
- `mutate.sh` applies each mutation from a manifest, runs the test that must catch it, records the verdict, and restores the file.

Run `bash tests/run-all.sh` to run every test.

## Lean mode

The plugin ships an optional output style named `lean`, in `output-styles/lean.md`. It asks for short replies: the answer first, no filler, one word for one meaning. Each developer turns it on for themselves, through the output style setting of Claude Code. No step of the pipeline needs it.

Nobody measured a token saving for this mode, so the plugin makes no claim of one.

## Token cost

The figure comes from `claude plugin details agentic-delivery`, run on plugin version 0.1.0 after a local install. The tool says that its counts are estimates.

- Always on: about 250 tokens in every session. This is the name and description of each skill and agent.
- Paid on invoke, each time the item fires:

| Item | Always on | On invoke |
| --- | --- | --- |
| `run-rules` | about 40 | about 6.3k |
| `controller` | about 60 | about 8.6k |
| `reviewer` | about 40 | about 1.3k |
| `qa-reviewer` | about 50 | about 1.3k |
| `implementer` | about 40 | about 1.6k |
| `feature` | about 30 | about 1.7k |

The tool does not count hook output. The start-up hook adds its pointer, which is 226 characters long, to a session in a project that has the project file.

## Status

The Flutter layer is the part that is not finished. The rest of the plugin is in place and has tests.
