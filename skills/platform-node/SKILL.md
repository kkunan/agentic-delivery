---
name: platform-node
description: "The Node layer of an agentic-delivery run, for TypeScript services such as NestJS, and for web apps in Next.js or React. It holds the setup, the test tiers, the commands, and the mutation runner. It also holds the rules for shared code, contracts, logs, and web apps. If the project file says `platform: node`, load this skill."
---

# Node platform

This skill holds the rules that depend on Node. The `run-rules` skill holds the rules for every agent, and the `controller` skill holds the rules for the controller. This skill does not repeat them. Each rule gives its reason in one sentence.

In this skill, `skills/platform-node/...` means the folder of the plugin, not a folder of the project. The start-up pointer gives its full path.

## Project file keys

- `test_processes` is `node`, because Jest, Nest, and Next all run as `node`.
- A service sets `view_globs` to `none`, because a service has no screens. Then `screenshot_branch` can stay empty.
- A web app sets `view_globs` to its screen folders, for example `components/**,pages/**,styles/**` for a Next.js app with the Pages Router.
- `jest_config` is optional. It is the path of a Jest configuration that the mutation runner passes to Jest, absolute or starting with `~/`. If the configuration of the repository cannot run the tests, set it, as the section Web apps says. Otherwise, leave it out.

## The rules file of the repository

If the repository has a rules file for agents, such as `CLAUDE.md` or `AGENTS.md`, every agent reads it before it writes or reviews code. It beats the brief, because the team of the repository reviews it. If a sample in the brief breaks it, follow the file and say so in the report.

## Setup of a worktree

Do these steps once in each new worktree, before the first test:

1. If the repository has `.gitmodules`, run `git submodule update --init`, because code in a submodule does not compile until it is there.
2. If the repository has `.nvmrc`, use the Node version in it.
3. Run `npm ci`. If it fails on macOS, run `npm install --no-package-lock`, and never commit a change to `package-lock.json` that the task did not need.
4. If `npm ci` fails with a 401 or a 404 on a private package, stop. Ask the gate owner for a token that can read the package. Never read, print, or write the token.
5. If the repository generates files before its tests compile, for example localization files, the project file names the command. Run it before the first test. Git usually ignores the generated files.

## Shared code in a submodule

Some teams keep shared enums, DTOs, and errors in one repository, and pin it in each service as a submodule. The project file names the submodule path and the services that pin it.

- Change the shared code in its own repository, through its own merge request. Never edit files under the submodule path inside a service, because the next submodule update erases the edit.
- After the shared merge request merges, bump the pointer in each service in a commit of its own: `git -C <submodule path> fetch && git -C <submodule path> checkout <sha>`, then commit the submodule path. The commit message names the shared commit.
- Before the shared code merges, a service task can point the submodule at the unmerged commit to test. The ship step points it at the merged commit, because a CI that clones submodules fails on a commit that no branch holds.
- A shared repository can have specs but no test runner. Then run its specs inside a service worktree, with the packages of the service:

  ```bash
  skills/platform-node/runners/submodule/test.sh <submodule path>
  ```

  Point the submodule at the commit under test first. A new spec for the shared code goes in the shared repository, beside the code that it tests. On 2026-10-16, the runner ran 9 suites and 50 tests of a shared repository in a NestJS service, and all passed.
- No mutation test runs on the shared code. The mutated file sits in a submodule, but the runner runs from the root of the service. Each new spec still reports one red run and one green run.
- A bump of the shared code can change more than the task needs. List every changed export of the bump, and search the service for each one.

## Test tiers

Use the cheapest tier that can prove the fact. These are the tiers, cheapest first:

1. Unit tests with Jest mocks. The specs sit beside the code as `*.spec.ts` or `*.test.ts`, and the existing specs show the mocking style of each repository. They need no network and no database.
2. Tests against an in-memory database. Some repositories have them, for example with `mongodb-memory-server` started in a Jest global setup. The first run downloads a database binary, so it needs the network once and can take minutes.
3. A test against a real dependency on a shared host. Do not build one as a side effect of a task. It is scheduled work with a ticket of its own.

