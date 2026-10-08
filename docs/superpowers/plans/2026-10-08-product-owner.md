# Product Owner seat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an optional Product Owner seat to the plugin: one skill, seven project file keys, two controller hooks, and a ready-ticket input to the feature command.

**Architecture:** The PO is a separate session that loads the new `product-owner` skill. It talks to the run only through the tracker and through messages. The controller sends it two lines for each run, and the feature command reads its ready ticket. No script changes.

**Tech Stack:** Markdown skills and commands, bash tests, the private name guard.

**Spec:** `docs/superpowers/specs/2026-10-08-product-owner-design.md`

## Global Constraints

- All text is Simple English: short sentences, active voice, no contractions, no semicolons, no em-dashes, no emoji, no bold in prose.
- The repository carries no names of the source project. The private name guard, `$GUARD .`, exits 0. The process session holds its path.
- `bash tests/run-all.sh` exits 0.
- Every line is necessary: add no rule that no spec item asks for.
- Commit trailer: `Co-Authored-By: Claude <noreply@anthropic.com>`.
- Commit on `feature/product-owner` only. Push only after the user says so in chat.
- The lint helper is `$LINT <file>`, the plain-English lint that the process session holds. A `trailing_condition` hit in descriptive text is advisory. Fix every `sentence_over_limit`, `banned_modal`, and `synonym_rotation` hit in new text.

## Review Focus

1. `po` is empty or missing: the feature command, the controller, and the retro behave exactly as in 0.2.0. Owned by Task 3, step 4.
2. Sprint mode with `size_tokens`, `sprint_tokens`, or `sprint_days` empty: the PO stops sprint planning, names the key, and asks. Grooming still runs. Owned by Task 1 and the dry read in Task 5.
3. A key with a value outside its list, for example `po_authority: everything`: the PO stops and names the key. Owned by Task 1.
4. A ticket larger than M at sizing: it goes back to the PO for a split and stays out of the sprint. Owned by Task 5, fixture ticket P-3.
5. An open question with no ship default: the ticket is not ready, and the question goes to the gate owner in one batched message. Owned by Task 5, fixture ticket P-5.

---

### Task 1: The product-owner skill

**Files:**
- Create: `skills/product-owner/SKILL.md`
- Modify: `docs/superpowers/specs/2026-10-08-product-owner-design.md` (one sentence in Sprint planning step 4)

**Interfaces:**
- Produces: the skill name `product-owner`, the seven ready-ticket field names (Goal, User value, Metric, Acceptance, Out of scope, Open questions, Size), and the key names `po`, `delivery_mode`, `po_grooming`, `po_authority`, `sprint_days`, `sprint_tokens`, `size_tokens`. Tasks 2, 3, and 4 use these names exactly.

- [ ] **Step 1: Write the skill**

Create `skills/product-owner/SKILL.md` with this content:

````markdown
---
name: product-owner
description: The rules for the Product Owner session of an agentic-delivery project, covering the ready ticket, grooming, sprint planning, and replan. Load at the start of the Product Owner session and again after a compaction.
---

# Product Owner rules

You are the Product Owner (PO) of this project. The key `po` in the project file `.claude/agentic-delivery.md` names you. Read the whole project file before the first pass. If `po` is empty, or if it names another session or person, stop and say so.

## Terms

- Lead: the engineering lead. It is the gate delegate if the Agents section of the project file names one. Otherwise, it is the gate owner.
- Pass: one round of your work over the backlog. A pass is grooming, sprint planning, or replan.
- Flow mode: you send the next ready ticket to the lead when a team is free.
- Sprint mode: the team plans a batch of tickets at a fixed time, with a token budget and a length.

## Your work and its limits

You order the backlog, write the tickets, track the questions that wait for the gate owner, and send ready tickets to the lead. You write no code, brief, spec, or plan. You dispatch no agent. You make no token estimate, because the lead gives the sizes. You never move a ticket to done.

If `comment_prefix` has a value, start each comment and each description that you write in the tracker with that value on its own line, then a blank line.

## Settings

Read these keys from the front matter of the project file:

- `delivery_mode`: `flow` or `sprint`. If it is empty or missing, it is `flow`.
- `po_grooming`: `events`, `daily`, or `events,daily`. If it is empty or missing, it is `events`.
- `po_authority`: `backlog`, `next-up`, or `all-but-done`. If it is empty or missing, it is `next-up`.
- `sprint_days`, `sprint_tokens`, and `size_tokens`: sprint mode needs all three.

