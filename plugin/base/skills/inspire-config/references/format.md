# Config — the format
> Part of [inspire-config](../SKILL.md). Read when the entry's index routes here.

`.inspire/emanate.yml` has seven top-level keys. The factory's reader is the
authority, and this page summarizes it: when the two disagree, the reader wins
and this page is stale. The reader stops at the **first** error, so one run of
it reports one problem. Any key it does not know is an error, at every level.
Keys are case-sensitive.

In the error column, `…` stands for the prefix `.inspire/emanate.yml`.

## Top level

| Key | Required | Rule | Factory error |
|---|---|---|---|
| (document) | yes | one YAML document, a mapping | `… is not valid YAML: <parser message>` · `… must be a mapping` |
| (keys) | — | only `factory`, `image`, `setup`, `setup_timeout`, `services`, `env`, `bash_timeout`, `phases` | `… has unknown key <k>; allowed keys: factory, image, setup, setup_timeout, services, env, bash_timeout, phases` |
| `factory` | no | a mapping: the factory's own settings, below. Omit the key to take every default | `… factory must be a mapping` |
| `image` | yes | the reader accepts it absent; the runner then stops before planning | `the factory runs agents in the project image: add image to .inspire/emanate.yml` |
| `services` | no | a mapping of name → service. With no services, omit the key: `services:` with nothing after it is null, and null is an error | `… services must be a mapping` |
| `env` | no | a mapping of variable → string. Omit it rather than leave it empty | `… env must be a mapping` |
| `setup` | no | one nonempty string | `… setup must be a nonempty string` |
| `setup_timeout` | no | only with `setup`; whole seconds, at least 1: the time limit of each run of `setup`, in the units, the scaffold, the release check and the base check. Without it the limit is 1800 s. A setup still running at it is stopped and fails with exit code 124 and the line naming the limit (§ Run checks). Needs INSPIRE Factory 0.26.0 or later | `… setup_timeout needs setup` · `… setup_timeout must be a whole number of seconds, at least 1` |
| `bash_timeout` | no | whole seconds from 1 to 3600: the time limit of each shell command a unit, scaffold, repair or reviewer agent runs when it passes no timeout of its own. Without it OMP's own limit applies (300 s), and a command that takes longer is killed before the agent sees its result. It limits the agents' commands, not the checks | `… bash_timeout must be a whole number of seconds from 1 to 3600` |
| `phases` | yes | a nonempty list | `… phases must be a nonempty list` |

## `factory`

The factory's own settings. Every key is optional, and a key that is absent takes its
default. The reader refuses any key not in the table, under `factory` and under
`sandbox`. Their old home was a separate settings file; [`derive.md`](derive.md) § Migrating `emanate.json` moves it here.

