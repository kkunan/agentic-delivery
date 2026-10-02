# Agentic Delivery

A Claude Code plugin that takes a feature from an idea to a merged pull request with a team of
agents. You approve one plan. The agents build, review, and test each task, keep a record of every
commit and decision, and write a retro at the end.

The workflow comes from a real mobile project that ran it for weeks. Each rule in it exists because
something went wrong without it. `lessons.md` tells the story behind each rule.

> Status: under construction. The rules, the agents, and the feature command are in place. The
> project file, the generic scripts, the hooks, and the Flutter layer are next. The plan is in
> `docs/superpowers/plans/`.

## How a feature runs

1. Brainstorm the feature with you, and write a spec.
2. Reviewers check the spec for design problems and for testability.
3. Write a plan of small tasks, and review the plan.
4. You approve the plan. This is the one gate.
5. For each task, an implementer agent writes the code and its tests, and a reviewer agent reviews
   the diff.
6. A final review of the whole branch, then QA and the ship checklist.
7. The pull request is ready for you. The run waits for your word to merge.
8. A retro compares the cost with the estimate, and proposes rule changes.

## What makes it different

- One gate. After you approve the plan, the run does not stop to ask permission for routine steps.
- A ledger. Each run records every commit, every decision, and the token cost of each phase.
- Checks that can fail. Each check states the value on a correct tree and on the defect that it
  excludes, and the run measures both.
- Rules load at the step that needs them. The rules are skills, not a file that every session carries
  from the start, so a session spends fewer tokens on instructions.
- Rule changes go through review. A retro never edits the rules. It proposes a pull request to this
  repository.

## What is in the plugin

- `commands/feature.md`: the pipeline, started with `/feature`.
- `agents/`: an implementer, a reviewer, and a QA reviewer. A team can replace any of them with its
  own agent.
- `skills/run-rules/`: the rules that every agent follows.
- `skills/controller/`: the rules for the session that runs the pipeline.
- `lessons.md`: the reason behind each rule.
- `scripts/`: the ready check, the stall watch, the device claim, the screenshot settle step, and the
  mutation runner, each with tests in `tests/`.

## Install

The install is not tested end to end yet. These commands come from the Claude Code help:

```bash
claude plugin marketplace add kkunan/agentic-delivery
```

```bash
claude plugin install agentic-delivery@agentic-delivery
```

## Set up a project

Each project adds one file, `.claude/agentic-delivery.md`, which git tracks. It names:

- the platform, for example `flutter`
- the base branch and the branch prefix for features
- where specs, plans, ledgers, and retros go: in the repository, or in a private folder
- the test devices and the test account
- how to move a ticket in your tracker, in plain words, so that any tracker works
- the actions that need a person's word, such as signing and secrets
- optionally, your own agent for any of the three seats

A template for this file is coming with the project file task in the plan.

## Platforms

Flutter is the first platform layer, for iOS, Android, and the web. A platform layer is one skill
that names the build, test, device, and screenshot commands. More layers can follow the same shape.

## Run the tests

```bash
bash tests/run-all.sh
```

## Contributing

Propose a rule change as a pull request. Name the incident that it comes from, and add a lesson to
`lessons.md`. Prose follows plain Simple English: short sentences, active voice, and one word for
one meaning.

## License

MIT