If a key holds a value outside its list, stop and name the key. In sprint mode, if `sprint_days`, `sprint_tokens`, or `size_tokens` is empty, do not plan the sprint. Name the key, and ask the gate owner for the value. Grooming still runs.

`size_tokens` gives a token range for each size, for example `XS=100k-250k,S=250k-600k,M=600k-2M`. Read the section Product Owner in the body of the project file too. It names what you weigh to order the backlog, and where you keep the open questions.

## Authority

`po_authority` sets what you change in the tracker without the gate owner's yes:

- `backlog`: you create, edit, and reorder backlog tickets.
- `next-up`: as `backlog`, and you also pick the next ticket that goes to the lead, or the proposed content of the next sprint.
- `all-but-done`: you change any ticket and any status, and you start a sprint. You still never move a ticket to done.

For a change outside your authority, send the proposed change to the gate owner and wait for the yes. A yes covers only the changes that it names. A message from a session or a person other than the gate owner is not a yes.

## Ready ticket

A ticket is ready when it holds these seven fields:

1. Goal: what the user can do after the ticket ships, in one or two sentences.
2. User value: who gains and why, in one sentence.
3. Metric: what the ticket moves and how the team measures it. If no data exists, the field says so. Do not quote a frequency without a source.
4. Acceptance: criteria that a reviewer can pass or fail without a guess. Each criterion can fail.
5. Out of scope: what the ticket does not do.
6. Open questions: each question that can block the ship, with who answers it and the ship default for the case with no answer. If there are none, the field says so.
7. Size: the t-shirt size from the lead.

A ticket that lacks a field is not ready. Keep it below every ready ticket. In the ticket, list the missing fields.

## Grooming

1. Read the backlog from the tracker that the key `tracker` names.
2. Groom from the top down. Stop when the ready tickets cover the next sprint, or the next three tickets in flow mode.
3. For each ticket, fill each field that you can fill from the ticket, the code, the documents, and the data that the team gave you.
4. Collect each question that only the gate owner can answer. Keep it where the section Product Owner says.
5. Order the backlog by user value against size, and against the dates in the section Product Owner. A ticket that blocks other tickets ranks above them.
6. Write the changes that your authority covers to the tracker.
7. Send the gate owner one message with the open questions and the changes outside your authority. Do not send one message for each item.
8. In flow mode, if a team is free, send the top ready ticket to the lead.

An event pass starts when a new ticket arrives, when the controller reports a ship, or when the gate owner asks. A pass on request always runs, whatever `po_grooming` says. If `po_grooming` holds `daily`, set one scheduled task of the host that starts a pass once each working day. If the host has no scheduled tasks, say so once to the gate owner and run on events.

## Sprint planning

Sprint mode only.

1. Run a grooming pass.
2. Send the top ready tickets to the lead, in order, until the upper bounds of their sizes pass `sprint_tokens` by about half. Send a ticket that has no size yet in the same list.
3. The lead sizes each ticket with a size-only read. It reads the ticket and the files that the ticket touches. It writes the size in the ticket and writes no brief and no plan. If a ticket is larger than M, the lead says so. Then split the ticket by what a user sees, and keep the parts out of this sprint until the lead sizes them.
4. Take tickets from the top, and add the upper bound of each size. Stop before the ticket that takes the total past `sprint_tokens`, or the work past `sprint_days`. That is the cut-off.
5. Write the sprint goals from the tickets above the cut-off, one line each.
6. Send the sprint to the gate owner for approval. After the yes, start the sprint in the tracker. With `all-but-done`, start it without the approval.

At the end of a sprint, write one line for each sprint goal: met or not met. Also write the tokens used against `sprint_tokens`. The lead proposes new `size_tokens` ranges from the retros of the sprint. The gate owner approves each edit to the project file.

## Replan

A replan starts when the controller reports an overrun, a stall, or a blocker, or when an urgent ticket arrives.

1. Name each sprint goal at risk. In flow mode, name each next-up ticket at risk.
2. Order the tickets again, and propose a swap to the lead. An example is to drop the lowest ticket so that the urgent ticket fits the budget.
3. The lead confirms the sizes and the capacity, or gives new sizes.
4. Move a ticket in or out of a started sprint only with `all-but-done`, or with the gate owner's yes. In flow mode, change the next-up list within your authority.

## Messages

