# The Product Manager scope: design

Date: 2026-10-09. Status: draft for review.

This file adds an optional Product Manager scope to the Product Owner seat of
`2026-10-08-product-owner-design.md`. It does not change that file.

## Goal

A team whose human Product Owner or Product Manager lacks the time to decide gets each product
decision prepared for it. The agent does the thinking, and a person makes the call. The first user is
a product squad at a company. The second is a small app with one owner.

## Decisions

1. A new skill, `skills/product-manager/SKILL.md`, adds to the `product-owner` skill. It changes no
   rule of that skill.
2. A new key, `po_scope`, holds `tickets` or `product`. If it is empty or missing, it is `tickets`,
   and nothing changes. With `product`, the Product Owner session also loads `product-manager`.
3. A person makes every product decision. The agent prepares a decision memo and shows it to the gate
   owner. Only the gate owner's answer in the chat of the session counts. The gate owner can take the
   memo to another person, for example the squad's Product Manager, and bring the answer back.
4. `po_authority` still sets what the agent changes in the tracker. A decision does not widen it.
5. The project file names the evidence sources that the agent can read. The agent reads only those
   sources, and only to read.
6. The skills of the Anthropic `product-management` plugin are the expert skills, in the same way
   that the Go layer names the Go skills. A run continues without a missing skill and says so.

## What the skill holds

- The job: the agent decides which problem to work on, which bet to make, and what evidence supports
  it. The decision comes before a ticket. The Product Owner rules then turn it into ready tickets.
- The decision memo, in this order:
  1. The question, in one sentence.
  2. Two or three options.
  3. The evidence for and against each option, each with its source.
  4. The agent's pick, and why.
  5. What a wrong pick costs, and how the team will know.
  6. The person who decides, from the project file.
- The evidence rule: every claim in a memo names its source. A claim without a source says "no
  data". A guess is labeled as a guess.
- Privacy: a memo holds no personal data of a user or a customer, such as a name, an email, or an
  account id. It quotes a number or a paraphrase. The same rule covers the decision record and each
  ticket.
- The record: after each answer, the agent writes the decision, its date, and the person who decided
  in the place that the project file names for open questions.
- When it works: when the gate owner asks, and in each grooming pass. In a pass, it lists each ticket
  whose user value or metric has no evidence, as a decision to prepare. A ticket on that list does
  not go to the lead until its decision is recorded.
- Limits: it never decides on its own, never contacts a user or a customer, and writes no code,
  brief, spec, or plan.
- Expert skills, by job: `metrics-review`, `synthesize-research`, `roadmap-update`, `write-spec`,
  `competitive-brief`, and `product-brainstorming`, with the two install commands for the plugin.

## Project file

- Front matter: `po_scope`, beside the other Product Owner keys.
- Body: a section Product Manager, filled in only with `po_scope: product`. It names the person who
  decides, and each evidence source and how to read it. If the team has a strategy document, the
  section names it too.

## Core changes

- `templates/agentic-delivery.md`: the key `po_scope` with its bullet, and the section Product
  Manager.
- `skills/product-owner/SKILL.md`: one line under Settings for `po_scope`. If it is `product`, the
  session also loads `product-manager`.
- `README.md`: the skill in the component table, and one paragraph in "1. Pick the work".
- Version 0.5.0 in the four places that carry it.

## Tests

The plugin has no tests for prose. The branch passes these steps:

- `tests/run-all.sh` passes.
- The name guard and the Simple English lint pass on each changed file.
- A dry read: a fresh session loads both skills against a fixture in
  `tests/fixtures/product-manager/`. The fixture holds a project file with `po_scope: product`, a
  backlog of four tickets, a metrics file, and research notes. One note holds a customer name and an
  email. The session produces one decision memo. A reviewer reads the memo against this spec. The
  memo follows the order above and names a source for each claim. It says "no data" where the
  fixture has none, and it holds neither the name nor the email.

## Out of scope

- Connectors to analytics tools. The team gives the agent read access, or names a file.
- A memo channel other than the gate owner's chat, such as a tracker comment or a shared document.
- A separate discovery plugin.

## Estimate

- Size: S, four tasks: the skill, the template and the Product Owner line, the README and version, and
  the dry read.
- Wall clock: about one hour from approval to a ready pull request.
- Tokens: about 400k, with one fix round.
- Human touches: three, this spec review, the push, and the merge.
