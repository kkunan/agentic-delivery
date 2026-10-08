# The Product Owner seat: design

Date: 2026-10-08. Status: draft for review.

This file adds an optional Product Owner seat to the plugin design in
`2026-10-02-agentic-delivery-design.md`. It does not change that file.

## Goal

A team can name a Product Owner session in the project file. That session grooms and orders the
backlog by itself, plans a sprint with the engineering lead when the team works in sprints, and
replans when a run goes wrong. A run then starts from a ready ticket, so the feature command asks
the developer only for what the ticket lacks.

The seat is smaller than a product manager. It does not decide what to build from research. Product
discovery is out of scope.

## Terms

- Product Owner (PO): the session or person that the key `po` names.
- Lead: the engineering lead. It is the gate delegate when the Agents section names one, and the gate
  owner otherwise.
- Ready ticket: a ticket that holds every field in the section Ready ticket.
- Pass: one round of PO work over the backlog: grooming, planning, or replan.
- Flow mode: the PO sends the next ready ticket to the lead when a team is free.
- Sprint mode: the team plans a batch of tickets at a fixed time, with a token budget and a length.

## Decisions

1. The seat is one skill, `skills/product-owner/SKILL.md`. The PO session loads it at start and
   after a compaction. The controller and the agents do not load it.
2. The seat is optional. If `po` is empty or missing, the plugin works as it does today.
3. The PO writes no code, brief, spec, or plan. It dispatches no agent. It never moves a ticket to
   done.
4. The PO grooms in both modes. The key `po_grooming` sets when a pass starts by itself. A pass on
   request from the gate owner always works.
5. The key `po_authority` sets what the PO changes in the tracker without the gate owner's yes. The
   default is `next-up`.
6. Sprint planning uses t-shirt sizes, not token estimates. The lead sizes each candidate ticket with
   a size-only read. The token estimate stays at the start of the run, in the brief or the M
   document, so a run spends planning tokens only on tickets that a sprint or the flow takes.
7. Each size maps to a token range in the key `size_tokens`. The retros record the estimate against
   the actual for each run, and the lead proposes new ranges from them.
8. The controller tells the PO about a ship and about the first overrun, stall, or blocker of a run.
   These messages start the event passes.

## Settings

The template gains these optional front matter keys. Each value is plain text, as the template says.

- `po`: the PO, as a session id or a person's name. Empty means no PO.
- `delivery_mode`: `flow` or `sprint`. The default is `flow`.
- `po_grooming`: `events`, `daily`, or `events,daily`. The default is `events`.
- `po_authority`: `backlog`, `next-up`, or `all-but-done`. The default is `next-up`.
- `sprint_days`: the sprint length in working days. Sprint mode needs it.
- `sprint_tokens`: the token budget of one sprint, for example `6M`. Sprint mode needs it.
- `size_tokens`: a token range for each size, for example `XS=100k-250k,S=250k-600k,M=600k-2M`.
  Sprint mode needs it. The template leaves it empty, because each team measures its own.

The template body gains a section Product Owner. In it, the team names what the PO weighs to
order the backlog, for example the next release date. It also names where the PO keeps the open
questions.

The values of `po_authority`:

- `backlog`: the PO creates, edits, and reorders backlog tickets. It asks the gate owner before any
  other change.
- `next-up`: as `backlog`, and the PO also picks the next ticket that goes to the lead, or the
  proposed content of the next sprint.
- `all-but-done`: the PO changes any ticket and any status, and starts a sprint, but never moves a
  ticket to done.

## Ready ticket

A ticket is ready when it holds these fields. The PO writes them in the ticket.

1. Goal: what the user can do after the ticket ships, in one or two sentences.
2. User value: who gains and why, in one sentence.
3. Metric: what the ticket moves and how the team measures it. If no data exists, the ticket says
   so. The PO does not quote a frequency without a source.
4. Acceptance: criteria that a reviewer can pass or fail without a guess. Each criterion can fail.
5. Out of scope: what the ticket does not do.
6. Open questions: each question that can block the ship, with who answers it and the ship default
   for the case with no answer.
7. Size: the t-shirt size from the lead, when the lead sized it.

A ticket that lacks a field is not ready. The PO lists the missing fields and the questions only the
gate owner can answer, and keeps the ticket below every ready ticket.

## The grooming pass

