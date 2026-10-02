---
name: controller
description: The rules that only the controller of an agentic-delivery run follows, covering dispatch, review seats, estimates, stall watch, tracker steps, ship, merge, report, and retro. Load before a run starts and again after a compaction.
---

# Controller rules

The controller is the session that dispatches agents and coordinates the run. A dispatched agent does not read this skill. The rules for every agent are in the `run-rules` skill, which also defines the terms that this skill uses.

The project file is `.claude/agentic-delivery.md` in the repository of the user. Its front matter holds the keys `platform`, `min_plugin_version`, `base_branch`, `release_branch`, `branch_prefix`, and `protected_branches`. It also holds `docs`, `docs_dir`, `view_globs`, `test_processes`, and `screenshot_branch`. The last keys are `implementer_agent`, `reviewer_agent`, and `qa_agent`. Its body holds the sections Tracker steps, Devices, Accounts, Ask-first areas, and Agents. Read the whole file before the run starts. The ledger folder is `<docs_dir>/<date>-<slug>/`.

Where a rule here says "the gate owner", it means the person who approves the plan and who says merge.

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

Every brief and every resume message that builds or tests names the device by its id from the Devices section. The words "the same device" never stand alone, because a resumed agent cannot tell which device you mean.

A check that compares the base against the head takes its base half in Task 0. Take it from the worktree of the run, before the first task commit. Never take it from a second worktree, because the device claim refuses a second worktree on the device that the run holds.

When a plan injects a seam that has a production default, the task names one test that uses the default. The tests of the fake do not cover the default.

### Agent types for dispatch

Dispatch the agents of this plugin, not `general-purpose`. This overrides any template that hardcodes the agent type. Where a template names a subagent type, use the agent from this table instead:

| Dispatch point | Agent | Project file key |
|---|---|---|
| Implementer, one per task | `implementer` | `implementer_agent` |
| Task review, spec and quality | `reviewer` | `reviewer_agent` |
| Scoped re-review after a fix | `reviewer` | `reviewer_agent` |
| Final whole-branch review | `reviewer` | `reviewer_agent` |
| Spec review at grooming, engineering | `reviewer` | `reviewer_agent` |
| Spec review at grooming, testability | `qa-reviewer` | `qa_agent` |
| Plan review, before the gate | `reviewer` | `reviewer_agent` |

The project file can name a team's own agent for each seat with the keys in the last column. Each key defaults to the plugin's agent. Three rules apply to every dispatch:

- Every brief tells the agent to load the `run-rules` skill and the skill `platform-<platform>`, because a custom agent does not load them by itself.
- If the named agent does not exist, the run stops and names the key. It never falls back to the default, because a silent fallback hides that the team's rules did not apply.
- The prompt body of each template still applies in full.

The type `general-purpose` stays correct for work that is not engineering, such as research, documents, and tidying.

Do not pass a model override on these dispatches. A model passed at dispatch overrides the model in the agent file. Pass a model only for a task that you decided needs a stronger model, and record that decision in the ledger.

## Review seats

Groom the spec before you write the plan. By default, two seats run in parallel. The `reviewer` seat reviews whether the design is right and whether this codebase can carry it. The `qa-reviewer` seat reviews whether anyone can tell that it worked. Merge their findings into one list. Where they disagreed, say so. Do not pick one side without a word. Fix what you can fix, and amend the spec for each fix. At the gate, the gate owner reads one list, not two.

A seat earns its place with knowledge that the other seats do not have, never with a different attitude. Reviewers that differ only in attitude share a knowledge base. Each one misses part of what a single reviewer with the union of their prompts finds, and together they cost more. Do not add a reviewer to be more careful. If a reviewer knows something that the others do not, add it. QA qualifies. A product seat does not, because the gate owner writes the brainstorm and reads the spec.

If the spec changes a screen, brief the skills `design-critique` and `accessibility-review` onto the `reviewer` seat, against the design documents of the project.

Name the seats in the spec header at brainstorm time, beside the estimate, because they are part of the estimate. A feature that changes a screen adds the design review. A documentation-only change can take one seat. If you decide the list late, whoever is available decides it.

### Rulings and fix briefs

Apply the same rubric to your own rulings. Before dispatch, examine each ruling that adds or changes a test. Name a change to production code that makes this assertion fail. If no such change exists, the assertion is decoration, so do not add it.