| Key | Rule | Default | Factory error |
|---|---|---|---|
| `kb_root` | a nonempty string: the knowledge base root (`SDD_KB_ROOT` wins) | `inspire_kb` | `… factory.kb_root must be a nonempty string` |
| `spec_root` | a nonempty string: the domain specification root (`SDD_SPEC_ROOT` wins) | `<kb_root>/01_spec` | `… factory.spec_root must be a nonempty string` |
| (keys) | only the keys below | — | `… factory has unknown key <k>; allowed keys: kb_root, spec_root, model, review_model, subagent_models, concurrency, check_concurrency, max_tries, spec_strictness, spec_max_revisions, spec_classifier_model, base_branch, viewer_port, sandbox` |
| `model` | `anthropic/<model>` or `litellm/<alias>`, and the **exact** name OMP resolves | none | `… factory.model must be anthropic/<model> (the Claude subscription) or litellm/<alias> (the LiteLLM gateway)` |
| `review_model` | same form as `model`; the model of the review checks | `model` | `… factory.review_model must be anthropic/<model> …` |
| `subagent_models` | a list of models in the same form | `[]` | `… factory.subagent_models must be a list of models` |
| `concurrency` | a positive integer: units solved at once | `3` | `… factory.concurrency must be a positive integer` |
| `check_concurrency` | a positive integer: check commands (lint, typecheck, test suites) running at once across all units; the others wait for a free one. Review checks, the setup and the agents take none. Agents mostly wait on the model while suites keep the CPUs busy, so this bounds the load of the factory's own checks better than `concurrency`. The tests an agent runs in its shell take no slot | `2` | `… factory.check_concurrency must be a positive integer` |
| `max_tries` | a positive integer: repairs per check for each unit | `2` | `… factory.max_tries must be a positive integer` |
| `spec_strictness` | `strict`, `auto` or `yolo`: what a unit does when its agent reports a spec problem with `report_spec_issue`. `strict` stops the unit with the report. `yolo` has a spec writer agent apply the proposed solution to the spec files and lets the unit continue; each applied report is a numbered spec revision committed to the release branch. `auto` has a small model (`spec_classifier_model`) classify each report: `small` is applied as in `yolo`, `critical` stops the unit as in `strict` | `strict` | `… factory.spec_strictness must be strict, auto or yolo` |
| `spec_max_revisions` | a positive integer: the most spec revisions a `yolo` or `auto` run commits; once the run holds that many, the next report stops its unit as in `strict` | `5` | `… factory.spec_max_revisions must be a positive integer` |
| `spec_classifier_model` | same form as `model`: the model that classifies each report in `auto`; a small model is enough. Required by `auto` | none | `… factory.spec_classifier_model must be anthropic/<model> (the Claude subscription) or litellm/<alias> (the LiteLLM gateway)` · `… factory.spec_strictness auto requires spec_classifier_model` |
| `base_branch` | a branch name, or `null` for a local release | `main` | `… factory.base_branch must be a branch name or null` |
| `viewer_port` | an integer from 0 to 65535 | `4319` | `… factory.viewer_port must be an integer from 0 to 65535` |
| `sandbox` | a mapping with only `memory`, the memory limit of each unit container (setup, each check, each agent): a Docker size such as `1536m` or `2g` (default `1536m`); requires `model`. The Factory runs at once only as many units as fit in Docker's memory, each taking `sandbox.memory` plus every service's `memory`, so raise it only for a suite that needs it | none | `… factory.sandbox must be a mapping` · `… factory.sandbox has unknown key <k>; allowed keys: memory` · `… factory.sandbox.memory must be a Docker memory size such as 1536m or 2g` · `… factory.sandbox requires model` |