1. Read the backlog from the tracker that `tracker` names.
2. For each ticket near the top, fill each field that the PO can fill from the ticket, the code, the
   docs, and data that the team gave it.
3. Collect the questions that only the gate owner can answer. Send them in one message, not one
   message for each question.
4. Order the backlog by user value against size, and against the dates in the section Product Owner.
   A ticket that blocks other tickets ranks above them.
5. Within `po_authority`, write the changes to the tracker. Outside it, send the proposed changes to
   the gate owner in the same message as the questions.
6. In flow mode, when a team is free, send the top ready ticket to the lead.

An event pass starts when a new ticket arrives, when the controller reports a ship, or when the gate
owner asks. A daily pass starts once each working day through a scheduled task of the host. If the
host has no scheduled tasks, the PO says so once and runs on events.

## Sprint planning

Sprint mode only.

1. The PO runs a grooming pass.
2. The PO sends the top ready tickets to the lead, ordered, until their sizes pass `sprint_tokens`
   by about half.
3. The lead sizes each ticket with a size-only read. It reads the ticket and the files that the
   ticket touches, writes the size and its token range from `size_tokens`, and writes no brief and no
   plan. If a ticket is larger than M, the lead says so, and the PO splits it by what a user sees.
4. The PO takes tickets from the top. It stops before the ticket that takes the total past
   `sprint_tokens`, or the work past `sprint_days`. That is the cut-off.
5. The PO writes the sprint goals from the tickets above the cut-off, one line each.
6. The gate owner approves the sprint. Then the PO starts the sprint in the tracker. With
   `all-but-done`, the PO starts the sprint without the approval.

At the end of a sprint, the PO writes one line for each sprint goal: met or not met. It also writes
the tokens used against `sprint_tokens`. The lead proposes new `size_tokens` ranges from the retros of the
sprint. The gate owner approves an edit to the project file.

## Replan

A replan starts when the controller reports an overrun, a stall, or a blocker, or when an urgent
ticket arrives.

1. The PO names each sprint goal at risk. In flow mode, it names the next-up tickets at risk.
2. The PO orders the tickets again and proposes a swap to the lead. An example is to drop the
   lowest ticket so that the urgent ticket fits the budget.
3. The lead confirms the sizes and the capacity, or gives new sizes.
4. A ticket moves in or out of a started sprint only with `all-but-done`, or with the gate owner's
   yes. In flow mode, the PO changes the next-up list within `next-up`.

## Changes to existing files

- `commands/feature.md`, step 1: if `po` names a PO and the ticket is ready, take the goal, metric,
  acceptance, out of scope, and open questions from the ticket. Ask the developer only for a field
  that is missing. The run still writes its own estimate.
- `skills/controller/SKILL.md`, a new section Product Owner messages: if `po` names a PO, the
  controller sends it one line at ship, and one line at the first overrun, stall, or blocker of the
  run. The PO gets no other message from the run, so the limit in the section Messages to other
  sessions holds.
  Section Estimates: the size of a ticket that the lead sized is the starting size, and the run says
  so when it changes the size.
- `skills/controller/SKILL.md`, section Retro format: the estimate row for size also names the size
  that the lead gave at planning, if any.
- `templates/agentic-delivery.md`: the new keys and the section Product Owner.
- `README.md`: the seat in the agent table and one paragraph on the two modes.
- Version 0.3.0 in `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `README.md`, and
  the template's `min_plugin_version`.

No script changes. `scripts/project-config.sh` already reads any flat key.

## Out of scope

- Product discovery and research.
- Analytics connectors. The PO uses the data that the team gives it.
- Story points, velocity charts, and burndown charts.
- A sprint review meeting beyond the end-of-sprint lines.

## Tests

The plugin has no tests for prose. The branch passes these steps:

- `tests/run-all.sh` passes, so the change breaks no script.
- The name guard passes.
- A dry read: a fresh session loads the skill against a sample backlog of five tickets in a fixture
  file. It produces a ready list, a question list, and a cut-off for `sprint_tokens: 2M`. A reviewer
  reads the output against this spec.

## Estimate

- Size: M, five tasks: the skill, the template and README, the controller and feature command, the
  version bump, and the dry read.
- Wall clock: one to two hours from approval to a ready pull request.
- Tokens: about 600k for the whole run, with one fix round.
- Human touches: two, this spec review and the merge.
