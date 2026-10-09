# The Go platform layer: design

Date: 2026-10-09. Status: draft for review.

This file adds a platform layer for Go services to the plugin design in
`2026-10-02-agentic-delivery-design.md`. That design lists a backend layer as future work, and this
file fills that slot. It does not change the main design file.

## Goal

A team installs the plugin in a Go repository and runs `/feature` there, as a Flutter or iOS team
does. The layer is generic Go. Gin, GORM, and resty appear only as examples. The rules of one
product go into the project file of that repository, not into the plugin. Examples are a forbidden
host and a field that must never reach a log.

The first user is a pair of Go services, each with one HTTP API and a mobile app as its client.
Every job there ends at an open pull request, and a backend person merges and deploys it.

## Decisions

1. The layer is one skill, `skills/platform-go/SKILL.md`, and one mutation runner,
   `skills/platform-go/mutation-runner.sh`. A project selects it with `platform: go`.
2. The general agents of the plugin do the work, and they load the layer. There is no Go-only
   agent.
3. A new optional key `go_command` gives the command that runs Go. The default is `go`. A team
   without a local toolchain can run Go in a container, for example
   `docker run --rm -v "$PWD":/src -w /src golang:1.25-alpine go`. Every command in the skill and
   the runner starts with this value.
4. An optional section API clients in the project file names each client repository and the place
   of its request and response types. The reviewer compares each changed API field against them.
5. The core accepts `view_globs: none` for a project with no screens. With `none`, the ready check
   skips the screenshot proof, `screenshot_branch` can stay empty, and the ship step takes no
   screenshots.
6. The layer names skills of the `cc-skills-golang` plugin as its expert skills, the same way the
   iOS layer names the Apple skills. The repository's own rules win on a conflict. A run continues
   without a missing skill and says so.

## What the skill holds

- Project file keys: `go_command`, and the values of `test_processes` and `view_globs` for a Go
  service.
- A rules file for agents. If the repository has one, such as `AGENTS.md` or `agent.md`, every
  agent reads it before it writes or reviews code, and it beats the brief.
- Test tiers, cheapest first: unit tests with fakes, then handler tests with `net/http/httptest`,
  then tests against a real dependency. A test that needs a real database or a live host is
  scheduled work. It gets a ticket of its own, and it is never a side effect of a task.
- Commands: `go test ./...`, `go vet ./...`, and `gofmt -l .`, each with its output in a log in the
  ledger folder. `go test` passes `-count=1` when a result must not come from the test cache.
- Contract rules: a request without a new field works as before, and a named test proves it. A
  change to a handler or to an API field also changes the generated API docs, such as Swagger, with
  the generator version that `go.mod` names.
- Privacy in logs: a log line or an error string never holds a request body, a token, or a user
  value. The project file can name more fields.
- Stalled runs: `go test` ends a hung test after its own timeout, 10 minutes by default, and prints
  the stack. The stall watch reads the log size. `test_processes` is `go`, or `docker` when
  `go_command` runs a container.
- Manual checks: a backend run has none unless the repository can start the service with fakes on
  this machine. Then a check is a request and its expected status and body.
- Mutation tests: the runner contract, the test id form, and an example manifest.
- Expert skills, by role, from `cc-skills-golang`: `golang-testing`, `golang-error-handling`,
  `golang-security`, `golang-observability`, `golang-database`, `golang-swagger`,
  `golang-project-layout`, `golang-structs-interfaces`, `golang-code-style`, `golang-naming`, and
  `golang-troubleshooting`.

## The mutation runner

The runner follows the contract in `scripts/mutate.sh`. A test id has the form
`<package>::<test name>`, for example `./internal/usecase::TestSendMessage`. The package is a path
that `go test` accepts. A subtest name keeps its slash, for example `TestSendMessage/no_field`.

For each package, the runner calls `<go_command> test -json -count=1 -run <pattern> <package>`. The
pattern anchors each part of the test name. The runner reads the JSON events and writes the result
file: `compiled` is false when the package did not build, and each test gets `passed`, `failed`, or
`skipped`. The exact form of the build failure events is a claim to measure. The CI job below
measures it on a real toolchain before the runner relies on it.

The runner takes the Go command from the environment variable `GO_BIN` when it is set, so the
tests can pass a stub. Otherwise it reads `go_command` from the project file.

## Core changes

- `commands/feature.md`, step 0: `view_globs` can be `none`. With `none`, `screenshot_branch` can be
  empty.
- `scripts/ready-check.sh`: with `view_globs: none`, the check reports the screenshot proof as
  skipped and reads no `screenshot_branch`.
- `skills/controller/SKILL.md`, ship checklist step 5: with `view_globs: none`, take no screenshots.
- `templates/agentic-delivery.md`: the value `go` for `platform`, the key `go_command`, the value
  `none` for `view_globs`, and the optional section API clients.
- `README.md`: the Go row in the platform table, the skill in the component table, and the install
  line for `cc-skills-golang` beside the Apple skills.
- Version 0.4.0 in the four places that carry it.

## Tests

- `tests/test-go-runner.sh`: the runner with a stub Go command. Cases: one passing test, one
  failing test, a skipped test, a subtest, a package that does not build, a refused test id, and
  two test ids in one package.
- `tests/test-ready-check.sh`: a case with `view_globs: none` that passes with no screenshot link
  and no `screenshot_branch`.
- A CI job, Go layer on a real toolchain: it builds a small sample Go module in `tests/go-module/`,
  runs the three commands of the skill, and runs the runner through `scripts/mutate.sh` with one
  mutation that a test kills and one that survives.
- The skill passes the Simple English lint and the name guard.

## Out of scope

- Adoption in the first Go repository: its project file, its plugin setting, and its rules. That is
  a separate step after the release, and a backend person merges it.
- Tests against a real database, and a container for one.
- Deploys and release builds. The first team deploys by hand.

## Estimate

- Size: M, five tasks: the core `none` change with its ready check test, the skill, the runner with
  its stub tests, the CI job with the sample module, and the README, template, and version.
- Wall clock: one day, because the CI job needs runs on GitHub.
- Tokens: about 900k, with two fix rounds for the runner, because it is a proof task.
- Human touches: two, this spec review and the merge.