The old file's `schema` key has no place here: the reader refuses it as an unknown key.
A model name must be exact: the reader checks only its form, and the run stops when it
creates the first agent if OMP would run a different model
(`<model> is not an exact model name: OMP would run <provider>/<id> instead`).
Numbers and `null` are written bare; every string is single-quoted
([§ Quoting](#quoting)).

## `image`

The image every setup, check and agent runs in.

| Key | Required | Rule | Factory error |
|---|---|---|---|
| `image` | yes | a mapping; `image: node:24` is an error | `… image must be a mapping` |
| `name` | yes | an image reference: no spaces, no leading `-`. A tag, optionally `@sha256:…` | `… image.name must be a nonempty string` · `… image.name must be an image reference without spaces that does not start with -` |
| `description` | no, but write it | the agent receives it as `This image provides: <description> Nothing else is guaranteed.` It is the only description of the toolchain an agent gets | `… image.description must be a nonempty string` |

The reader checks the shape only. With units to emanate, the runner pulls the image
and probes it as the orchestrator's uid:gid with no root and `HOME=/tmp`:

- `image <name> has no git: the unit agents read the repository with it`
- `image <name> cannot run the factory's Bun: it needs glibc (Alpine and other musl images do not work)`
- `image <name> must provide bash and run as user <uid:gid>: <stderr>`

So the image needs `bash`, `git` and glibc, and every tool the commands call must
work without root. Official `-slim` images usually lack `git`; Alpine fails on
both counts. The pull happens on **every** run: a tag that exists only locally
stops it with `pull access denied`, and a floating tag can change the toolchain
between runs. Write `description` as full English sentences ending in a period,
naming each toolchain and its version.

## `services.<name>`

Each service starts fresh for each unit, on a network the unit's containers share.
The unit reaches it by its name, which is the hostname.

| Key | Required | Rule | Factory error |
|---|---|---|---|
| `<name>` | — | a hostname label: lowercase letters, digits, hyphens, at most 63 characters, not `orchestrator` | `… services.<name>: the name must be a hostname label (lowercase letters, digits and hyphens) other than orchestrator` |
| (keys) | — | only `image`, `env`, `command`, `healthcheck`, `memory` | `… services.<name> has unknown key <k>; allowed keys: image, env, command, healthcheck, memory` |
| `image` | yes | same reference rule as `image.name`. The bash/git/glibc probe does not apply: a service image may be Alpine | `… services.<name>.image must be a nonempty string` |
| `env` | no | same rules as `env`. The top-level `env` is **not** passed to services | `… services.<name>.env.<VAR> must be a string; quote numbers and booleans` |
| `healthcheck` | yes | one shell string, run **inside the service's image**, so that image must carry the tool it calls. Compose's `[CMD, …]` form is not accepted | `… services.<name>.healthcheck must be a nonempty string` |
| `command` | no | a nonempty list of strings; replaces the image's `CMD` | `… services.<name>.command must be a nonempty list` |
| `memory` | no | the service container's memory limit, a Docker size such as `512m` or `1g` (default `512m`); it counts towards each unit's share when the Factory decides how many units run at once | `… services.<name>.memory must be a Docker memory size such as 512m or 1g` |

At run time the factory polls the healthcheck every second for up to 60 seconds,
then stops the run:
`service <name> (<container>) was not healthy after 60 seconds: its healthcheck reports <status>`.
Compose keys with no equivalent — `ports`, `volumes`, `depends_on`, the
healthcheck's `interval`/`retries` — are dropped; say which ones and where their
job goes.

## `env`

| Key | Rule | Factory error |
|---|---|---|
| `<VAR>` | matches `^[A-Za-z_][A-Za-z0-9_]*$` | `… env: <VAR> is not a valid variable name` |
| value | a string. `3000`, `true` and `~` unquoted are not strings | `… env.<VAR> must be a string; quote numbers and booleans` |

`env` reaches the setup, every check and every agent of a unit — not the services.
Never write `HOME`, `PATH`, `USER`, `DOCKER_*`, `LITELLM_*` or `ANTHROPIC_*`: the
reader accepts them, and they override the factory's own (`HOME=/tmp`, the model
proxy, the docker CLI). Every value appears in plain text in each agent's
environment message and in the archived run, so test credentials only. Inside a
unit the database host is the service name, never `localhost`.

## `setup`

One string, run with `bash -c` from the worktree root, before each unit's agent
and again whenever a dependency file changes (`package.json`, the npm, pnpm,
yarn and bun lockfiles, `.npmrc`, `.yarnrc.yml`, `schema.prisma`,
`pyproject.toml`, `uv.lock`, `poetry.lock`, `Pipfile.lock`, `requirements.txt`).
`Cargo.toml`, `*.cabal`, `go.mod` and Gradle files are not on that list: in those
stacks the checks must resolve new dependencies themselves.

Join several commands with `&&`, or start a block with `set -e`. Otherwise
`bash -c` returns only the last command's code and hides an earlier failure. An
`export` here does not reach the checks, which each run in a fresh container;
variables belong in `env`.

## `phases`

| Key | Rule | Factory error |
|---|---|---|
| `phases[i]` | a mapping with only `name` and `checks` | `… phases[<i>] has unknown key <k>; allowed keys: name, checks` |
| `name` | a nonempty label | `… phases[<i>].name must be a nonempty string` |
| `checks` | a nonempty list of mappings; a bare `- npm test` is an error | `… phase <name> checks must be a nonempty list` · `… phases[<i>].checks[<j>] must be a mapping` |
| (shape) | exactly one `claims` check, alone in the last phase | `…: the claims check must be the only check of the last phase` |
| (shape) | at least one phase of `run` or `review` checks before it | `…: at least one phase of run checks must come before the claims phase` |

A check holding the key `claims` is a claims check, one holding `review` is a
review check, and any other check is a run check. Run and review checks may share
a phase.

### Run checks

| Key | Rule | Factory error |
|---|---|---|
| (keys) | only `name`, `run`, `run_related`, `report`, `run_timeout` and `run_related_timeout` | `… phases[<i>].checks[<j>] has unknown key <k>; allowed keys: name, run, run_related, report, run_timeout, run_related_timeout` |
| `run` | one string, run with `bash -c` from the worktree root. The exit code decides | `… check <name> run must be a nonempty string` |
| `run_related` | optional; the same command as `run`, narrowed to the tests related to the unit: those related to the files it changed (`{files}`) or those that cite its claims (`{tests}`). It must contain `{files}` or `{tests}`, and it must pass when no test relates to them: Jest and Vitest need `--passWithNoTests` | `… check <name> run_related must be a nonempty string` · `… check <name> run_related must contain {files} or {tests}` |
| `report` | optional; the path, from the repository root, of the JSON test report that `run` and `run_related` write on every run (§ Test reports). Inside the repository, not under `.git`, a protected path, `.claude/worktrees` or `.inspire/check-output`, and never the same file as another check's, in any case | `… check <name> report must be a nonempty string` · `… check <name>: report <path> must be a path inside the repository` · `… check <name>: report <path> must not be under <dir>` · `…: checks <a> and <b> both write the report <path>` |
| `run_timeout` | optional; whole seconds, at least 1: the time limit of each `run`, the whole suite, wherever it runs: the scaffold, the release check, and a unit's check when it runs `run` (no `run_related`, or a fallback to `run`). Size it to the whole suite. Needs INSPIRE Factory 0.24.0 or later | `… check <name> run_timeout must be a whole number of seconds, at least 1` |
| `run_related_timeout` | optional, only with `run_related`; whole seconds, at least 1: the time limit of each `run_related`, which runs only in the units. Size it to the related tests. Needs INSPIRE Factory 0.24.0 or later | `… check <name> run_related_timeout must be a whole number of seconds, at least 1` · `… check <name> run_related_timeout needs run_related` |

On INSPIRE Factory 0.26.0 or later every run check has a limit: `run_related`
without `run_related_timeout` takes the check's `run_timeout`, and a command with
neither is stopped at 1800 s, lint and typecheck included. On 0.24.0 and 0.25.x a
check without them has no time limit: a watch mode, a foreground server or a test
that never ends holds its slot until someone stops the run (one held an e2e slot for
3.5 hours). The check is stopped at the limit of the command it runs, after its
container starts, not while it waits for a slot. It fails with exit code 124 and the
line `The command ran longer than its timeout of <N> seconds, so the factory stopped
it.` (`The check ran …` before 0.26.0), which goes to a repair agent with
the rest of its output; it is never rerun as a flaky kill. There are two limits
because one cannot fit both commands: sized to the related tests, a whole suite that
takes longer fails the release check on every run, and no repair can make it faster;
sized to the whole suite, a hung test holds a unit's slot that long. A pipe
returns its last command's code, so `cargo test | tail` is always green unless the
command starts with `set -o pipefail`.

A unit's agent does not run these commands as a whole. It runs only the tests its
change touches, and when it finishes the factory runs the checks. A failing check
reaches the agent through the repair prompt, with its output.

A factory that does not know `run_related` refuses the whole file as soon as the
run starts, before any unit, with `… has unknown key run_related`: update the
factory. In the command, `{files}` becomes
the files the unit changed since it left the release (`release...HEAD`, the range
the reviewer judges), as absolute paths, each shell-quoted. Write it where the
runner takes file paths:

- Jest: `npx --no-install jest --passWithNoTests --findRelatedTests {files}`
- Vitest: `npx --no-install vitest related --run --passWithNoTests {files}`

`{tests}` becomes the test files under the `claims` roots that cite a claim of the
unit or of a unit it requires, plus the files the unit changed there that cite any
claim, as absolute paths, each shell-quoted. When there are none, the check runs
`run`. It suits e2e suites, whose tests start the whole application, relate to
almost every change and seldom import the file a unit changed:

- Jest: `npx --no-install jest --passWithNoTests --runTestsByPath {tests}`
- Vitest: `npx --no-install vitest run --passWithNoTests {tests}`

A factory that does not know `{tests}` refuses the file when the run starts, with
`… run_related must contain {files}`: update the factory.

Without `--passWithNoTests`, a unit that changes only files outside this check's
package fails it: no test relates to them, and the runner exits non-zero.

#### Test reports

A run check with `report` passes only when its command exits with 0 and its report
shows that the tests ran. The factory reads two shapes: the Jest-shaped JSON that
Vitest and Jest write, and pytest-json-report's.

- Vitest: `--reporter=default --reporter=json --outputFile.json=<file>`
- Jest: `--json --outputFile=<file>`
- pytest: `--json-report --json-report-file=<file>`, with `pytest-json-report` installed

`<file>` is relative to the command's `cd`; `report` is the same file from the
repository root. The factory:

- deletes the report before each run, so an old one never passes a check, and keeps
  it out of every commit;
- fails the check when the report is missing or unreadable, when a test failed, was
  skipped, disabled or todo (pytest's `xfailed` counts as skipped), and, on `run`,
  when no test passed. A run of `run_related` may run none;
- names each failed test, with its messages, and each skipped one in the repair
  prompt;
- counts a `@claim` citation only in a file in which a test passed in a report of the
  unit's checks. A test that `run_related` does not select never counts in that unit, so
  the claims of a unit must be cited in tests its related run reaches: `{tests}` selects
  them all.

A run whose plan has units with claims stops before it starts when no check has a
report: `<n> units of the plan have claims, but no tests check of .inspire/emanate.yml
declares a report, so the factory cannot tell whether the tests that cite them ran and
passed: add report to the checks that run the tests`.

### Review checks

A review check runs no command: a reviewer agent judges the unit's change against
the rules the check gives it.

| Key | Rule | Factory error |
|---|---|---|
| (keys) | only `name` and `review` | `… phases[<i>].checks[<j>] has unknown key <k>; allowed keys: name, review` |
| `review` (keys) | a mapping with only `skills`, `read`, `focus` | `… check <name> review has unknown key <k>; allowed keys: skills, read, focus` |
| `skills` | a list of skill names: lowercase letters, digits, hyphens | `… check <name> review.skills must list nonempty strings` · `… check <name>: skill <s> must be the name of a project or factory skill` |
| `read` | a list of entries, below | `… check <name> review.read must list nonempty strings` |
| (shape) | at least one of `skills` and `read` | `… check <name>: a review needs skills or read to know what to check` |
| `focus` | optional; one sentence that narrows what to judge | `… check <name> review.focus must be a nonempty string` |

A `read` entry is a file in the repository, whole (`CLAUDE.md`) or one `##`
section of it (`docs/api.md#Errors`), or `{profiles}#<Section>`: that section of
every profile `stack.md` lists, skipping the profiles without it. A skill is a
factory skill or a project skill committed at `.claude/skills/<name>/SKILL.md`
with a frontmatter `description`.

The reader checks the shape only. The runner resolves every review before the
release is created, reading the committed files at `HEAD`, and stops at the first
of:

- `Two review checks are named <name>; review check names must be unique`
- `Review check <name>: skill <s> is neither a factory skill nor committed at .claude/skills/<s>/SKILL.md`
- `Review check <name>: skill <s> has no description in its frontmatter`
- `Review check <name>: read <path> must be a file inside the repository`
- `Review check <name>: <path> is not committed`
- `Review check <name>: read <entry> found no file` · `… found no ## <Section> section`

How the factory runs a review:

- The reviewer reads the worktree read-only, with only the check's skills, the
  `read` context and the `focus`, and judges the diff from the release to the
  unit's `HEAD`. Lockfiles are left out of that diff.
- Only a finding on a file the unit changed, and on a line it added, counts. Any
  counted finding turns the check red, and a repair agent receives the findings
  like the output of a red run check.
- After a repair, the review rechecks its earlier findings and judges only what
  the repair added; code an earlier review accepted never fails later.
- A reviewer that gives no verdict twice fails the unit without a repair.
- `factory.review_model` picks the reviewer's model; without it the
  reviewer uses `model`.
- Each review costs a model session per round, and its findings cost repairs.
  Narrow it with `focus`, and order it after lint and types and before the tests
  ([§ How the factory runs the phases](#how-the-factory-runs-the-phases)).

### The claims check

| Key | Rule | Factory error |
|---|---|---|
| (keys) | only `name` and `claims` | `… phases[<i>].checks[<j>] has unknown key run; allowed keys: name, claims` |
| `claims` | a nonempty list of roots | `… check <name> claims must be a nonempty list` |
| `claims[k]` | a path relative to the repository root; no absolute path, no `..` | `… check <name>: root <root> must be a path inside the repository` |

The roots are where the factory reads `@claim` citations from the tests. A root is
a **literal directory**: a glob such as `source/**/test` passes the reader, matches
nothing on disk, and leaves every claim uncited without an error. A root that does
not exist is skipped just as silently. A root that holds `node_modules`, `target`
or `.venv` makes the scan read all of it. Point at the directories that hold tests.

## How the factory runs the phases

- Phases run in order. Every check of a phase runs, even after one fails.
- The first phase with a red check stops the suite. The repair receives all of
  that phase's red checks together.
- Each new try starts again from the first phase. `factory.max_tries`
  bounds the repairs.
- The claims check runs only once every run and review check is green.
- A run check with `run_related` runs that command in the unit: in its first
  run, after each repair, and again when the unit is rechecked after a merge from
  a base that moved. It runs `run` instead in three cases: the unit changed no
  file, it deleted a file, or the command with its files would pass 100,000
  characters.
- Order the phases: lint and types, then `review`, then tests, then claims. A
  red phase stops the suite, so a change the review rejects is repaired before a
  full test run is spent on it.

### The release check

When at least one check has `run_related`, the factory checks the whole suite
once more at the end of the run. It does this after every unit has merged and
before it opens the PR, also when `base_branch` is `null`.

- It runs the `run` of every run check in a worktree of the release, with its
  own services and `setup`. It does not run `run_related`, review checks or the
  claims check, which already ran in each unit.
- A red suite goes to a repair agent, up to `factory.max_tries` repairs. A suite
  that stays red fails the run like a unit: no PR, and the release keeps the
  merged units.
- It covers what `run_related` lets through: a change that no test imports, such
  as a migration or `package.json`, runs no test in the unit.

Without any `run_related`, there is no release check: every unit already ran the
whole suite.

Agents cannot change this file during a run: it is a protected path, and so are
the project skill folders and the `read` files a review check uses. A wrong
command, root or image is not repaired. It spends every unit's repairs and then
fails them all.

## Quoting

Some unquoted YAML values change silently: a leading `&` is an anchor and
disappears, a leading `!` is a tag and is dropped — so `run: ! grep -q TODO src`
becomes a check that passes when it should fail — and ` #` starts a comment that
cuts the command. A `: ` inside an unquoted value is a parse error, reported
without a line number. A repeated key keeps the last value, also silently.

So: **single-quote every string value** except phase and check names —
`image.name`, `image.description`, `setup`, every `run`, every root, every `env`
and `services.*.env` value, every `healthcheck` and `command` item, every string
under `factory`. A single quote inside a value is written `''`. Indent with two
spaces; tabs are rejected. Write the keys in the order `factory`, `image`,
`services`, `env`, `setup`, `setup_timeout`, `bash_timeout`, `phases`.

## Worked example

A worked example, and not a rule: React and NestJS in one npm package under
`source/`, with PostgreSQL.

```yaml
factory:
  model: 'litellm/claude-opus-5-5'
  review_model: 'litellm/claude-sonnet-5-5'
  sandbox: {}
  max_tries: 2
  base_branch: 'main'
image:
  name: 'node:24.22.1-trixie'
  description: 'Node.js 24.22.1 with npm and npx on Debian 13, with git.'
services:
  postgres:
    image: 'postgres:18.6-trixie'
    env:
      POSTGRES_USER: 'inspire'
      POSTGRES_PASSWORD: 'inspire'
      POSTGRES_DB: 'app'
    healthcheck: 'pg_isready --host 127.0.0.1 --username inspire --dbname app'
env:
  DATABASE_URL: 'postgresql://inspire:inspire@postgres:5432/app'
setup: 'cd source && npm ci'
bash_timeout: 600
phases:
  - name: quality
    checks:
      - name: Lint
        run: 'cd source && npm run lint'
      - name: Typecheck
        run: 'cd source && npm run typecheck'
  - name: review
    checks:
      - name: Conventions
        review:
          read: ['{profiles}#Review focus']
          focus: 'Report only clear violations of the review focus in code this change adds.'
  - name: tests
    checks:
      - name: Unit tests
        run: 'cd source && npx --no-install vitest run --config vitest.config.ts --maxWorkers=2 --reporter=default --reporter=json --outputFile.json=.inspire-report-unit-tests.json'
        run_related: 'cd source && npx --no-install vitest related --run --passWithNoTests --config vitest.config.ts --maxWorkers=2 --reporter=default --reporter=json --outputFile.json=.inspire-report-unit-tests.json {files}'
        report: 'source/.inspire-report-unit-tests.json'
        run_timeout: 1800
        run_related_timeout: 900
      - name: E2E tests
        run: 'cd source && npx --no-install vitest run --config vitest.e2e.config.ts --fileParallelism --maxWorkers=2 --reporter=default --reporter=json --outputFile.json=.inspire-report-e2e-tests.json'
        run_related: 'cd source && npx --no-install vitest run --config vitest.e2e.config.ts --fileParallelism --maxWorkers=2 --passWithNoTests --reporter=default --reporter=json --outputFile.json=.inspire-report-e2e-tests.json {tests}'
        report: 'source/.inspire-report-e2e-tests.json'
        run_timeout: 3600
        run_related_timeout: 900
  - name: claims
    checks:
      - name: Claim citations
        claims: ['source/src', 'source/test', 'source/web/test']
```

`--host 127.0.0.1` keeps `pg_isready` from answering through the socket while
Postgres is still initializing. The e2e config runs one file at a time, as the NestJS
profile requires, and each file copies its own database, so the check runs files side by
side with `--fileParallelism`: two workers at the default `sandbox` memory (`1536m`), four
with `sandbox.memory: 2g` or more, on INSPIRE Factory 0.19.0 or later. On an older Factory
the check keeps the config's one file at a time. `bash_timeout: 600` lets an agent's
long command finish and still bounds a shell that never returns to ten minutes. The
test checks' limits do the same for a test run that hangs, on INSPIRE Factory 0.24.0
or later: `run_related_timeout: 900` in the units, and a `run_timeout` three times
what each whole suite takes (here, up to ten minutes for the unit tests and twenty for
the e2e tests).
The review phase reads the `## Review focus` section of the react and nestjs
profiles; drop it to run without reviews. The unit tests narrow by `{files}`; the e2e
tests, which start the whole application and relate to almost every change, by
`{tests}`, the files that cite the unit's claims. Either `run_related` turns on the
release check. Both
test checks write a report, each to its own file: the e2e tests prove claims too.
