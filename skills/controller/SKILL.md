---
name: controller
description: The rules that only the controller of an agentic-delivery run follows, covering dispatch, review seats, estimates, stall watch, tracker steps, ship, merge, report, and retro. Load before a run starts and again after a compaction.
---

# Controller rules

The controller is the session that dispatches agents and coordinates the run. A dispatched agent does not read this skill. The rules for every agent are in the `run-rules` skill, which also defines the terms that this skill uses.

The project file is `.claude/agentic-delivery.md` in the repository of the user. Its front matter holds the keys `platform`, `min_plugin_version`, `base_branch`, `release_branch`, `branch_prefix`, and `protected_branches`. It also holds `docs`, `docs_dir`, `view_globs`, `test_processes`, `screenshot_branch`, `forge`, `tracker`, `push_policy`, `comment_prefix`, and `mutation_runner`. The last keys are `implementer_agent`, `reviewer_agent`, and `qa_agent`. Its body holds the sections Tracker steps, Devices, Accounts, Ask-first areas, and Agents. It can also hold the optional section Docs publishing. Read the whole file before the run starts. The ledger folder is `<docs_dir>/<date>-<slug>/`.

Where a rule here says "the gate owner", it means the person who approves the plan and who says merge.

## Size decides the process

The size of the ticket, as the section Estimates defines it, picks the path:

- XS and S run in lite mode by default. One session works from a short brief, with no spec, no plan, and no implementer, and one final review. The section Lite mode gives the conditions.
- M gets one short document that holds the spec and the plan, and one review of that document. Planning takes about 10% of the token budget. Tasks get no separate review, except a task that touches a server contract or pattern-matching code. That task gets a focused review. The section The M document and its review gives the method.
- Every ticket gets one final review of the whole branch.
- Split anything larger than M before it starts. Slice it by what a user sees, so that each part ships on its own.

The gate owner can name a different path for one ticket. Write the path and its reason in the brief or the document header. (lesson: planning-share)

## Dispatch

### Parallel work

Always look for work that can run in parallel. Run it in parallel unless that adds risk. At every dispatch point, ask what else can be in progress. This covers implementers, reviews, research, and verification, not only plan tasks.

Risk is a veto, not a cost to trade against speed. Do not parallelize in these cases:

- Two tasks touch the same file.
- One task uses an interface that another task produces.
- The pre-flight scan cannot show that the regions are disjoint.

Uncertainty counts as risk. If you cannot tell whether two tasks collide, run them in sequence and record that decision. Never split a task or change the order of a plan only to make work parallel.

Give each parallel implementer its own git worktree. Separate build folders in a shared checkout do not help, because a build compiles the whole app and test target. With test-driven work, each implementer spends part of its run with a tree that does not compile. The worktree is part of the dispatch, not an escalation after the first failure.

### Worktrees, plans, and briefs

Create every worktree under `.worktrees/` in the project root. Do not link or copy instruction files into a worktree. Claude Code loads instruction files from the start folder and from each folder above it. A link loads the same file a second time and costs context on every load. A worktree outside the project folder gets no instruction files, so do not start a session or dispatch a run there.

In plans and briefs, cite a rule. Do not transcribe it. A constraints block that quotes a rule file is a second source of truth, and every brief cut from that plan inherits the copy. Name the file and the rule, and let the implementer read the current text. If a brief needs the words inline, quote them and name the commit of the file.

Name each helper's report after its task, for example `task-3-report.md`, and never `report.md`. Claude Code refuses a helper's write to a file named exactly `report.md`.

Between notifications, examine `git status` and `git diff` in each worktree. Do not trust the reports alone.

Every brief and every resume message that builds or tests names the device by its id. The ledger holds the id of each device that the ticket creates. The words "the same device" never stand alone, because a resumed agent cannot tell which device you mean.

Before the first step of the run that uses a device, read the local file `.claude/agentic-delivery.local.md` in the project root. Git ignores this file, so it is not in a worktree. Each line holds the id or the name of one protected device of this developer. These devices are protected in the same way as the protected devices that the Devices section of the project file names. If the file is missing, ask the developer which devices hold a signed-in session. Write the answer into the file only after the developer agrees. An empty file means that this developer has no protected device. Never copy the ids from the local file into a file that git tracks.

A check that compares the base against the head takes its base half in Task 0. Take it from the worktree of the run, before the first task commit. Never take it from a second worktree, because the device claim refuses a second worktree on the device that the run holds.

When a plan injects a seam that has a production default, the task names one test that uses the default. The tests of the fake do not cover the default.

### Agent types for dispatch

Dispatch the agents of this plugin, not `general-purpose`. This overrides any template that hardcodes the agent type. Where a template names a subagent type, use the agent from this table instead:

| Dispatch point | Agent | Project file key |
|---|---|---|
| Implementer, one per task of an M ticket | `implementer` | `implementer_agent` |
| Review of the M document, before the gate | `reviewer` | `reviewer_agent` |
| Focused task review, server contract or pattern-matching code | `reviewer` | `reviewer_agent` |
| Scoped re-review after a fix | `reviewer` | `reviewer_agent` |
| Final whole-branch review | `reviewer` | `reviewer_agent` |
| Second seat that a document header names | `qa-reviewer` | `qa_agent` |

