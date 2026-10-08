---
description: Run the spec-driven pipeline for a feature, from brainstorm through code review
argument-hint: <short feature description>
---

Feature: $ARGUMENTS

Run the spec-driven pipeline of this repository from start to end. The project `CLAUDE.md` is already
in your context, so do not open it again.

0. Read `.claude/agentic-delivery.md`. If it is missing, stop. Offer to copy the file
   `templates/agentic-delivery.md` of the plugin into the project, and wait for the answer. If the file
   exists, check these keys first: `platform`, `base_branch`, `release_branch`, `branch_prefix`,
   `protected_branches`, `docs`, `docs_dir`, `view_globs`, `screenshot_branch`, and `tracker`. If one
   is empty or missing, stop. The one exception is `screenshot_branch` on GitLab, which can stay empty,
   because a merge request takes uploaded images. Ask the developer for each empty key, and write the
   answers into the project file only after the developer agrees. Never guess a value from the branches
   or the folders that you see. When you ask for `base_branch` or `release_branch`, show each
   candidate branch on `origin` with the date of its last commit, from
   `git log -1 --format=%cs origin/<branch>`. Never take `origin/HEAD` as the answer by itself. It can
   point to a branch that the team no longer uses. The key `push_policy` can be missing, and then it
   is `each-task`. If it holds a value other than `each-task` or `mr-and-ship`, stop and name the key.
   Next, make sure that the skills `superpowers:brainstorming`, `superpowers:writing-plans`,
   `superpowers:subagent-driven-development`, and `superpowers:requesting-code-review` are
   available. If one is missing, stop and tell the developer to install the superpowers plugin,
   because steps 1, 3, 5, and 6 need these skills. Do not do those steps without them.
   Then load the `controller` skill and the `run-rules` skill. Then load `platform-<platform>`,
   with the `platform` key of the project file. Read the controller skill again after a compaction.

Documents. Every spec, plan, ledger, and retro goes under `docs_dir`. It never goes under the
default folder of a superpowers skill, such as `docs/superpowers/specs/`. If `docs` is
`private`, never commit or push one of these documents, even where a superpowers skill says to
commit it. A `docs_dir` that starts with `~/` is under the home folder of the developer. If `docs` is
`private` and the project file has a section Docs publishing, `controller`, Docs publishing says
when the run publishes a copy of a document to the wiki.

Agents. Take each agent from the project file: `implementer_agent`, `reviewer_agent`, and `qa_agent`.
The defaults are the plugin agents `implementer`, `reviewer`, and `qa-reviewer`. If a key names an
agent that does not exist, stop and name the key. Never fall back to the default. Never dispatch
`general-purpose`, and pass no model override. Every brief tells the agent to load `run-rules` and
`platform-<platform>`.

The gate is the developer who runs the feature. If `controller`, Delegated gate applies, the
delegate holds the gate instead.

If a brief or an M document for this feature already exists under `docs_dir`, skip to step 5 and
resume from its ledger.

1. Brainstorm with the developer, using `superpowers:brainstorming`. This is the one conversational
   stage. Ask real questions and push back on vague answers. Establish the ticket id in the
   first exchange, in the form of the tracker that `tracker` names. If the developer gives none, ask.
   If there is no ticket, or `tracker` is `none`, say so and skip every tracker step. Never guess an
   id. Size the ticket, and add the estimate: size, wall-clock range, token budget, and the number
   of times you expect to need the developer. `controller`, Estimates defines all four. If the run
   passes them, tell the developer at that time.
1b. Pick the path by size, as `controller`, Size decides the process says. The developer can name a
   different path for this ticket.
   - XS or S that meets the conditions in `controller`, Lite mode: lite mode. Write the
     brief under `docs_dir`, with the id and the estimate in its header, and do step 2. Skip step 3,
     and at step 4 show the brief. At step 5, do the work yourself from the brief, tests first, with
     no implementer. At step 6, run one final review. Steps 6b to 9 do not change.
   - M, or an XS or S ticket that fails a lite condition: the M path, from step 2.
   - Larger than M: stop. Propose a split into tickets of size M or smaller, sliced by what a user
     sees, and wait for the answer.
