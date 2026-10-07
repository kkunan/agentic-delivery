---
platform:
min_plugin_version: 0.1.1
base_branch:
release_branch:
branch_prefix:
protected_branches:
docs:
docs_dir:
view_globs:
test_processes: flutter_tester,dartvm,xcodebuild,java
screenshot_branch:
forge:
tracker:
mutation_runner: scripts/mutation-runner.sh
implementer_agent: agentic-delivery:implementer
reviewer_agent: agentic-delivery:reviewer
qa_agent: agentic-delivery:qa-reviewer
---
# Agentic delivery project file

Copy this file to `.claude/agentic-delivery.md` in your repository. The lines between the two `---` lines at the top are the front matter. Each line is a plain `key: value` pair. Do not use quotes, YAML lists, or comments in the front matter. A list is plain text with commas, for example `main,develop`. The text below the front matter is for people and for the controller. The scripts of the plugin ignore it.

## Keys

- Ten keys have no value in this file, because each team makes its own choice: `platform`, the four branch keys, `docs`, `docs_dir`, `view_globs`, `screenshot_branch`, and `tracker`. Fill in all ten before the first run. If one is empty, the feature command asks you for it and does not start. The ready check also stops and names the key. On GitLab, `screenshot_branch` may stay empty, as the `screenshot_branch` key says.
- `platform` names the platform skill. The value `flutter` loads the skill `platform-flutter`, and the value `ios` loads the skill `platform-ios`. The value of `test_processes` in this file is for Flutter. For an iOS project, also add the keys `ios_workspace`, `ios_scheme`, `ios_test_plan`, and `ios_runtime`. The skill `platform-ios` explains each one, and says what `test_processes` and `view_globs` hold for iOS.
- `min_plugin_version` is the oldest plugin version that this project accepts.
- `base_branch` is the branch that each feature branch starts from and merges into, for example `main` or `develop`. The run merges through the pull request, as a merge commit. There is no key for the merge method.
- `release_branch` is the branch that holds the released code, for example `main`. Releases come from this branch. If your team releases from the base branch, give the same name twice.
- `branch_prefix` starts the name of each feature branch, for example `feature/`.
- `protected_branches` lists the branches that no run can push to or commit on, for example `main` or `main,develop`. List the base branch and the release branch at least.
- `docs` is `repo` or `private`. It decides whether the specs, the plans, the ledgers, and the retros of a run go into your repository. With `repo`, the run commits them with the code. With `private`, they stay in a folder outside the repository, and the run never commits or pushes them. If you do not want these documents in your repository, choose `private`.
- `docs_dir` is the folder for the specs, the plans, the ledgers, and the retros. With `repo`, give a folder in the repository, for example `docs/features`. With `private`, give a folder outside it, as an absolute path or a path that starts with `~/`, for example `~/agentic-notes/<project>`. A path that starts with `~/` works for every developer, so one shared project file is enough. The ledger folder is `<docs_dir>/<date>-<slug>` in both `docs` modes. A relative `docs_dir` resolves from the top of the repository.
- `view_globs` lists the file patterns for the screens of the app, for example `lib/views/**,lib/**/views/**,lib/**/widgets/**` for a Flutter app. A change to a file that matches them needs a screenshot. The ready check matches each pattern as a shell `case` pattern, and it ignores spaces around each comma. In a `case` pattern, `**` matches the same text as `*`, so the slashes around it still need a folder between them. Thus `lib/**/views/**` does not match `lib/views/x`. To match both, use `lib/views/**,lib/**/views/**`.
- `test_processes` lists the names of the processes that the tests start. The stall watch uses them. The value in this file holds the names that `pgrep -x` matched on Flutter 3.38.9 stable. `flutter_tester` runs the unit and widget tests, and `dartvm` runs the `flutter` tool. `xcodebuild` runs an iOS device build, and `java` runs the Gradle build of an Android device run. The processor time of `java` alone does not show a hung Gradle build. Idle Gradle and Kotlin daemons keep adding processor time, so also check that the build log still grows. `pgrep -x java` also matches other Java programs, for example the Gradle daemon of an editor. So read the command of the process before you report a freeze. The section "A stalled test run" of the `platform-flutter` skill gives the detail. Measure the names again on your machine.
- `screenshot_branch` is the branch that holds the screenshots for the review, for example `screenshots`. The run never deletes it. On GitLab, the run can instead upload each image to the merge request description, and GitLab stores it as a link that contains `/uploads/<hash>/`. The ready check accepts either form on GitLab. So on GitLab you may leave `screenshot_branch` empty, and then the run uploads every screenshot.
- `forge` is `github` or `gitlab`. It names the host of the pull request. GitLab calls it a merge request. The ready check reads the request through `gh` for GitHub and through `glab` for GitLab, so install the matching tool and sign in. If `forge` is empty, the ready check reads the host of the `origin` remote. A host with `gitlab` in its name gives `gitlab`, and any other host gives `github`. Fill in the key for a GitLab server whose host has no `gitlab` in its name.
- `tracker` names the ticket tracker: `jira`, `linear`, `github`, `gitlab`, or `none`. With `github` or `gitlab`, the tickets are the issues of the forge. The run never assumes Jira. With `none`, the run skips every tracker step. The skill `controller`, section Tracker and pull request, says how the run moves a ticket in each tracker.
- `mutation_runner` is the path from the top of the repository to an executable that follows the runner contract of `scripts/mutate.sh`. The Flutter adapter of the plugin is `skills/platform-flutter/mutation-runner.sh`, and the iOS adapter is `skills/platform-ios/mutation-runner.sh`. The path of a plugin install differs on each machine. So copy the file for your platform to `scripts/mutation-runner.sh` in your repository, which is the value in this file, and commit it.
- `implementer_agent`, `reviewer_agent`, and `qa_agent` name the agent for each seat. See the Agents section.