The project file can name a team's own agent for each seat with the keys in the last column. Each key defaults to the plugin's agent. Three rules apply to every dispatch:

- Every brief tells the agent to load the `run-rules` skill and the skill `platform-<platform>`, because a custom agent does not load them by itself.
- If the named agent does not exist, the run stops and names the key. It never falls back to the default, because a silent fallback hides that the team's rules did not apply.
- The prompt body of each template still applies in full.

The type `general-purpose` stays correct for work that is not engineering, such as research, documents, and tidying.

Do not pass a model override on these dispatches. A model passed at dispatch overrides the model in the agent file. Pass a model only for a task that you decided needs a stronger model, and record that decision in the ledger.

## Review seats

An M ticket gets one review before the gate: one `reviewer` seat over the M document. Brief the QA questions onto that seat: can each acceptance criterion fail, and can each manual check fail? If the document changes a screen, also brief the skills `design-critique` and `accessibility-review` onto it, against the design documents of the project. XS and S tickets get no review before the gate. Every ticket gets one final review of the whole branch.

A seat earns its place with knowledge that the other seats do not have, never with a different attitude. Reviewers that differ only in attitude share a knowledge base. Each one misses part of what a single reviewer with the union of their prompts finds, and together they cost more. Do not add a reviewer to be more careful. If a ticket needs a second seat, name it and its reason in the document header, beside the estimate. The seat is part of the estimate. An example is `qa-reviewer` on a server contract. A product seat does not qualify, because the gate owner writes the brainstorm and reads the document. (lesson: seats-by-knowledge)

### Rulings and fix briefs

Apply the same rubric to your own rulings. Before dispatch, examine each ruling that adds or changes a test. Name a change to production code that makes this assertion fail. If no such change exists, the assertion is decoration, so do not add it.

Material written after the gate carries its failing input, and the re-review runs it. If a fix brief or a ruling adds a check, a figure, or a premise, write the failing input beside it. Include the output measured on that input. The scoped re-review runs that input before it marks the item addressed. Nobody else reviews material that the controller writes after the gate.

Before you rule that a new mechanism replaces an old one, read the callers. Search every call site, and read every test that exercises the mechanism. If a brief pins a test byte-identical, it pins the mechanism of that test too. The ruling then becomes "add the new mechanism", not "replace the old one".

An observation from an implementer outranks the memory of the controller. Never answer an environment question from an agent with an unverified mechanism. Either examine the mechanism, or say "unverified, work around it".

If a dispatched agent returns idle two times, terminate it, but only when the stall watch also reports its worktree idle or its build frozen. An agent whose own build, test, or mutation run still makes progress is not idle, whatever it returns.

When an agent reports that it waits and is not finished, do not dispatch it again and do not wait on it again. Read the verdict from the log yourself. Then finish the work or escalate to a new agent.

A one-line fix is never a known limitation. If you can state the fix of a limitation in one line, do not record it. Give it to the gate owner as a decision. Include the measurement, the proposed value, and the blast radius, so that one word can answer it. This rule does not permit a fix round, because a round costs two seats and every proof that the change runs again.

## The M document and its review

An M ticket has one short document under `docs_dir` that holds the spec and the plan. It states the goal and the design decisions. It gives the tasks with exact signatures and test bodies. It lists the manual checks, each with its value on a correct tree and on the defect. Its header lists each build output folder that the run builds into. Writing and reviewing the document takes about 10% of the token budget of the ticket. If planning passes that share, say so at that time.

A reviewer reviews the document before the gate, in one pass. Its author does not review it alone. Brief the QA questions onto the same seat, as the section Review seats says. The reviewer does these things, and it reports what it ran and what it skipped:

1. Typecheck the code of the document against the platform SDK. Do not build it and do not run the tests. The implementer compiles and runs the code, and a build in the review makes every gate slow.
2. For a task that touches a server contract or pattern-matching code, run each check against the input that its author thinks the check misses. The document carries that input beside the check, written at the same time. If it does not, send the document back. This is the focused review. The costly misses of the source project came from those two kinds of work.
3. Read each check for the case where its inputs are missing. The rule about missing inputs is in the `run-rules` skill. This step is reading only, and it costs nothing.

No review mutates the code by default. For each new test, the implementer still reports one red run and one green run on its own acceptance branch. That proves that the test can fail. A focused task review can run `scripts/mutate.sh` on the branch that the acceptance criteria of its task depend on. In the skills and commands of this plugin, `scripts/...` means the `scripts` folder of the plugin, not a folder of the project. The start-up pointer gives its full path.

Every implementer brief says this: if a test cannot go green with a correct body, stop and report. Never change the test, and never fake the body.

A document with several view tasks ends them with a visual fix task. The rule for visual findings is in the `run-rules` skill, under review findings. The review marks each screen whose visual fixes must stay in their own task, and says why.