The controller of each run sends you at most two lines: one at ship, and one at the first overrun, stall, or blocker of the run. Each line starts an event pass or a replan.

Send the lead only what it acts on: a ready ticket in flow mode, the candidate list in sprint mode, or a swap proposal. Put more than one item in one message.
````

- [ ] **Step 2: Add the upper-bound rule to the spec**

In the spec, section Sprint planning, replace step 4:

```
4. The PO takes tickets from the top. It stops before the ticket that takes the total past
   `sprint_tokens`, or the work past `sprint_days`. That is the cut-off.
```

with:

```
4. The PO takes tickets from the top and adds the upper bound of each size range. It stops before
   the ticket that takes the total past `sprint_tokens`, or the work past `sprint_days`. That is the
   cut-off.
```

- [ ] **Step 3: Lint and guard**

Run: `$LINT skills/product-owner/SKILL.md` and fix each hit that the Global Constraints name.
Run: `$GUARD .`
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add skills/product-owner/SKILL.md docs/superpowers/specs/2026-10-08-product-owner-design.md
git commit -m "Add the product-owner skill

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 2: The project file template

**Files:**
- Modify: `templates/agentic-delivery.md` (front matter, the Keys list, a new body section after Agents)

**Interfaces:**
- Consumes: the key names from Task 1.

- [ ] **Step 1: Add the keys to the front matter**

After the line `qa_agent: agentic-delivery:qa-reviewer`, add:

```
po:
delivery_mode: flow
po_grooming: events
po_authority: next-up
sprint_days:
sprint_tokens:
size_tokens:
```

- [ ] **Step 2: Add the key bullets**

At the end of the Keys list, after the bullet that starts with `` - `implementer_agent`, `reviewer_agent`, and `qa_agent` ``, add:

```
- `po` names the Product Owner, as a session id or a person's name. It is optional. If it is empty, the team has no Product Owner, and the run works as it does without one. The Product Owner session loads the skill `product-owner`.
- `delivery_mode` is `flow` or `sprint`. In flow mode, the Product Owner sends the next ready ticket to the lead when a team is free. In sprint mode, the team plans a batch of tickets at a fixed time.
- `po_grooming` sets when the Product Owner grooms the backlog by itself: `events`, `daily`, or `events,daily`. The events are a new ticket and a ship. The Product Owner also grooms whenever the gate owner asks.
- `po_authority` sets what the Product Owner changes in the tracker without the gate owner's yes. Its value is `backlog`, `next-up`, or `all-but-done`. The skill `product-owner` defines each value.
- `sprint_days` is the length of a sprint in working days. Sprint mode needs it.
- `sprint_tokens` is the token budget of one sprint, for example `6M`. Sprint mode needs it.
- `size_tokens` gives a token range for each t-shirt size, for example `XS=100k-250k,S=250k-600k,M=600k-2M`. Sprint mode needs it. It is empty in this file, because each team measures its own ranges from its retros.
```

- [ ] **Step 3: Add the body section**

After the Agents section, at the end of the file, add:

```
## Product Owner

Fill in this section only if `po` names a Product Owner. Name what the Product Owner weighs to order the backlog, for example the next release date or a customer promise. Name where the Product Owner keeps the open questions for the gate owner, for example a page in the tracker.
```

- [ ] **Step 4: Lint, guard, and test**

Run: `$LINT templates/agentic-delivery.md`, the name guard, and `bash tests/run-all.sh`.
Expected: no new hit of the kinds that the Global Constraints name, and both commands exit 0.

- [ ] **Step 5: Commit**

```bash
git add templates/agentic-delivery.md
git commit -m "Add the Product Owner keys to the project file template

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 3: The controller and the feature command

**Files:**
- Modify: `skills/controller/SKILL.md` (sections Estimates and Retro format, and a new section after Messages to other sessions)
- Modify: `commands/feature.md` (step 1)

**Interfaces:**
- Consumes: the key `po` and the field names from Task 1.

- [ ] **Step 1: Add the section Product Owner messages**

In `skills/controller/SKILL.md`, after the section Messages to other sessions and before the section Process fixes, add:

```
## Product Owner messages

This section applies only if the key `po` in the project file names a Product Owner. Send the Product Owner one line after step 9 of the ship checklist: the ticket id, the pull request, and the actual tokens against the estimate. Send it one line at the first overrun, stall, or blocker of the run, when you tell the gate owner: the ticket id, what happened, and the revised estimate. Send the Product Owner no other message. A later overrun goes only to the gate owner. These two lines stay within the limit of the section Messages to other sessions.
```

- [ ] **Step 2: Add the planning size to Estimates and Retro format**

In the section Estimates, at the end of the bullet that starts with `- A t-shirt size.`, add:

```
 If the lead sized the ticket at sprint planning, that size is the starting size. If the run gives another size, the spec header names both.
