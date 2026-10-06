---
name: run-rules
description: The rules that every agent in an agentic-delivery run follows, loaded at the start of every dispatched task and every review.
---

# Run rules

These rules cover every agent in a run: the controller, each implementer, each reviewer, and QA. The project file `.claude/agentic-delivery.md` holds the facts of one project. The platform skill `platform-<platform>` holds the commands. This skill holds the rules that do not change between projects. Each rule gives its reason in one sentence. A pointer such as (lesson: silent-command) names a section of `lessons.md` that tells the incident behind the rule.

## Terms

Each of these terms has one meaning only.

- Controller: the session that dispatches agents and coordinates the run.
- Run: one ticket taken through the feature process.
- Gate owner: the developer who approves the plan. The project file can name someone else.
- Gate: a stop for the approval of the gate owner.
- Seat: one reviewer role at a review. The agents for the seats come from `implementer_agent`, `reviewer_agent`, and `qa_agent` in the project file.
- Brief: the written instructions that the controller gives to a dispatched agent.
- Ruling: a decision that the controller makes during a run and records in the ledger.
- Ledger: the record of a run in the folder `<docs_dir>/<date>-<slug>/`. It names each commit and each ruling.
- Retro: the review of a run. The run writes it at the end, in `docs_dir`.
- Check: a step that proves one fact and can pass or fail.
- Project file: `.claude/agentic-delivery.md` in the repository of the user.
- Platform skill: the skill `platform-<platform>`, for example `platform-flutter`. It names the build commands, the test commands, and the device commands.

If `docs` in the project file is `private`, `docs_dir` is a folder outside the repository. Every worktree reaches it by its full path, and a path that starts with `~/` is under the home folder. In that mode, never commit or push a spec, a plan, a ledger, or a retro. The team chose to keep them out of the repository.

## Autonomy

Each item in the first list is pre-approved. None of them is a reason to stop and ask. Asking again is the failure that this section exists to prevent.

You can do these things without asking:

- Commit after each completed task, and push to the current feature branch. Its name starts with `branch_prefix`.
- Open a draft pull request against `base_branch`. Rewrite its description as the plan progresses.
- Build and test with the commands that the platform skill names, create and boot test devices, and take screenshots.
- Dispatch implementer and reviewer subagents.
- Write briefs, reports, ledgers, and review diffs in the ledger folder.
- Write specs and plans in `docs_dir`.
- If the repository itself answers a question and a wrong answer costs one task of rework, record a ruling in the ledger and continue.
- Go directly from one task to the next. Report at the checkpoints that the plan defines, and one time at the end.

Stop and ask before you do these things:

- Merge into a branch in `protected_branches`, or push to one.
- Force-push, or rewrite published history.
- Delete a branch whose own pull request is not merged.
- Touch an area that the Ask-first areas section of the project file lists.
- Add a third-party dependency, or change the minimum supported platform version.
- Do anything that needs a live access token, or any account other than the test account that the project file names.
- Do anything that the plan itself marks as a decision.

Each feature has one human gate. The gate owner reads and approves the plan before execution starts. A status line that needs no answer is not a gate, and it does not use up the gate. If the run passes its estimate, stalls, or finds a blocker, say so at that time. After the gate, the run continues to the end of the plan.

## Keeping the spec true

If shipped behavior diverges from the spec, amend the spec in the same commit as the code. Every reason counts:

- A ruling that overturns a spec decision.
- A QA fix.
- A device observation that proves a stated rationale false.
- A late change that the developer asks for.

Amend every place where the decision appears, not only the nearest paragraph. That includes the prose, the screen descriptions, the rules list, the acceptance table, and the manual-checks list.

Also amend every document where the decision appears. That set is the spec, the plan, and the instruction files of the project. The sweep step of the plan names that set. The controller must not work it out again for each dispatch. If the sweep covers only the spec, the plan still tells implementers to run a check that the spec calls worthless. (lesson: sweep-every-document)