2. Create the branch with `branch_prefix` and a slug, from `base_branch`. If `docs` is `repo`,
   commit the brief or the document, push it, and open a draft pull request against `base_branch`.
   If `docs` is `private`, wait for the first task commit. Then push the branch and open the draft
   pull request, because the branch has no commit of its own before then. Fill in the description
   template of the forge, as `controller`, Tracker and pull request says. In the same step, work
   the tracker steps in the project file: move the ticket to in progress and post the trail comment.
   `controller`, Tracker and pull request describes both.
3. Write the M document with `superpowers:writing-plans`, under `docs_dir`. It holds the spec and the
   plan in one file, in the shape that `controller`, The M document and its review gives. Then
   dispatch one reviewer against it, with the QA questions in the brief, and fix its findings before
   the developer sees it. Do not review it yourself. For the rule on a second seat, read `controller`,
   Review seats.
4. Stop. Show the developer the task list and the risks. Also show every step that the permission
   system will deny, as the document header lists them, so that the developer allows them all in
   one answer. Wait for approval. This is the only gate. If a delegate approves the document, still
   send that one permission request to the developer, because a delegate cannot grant a permission.
5. After approval, execute the document with `superpowers:subagent-driven-development`. Keep the
   ledger in `docs_dir`, as `run-rules`, The ledger describes. Begin it with a conflict scan, and let
   the scan decide which tasks run in parallel waves. Dispatch the implementer for each coding task.
   If a task touches a server contract or pattern-matching code, dispatch a reviewer after it.
   Commit after each task, and push at the times that `push_policy` names. `controller`, Pushes
   gives the rule. For each new test, the implementer reports one red run and one green run on its own acceptance branch, with the branch named. If a report lacks them, send the
   task back. Every fix brief and ruling that you write after the gate carries the failing input for
   each check, figure, or premise in it. The scoped re-review runs that input before it marks the
   item addressed. When a phase ends, write its cost line in the ledger. `run-rules`, The ledger
   names the phases, and `scripts/ready-check.sh` refuses a ledger without them. In this command,
   `scripts/...` means the `scripts` folder of the plugin, not a folder of the project. The start-up
   pointer gives its full path. Do not stop for approval between tasks.
   If the run passes the estimate or hits a stall, say so at that time.
6. Run `superpowers:requesting-code-review` for each focused task review, and over the whole branch
   when the final task lands. Critical and Important findings block, with one fix wave and one
   re-review for each wave. A fix wave that changes only documents gets no re-review. If the fix of
   a Minor finding is one line and needs no new device run, no new proof run, and no re-review,
   make it. Put everything else under Follow-ups in the pull request description and in the ledger.
   The final review gets one fix wave and one re-review, and then the ticket ships. Answer every
   review comment on its own thread. Use the comment prefix that `controller`, Tracker and pull
   request gives, and name the commit that addressed it. If `comment_prefix` is empty, the prefix is
   `Claude said:`. `run-rules`, Review findings gives the rules.
6b. Work the ship checklist in `controller`, Ship checklist, in order, as the last task of the
   plan. Do not work from memory. If a ship step mutates code, cite the review that ran the same
   mutation and its result. If the file changed after that review, run the mutation again.
7. Hand off once, as the last step of the ship checklist, in the format of `controller`, Report
   format. By then the pull request is already marked ready, because `scripts/ready-check.sh`
   decides that and not the developer. Do not ask first. Say what shipped, what the review found,
   that you read the spec again, that the final review passed, and what still needs the developer.
   This is the handoff and not the feature report. Its purpose is to tell the developer that it is
   the developer's turn. The feature report comes after the merge.
8. Write the retro under `docs_dir`, in the format of `controller`, Retro format. Lead with the
   estimate against the actual. Do not edit any plugin file. Propose each rule change as an action
   item that names the plugin file where it belongs, for a pull request to the plugin repository.
9. Wait. The run is not finished. When the developer says merge, work the steps in `controller`,
   When the gate owner says merge, in order and without asking again. Do not merge because the
   branch looks ready. Reaching ready for review is not permission to merge. Merge stays with the
   gate owner, and it is the only gate after the plan.