## Tracker steps

Say how the ticket tracker that `tracker` names works for your team. Fill in the status that a ticket gets at each stage. The stages are work start, plan wait for the gate owner, review start, and done. Say who owns the gate and where the controller posts the plan and the result. On GitHub, say whether the status is a field of a GitHub project, and name the project and the field, or whether it is a label. On GitLab, say whether the status is a scoped label, such as `workflow::in progress`, or the Status field of the issue. On GitHub and GitLab, also say whether the team closes the issue when the pull request merges. By default, the run links the issue without a closing keyword.

## Devices

Say which device kinds the tests use, and the base image of each kind: the simulator runtime, the emulator system image, and Chrome. Each ticket creates its own simulator and emulator from these images, and deletes them at the end. The ids of the devices that one ticket creates go in the ledger of that ticket, not in this file. Say how a run claims a device, so that two runs never use the same one.

Name each protected device. A protected device holds a signed-in session, and tests must never touch it. If the id of a protected device belongs to one person, put it in local settings and not in this file, which git tracks. Examples of local settings are `.claude/settings.local.json` and a file that git ignores. Then say here where the controller finds that id.

## Accounts

Say which test accounts a run can use and where their sign-in details live. Write the place to find them, never the details themselves. Say which accounts a run must never use.

## Ask-first areas

List the parts of the code and the actions that need a word from the gate owner before a run touches them. Examples are payment code, data migrations, release settings, and changes to the build pipeline. Fill in the paths and the reason for each one.

## Agents

By default each seat uses the agent of this plugin. Claude Code lists a plugin agent as `<plugin>:<agent>`, so the defaults are `agentic-delivery:implementer`, `agentic-delivery:reviewer`, and `agentic-delivery:qa-reviewer`. To use an agent of your team for a seat, put its name in `implementer_agent`, `reviewer_agent`, or `qa_agent`. For example, name an agent from a file in the `.claude/agents/` folder of the project by its `name` line. A key that names a missing agent stops the run at its first dispatch and names the key. There is no fallback to another agent. The brief still makes that agent load the run rules and the platform skill. So an agent of your team gets the same rules as the default one. Write here what each custom agent is for and why the team chose it.

Optionally, name a process owner here, as a session or a person. The process owner decides each process change and triages the action items of each retro. If you name none, the gate owner decides. The `controller` skill, section Process fixes, gives the rule.