The `spec` cost line of an M ticket reads `tokens=0k minutes=0 fix_rounds=0`. The `plan` line holds the writing and the review of the document. The retro copies that line beside the number of fix rounds that the run needed after it.

If the project file names a gate delegate, send the document to the delegate under the rules of the section Delegated gate. Send the document commit and the review result in one message.

## Lite mode

Lite mode is the default for every XS or S ticket, unless the gate owner says otherwise for that ticket. In lite mode, the controller does the work itself from a short brief. It writes no spec and no plan, and it dispatches no implementer.

For lite mode, each of these must be true:

- The ticket is XS or S, as the section Estimates defines.
- The ticket touches no server contract, no request or reply body, and no fixture.
- The ticket writes no pattern-matching code, for example a lint, a parser, a regex, or a guard. The costly misses of the source project came from this kind of code and from server contracts.
- If the ticket changes a screen, the gate owner already approved its design.

If one condition is false, the ticket takes the M path. Write which condition failed in the document header.

The brief replaces the spec and the plan. It states the goal, the files, the tests, the manual checks, and each build output folder that the run builds into. Each check gives its value on a correct tree and on the defect. Write the brief under `docs_dir`, with the ticket key and the estimate in its header. The gate owner approves the brief, and that is the one gate. A gate delegate can approve it under the first four conditions of the section Delegated gate. The fifth condition does not apply, because lite mode has no review before the gate.

After the gate, the controller writes each test before its code. It commits after each step, and it pushes at the times that the section Pushes names. At the end, it dispatches the reviewer agent one time over the whole branch, with one fix wave and one re-review. Then it works the ship checklist, the handoff, the retro, and the merge steps as usual. The ledger starts with the line `mode: lite`, and its cost lines follow the `run-rules` skill, The ledger.

If the work finds a server contract or pattern-matching code partway, stop. Record a ruling, and move the ticket to the M path from step 1 of the feature command. The retro of a lite run compares its total cost with recent full runs of the same size. It also lists each defect that turned up after the merge.

## Estimates

Agree on test data and accounts before execution starts, in the plan header. The Accounts section of the project file is the source. The header states these things:

- The account and environment that QA runs against.
- What QA can create, change, and permanently delete on that account.
- Whether a valid session already exists on the target device. Find out by launching the app.
- Each build output folder that the run builds into. The ship step deletes the ones that it does not use.
- Each step that the permission check of the session will deny. Examples are an edit to a protected file and a test run while a script holds a mutation. Another example is an install on a device that holds a signed-in session. The gate owner allows them all in one message at the gate. If a delegate approves the plan, the controller still sends that one request to the gate owner. A peer cannot grant a permission.

"Requires a fresh sign-in, therefore blocked" is a claim to test, not a fact.

Every spec has an estimate, and the retro reports it against the actual result. Put all four parts in the spec header. When the task list exists, refine them in the plan. Change them only after you say so openly:

- A t-shirt size. XS is one task, S is two or three, M is four to six, L is seven to ten, and XL is more than ten. If you can, split an XL ticket. Give the size at spec time, before the breakdown. If a ticket builds its own proof, count that proof as one task. That applies to a test rig, a lint, or a self-test, because every later change runs it again. If the ticket got a size at sprint planning, that size is the starting size. If the run gives another size, the spec header names both.
- The wall-clock time to done, as a range, from the approval gate to the moment that the pull request is ready.
- A token budget for the whole run, for the controller and the agents together. Build it from seats: one implementer seat for each task, one reviewer seat for each review pass, and the controller. Count every pass: the review of the M document, each focused task review, the whole-branch review, and each re-review. Planning is about 10% of the budget. State how many fix rounds the figure assumes. Count two fix rounds for each proof task, because proof tasks restart on every edit.
- The number of human touches that you expect. Normally that is one, the approval gate. If a feature needs more, say which touches and why at the start.

Use the estimate as a tripwire. When the elapsed time or the tokens pass the estimate, say so without a prompt. Include what is left and the revised figure. Do not wait for the gate owner to ask.

Count tokens for each distinct agent, and use the final cumulative count of each agent. If you add up the completion notices, you count a resumed agent two times. The actual figure for a run is the sum of the cost lines plus the controller. The first few runs are calibration, so record their numbers anyway.

## The stall watch

Arm a stall watch at dispatch, and keep it armed until every agent returns. Task notifications report completion. They cannot report that progress stopped, so an agent blocked on a hung build stays "running" forever. Two problems occur. In the first, a build freezes and its processor time stops. In the second, an agent does nothing at all, and no build watch can see it.

Use `scripts/stall-watch.sh`. Do not write another watch, because hand-written watches usually fail from the start. Arm one watch that takes every name in `test_processes`. With no `--process` flag, the script reads `test_processes` from the project file by itself. You can also pass one `--process` flag for each name. Pass one `--log <path>` flag for each command log of the run:

    scripts/stall-watch.sh --interval 60 --log <log> --log <log>