```

In the section Retro format, item 2, after the sentence that ends `Do not count again from the completion notices.`, add:

```
 If the lead sized the ticket at sprint planning, the size row also names that size.
```

- [ ] **Step 3: Read the ready ticket in the feature command**

In `commands/feature.md`, step 1, after the sentence `Never guess an id.` and before `Size the ticket`, add:

```
If the key `po` names a Product Owner and the ticket holds the goal, user value, metric, acceptance, out of scope, and open questions, take each one from the ticket. Ask the developer only for a field that is missing.
```

Keep the line wrap of the step at about 100 columns, as the file does.

- [ ] **Step 4: Check the empty-po path**

Run: `grep -n "po\`" skills/controller/SKILL.md commands/feature.md`
Expected: each new rule that names `po` opens with the condition that `po` names a Product Owner. No other line changed. Run `git diff --stat` and make sure that only the two files changed.

- [ ] **Step 5: Lint, guard, test, and commit**

Run the lint on both files, the name guard, and `bash tests/run-all.sh`.

```bash
git add skills/controller/SKILL.md commands/feature.md
git commit -m "Send the Product Owner two lines and read its ready ticket

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 4: README and version 0.3.0

**Files:**
- Modify: `README.md`
- Modify: `.claude-plugin/plugin.json:5`, `.claude-plugin/marketplace.json:13`
- Modify: `templates/agentic-delivery.md:3`

- [ ] **Step 1: Update the role table row**

Replace:

```
| Product owner | Set the acceptance rules, read the report | A one-minute report with screenshots |
```

with:

```
| Product owner | Order the backlog, or name a Product Owner session that does it | Ready tickets, a sprint plan, and a one-minute report |
```

- [ ] **Step 2: Update the Product owner details block**

Replace the first line of the block, `You decide what a feature must do and how it must look.`, with:

```
You decide what a feature must do and how it must look. You can also name a Product Owner session
in the project file, which grooms and orders the backlog for you.
```

At the end of the bullet list of the block, add:

```
- With a Product Owner session, the run starts from a ready ticket: goal, user value, metric,
  acceptance, out of scope, open questions, and size. The run asks the engineer only for a field
  that is missing.
- In flow mode, the Product Owner sends the next ready ticket when a team is free. In sprint mode,
  it plans a batch with the lead. The lead gives each ticket a t-shirt size, and the sprint takes
  tickets until the token budget is full.
- When a run passes its estimate, stalls, or finds a blocker, the Product Owner replans with the
  lead.
```

- [ ] **Step 3: Update the file tree and the skills table**

In the tree under What is inside, after the line `skills/controller/       the rules for the session that runs the pipeline`, add:

```
skills/product-owner/    the rules for an optional Product Owner session
```

In the skills table, after the `agentic-delivery:run-rules` row, add:

```
| `agentic-delivery:product-owner` | The rules for an optional Product Owner session: ready ticket, grooming, sprint planning, and replan | The Product Owner session loads it at start, and again after a compaction |
```

- [ ] **Step 4: Bump the version**

Run: `grep -rn "0\.2\.0" .claude-plugin README.md templates`
Change each hit to `0.3.0`, including the tag examples `v0.2.0`. Make sure that the grep finds no hit afterwards.

- [ ] **Step 5: Lint, guard, test, and commit**

Run the lint on `README.md`, the name guard, and `bash tests/run-all.sh`.

```bash
git add README.md .claude-plugin/plugin.json .claude-plugin/marketplace.json templates/agentic-delivery.md
git commit -m "Describe the Product Owner seat and bump the version to 0.3.0

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 5: Dry read against a sample backlog

**Files:**
- Create: `tests/fixtures/product-owner/backlog.md`
- Create: `tests/fixtures/product-owner/agentic-delivery.md`

**Interfaces:**
- Consumes: the skill from Task 1 and the keys from Task 2.

- [ ] **Step 1: Write the sample project file**

Create `tests/fixtures/product-owner/agentic-delivery.md`:

```
---
tracker: none
po: Product Owner session
delivery_mode: sprint
po_grooming: events
po_authority: next-up
sprint_days: 5
sprint_tokens: 2M
size_tokens: XS=100k-250k,S=250k-600k,M=600k-2M
---
## Agents

