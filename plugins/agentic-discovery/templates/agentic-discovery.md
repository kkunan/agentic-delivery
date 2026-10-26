---
po:
gate_owner:
lead:
tracker:
comment_prefix:
delivery_mode: flow
po_grooming: events
po_authority: next-up
po_scope: tickets
sprint_days:
sprint_budget:
size_budget:
---
# Agentic discovery project file

Copy this file to `.claude/agentic-discovery.md` in the folder where the Product Owner session runs. Use it when a team of people builds the tickets. If the team uses the agentic-delivery pipeline, use its project file instead. The skill `product-owner` then reads that file.

The lines between the two `---` lines at the top are the front matter. Each line is a plain `key: value` pair. Do not use quotes, YAML lists, or comments in the front matter.

## Keys

- `po` names the Product Owner session, for example `Product Owner`.
- `gate_owner` names the person who approves the changes outside the authority of the Product Owner, and who answers its questions. This person uses the Product Owner session.
- `lead` names the person who gets the ready tickets and gives each ticket a size.
- `tracker` names the ticket tracker: `jira`, `linear`, `github`, `gitlab`, `other`, or `none`. With `none`, the section Product Owner names a backlog file. With `other`, the section Tracker steps names the connector.
- `comment_prefix` is optional. If it has a value, the Product Owner starts each tracker comment and description with it, for example `Claude said:`.
- `delivery_mode` is `flow` or `sprint`. In flow mode, the Product Owner sends the next ready ticket to the lead when the team is free. In sprint mode, the team plans a batch of tickets at a fixed time.
- `po_grooming` is `events`, `daily`, or `events,daily`. The events are a new ticket and a ticket that ships.
- `po_authority` is `backlog`, `next-up`, or `all-but-done`. The skill `product-owner` defines each value.
- `po_scope` is `tickets` or `product`. With `product`, the Product Owner also prepares product decisions, and loads the skill `product-manager`.
- `sprint_days` is the length of a sprint in working days. Sprint mode needs it.
- `sprint_budget` is the capacity of one sprint, in the unit of the team, for example `20` points. Sprint mode needs it.
- `size_budget` gives a value or a range for each t-shirt size, in the same unit, for example `XS=1,S=2,M=5`. Sprint mode needs it.

## Tracker steps

Name the status of a ticket that is ready, and the status of a ticket that is done. Say how the Product Owner hands a ready ticket to the lead, for example by an assignee or a label. With `other`, name the connector that reaches the tracker.

## Product Owner

Name what the Product Owner weighs to order the backlog, for example the next release date or a customer promise. Name where the Product Owner keeps the open questions for the gate owner, for example a page in the tracker.

## Product Manager

Fill in this section only if `po_scope` is `product`. Name the person who makes product decisions. Name each evidence source that the Product Owner can read, and how to read it. If the team has a strategy document, name it too.