No test reaches a dev, staging, or production host or database, because those hold shared or real data.

## Commands

Run each command from the top of the worktree, and write its output to a log in the ledger folder.

One spec file, without coverage:

```bash
npx jest <spec file> --coverage=false
```

One test by name:

```bash
npx jest <spec file> -t "TC-3" --coverage=false
```

The whole suite:

```bash
npx jest --coverage=false
```

The type check:

```bash
npx tsc --noEmit -p tsconfig.json
```

The lint of the changed files only:

```bash
npx eslint $(git diff --name-only --diff-filter=d <base>...HEAD -- '*.ts' '*.tsx')
```

The build, before every push:

```bash
npm run build
```

The type check does not prove that the build passes. A NestJS service builds with `tsconfig.build.json`, which can include files that `tsconfig.json` excludes. In one run, the type check and the suite passed, but `nest build` failed in CI on 17 errors in a submodule after a bump. Run the build before the first push and before the ship push.

If the Jest configuration collects coverage on every run, `--coverage=false` keeps a test run fast. Many repositories have a `lint` script that passes `--fix`, and a `format` script that rewrites every file. Never run either on a feature branch, because the diff then holds unrelated changes.

After the base merge, QA looks for a change since the last suite run:

```bash
git diff --stat <last suite SHA>..HEAD -- '*.ts' '*.tsx' package.json package-lock.json
```

If the repository has a submodule, add its path. If the output lists a file, run the suite again. If the output is empty, cite the last run.

## API contract

- A request without a new field works as before. Write a test for that case, and name it in the report, because a client that users did not update still sends the old request.
- Each new or changed field gets three tests: the field is present, the field is absent, and the field has the wrong type.
- In NestJS, a new field in a request needs a `class-validator` decorator on its DTO. A validation pipe with `whitelist` drops a field without a decorator, and the endpoint never sees it.
- A new enum value fails `@IsEnum` on each DTO that lists the old enum. Search every DTO and every hard-coded list of values, for the enum name and for the value strings.
- A response that an old client reads must hold only values that the old client understands. If a new value can reach an old client, map it to an old value below a minimum client version. If the repository already has a version check, copy it.
- The project file can have a section API clients. It names each client repository, the branch to read, and the place of its request and response types. The reviewer reads each changed field there with `git show <branch>:<path>`. It compares the JSON key, the type, and whether the field is optional. A mismatch is Important.

## Logs

A log line, an error string, and a response body never hold a request body, a token, or a secret. They also never hold a phone number or another user value. A log line names the event, the id of the record, and the error. The reviewer reads every new or changed log line, and a user value in one is Critical.

## Manual checks for a service

A service run has no manual checks, unless the service can start on this machine with local fakes. Never start a service with a dev, staging, or production configuration. With no checks, the QA log ends with `tally: 0 checks, 0 run, 0 unrun, 0 waived`, and the ready check accepts it.

## Web apps

Read `package.json` and the Jest configuration from `origin/<base_branch>` after a fetch, not from a local checkout, which can be behind. They decide which tests the CI of the repository can run.

A web app that runs Jest only in the `node` environment, with no jsdom and no React Testing Library, cannot run a component test. A committed component test then fails its CI with "document is not defined". For component tests, this skill gives a local runner, outside the repository:

```bash
skills/platform-node/runners/web/test.sh --coverage=false
```

The script installs Jest 29, jsdom, and React Testing Library with `npm install --no-save`, so `package.json` and `package-lock.json` do not change. If either file changed, it warns. It runs every `*.test.ts` and `*.test.tsx` file with `next/jest`, and it stubs `window.matchMedia`, which UI libraries such as Ant Design read. It maps the import prefix `@/` to `src/`. If the repository uses another prefix, copy the folder `runners/web` outside the repository, change `moduleNameMapper` in the copy, and run the copy.

For the mutation runner, copy the folder `runners/web` to a folder outside the repository, for example `~/.config/agentic-delivery/web-runner/`, and set `jest_config` to its `jest.config.js`.

A new test file sits beside the code that it tests, as `<name>.test.tsx`. If the CI of the repository cannot run it, the gate owner decides at the gate whether the merge request carries the test files. Until then, the run keeps them uncommitted, and the QA log cites their runs.