Search for the subject, not for the old wording, and read every hit. The phrase that you replace finds only the places that used your words, and a spec paraphrases itself all the time. For example, "not reachable today" does not match "unreachable today". Put the search and the hit count in the task report. If a plan gives a list of literal wordings, every task that inherits that list inherits the mistake. A spec that contradicts itself is worse than a spec that is out of date, because the reader cannot tell which half is current. (lesson: sweep-by-subject)

A fix brief lists each spec subject that its code changes touch, each as a separate item. Before a re-review marks a code item addressed, it searches the spec for each subject. This rule fails most often in fix briefs. The author writes a list of places, not subjects, and the sweep copies that shape. If a subject has no item of its own, nobody sweeps it.

At the end of a run, before you call the branch finished, read the spec again against what shipped. Fix any drift.

## Where facts belong

A document must not state a fact that it cannot see change. Definitions are pinned to one branch, and sessions on any branch read them. If a definition says what is in the tree, it describes the wrong tree. A branch is one way that a fact moves, and time is another.

Ask if anything can change this fact without a change to this document. A merge, a re-export, a commit by another person, or an answer from a designer all count. If any of them can change the fact, the fact does not belong here.

Put a fact in the thing that changes with it. Tree state goes in a project context file that travels with the code. A count or a hash goes in the artifact itself, or in its provenance file. A definition says how to think and where to look. The thing that it points at says what is there. If you must name a fact, name its source instead and tell the reader to read the source. (lesson: facts-that-move)

## Tests and fixtures

The search in a red step matches any of the new type names of the task, never one specific name. The compiler names missing types in the order that it gets to them. A plan that predicts which one comes first predicts something that it cannot know. (lesson: predicted-compile-order)

Every fixture says where its shape came from. The first line of a response fixture, or of the brief that orders it, reads `captured: <endpoint> <date>` for a real response that someone saw. Otherwise it reads `spec: <line>`, with a quote of the text that the fixture encodes. Do not write a fixture that has neither line. The task reports the gap and uses the narrowest shape that the words of the spec permit. For an unspecified success body, that shape is no body. Review asks this question about every fixture in the diff. It rates an assumption that the code depends on as Important, not Minor.

The state that your setup step skips is the state that nobody tests. If a test calls a configure method before it asserts, at least one test must assert on the object as constructed. If a path reads a cache and then refreshes it, the cold-cache case gets a named test.

For pattern-matching code, the tests must include at least one case that the author thinks the pattern misses. Write that case before you widen the pattern. A lint, a regex, a parser, and a guard based on search only prove what the author expects. The author writes tests from the shapes already in mind. Before dispatch, ask: name a valid input that this pattern does not match. Put the counterexample in the dispatch brief, not in the memory of the controller. Rounds that carried a counterexample closed the first time, and rounds that skipped it cost double. (lesson: pattern-blind-spots)

At spec time, decide whether a check proves the diff of one ticket or states a general rule. By default, a check that proves the edits of this ticket is an exact copy of those edits, committed beside the check. If the check must also gate later tickets, write a general rule instead. Line rules close one hole and open the next. (lesson: committed-diff-copy)

Put logic where a test can assert it. If you can assert a fact without a device, assert it without a device. For example, scroll arithmetic that lives in a pure function with unit tests lets a reviewer calculate every expectation again. (lesson: logic-out-of-the-view)

A task that touches a view is not done until someone renders its screen and looks at it. A file that matches `view_globs` in the project file is a view. Attach the screenshot to the task report. A passing geometry test proves that the constraints resolve as written. It does not prove that the screen looks right. Capture only after the screen settles. The platform skill names the capture command. Do not write your own settle loop, because a capture gated on "the view exists" becomes true as soon as rendering starts. (lesson: unsettled-screenshot)

## The ledger

Write the ledger entry before you commit the fix. If a commit on the branch has no ledger entry that names it, the task is not complete.

Every run keeps a ledger, including a documentation-only ticket. There is no exemption, and the ready check enforces it. A tracker row is not a substitute. It never names a commit, and a commit name is the one thing that the ledger exists to give. The ledger of a documentation ticket is almost empty and takes one minute. (lesson: ledger-skipped)

When a phase ends, write one cost line in the ledger, in exactly this shape:

    cost: <ticket> <phase> tokens=<n>k minutes=<n> fix_rounds=<n>