When a log keeps the same size for `--build-after` minutes, the watch writes one `LOG STALLED <path>` line. It writes the line again only after the log grows and then stops again. The processor total alone does not show a hung Gradle build, because idle build daemons keep adding a little processor time. The log size shows it.

With no `--roots`, the script asks `git worktree list`. If nothing resolves, it refuses to start, so it never polls an empty set and reports all clear. It writes a heartbeat line on every poll. Do not dispatch until you see a heartbeat. If the heartbeat stops, treat that as a stall in the watcher. An unverified watcher is worse than none, because it looks like coverage.

A running watch never gets an edit to the script, because bash parses the whole loop before it runs it. To use a fix, stop the watch and arm it again.

This rule binds the controller, not the agent that runs the test, because only the controller can see across agents.

A stall verdict is a report, never an automatic kill. A process that exists is not proof of progress, and a wedged process also exists. A healthy build can sit with its processor total frozen while it waits on a device. Give the budget 600 seconds or more. When the budget expires, escalate the decision.

## Messages to other sessions

Send a maximum of two messages to any one other session for each task. A reply counts as one. The receiver pays the whole cost. A message takes a turn to read and usually another turn to answer. The test is whether the message changes what the receiver does next. Three things pass that test:

- Work that is about to collide.
- Something of theirs that is already broken.
- An answer that blocks them.

Put everything else in the retro or the ledger.

Batch what is left. Three findings in one message cost one interruption, and three messages cost three. If the question of a peer needs a measurement, run it and send the result one time. A correction to something that you already sent does not count against the limit, because a wrong claim that stays is worse than the interruption. To go over the limit, stop and ask the gate owner first.

## Product Owner messages

This section applies only if the key `po` in the project file names a Product Owner. Send the Product Owner one line after step 9 of the ship checklist: the ticket id, the pull request, and the actual tokens against the estimate. Send it one line at the first overrun, stall, or blocker of the run, when you tell the gate owner: the ticket id, what happened, and the revised estimate. Send the Product Owner no other message. A later overrun goes only to the gate owner. These two lines stay within the limit of the section Messages to other sessions.

## Process fixes

Hold process and tooling fixes until after the retro. Make one change, one time, while nobody is in the middle of a task. A running session gets a change to a shared script or an agent definition only after it stops and loads it. So each change costs every live ticket an interruption and a restart.

The exception is narrow. If a defect is breaking the work of a live session at this time, fix it now. Examples are a watch that ignores the signal that stops it and an agent definition that does not load. A third example is a check that passes in a case where it must fail. Everything else waits, including anything that you find while you measure one of those. The test is not the size of the fix or how sure you are. The test is whether the defect harms a session between now and the retro.

While a fix waits, record it in the action items of the retro. If nobody can find a fix at retro time, it was dropped, not deferred.

You never edit plugin files during a run. A fix to a plugin rule or script becomes an action item that names the plugin file, for a pull request to the plugin repository.

The Agents section of the project file can name a process owner, as a session or a person. The process owner decides each process change and triages the action items of each retro. Another session or person can make the edits after that decision. A decision arrives as a message from the named process owner. If the project file names no process owner, the gate owner decides.

## Pushes

The key `push_policy` in the project file sets the push times of the feature branch. Read it with `scripts/project-config.sh push_policy each-task`, so that a project file without the key gets `each-task`. If the value is not `each-task` or `mr-and-ship`, stop the run and name the key. Each push of the feature branch can start a CI build, and some teams pay for each build. (lesson: build-per-push)

With `each-task`, push the feature branch after each commit.

With `mr-and-ship`, commit after each completed task, and do not push it. Push the feature branch at these times only:

- One time at step 2 of the feature command, where you open the draft pull request.
- One time at ship, after the final fixes and the final ledger entry. Step 4 of the ship checklist gives the place.
- After the pull request is ready, one time for each fix wave that a review needs. Collect all the fixes of the wave first, and push them together.

Before any other push of the feature branch, ask the gate owner. Never push only to make sure that a commit is safe. A local commit is enough until the next planned push. The fix waves of the task reviews and of the final whole-branch review come before ship, so the ship push carries them.

`push_policy` covers the feature branch only. The push of the screenshots to `screenshot_branch`, at step 5 of the ship checklist, happens with both values. It is a different branch, with no pull request of its own.

`scripts/ready-check.sh` compares the local branch with the remote branch. It runs at step 7 of the ship checklist, after the ship push. So the local commits between the pushes do not make it fail.

## Tracker and pull request

The key `tracker` in the project file names the ticket tracker: `jira`, `linear`, `github`, `gitlab`, `other`, or `none`. Never assume Jira. On Jira and Linear, the ticket id is the key, for example `ABC-123`. On GitHub and GitLab, it is the issue reference, for example `#123`, or `group/project#123` for an issue in another repository. With `other`, the team uses a tracker that is not in this list, for example an internal tool with its own connector. The section Tracker steps names the connector, the form of the ticket id, the statuses, and the comment rules. Use only what that section says. With `none`, the team has no tracker, so skip every tracker step and say so once.