The other checks are these commands:

```bash
npm run lint
```

```bash
npx tsc --noEmit
```

```bash
npm run build
```

A run never signs in to an account. A screen check uses one of these ways:

1. A temporary page that renders the changed component with fixture data, at `npm run dev`, in the browser pane. With the Pages Router, the page goes under `pages/`. Never commit the page. The ship step deletes it before the final build.
2. The gate owner signs in to the dev environment of the web app in the browser pane, and the run takes the screenshot there. Ask for this at the gate.

Each manual check names the page, the fixture, and the expected text or color. It can fail, and it names the value on a correct tree.

## Stalled runs

Jest gives each test 5 seconds by default. A Jest run that prints every result but does not exit has an open handle, for example a database connection. Run it again with `--detectOpenHandles` to name the handle. The first download of an in-memory database writes little to the log for minutes. That is slow, not stalled, while the process uses the network. A frozen log with a live `node` process is a stall to report, not a process to stop.

## Mutation tests

`scripts/mutate.sh` runs the tests through a platform runner, as its usage text says. The Node runner of this plugin is `skills/platform-node/mutation-runner.sh`. Copy it into the project as `scripts/mutation-runner.sh`, and commit it. That path is the default of the `mutation_runner` key.

A test id has the form `<spec file>::<full test name>`. The spec file is relative to the top of the worktree. The full test name is each `describe` title and the `it` title, joined by one space, as Jest prints it in `fullName`. An example is `src/helper/number.helper.spec.ts::numberHelper formatNumber map correct`.

The runner calls Jest once for each spec file, with `--runTestsByPath` and an anchored `-t` pattern of the wanted names. When the project file sets `jest_config`, it adds `--config`. If the worktree has no project file, it reads the project file of the main checkout. It reads the JSON report of Jest:

- A passing test gives `passed`, and a failing test gives `failed`, so the verdict is `killed`.
- A skipped or pending test gives `skipped`, so the verdict is `error`.
- A suite that fails to run, for example on a TypeScript error from ts-jest, gives `compiled: false`, so the verdict is `did-not-compile`.
- A name that matches no test gives no entry, so the verdict is `error`, and the baseline stops the run.
- A spec file that does not exist, or a missing `node_modules/.bin/jest`, gives exit 2 before any test runs.

On 2026-10-12, the runner was measured in three repositories. In a NestJS service, three mutations of a helper gave `killed`, `survived`, and `did-not-compile`. In a Next.js 14 app with the Pages Router and Ant Design 4, two mutations of a constants file gave `killed` and `survived`. In a NestJS service with `mongodb-memory-server`, two mutations checked by an integration spec gave `killed` and `survived`.

## Expert skills

For NestJS, the skill `nestjs-best-practices` from `Kadajett/agent-nestjs-skills` holds about 40 rules. It is Markdown only, with no scripts. Install it as a user skill from that repository, and note the commit that you copied. Load it for NestJS work, with these limits:

- It applies to the code that a task writes or changes. Never refactor other code to follow it, because the task then holds changes that nobody asked for.
- The rules file of the repository and the existing code beat it. Its database examples use TypeORM. If the repository uses another library, such as Mongoose, follow the code of the repository.
- A reviewer cites a rule by its file name, for example `api-use-pipes`. A finding that only cites this skill, against code that the task did not change, is a follow-up, not a blocking finding.

Implementer: `test-use-testing-module`, `test-mock-external-services`, `api-use-pipes`, `api-use-dto-serialization`, `security-validate-all-input`, and `error-throw-http-exceptions`.

Reviewer: the same rules, plus `arch-avoid-circular-deps`, `arch-module-sharing`, and `devops-use-logging`.

If no expert skill covers the web framework of the repository, follow the existing code of the repository, and say so in the report.

## Where this layer was used

This layer comes from real runs on four tickets in October 2026: three NestJS services that share code through a submodule, and a Next.js 14 admin web with the Pages Router. The commands, the runners, and the mutation verdicts above were measured in those runs. No CI job in this repository runs this layer yet.