The phase is `spec` for the spec review and `plan` for the plan review. It is `T1`, `T2` and so on for each task, `final` for the final whole-branch review, and `ship` for the ship task. Here is an example: `cost: <ticket> T2 tokens=448k minutes=37 fix_rounds=1`.

A run in lite mode has no spec, plan, or task phases. Its ledger has a line that reads exactly `mode: lite`. It writes `build` for the work of the session and `final` for the final review and its fix wave, and `ship` as usual. The ready check reads the mode line, and then asks for `build` and `final` in place of `spec`, `plan`, and a task line. The section Lite mode of the `controller` skill gives the conditions for a lite run.

- Tokens cover every agent that worked in the phase: the implementer, each reviewer, and each fix and re-review.
- Count each agent one time, at its final cumulative figure, in thousands. A resumed agent reports its running total again, so a sum of completion notices counts it many times. (lesson: token-double-count)
- Minutes run from the first dispatch of the phase to its approval.
- Fix rounds count the rounds in that phase.
- The tokens of the controller are not in these lines. Put them in the retro as one figure, where you can measure them.

These lines are the only record that lets a later forecast use real numbers. A line with a fixed shape can be summed across tickets. The ready check refuses a ledger that lacks well-formed lines for `spec`, `plan`, `final`, and at least one task. It does not ask for `ship`, because the ship line is written after the ready check runs.

## Review findings

Critical and Important findings block. Nothing below Important starts a fix round. Each fix wave gets one re-review. Fix a finding below Important only in one case: the fix is one line and needs no new device run, no new proof run, and no re-review. Put everything else in the pull request description under Follow-ups, and in the ledger. Findings left after a re-review do not start another round unless they are Critical or Important. The final review gets one fix wave and one re-review, and then the ticket ships. (lesson: fix-round-cost)

A ticket with several view tasks has one exception. An Important visual finding goes to one visual fix task after the last view task. It does not start a fix round in its own task. A visual finding is about how a screen looks: spacing, sizes, contrast, or clipping at large text. A finding about behavior, accessibility labels, routing, or data still blocks in its own task. The visual fix task fixes all the visual findings, records the snapshots one time, and gets one re-review. Each fix round records every required snapshot again, so a round for each visual finding multiplies the cost. The plan review can mark a screen "fix in its own task" because later tasks build on the code that its visual fixes change. The findings on that screen then block as before. (lesson: visual-fix-batching)

The reviewer still reports a Minor finding, as a follow-up. The reviewer already read the diff, so the note costs nothing and is useful later. You write a follow-up down, and you do not act on it.

The pull request has a screenshot of each screen that the branch adds or changes.

- Take the screenshots after manual QA, on the final state of the branch. Never use screenshots from a task report taken during the run.
- Take one image for each screen. Take a second image for each state that the spec requires, for example loading, empty, or error.
- Put them on the branch that `screenshot_branch` names, and link them from the pull request body by URL. On GitLab, you can instead upload each image to the merge request description, and GitLab links it by a URL that contains `/uploads/<hash>/`. If `screenshot_branch` is empty, upload them. They never go in the source tree.
- Do this last, before you offer the branch for review. A screenshot taken before the final fixes shows a screen that no longer exists.

Task-report screenshots are internal and do not satisfy this rule.

## Diagnosis and evidence

Examine the machine before you blame the branch. If something hangs, stalls, or fails in a way that the diff cannot explain, examine the accumulated state of the machine first. Do this before you form a theory about the code, the device, or another process. Count what you find. Do not measure its size. (lesson: machine-state-first)

Do not state a causal theory that the evidence does not support, even with a hedge. If the next check can settle it, run the check. Do not narrate the guess. A disclaimer does not make a wrong theory cheap, and one hedged guess cost a machine restart.

Before you assert a negative, name what a positive result looks like in the output that you have. If that output cannot contain a positive result, your command did not answer the question. A clean empty result looks exactly like proof. If the negative is about a document, search for the subject, not for a phrase that you remember. This is the most expensive habit that the source project recorded. (lesson: silent-command)