Get the ticket id in the first exchange of the brainstorm, not in the plan header. If the gate owner gave an id in the request, use it. If not, ask. A feature with no ticket is legitimate. In that case, say so and skip every tracker step. Do not guess an id later. After you get the id, put it in the spec header, the plan header, and the pull request body.

The tracker steps are in the section Tracker steps of the project file body. Follow them as written. If no tool reaches the tracker, the run writes the comment text into its report, and the developer posts it.

Do not decide from a role whether you can move a ticket. A global role, such as `viewer` in the answer of a whoami call, does not show the permissions of the user on one project or board. Try the first status change. If it fails, tell the developer what failed, put the move in the report for the developer to do, and continue the run. A failed tracker step does not stop the run.

At the moment that you cut the branch and open the draft pull request, move the ticket to in progress. Do it in the same step as the trail comment. That is the moment that the work becomes visible.

At the moment that you mark the pull request ready, move the ticket to review. Do it in the same step, not as a follow-up.

Resolve every status change from what the tracker offers for that ticket. Do not assume a name. Report the status that the ticket is in after the change.

One tracker can hold many projects, and each project can have its own statuses. Take the project from the ticket id of this run, for example `ABC` from `ABC-123`, and not from a project that the project file names. Read the statuses of that project before the first move. If a status that the section Tracker steps names does not exist in that project, ask the developer which status to use.

Each tracker holds the status in its own way:

- `jira`: the status moves through a transition. Resolve it from the available transitions of the issue. The name of a transition is not its target status.
- `linear`: the status is a workflow state of the team that owns the issue. Resolve it from the states of that team. Two teams can use the same state name for different stages.
- `github`: an issue is only open or closed. The status that the team uses is a field of a GitHub project, often named Status, or a label. The section Tracker steps says which one. Without that, the run changes no status, and it says so.
- `gitlab`: the status is a scoped label, for example `workflow::in progress`, or the Status field of the issue. The section Tracker steps says which one. Setting a scoped label removes the other label of the same scope, and that is the move. Without that section, the run changes no status, and it says so.
- `other`: the section Tracker steps says where the status is and which tool moves it. Without that section, the run changes no status, and it says so.

Stay in this scope and go no further: that one ticket, its status only, and the single trail comment. Do not edit the description. Do not change other fields or other tickets. Do not move anything to done during the run, because closing a ticket is the decision of the gate owner. If the tracker has no status for the stage that you want, say so. Do not pick a different status.

On GitHub and GitLab, a closing keyword in the pull request body closes the issue at merge. So name the issue with `Refs #123` on GitHub and `Related to #123` on GitLab. Never use a closing keyword such as `Closes`, `Fixes`, `Resolves`, or, on GitLab, `Implements`. If the section Tracker steps says that the team closes the issue at merge, use a closing keyword.

Before you open the pull request, read the description template of the forge, and fill it in. Keep its headings and its checklist. Tick a box only for a step that the run really did. Leave a box empty for a step that the run did not do, for example a manual test on a device. If the forge has no template, write a plain description.

- GitHub: the template is `pull_request_template.md`, or a file in a `PULL_REQUEST_TEMPLATE` folder. Each one can be at the top of the repository, in `.github/`, or in `docs/`.
- GitLab: the default template can be in the project settings, and not in the repository. Read it with `glab api projects/<path>`, where `<path>` is the URL-encoded path of the project, and take the field `merge_requests_template`. If that field is empty, use `.gitlab/merge_request_templates/Default.md`. If that folder holds other templates and no default, ask the developer which one to use.

A GitLab template can hold quick actions, for example `/assign_reviewer`. GitLab runs them when it saves the description, and they notify people. They are the choice of the team, so keep them as the template has them. In the handoff, say who the quick actions assigned.

Reply to every pull request review comment, and start the reply with the comment prefix that follows. If `comment_prefix` is empty, start the reply with `Claude said:`. Write one reply for each comment, on the thread of that comment. Never write a summary somewhere else, and never stay silent. A reply says what changed and names the commit that changed it. Reply after the push that carries that commit, so that the reader can open it. Otherwise, it says clearly that nothing changed and why. You can disagree without permission. You cannot say nothing.

The key `comment_prefix` gives the comment prefix. Read it with `scripts/project-config.sh comment_prefix ""`, which prints an empty line and exits 0 when the key is empty or missing. If it has a value, start every comment that the run posts with the account of a person with that value on its own line, then a blank line. That covers the trail comment on the ticket, each reply and note on the pull request, and each comment on a wiki page. When you edit a comment, keep the prefix at its start. The prefix does not go in the description of the pull request, in a commit message, or in a wiki page itself. If the key is empty, add no prefix, except on a reply to a review comment, as the paragraph above says.

Leave one trail comment on the ticket, and continue to edit it. Post it as soon as the pull request goes up, and edit it as things change. Never add new comments on top of it. It has the pull request link, four or five lines about the approach, and links to the spec and the plan. Never write into the description of the ticket, which holds the request in the words of the gate owner. Never paste the documents. Link them pinned to a commit SHA, never to a branch, so that the links still resolve after the branch is deleted.