Material written after the gate carries its failing input, and the re-review runs it. If a fix brief or a ruling adds a check, a figure, or a premise, write the failing input beside it. Include the output measured on that input. The scoped re-review runs that input before it marks the item addressed. Nobody else reviews material that the controller writes after the gate.

Before you rule that a new mechanism replaces an old one, read the callers. Search every call site, and read every test that exercises the mechanism. If a brief pins a test byte-identical, it pins the mechanism of that test too. The ruling then becomes "add the new mechanism", not "replace the old one".

An observation from an implementer outranks the memory of the controller. Never answer an environment question from an agent with an unverified mechanism. Either examine the mechanism, or say "unverified, work around it".

If a dispatched agent returns idle two times, terminate it, but only when the stall watch also reports its worktree idle or its build frozen. An agent whose own build, test, or mutation run still makes progress is not idle, whatever it returns.

When an agent reports that it waits and is not finished, do not dispatch it again and do not wait on it again. Read the verdict from the log yourself. Then finish the work or escalate to a new agent.

A one-line fix is never a known limitation. If you can state the fix of a limitation in one line, do not record it. Give it to the gate owner as a decision. Include the measurement, the proposed value, and the blast radius, so that one word can answer it. This rule does not permit a fix round, because a round costs two seats and every proof that the change runs again.

## Plan review

A reviewer reviews the plan. Its author does not review it alone. In the brief, tell the reviewer to run each command whose output the plan predicts. Also tell the reviewer to make sure that the acceptance criteria of each task can fail.

The plan reviewer does four things, and it does not only read about them. It does all four in one pass over the plan, not one pass each. The review reports what it ran and what it skipped.

1. Typecheck the code of the plan against the platform SDK. Do not build it and do not run it. The implementer compiles and runs the code of the plan, and a build in the review makes every gate slow.
2. Mutate the code that the plan writes with `scripts/mutate.sh`, one time for each task that adds tests. Make sure that a test goes red. Do not mutate the whole tree, and do not mutate every branch that you find. Pick the branch that the acceptance criteria of that task depend on. For each row test, also record whether the test is green before the action that it tests. A test that is already green without the action proves nothing about the action.
3. Run each check that the plan writes against the input that its author thinks the check misses. The plan carries that input beside the check, written at the same time. If a plan arrives without that input, send it back and do not review it. The reviewer runs the input of the author and does not invent more.
4. Read each check for the case where its inputs are missing. The rule about missing inputs is in the `run-rules` skill. This step is reading only, and it costs nothing.

Size the mutation table of each task by what the task adds. On a task whose diff is mostly view code, the table covers the logic that the task adds, for example routing, validation, and state changes. It adds at most eight view mutations, and each row says why it was chosen. A snapshot test already shows a change to a view. A task whose diff is mostly logic keeps the full table. The plan review makes sure that each view task names its sample.

A plan with several view tasks ends them with a visual fix task. The rule for visual findings is in the `run-rules` skill, under review findings. The plan review marks each screen whose visual fixes must stay in their own task, and says why.

The `plan` cost line in the ledger records what this seat costs. The retro copies that line beside the number of fix rounds that the run needed after it.

If the project file names a gate delegate, send the plan to the delegate under the rules of the section Delegated gate. Send the plan commit and the plan review result in one message.

## Estimates

Agree on test data and accounts before execution starts, in the plan header. The Accounts section of the project file is the source. The header states these things:

- The account and environment that QA runs against.
- What QA can create, change, and permanently delete on that account.
- Whether a valid session already exists on the target device. Find out by launching the app.
- Each step that the permission check of the session will deny. Examples are an edit to a protected file and a test run while a script holds a mutation. Another example is an install on a device that holds a signed-in session. The gate owner allows them all in one message at the gate. If a delegate approves the plan, the controller still sends that one request to the gate owner. A peer cannot grant a permission.

"Requires a fresh sign-in, therefore blocked" is a claim to test, not a fact.

Every spec has an estimate, and the retro reports it against the actual result. Put all four parts in the spec header. When the task list exists, refine them in the plan. Change them only after you say so openly:

- A t-shirt size. XS is one task, S is two or three, M is four to six, L is seven to ten, and XL is more than ten. If you can, split an XL ticket. Give the size at spec time, before the breakdown. If a ticket builds its own proof, count that proof as one task. That applies to a test rig, a lint, or a self-test, because every later change runs it again.
- The wall-clock time to done, as a range, from the approval gate to the moment that the pull request is ready.
- A token budget for the whole run, for the controller and the agents together. Build it from seats: one implementer seat for each task, one reviewer seat for each review pass, and the controller. Count every pass, including the spec review, the plan review, each task review, the whole-branch review, and each re-review. State how many fix rounds the figure assumes. Count two fix rounds for each proof task, because proof tasks restart on every edit.
- The number of human touches that you expect. Normally that is one, the approval gate. If a feature needs more, say which touches and why at the start.

Use the estimate as a tripwire. When the elapsed time or the tokens pass the estimate, say so without a prompt. Include what is left and the revised figure. Do not wait for the gate owner to ask.

Count tokens for each distinct agent, and use the final cumulative count of each agent. If you add up the completion notices, you count a resumed agent two times. The actual figure for a run is the sum of the cost lines plus the controller. The first few runs are calibration, so record their numbers anyway.

## The stall watch

Arm a stall watch at dispatch, and keep it armed until every agent returns. Task notifications report completion. They cannot report that progress stopped, so an agent blocked on a hung build stays "running" forever. Two problems occur. In the first, a build freezes and its processor time stops. In the second, an agent does nothing at all, and no build watch can see it.

Use `scripts/stall-watch.sh`. Do not write another watch, because hand-written watches usually fail from the start. Arm one watch for each name in `test_processes`:

    scripts/stall-watch.sh --process <name> --interval 60

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

## Process fixes

Hold process and tooling fixes until after the retro. Make one change, one time, while nobody is in the middle of a task. A running session gets a change to a shared script or an agent definition only after it stops and loads it. So each change costs every live ticket an interruption and a restart.

The exception is narrow. If a defect is breaking the work of a live session at this time, fix it now. Examples are a watch that ignores the signal that stops it and an agent definition that does not load. A third example is a check that passes in a case where it must fail. Everything else waits, including anything that you find while you measure one of those. The test is not the size of the fix or how sure you are. The test is whether the defect harms a session between now and the retro.

While a fix waits, record it in the action items of the retro. If nobody can find a fix at retro time, it was dropped, not deferred.

You never edit plugin files during a run. A fix to a plugin rule or script becomes an action item that names the plugin file, for a pull request to the plugin repository.

## Tracker and pull request

Get the ticket key in the first exchange of the brainstorm, not in the plan header. If the gate owner gave a key in the request, use it. If not, ask. A feature with no ticket is legitimate. In that case, say so and skip every tracker step. Do not guess a key later. After you get the key, put it in the spec header, the plan header, and the pull request body.

The tracker steps are in the section Tracker steps of the project file body. Follow them as written. If no tool reaches the tracker, the run writes the comment text into its report, and the developer posts it.

At the moment that you cut the branch and open the draft pull request, move the ticket to in progress. Do it in the same step as the trail comment. That is the moment that the work becomes visible.

At the moment that you mark the pull request ready, move the ticket to review. Do it in the same step, not as a follow-up.

Resolve every transition from the available transitions of the issue. Do not assume a name. The name of a transition is not its target status. Report the status that the issue is in after the transition.

Stay in this scope and go no further: that one issue, its status only, and the single trail comment. Do not edit the description. Do not change other fields or other issues. Do not move anything to done during the run, because closing a ticket is the decision of the gate owner. If the workflow has no transition to the column that you want, say so. Do not pick a different column.

Reply to every pull request review comment, and start the reply with `Claude said:`. Write one reply for each comment, on the thread of that comment. Never write a summary somewhere else, and never stay silent. A reply says what changed and names the commit that changed it. Otherwise, it says clearly that nothing changed and why. You can disagree without permission. You cannot say nothing.

Leave one trail comment on the ticket, and continue to edit it. Post it as soon as the pull request goes up, and edit it as things change. Never add new comments on top of it. It has the pull request link, four or five lines about the approach, and links to the spec and the plan. Never write into the description of the ticket, which holds the request in the words of the gate owner. Never paste the documents. Link them pinned to a commit SHA, never to a branch, so that the links still resolve after the branch is deleted.

## Ship checklist

The last plan task is always "ship", and these are its steps. They are a dispatched task, not remembered rules. Do the steps in this order. Do not skip a step, and do not defer a step to a line in the pull request description.