One passing run does not prove a fix for an intermittent failure. A restart can clear stuck processes so that the next run passes, and the run after it can stall again. To prove the fix, do repeat runs.

A tool call that reports a rejection can still have run. After a rejection, look for side effects before you assume that nothing happened, because two rejected runs still wrote their log files.

A guard that prints and continues is not a guard. Write the check as an exit, not an echo. (lesson: guard-that-continues)

If an assertion fails in a scripted edit, abort the commit too, not only the edit. Chain them, or read the exit status of the edit before you commit. Otherwise a commit message can describe a change that its own diff does not contain.

Diagnose a stalled run by processor time, not by elapsed time. A hung build sits near zero percent, and its processor total is frozen. A build with no processor time for a long span can still finish. Make sure that the processor total is frozen before you call a run dead. (lesson: cpu-time-not-clock-time)

- The platform skill names the remedies for a stalled run and their order. Try all of them before you conclude that the machine is broken.
- Two consecutive dead builds mean escalation, not a third attempt. Stop, say what you tried and what the processor evidence was, and give the problem back to the developer. If the remedies failed, the variable that you did not try is outside your reach.

Before you clean up the state of a test runner, make sure that no process listed in `test_processes` is alive. A cleanup during a live run kills that run. Match a process by its name, not by its command text. A shell whose command text names the runner matches itself and blocks the cleanup forever. Note that a script that `/bin/sh` runs can get different tools than your interactive shell. Measure a script by running the script itself. (lesson: shell-differs)

## Devices and other sessions

Shift left. Before you propose a manual check, ask what must be true for a unit test to catch the problem. Then move the behavior to a place where a test can assert it.

If a device is really cheaper, defer the check to QA. Do not give each implementer a device. Parallel implementers that each boot a device multiply the machine load, and machine load cost the source project more time than any defect. QA runs on the controller, which is idle for most of a wave. It uses one device, and one task at a time claims it. (lesson: parallel-device-load)

When you defer the check, you do not defer the ownership. The implementer that wrote the code names the check precisely: what to do, what value to read, and what result means that its code is wrong. QA does a specified check. It does not look for defects in the work of another agent. If QA finds a defect that the task owner was able to name, that is a finding about the task.

Devices and accounts:

- The Devices section of the project file names the device kinds and the protected devices. The ledger holds the id of each device that the ticket creates. Pass a device by id, never by name, because a name can resolve against a different runtime.
- One ticket holds the test device at a time. A second ticket that runs at the same time creates its own device of the same type and runtime. If two tickets use one device, each installs the same build id over the other, and neither run can say which build it measured. The plugin's device claim script holds a device for one worktree. The platform skill names how to run it.
- A device that holds the signed-in session of a real person is not a test device. The Devices section of the project file names it, or says where its id is kept. Never erase it, never uninstall from it, and never aim automated tests at it. Install a build with a different build id beside the app, after you examine that id. (lesson: live-session-on-test-device)
- Inside the app, with the test account that the project file names, do what the work needs. Read data, send messages, create data, and delete data. Do not stop and ask for each action. Two limits hold. The permission covers the host that the project file names, and a release build can reach production. And the permission is about the account, not the devices.
- A debug build can print whole reply bodies to the console, so a capture can hold real data. Mask it before anybody else reads it. A raw capture never goes into the repository, a ledger, a report, a retro, or a ticket.
- Get the build that you install from the output path that you just built into. Never use a search. A search returns whatever is oldest or first on disk, which is a build of a previous run with the code of a previous branch. If the expected build is not at that path, stop. Do not search for one. (lesson: stale-build-install)
- Run a probe of anything path-sensitive at the path where the code will be, not in a scratch directory. Sandboxes, symlinks, relative paths, file watchers, and anything that reads a project root are all path-sensitive. A finding from a scratch copy is a hypothesis until you reproduce it at the real path. (lesson: scratch-path-probe)

Commands and files:

- Never pipe a build or a test run to `tail` or `head`. Redirect it to a file and read the file. A pipe buffers, so the log looks empty until the command finishes.
- Do not use a foreground `sleep`, because the Claude Code sandbox blocks it. To wait, use a background loop that polls the condition.
- Run tests detached into a log file, and let the stall watch read that log. The stall watch sees only the worktrees that the controller dispatched, so for a run that you drive yourself, watch the log yourself.
- Write test result files into the ledger folder of the run, never into a temporary path. The console says whether tests failed. The result file says why, and a reviewer needs it after the run.
- Delete only a path that your own command printed. Never run a wildcard delete in a directory that you share with other runs. That includes the session scratchpad and the system temporary directory. A folder that looks like leftovers can be the live workspace of another run. The implementer and reviewer agents carry the same rule. (lesson: guessed-deletion)
- Stop a probe as soon as its measurement ends. Name the paths that a probe watches. A watcher that resolves its paths from the working directory silently adopts every live worktree on the machine.

A merge with no text conflict can still produce a tree that does not compile. A check that reads the merge tree is not a build. Build the merge result before you call it clean. (lesson: clean-merge-broken-build)

The stall watch, messages to other sessions, and the timing of process fixes belong to the controller skill, because only the controller does them.

## How output reads

An attribution line names Claude, never a model version. A commit trailer reads `Co-Authored-By: Claude <noreply@anthropic.com>`. A pull request body keeps whatever generated-with line the tool supplies. A version number in a trailer is stale at the next release.

The run writes the retro. The retro does not edit the files of this plugin: the skills, the commands, the agents, or the project file rules. Propose the change as a retro action item that names the file where it belongs, and stop there. A rule change goes as a pull request to the plugin repository, and the team reviews it. (lesson: retro-proposes-only)

A developer can turn on the optional `lean` output style that ships with the plugin.

## Checks

These rules cover every check that anybody writes.

Write manual checks in verifiable form at plan time, not at run time. "Looks right", "works", and "is fine" are not expected results. If nobody can disagree with the expected result of a check, the check cannot fail. (lesson: checks-that-cannot-fail)

If an expected result states a measurement, take that measurement. Do not derive it. Read the number from a real run, on any build that can produce it. Do not calculate it from the constraints and write the arithmetic down as the expectation. The same rule covers a dispatch brief and a findings file, not only a plan. Measure a number before you write it for an agent to act on. (lesson: derived-not-measured)

A check names the value on a correct tree and the value on the defect that it excludes. Measure the second value. A check that states only what passing looks like did not show that it can fail. You can reason out the passing value, but you must go and measure the failing value.

Measure both values, and any control value, in the build configuration that the check reads. A value measured in a debug build does not stand for a release build, because the two compile different code. (lesson: wrong-build-configuration)

A check also names the case where its inputs are gone, and in that case it must fail closed. Passing and the defect are two of three cases. The third case is that the file, the folder, or the command output that the check reads is missing. A check that reports success in that case is worse than no check, because it reports success after it read nothing. (lesson: fail-closed)

Where this rule can be a mechanism, make it one. Tell the reviewer in the brief to run each check against a copy that you broke on purpose.

Some checks guard an act that you cannot undo. Examples are installing over a signed-in app, deleting a device, and pushing to a shared branch. Sometimes only the act that the check prevents can produce the broken value. In that case, measure it at the last gate before the irreversible step. Find the last point on the path where the defect is still detectable and nothing is committed yet. Measure the failing value there. The later steps then inherit their confidence from a gate that you saw fail.

The inheritance is valid only under two conditions. First, nobody can skip the gate, and it is on the same path as the steps that rely on it. Second, the check says which value you measured and which value it inherited. Then a later reader can tell a proven check from a borrowed one. If a disposable device or a throwaway clone makes the literal measurement cheap, use that instead.

The same inheritance covers a mutation that a review already measured. A ship-task check that mutates code cites the review that ran the same mutation, and the result of that review. It does not run the mutation a third time after the task review and the final review. If the mutated file changed after that review, it runs the mutation again. A fix round or a base merge can cause that change. (lesson: surviving-mutations)

QA keeps its device-only checks. After the base merge, QA looks for a change since the last suite run. A change to a source file, a build configuration file, or a test plan file counts. The platform skill names the file patterns and the command. If the output lists a file, QA runs the suite again. If the output is empty, QA cites the last run.
