---
name: platform-go
description: "The Go layer of an agentic-delivery run, for services with an HTTP API. It holds the test tiers, the commands, the contract and log rules, and the mutation runner. If the project file says `platform: go`, load this skill."
---

# Go platform

This skill holds the rules that depend on Go. The `run-rules` skill holds the rules for every agent, and the `controller` skill holds the rules for the controller. This skill does not repeat them. Each rule gives its reason in one sentence.

## Project file keys

- `go_command` is the command that runs Go. It is optional, and the default is `go`. A team without a local toolchain can run Go in a container, for example `docker run --rm -v "$PWD":/src -w /src golang:1.25-alpine go`. In the commands below, `<go>` stands for this value. The value runs through `bash -c` from the top of the worktree, so `$PWD` and quotes in it work.
- `test_processes` is `go`. If `go_command` runs a container, it is `docker`.
- `view_globs` is `none`, because a service has no screens. Then `screenshot_branch` can stay empty, and the ship step takes no screenshots.

## The rules file of the repository

If the repository has a rules file for agents, such as `AGENTS.md` or `agent.md`, every agent reads it before it writes or reviews code. It beats the brief, because the team of the repository reviews it. If a sample in the brief breaks it, follow the file and say so in the report.

## Test tiers

Use the cheapest tier that can prove the fact. These are the tiers, cheapest first:

1. Unit tests with fakes. A fake is a struct in the test file that implements an interface of the domain, as the existing tests do. These tests need no network and no database.
2. Handler tests with `net/http/httptest`. They prove the status, the headers, and the body of an endpoint without a server.
3. Tests against a real dependency, such as a database. If the repository has none, do not build one as a side effect of a task. It is scheduled work with a ticket of its own.

No test reaches a live host, because a live host holds real data.

## Commands

Run each command from the top of the worktree, and write its output to a log in the ledger folder:

```bash
<go> test -count=1 ./...
```

```bash
<go> vet ./...
```

```bash
<go> run cmd/gofmt -l .
```

`-count=1` turns off the test cache, so the result comes from this tree. The format check must print nothing. It runs `gofmt` through `<go>`, so it works in a container too.

After the base merge, QA looks for a change since the last suite run:

```bash
git diff --stat <last suite SHA>..HEAD -- '*.go' go.mod go.sum
```

If the output lists a file, run the suite again. If the output is empty, cite the last run.

## API contract

- A request without a new field works as before. Write a test for that case, and name it in the report, because a client that users did not update still sends the old request.
- Each new or changed field gets three tests: the field is present, the field is absent, and the field has the wrong type. If the field has a size limit, a test also covers a value over the limit.
- The project file can have a section API clients. It names each client repository, the branch to read, and the place of its request and response types. The reviewer reads each changed field there with `git show <branch>:<path>`. It compares the JSON key, the type, whether the field is optional, and the size limit. A mismatch is Important.
- Generated API docs change with the code. If the repository generates them, for example with swaggo/swag, regenerate them with the generator version that `go.mod` names. If you cannot run the generator, edit the generated files by hand to match, and say so in the report.

## Logs

A log line, an error string, and a response body never hold a request body, a token, a secret, or a user value. A log line names the event and the error. The project file can name more fields, for example health values. The reviewer reads every new or changed log line, and a user value in one is Critical.

## Manual checks

A service run has no manual checks, unless the repository can start the service with fakes on this machine. Then each check is one request, with its expected status and body. With no checks, the QA log ends with `tally: 0 checks, 0 run, 0 unrun, 0 waived`, and the ready check accepts it.

## Stalled runs

`go test` stops a test that runs past its timeout, 10 minutes by default, and prints the stack of each goroutine. The stall watch reads the size of each log. A frozen log with a live `go` process is a stall to report, not a process to stop.

## Mutation tests

`scripts/mutate.sh` runs the tests through a platform runner, as its usage text says. The Go runner of this plugin is `skills/platform-go/mutation-runner.sh`. Copy it into the project as `scripts/mutation-runner.sh`, and commit it. That path is the default of the `mutation_runner` key.

A test id has the form `<package>::<test name>`, for example `./internal/usecase::TestSendMessage`. The package is a path that `go test` accepts, such as `.` or `./internal/usecase`. A subtest keeps its slash, for example `.::TestClamp/low`. Go replaces each space in a subtest name with `_`, so write the name as `go test -v` prints it.

The runner calls `<go> test -json -count=1 -run <pattern> <package>` once for each test id. The pattern anchors each part of the name. The verdicts:

- A passing test gives `passed`, and a failing test gives `failed`, so the verdict is `killed`.
- A skipped test gives `skipped`, so the verdict is `error`.
- A package that does not build gives `compiled: false`, so the verdict is `did-not-compile`.
- A name that matches no test gives no entry, so the verdict is `error`, and the baseline stops the run.
- A call that exits with an error and shows neither a test nor a build failure gives no result file and exit 3. Read the log of the call.

This is an example. The code:

```go
func Clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
```

The test checks a value below the range and a value inside it. The manifest entry changes `return hi` to `return lo`:

```json
{"label": "high", "file": "calc.go", "find": "return hi", "replace": "return lo", "test": ".::TestClamp"}
```

The test still passes, because no case goes above the range. So the verdict is `survived`. Add a subtest with a value above the range, and run the mutation again. The verdict is then `killed`.

In this repository, the CI job "Go layer on a real toolchain" runs `tests/go-toolchain/check.sh`. It runs on each pull request that changes the Go layer or a script that the job runs. It runs the commands of this skill and the runner against a small sample module. The run on 2026-10-09 used `go version go1.24.13 linux/amd64` on a GitHub `ubuntu-latest` runner. A passing test gave `passed`, and a test name that matches nothing gave no entry. A type error gave `did-not-compile`, and the example above gave `survived`. The test `tests/test-go-runner.sh` covers the other cases with a stub Go command. Do not set `GO_BIN` in a run, because only the tests use it.

## Expert skills

The skills below come from the `cc-skills-golang` plugin. Install it in Claude Code with these two commands:

```bash
/plugin marketplace add samber/cc
```

```bash
/plugin install cc-skills-golang@samber
```

If the task is in the territory of a skill, load the skill. If a skill conflicts with the rules file of the repository, the rules file wins. Say in the report that you diverged. If a skill is not installed, say so and continue without it.

Implementer:

- `golang-testing` for tests and fakes.
- `golang-error-handling` for errors.
- `golang-security` for input, secrets, and logs.
- `golang-observability` for what a log line can hold.
- `golang-database` for a change to database code.
- `golang-swagger` for generated API docs.
- `golang-project-layout` and `golang-structs-interfaces` for packages and interfaces.
- `golang-code-style` and `golang-naming` for style.
- `golang-troubleshooting` for a test that fails for a cause that is not clear.

Reviewer:

- `golang-testing` to judge whether the tests are adequate.
- `golang-security` and `golang-observability` for input, secrets, and logs.
- `golang-error-handling` for errors.
- `golang-swagger` for generated API docs.
- `golang-project-layout` for the layers.