1. Make sure that the final whole-branch review passed and that every change after the review is committed.
2. Run every manual check. An unrun check blocks ready-for-review. A "still open" note does not replace the run. Run the check, or ask the gate owner for what unblocks it. Run the checks as an `exploratory-testing` session with a charter and a session log. Save the log as `qa-session-log.md` in the ledger folder, because `scripts/ready-check.sh` reads that name.

   End the log with a tally line in exactly this shape, because step 7 parses it:

       tally: 8 checks, 8 run, 0 unrun, 0 waived

   The line has four numbers, in that order. Any unrun or waived check blocks ready-for-review. Only the gate owner can give a waiver, so a waived count that is not zero means stop and ask. If the gate owner waives a check, write one line for it. Put the line in `progress.md` in the ledger folder, in this shape, and the ready check accepts it:

       waiver: M1 by gate owner on <yyyy-mm-dd>: <reason>

3. Read the spec again against what shipped, and fix any drift.
4. Make sure that the ledger has an entry that names every commit on the branch. Do this after the final push, because at write time the ready check cannot see the commit that you are writing.
5. Take the screenshots again on the final tree, after all the steps above, and push them to the branch that `screenshot_branch` names. Use `scripts/settle-screenshot.swift --capture "<command>"` so that each capture waits for the screen to settle.
6. Rewrite the pull request description.
7. Run `scripts/ready-check.sh`. It must exit 0. Then mark the pull request ready. Do not ask the gate owner.
8. Immediately after that, move the ticket to review, and post or update the trail comment, as the section Tracker and pull request says.
9. If the `brief` skill is installed, hand off in its style. Say that the pull request is ready and what still needs the gate owner.

`scripts/ready-check.sh` covers the things that a machine can prove:

- The base is merged into the branch, and the tree is committed and pushed.
- The ledger names every commit in `<base_branch>..HEAD`.
- The ledger has cost lines for the spec review, the plan review, the final review, and at least one task.
- The QA tally line reads all run, or each waived check has a waiver line from the gate owner.
- The pull request body is a real description.
- If the branch touches a file that matches `view_globs`, the body links screenshots on the screenshot branch.

It skips the screenshot proof on a branch that changes no view. Run it from the checkout that holds the ledger.

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

   Immediately before the merge, make sure that the base is still an ancestor of the branch. Run `git fetch origin` and then `git merge-base --is-ancestor origin/<base_branch> HEAD`. The ready check asks the same question, but it asks at ready. The base can move between ready and the word of the gate owner. If the base moved, merge it into the branch, run the suite again, and say so before you merge the pull request. A clean text merge is not a working tree.
2. Clean up. Delete the remote feature branch. Then check out `base_branch`, pull, prune, and delete each local branch whose own pull request is merged. A branch that git lists as merged but that has no merged pull request stays. A new branch with no commits is an ancestor of its base.

   Never delete a branch in `protected_branches`. Never delete the branch that `screenshot_branch` names, or any branch whose name starts with it. It is usually an orphan branch with no pull request, and it holds the screenshots that pull request bodies link to.

   Remove the worktrees of this run and every build folder of this run, including build folders that sit beside the worktrees. List them with `ls -d .worktrees/<slug>-*` and remove only the paths that the list prints. Stop each stall watch whose roots name a worktree of this run. Do not touch devices that hold a signed-in session, and never remove a worktree that such a device builds from. The Devices section of the project file names them.
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
- The plan review ran, and it left no Critical or Important finding open.

If a condition is false, the gate goes to the gate owner as usual, and the delegate names the condition that failed. The project file can add conditions. It cannot remove one of these five.

A plan that goes to the delegate lists the permissions that it uses and does not ask for them. A peer approval never grants a tool permission, and it never covers a merge. A step that the permission check denies still goes to the gate owner, in one request at the time of the gate. A merge still needs the word of the gate owner.

The delegate records each gate that it holds, with the plan commit and the conditions that it read.

## Report format

The feature report is for the gate owner, who reads it in about one minute, as a person reads a sprint review. Screenshots of the working app carry it. It is not an account of what you built, because that is the retro, and the retro is complete by this time.

