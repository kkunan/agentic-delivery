---
platform: flutter
min_plugin_version: 0.1.0
base_branch: develop
release_branch: main
branch_prefix: feature/
protected_branches: main,develop
docs: repo
docs_dir: docs/features
view_globs: lib/**/views/**,lib/**/widgets/**
test_processes: flutter_tester,dart
screenshot_branch: screenshots
implementer_agent: agentic-delivery:implementer
reviewer_agent: agentic-delivery:reviewer
qa_agent: agentic-delivery:qa-reviewer
---
# Agentic delivery project file

Copy this file to `.claude/agentic-delivery.md` in your repository. The lines between the two `---` lines at the top are the front matter. Each line is a plain `key: value` pair. Do not use quotes, YAML lists, or comments in the front matter. A list is plain text with commas, for example `main,develop`. The text below the front matter is for people and for the controller. The scripts of the plugin ignore it.

## Keys

- `platform` names the platform skill. The value `flutter` loads the skill `platform-flutter`.
- `min_plugin_version` is the oldest plugin version that this project accepts.
- `base_branch` is the branch that each feature branch starts from and merges into. The run merges through the pull request, as a merge commit. There is no key for the merge method.
- `release_branch` is the branch that holds the released code. Releases come from this branch.
- `branch_prefix` starts the name of each feature branch.
- `protected_branches` lists the branches that no run can push to or commit on.
- `docs` is `repo` or `private`. The value `repo` keeps the ledger folder inside the repository. The value `private` keeps it outside the repository, so that the notes of a run stay off the history. A `private` project needs an absolute `docs_dir` beside the repository.
- `docs_dir` is the folder for the ledger and the retro. The ledger folder is `<docs_dir>/<date>-<slug>` in both `docs` modes. A relative `docs_dir` resolves from the top of the repository.
- `view_globs` lists the file patterns for the screens of the app. A change to a file that matches them needs a screenshot.
- `test_processes` lists the names of the processes that the tests start. The stall watch uses them. The value in this file is a placeholder for Flutter. Replace it with the names that you measure on your machine.
- `screenshot_branch` is the branch that holds the screenshots for the review.
- `implementer_agent`, `reviewer_agent`, and `qa_agent` name the agent for each seat. See the Agents section.

## Tracker steps

Say how the ticket tracker works for your team. Fill in the status that a ticket gets at each stage. The stages are work start, plan wait for the gate owner, review start, and done. Say who owns the gate and where the controller posts the plan and the result.

## Devices

Say which devices and simulators the team uses for the tests on screen. Fill in the name of each one and how to start it. Say how a run claims a device, so that two runs never use the same one. Do not write device ids or addresses that belong to one person.

## Accounts

Say which test accounts a run can use and where their sign-in details live. Write the place to find them, never the details themselves. Say which accounts a run must never use.

## Ask-first areas

List the parts of the code and the actions that need a word from the gate owner before a run touches them. Examples are payment code, data migrations, release settings, and changes to the build pipeline. Fill in the paths and the reason for each one.

## Agents

By default each seat uses the agent of this plugin. Claude Code lists a plugin agent as `<plugin>:<agent>`, so the defaults are `agentic-delivery:implementer`, `agentic-delivery:reviewer`, and `agentic-delivery:qa-reviewer`. To use an agent of your team for a seat, put its name in `implementer_agent`, `reviewer_agent`, or `qa_agent`. For example, name an agent from a file in the `.claude/agents/` folder of the project by its `name` line. A key that names a missing agent stops the run at its first dispatch and names the key. There is no fallback to another agent. The brief still makes that agent load the run rules and the platform skill. So an agent of your team gets the same rules as the default one. Write here what each custom agent is for and why the team chose it.