## Docs publishing

This section applies only if `docs` is `private` and the body of the project file has a section Docs publishing that names a wiki. Otherwise, the run publishes nothing, and this section does not apply.

With private docs, the specs, the plans, and the retros never go into git, so a person who reads the ticket cannot open them. The run publishes a copy of each document to the wiki that the section names. The local file stays the source of truth. A wiki page is a copy of the file at one publish point. Never edit a document on the wiki in place of the local file.

The run publishes at these points, unless the section names other points:

1. The gate owner approves the spec at the end of the brainstorm. Publish the spec.
2. The gate owner approves the plan at the gate. Publish the plan, and update the spec page.
3. Ship, at step 8 of the ship checklist. Update the spec page and the plan page, so that they match what shipped. The run writes the retro after the handoff. Publish the retro then, as part of this point.

In lite mode, the brief replaces the spec and the plan. Publish the brief at the gate, and update it at ship.

Ask before the first publish of the run, at the first publish point and not before. Ask the developer who runs the feature, or the person that the section names. The answer covers this run only. Record the answer in the ledger. If the ledger does not exist yet, start it at this point. Never carry it to a later run, and never take it from the ledger of another run. If the answer is no, publish nothing in this run.

At each publish point, follow these rules:

- Create each page under the parent page that the section names. Use the connector or the API that the section names.
- A wiki page can have more readers than the local file. Before each publish, make sure that the document holds no sign-in detail and no raw capture.
- Link the page from the trail comment of the ticket. Never paste the document into the ticket. With private docs, no commit holds the document, so this link replaces the link pinned to a commit SHA that the section Tracker and pull request asks for.
- Record the id of each page that the run creates in the ledger, on its own line, in this shape: `wiki-page: <page id> <document file name>`.
- Update a page only if its id is in the ledger of this run.

The run can delete a page only if its id is in the ledger of this run. Read the id from the ledger, not from a search of the wiki. Never delete a page that a person or another run created, even if its title matches.

If no tool reaches the wiki, say so one time and publish nothing. Do not paste the documents into the ticket in place of the page.

## Ship checklist

The last plan task is always "ship", and these are its steps. They are a dispatched task, not remembered rules. Do the steps in this order. Do not skip a step, and do not defer a step to a line in the pull request description.

1. Make sure that the final whole-branch review passed and that every change after the review is committed. Then free the disk for the ship builds. The document header or the brief names the build output folders of earlier tasks and probes. If the ship step does not use one of them, delete it. Delete only those paths, never a path found by a pattern. (lesson: disk-full-at-ship)
2. Run every manual check. An unrun check blocks ready-for-review. A "still open" note does not replace the run. Run the check, or ask the gate owner for what unblocks it. Run the checks as an `exploratory-testing` session with a charter and a session log. Save the log as `qa-session-log.md` in the ledger folder, because `scripts/ready-check.sh` reads that name.

   End the log with a tally line in exactly this shape, because step 7 parses it:

       tally: 8 checks, 8 run, 0 unrun, 0 waived

   The line has four numbers, in that order. Any unrun or waived check blocks ready-for-review. Only the gate owner can give a waiver, so a waived count that is not zero means stop and ask. If the gate owner waives a check, write one line for it. Put the line in `progress.md` in the ledger folder, in this shape, and the ready check accepts it:

       waiver: M1 by gate owner on <yyyy-mm-dd>: <reason>

3. Read the spec again against what shipped, and fix any drift.
4. Make sure that the ledger has an entry that names every commit on the branch. Do this after the final push, because at write time the ready check cannot see the commit that you are writing. A commit that changes only files in the ledger folder needs no entry, so a ledger that git tracks can record itself. With `push_policy: mr-and-ship`, the final push comes after this step, not before it. Write the entry after the last commit outside the ledger folder. If `docs` is `repo`, commit the ledger. Then push the feature branch. This push is the ship push.
5. Take the screenshots again on the final tree, after all the steps above, and push them to the branch that `screenshot_branch` names. On GitLab, you can instead upload them to the merge request description. If `screenshot_branch` is empty, you must upload them. Use `scripts/settle-screenshot.swift --capture "<command>"` so that each capture waits for the screen to settle. If `view_globs` is `none`, the project has no screens, so skip this step.
6. Rewrite the pull request description in the template of the forge, as the section Tracker and pull request says.
7. Run `scripts/ready-check.sh`. It must exit 0. With `mr-and-ship`, a failure can need a new commit on the feature branch. In that case, fix all the failures, and ask the gate owner before you push again. When the check exits 0, mark the pull request ready. Do not ask the gate owner. On GitHub that is `gh pr ready`. On GitLab, where the pull request is a merge request, it is `glab mr update --ready`. The key `forge` in the project file says which one.
8. Immediately after that, move the ticket to review, and post or update the trail comment, as the section Tracker and pull request says. If the section Docs publishing applies, publish at this step too.
9. If the `brief` skill is installed, hand off in its style. Say that the pull request is ready and what still needs the gate owner.

`scripts/ready-check.sh` covers the things that a machine can prove:

- The base is merged into the branch, and the tree is committed and pushed.
- The ledger names every commit in `<base_branch>..HEAD`, except a commit that changes only files in the ledger folder.
- The ledger has cost lines for `spec`, `plan`, `final`, and at least one task. A lite ledger has `build` and `final` instead.
- The QA tally line reads all run, or each waived check has a waiver line from the gate owner.
- The pull request body is a real description.
- If the branch touches a file that matches `view_globs`, the body links screenshots on the screenshot branch. On GitLab, images uploaded to the merge request also count.

The screenshot proof is a URL in the body that contains `/<screenshot_branch>/`. On GitLab, a link that contains `/uploads/<hash>/`, the form that GitLab gives an uploaded image, is also proof. If a view file changed but no screen changed, the body has a line that reads `No screen changed.` and the ready check accepts it. It skips the screenshot proof on a branch that changes no view. Run it from the checkout that holds the ledger. It reads the pull request through `gh` on GitHub and the merge request through `glab` on GitLab.

The script cannot prove steps 1 and 3, the review verdict and the spec re-read. State those two yourself, with one line each in the handoff. A green ready check does not mean that the run was good. If it fails, fix what it names, or ask the gate owner to waive it. Do not mark the pull request ready first.

### QA skills

QA uses named skills, and the skill `platform-<platform>` names them. Three rules hold for any platform:

- Use a charter for each manual QA session. It names the target and the information goal, sets a time box, and keeps a written session log.
- Write each manual check with one assertion for each step and one case for each business rule. The expected result must let a second person pass or fail the check without a guess.
- For a defect that arrives without reliable steps, ask the intake questions, make the steps deterministic, and bisect.

If a QA skill assumes a tool that the project does not have, the project wins. Say that you diverged. Do not edit vendored skills.

## When the gate owner says merge

The run ends here, after the gate owner says so. Marking the pull request ready is not a gate. Merge is a gate, and ready does not mean merge. Never infer it because the branch looks finished.

"Merge" authorizes all four steps that follow, in this order, without another question.

1. Merge the pull request for the branch of this run, and nothing else. The branch starts with `branch_prefix`, and the pull request targets `base_branch`. Merge through the pull request, as a merge commit. Do not squash, do not push a local merge directly to the base, and do not rebase. Before you merge, make sure that the pull request number matches the branch named in the ledger, because you cannot undo a wrong merge quietly. If the pull request does not merge because of a conflict, a failing check, or a requested review, stop and say which one.

   Immediately before the merge, make sure that the base is still an ancestor of the branch. Run `git fetch origin` and then `git merge-base --is-ancestor origin/<base_branch> HEAD`. The ready check asks the same question, but it asks at ready. The base can move between ready and the word of the gate owner. If the base moved, merge it into the branch, run the suite again, push, and say so before you merge the pull request. The word merge covers that push with both values of `push_policy`. A clean text merge is not a working tree.
2. Clean up. Delete the remote feature branch. Then check out `base_branch`, pull, prune, and delete each local branch whose own pull request is merged. A branch that git lists as merged but that has no merged pull request stays. A new branch with no commits is an ancestor of its base.

   Never delete a branch in `protected_branches`. Never delete the branch that `screenshot_branch` names, or any branch whose name starts with it. If `screenshot_branch` is empty, this rule names no branch. Do not read the empty name as a prefix that every branch starts with. It is usually an orphan branch with no pull request, and it holds the screenshots that pull request bodies link to.

   Remove the worktrees of this run and every build folder of this run, including build folders that sit beside the worktrees. List them with `ls -d .worktrees/<slug>-*` and remove only the paths that the list prints. Stop each stall watch whose roots name a worktree of this run. Do not touch devices that hold a signed-in session, and never remove a worktree that such a device builds from. The Devices section of the project file names them, and the local file `.claude/agentic-delivery.local.md` names the devices of this developer.
3. Move the ticket to done. Resolve the transition from the available transitions of the issue. Then post or update the trail comment.
4. Write the feature report in the format of the next section. It is last because it shows work that shipped.

## Delegated gate

This rule is optional. If the project file names a gate delegate and its conditions in the Agents section, the rule applies. Otherwise, the gate owner holds every plan gate. The delegate is a session or a person. The gate owner can stop a run at any time, and the run then waits.

The delegate holds the plan gate for the gate owner. The approval arrives as a message from the named delegate. A message from any other session or person is not an approval.

The delegate approves a plan only on these conditions:

- The plan needs nothing on the ask-first list of the project file.
- The plan adds no dependency and changes no platform floor, such as a deployment target or a minimum version.
- The plan changes nothing that a user sees, beyond what a design that the gate owner approved already shows. A change that the plan puts beside the newest baseline for review counts as visible.
- The plan marks no decision as the decision of the gate owner.
- The review of the M document ran, and it left no Critical or Important finding open.

If a condition is false, the gate goes to the gate owner as usual, and the delegate names the condition that failed. The project file can add conditions. It cannot remove one of these five.