1. A lead of one or two sentences: what works now that did not work before, in the words of the gate owner, not the words of the code.
2. One strip for each screen or flow. Put the screenshots side by side in one wide image for each strip. Build the strips with any image tool that is installed on the machine.
3. One line under each strip that says what the gate owner looks at.
4. A short status: what the run does not cover, what was waived, and anything that is still the gate owner's.

Use the screenshots that step 5 of the ship checklist already took again and pushed. Do not take them again.

Do not include before-and-after tables, test counts beyond one line, process detail, a chronology, or a findings list. Each of those belongs in the retro or on the pull request. Deliver the report as a document that the gate owner can open, with the strips inline. Do not deliver it as a wall of chat text.

## Retro format

Every run ends with a retro at `<docs_dir>/retros/<yyyy-mm-dd>-<slug>-retro.md`, in this order and with these headings.

1. Goal. Write two or three sentences on what the run set out to do and whether it landed. Then give the one-line facts: branch, commit range, task count, test count, and what the reviews said.

   Report the spec review by seat. Name the seats that sat, and for each seat, what it found that no other seat found. Write one line for each seat. This is the only evidence that can show whether two seats was the right guess. If a seat contributes nothing unique across three runs, cut it. If a finding continues to arrive late, that is an argument for a seat that does not exist yet.
2. Estimate against actual. Give a table with four rows: t-shirt size, wall-clock time, tokens, and human touches. Give the estimate, the actual, and the difference for each row. The actual tokens are the sum of the cost lines in the ledger, plus the controller where you measured it. Do not count again from the completion notices. Then write one or two sentences on where the difference went. Name the specific cause, not "unexpected issues".

   Split the actual human touches into three counts, and name each touch in a few words:

   - Steering: the gate owner made a product, design, or scope decision, or approved a gate.
   - Permission: the gate owner allowed a step that the permission check denied. The plan header lists these, so a touch here that the header did not list is a gap in the plan.
   - Rescue: the gate owner noticed or fixed something that the run must catch itself. Examples are a stalled turn, a hung build, and an unchecked claim.

   Write it as one line, for example `touches: steering 1, permission 2, rescue 1`.

   Add one line for the plan review: copy its `plan` cost line, and give the number of fix rounds that the run then needed. That seat runs the plan and does not only read it.
3. Score, 1 to 4. Give one sentence of justification. Score the run, not the feature.
   - 1: the run did not land, or it needed rescue throughout.
   - 2: the run landed, but with significant rework or human help beyond the agreed gates.
   - 3: the run landed with ordinary friction, and review caught the defects, not the gate owner.
   - 4: the run landed clean. The run caught defects before review and needed no help beyond the agreed gates.
4. What went well. Give each item with the evidence that it worked. If something carried the run, name it so that the next run keeps it.
5. What to improve. Write one entry for each problem: what happened, the root cause, and the change that removes it. Say clearly whose error it was, including errors of the controller. Order the entries by what the problem cost, heaviest first. Anything that damaged work outside this run goes first, whatever its size.
6. Waivers. List each ship checklist step that did not run as written, who agreed to waive it, and when. If there were no waivers, say so in one line. A deferred manual check is a waiver.
7. Action items. These are proposals, and the triage belongs to the gate owner. Say so at the top. Then, for each item, say what changes, which plugin file it belongs in, and who does it. The run never edits plugin files. A rule change becomes an action item that names the plugin file, and it goes to the plugin repository as a pull request.
   - Prefer a mechanism to a rule. An armed watch, a check that runs, and a script that aborts are better than a sentence that someone must remember at the right moment. Say what the mechanism makes unnecessary.
   - An amendment is not an addition. If an existing rule covers the ground and was wrong or incomplete, say which rule and how it must read.
   - Rank the items, and say which items you recommend that the gate owner drops.

   A retro proposes from inside one run, so it cannot see what an item costs on every later run. Ask how often the case occurs and what the item costs where it does not occur. An item measured one time is a candidate, not a finding. A single incident is rarely a rule.
8. Optional chronology. If the action items already cite their incidents, skip it. Otherwise, add one table at the end.

Before you write down a claim, examine it against the repository or the ledger. Mark inline where the raw account did not pass that test. That includes the figures of the retro itself, because counts written from memory are often wrong. A run with one real problem has a short retro.

### The retro notice

The plugin ships a hook. When a retro file is written, the hook reminds the run to propose each rule change as a pull request to the plugin repository. The run also names the retro and its action item count in its handoff.