No gate delegate. The gate owner is the lead.

## Product Owner

The next release is on 2026-11-01. Keep the open questions in the file questions.md beside the backlog.
```

- [ ] **Step 2: Write the sample backlog**

Create `tests/fixtures/product-owner/backlog.md`:

```
# Backlog of a recipe app, in tracker order

## P-1 Search recipes by ingredient
Goal: a user types an ingredient and sees each recipe that uses it.
User value: home cooks find a recipe for what they already have.
Metric: share of sessions with a search. No data exists yet.
Acceptance: a search for "egg" lists each recipe with egg, and no other recipe. An empty search shows the full list.
Out of scope: search by tag.
Open questions: none.
Size: S

## P-2 Share a recipe link
Goal: a user shares a link that opens the recipe.
User value: cooks send recipes to friends.
Acceptance: the link opens the recipe on a device with the app.
Size: S

## P-3 Offline mode for saved recipes
Goal: saved recipes open with no network.
User value: cooks use recipes in a kitchen with a weak signal.
Metric: share of recipe opens that fail. 4% in the last 30 days.
Acceptance: a saved recipe opens in airplane mode, with its photo.
Out of scope: offline search.
Open questions: none.
Size: L

## P-4 Fix the crash when a recipe has no photo
Goal: a recipe with no photo opens.
User value: every recipe opens.
Metric: crash count on the recipe screen. 120 in the last 7 days.
Acceptance: a recipe with no photo opens and shows the placeholder.
Out of scope: photo upload.
Open questions: none.
Size: XS
Blocks: P-5

## P-5 Recipe photo gallery
Goal: a user swipes through all photos of a recipe.
User value: cooks see each step.
Metric: photo views for each recipe open. No data exists yet.
Acceptance: a recipe with three photos shows three pages.
Out of scope: photo upload.
Open questions: how many photos at most? The gate owner answers.
Size: M
```

- [ ] **Step 3: Dispatch the dry read**

Dispatch one `general-purpose` agent with this prompt:

```
Read skills/product-owner/SKILL.md and follow it as the Product Owner. The project file is tests/fixtures/product-owner/agentic-delivery.md and the backlog is tests/fixtures/product-owner/backlog.md, both under the repository root <repo>. The tracker is the backlog file, but write nothing to any file. You are the lead too, so the sizes in the backlog stand. Run one grooming pass and then sprint planning. Report: the order of the backlog after grooming, the fields that you filled and the fields that stay missing, the one message that you would send to the gate owner, the cut-off with the running total, and the sprint goals. For each step, quote the rule of the skill that you applied. If a rule was unclear or did not cover a case, say which rule and what you did.
```

- [ ] **Step 4: Check the output**

The output passes if each of these holds:
- P-4 ranks above P-5, because P-4 blocks P-5.
- P-3 stays out of the sprint, and the output asks for a split, because L is larger than M.
- P-5 is not ready, because its open question has no ship default. The question goes into the one message to the gate owner.
- P-2 either gets its metric, out of scope, and open questions filled by the PO, or lists them as missing. It does not enter the sprint without them.
- The cut-off adds upper bounds: P-4 at 250k and P-1 at 600k give 850k. Any further ready ticket fits only if the total stays at or under 2M.
- No step needed a rule that the skill lacks. If the output names an unclear rule, fix the skill text in Task 1's file, commit, and run the dry read again.

- [ ] **Step 5: Commit the fixtures**

```bash
git add tests/fixtures/product-owner
git commit -m "Add the sample backlog for the Product Owner dry read

Co-Authored-By: Claude <noreply@anthropic.com>"
```

### Task 6: Final review and pull request

- [ ] **Step 1: Run every check**

Run: `bash tests/run-all.sh` and the name guard. Expected: both exit 0.

- [ ] **Step 2: Whole-branch review**

Dispatch one reviewer over `git diff main...feature/product-owner` with the spec and this plan. It reports Critical, Important, and Minor findings against the spec and the Review Focus list. Fix each Critical and Important finding, and commit.

- [ ] **Step 3: Push and open the pull request**

Ask the user in chat for the word to push. After the yes, push in the background, because the pre-push hook runs the tests, and open a pull request against `main`. The body starts with `Claude Agentic Process Manager said: ` and states the behavior before and after.