A plan that goes to the delegate lists the permissions that it uses and does not ask for them. A peer approval never grants a tool permission, and it never covers a merge. A step that the permission check denies still goes to the gate owner, in one request at the time of the gate. A merge still needs the word of the gate owner.

The delegate records each gate that it holds, with the plan commit and the conditions that it read.

## Report format

The feature report is for the gate owner, who reads it in about one minute, as a person reads a sprint review. Screenshots of the working app carry it. It is not an account of what you built, because that is the retro, and the retro is complete by this time.

1. A lead of one or two sentences: what works now that did not work before, in the words of the gate owner, not the words of the code.
2. One strip for each screen or flow. Put the screenshots side by side in one wide image for each strip. Build the strips with any image tool that is installed on the machine.
3. One line under each strip that says what the gate owner looks at.
4. A short status: what the run does not cover, what was waived, and anything that is still the gate owner's.

Use the screenshots that step 5 of the ship checklist already took again and pushed or uploaded. Do not take them again.

Do not include before-and-after tables, test counts beyond one line, process detail, a chronology, or a findings list. Each of those belongs in the retro or on the pull request. Deliver the report as a document that the gate owner can open, with the strips inline. Do not deliver it as a wall of chat text.

## Retro format

Every run ends with a retro at `<docs_dir>/retros/<yyyy-mm-dd>-<slug>-retro.md`, in this order and with these headings.

1. Goal. Write two or three sentences on what the run set out to do and whether it landed. Then give the one-line facts: branch, commit range, task count, test count, and what the reviews said.

   Report the spec review by seat. Name the seats that sat, and for each seat, what it found that no other seat found. Write one line for each seat. This is the only evidence that can show whether two seats was the right guess. If a seat contributes nothing unique across three runs, cut it. If a finding continues to arrive late, that is an argument for a seat that does not exist yet.
2. Estimate against actual. Give a table with four rows: t-shirt size, wall-clock time, tokens, and human touches. Give the estimate, the actual, and the difference for each row. The actual tokens are the sum of the cost lines in the ledger, plus the controller where you measured it. Do not count again from the completion notices. If the ticket got a size at sprint planning, the size row also names that size. Then write one or two sentences on where the difference went. Name the specific cause, not "unexpected issues".

   Split the actual human touches into three counts, and name each touch in a few words:

   - Steering: the gate owner made a product, design, or scope decision, or approved a gate.
   - Permission: the gate owner allowed a step that the permission check denied. The plan header lists these, so a touch here that the header did not list is a gap in the plan.
   - Rescue: the gate owner noticed or fixed something that the run must catch itself. Examples are a stalled turn, a hung build, and an unchecked claim.

   Write it as one line, for example `touches: steering 1, permission 2, rescue 1`.

   Add one line for the planning share: copy the `plan` cost line, give its share of the total tokens, and give the number of fix rounds that the run then needed.
3. Score, 1 to 4. Give one sentence of justification. Score the run, not the feature.
   - 1: the run did not land, or it needed rescue throughout.
   - 2: the run landed, but with significant rework or human help beyond the agreed gates.
   - 3: the run landed with ordinary friction, and review caught the defects, not the gate owner.
   - 4: the run landed clean. The run caught defects before review and needed no help beyond the agreed gates.
4. What went well. Give each item with the evidence that it worked. If something carried the run, name it so that the next run keeps it.
5. What to improve. Write one entry for each problem: what happened, the root cause, and the change that removes it. Say clearly whose error it was, including errors of the controller. Order the entries by what the problem cost, heaviest first. Anything that damaged work outside this run goes first, whatever its size.
6. Waivers. List each ship checklist step that did not run as written, who agreed to waive it, and when. If there were no waivers, say so in one line. A deferred manual check is a waiver.
7. Action items. These are proposals, and the triage belongs to the process owner, as the section Process fixes says. Say so at the top. Then, for each item, say what changes, which plugin file it belongs in, and who does it. The run never edits plugin files. A rule change becomes an action item that names the plugin file, and it goes to the plugin repository as a pull request.
   - Prefer a mechanism to a rule. An armed watch, a check that runs, and a script that aborts are better than a sentence that someone must remember at the right moment. Say what the mechanism makes unnecessary.
   - An amendment is not an addition. If an existing rule covers the ground and was wrong or incomplete, say which rule and how it must read.
   - Rank the items, and say which items you recommend that the gate owner drops.

   A retro proposes from inside one run, so it cannot see what an item costs on every later run. Ask how often the case occurs and what the item costs where it does not occur. An item measured one time is a candidate, not a finding. A single incident is rarely a rule.
8. Optional chronology. If the action items already cite their incidents, skip it. Otherwise, add one table at the end.

Before you write down a claim, examine it against the repository or the ledger. Mark inline where the raw account did not pass that test. That includes the figures of the retro itself, because counts written from memory are often wrong. A run with one real problem has a short retro.

### The retro notice

The plugin ships a hook. When a retro file is written, the hook reminds the run to propose each rule change as a pull request to the plugin repository. The run also names the retro and its action item count in its handoff.
