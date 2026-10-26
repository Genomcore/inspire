# Emanate config — the format
> Part of [inspire-emanate-config](../SKILL.md). Read when the entry's index routes here.

`.inspire/emanate.yml` has five top-level keys. The factory's reader is the
authority, and this page summarizes it: when the two disagree, the reader wins
and this page is stale. The reader stops at the **first** error, so one run of
it reports one problem. Any key it does not know is an error, at every level.
Keys are case-sensitive.

In the error column, `…` stands for the prefix `.inspire/emanate.yml`.

## Top level

| Key | Required | Rule | Factory error |
|---|---|---|---|
| (document) | yes | one YAML document, a mapping | `… is not valid YAML: <parser message>` · `… must be a mapping` |
| (keys) | — | only `image`, `setup`, `services`, `env`, `phases` | `… has unknown key <k>; allowed keys: image, setup, services, env, phases` |
| `image` | yes | the reader accepts it absent; the runner then stops before planning | `the factory runs agents in the project image: add image to .inspire/emanate.yml` |
| `services` | no | a mapping of name → service. With no services, omit the key: `services:` with nothing after it is null, and null is an error | `… services must be a mapping` |
| `env` | no | a mapping of variable → string. Omit it rather than leave it empty | `… env must be a mapping` |
| `setup` | no | one nonempty string | `… setup must be a nonempty string` |
| `phases` | yes | a nonempty list | `… phases must be a nonempty list` |

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
| (keys) | — | only `image`, `env`, `command`, `healthcheck` | `… services.<name> has unknown key <k>; allowed keys: image, env, command, healthcheck` |
| `image` | yes | same reference rule as `image.name`. The bash/git/glibc probe does not apply: a service image may be Alpine | `… services.<name>.image must be a nonempty string` |
| `env` | no | same rules as `env`. The top-level `env` is **not** passed to services | `… services.<name>.env.<VAR> must be a string; quote numbers and booleans` |
| `healthcheck` | yes | one shell string, run **inside the service's image**, so that image must carry the tool it calls. Compose's `[CMD, …]` form is not accepted | `… services.<name>.healthcheck must be a nonempty string` |
| `command` | no | a nonempty list of strings; replaces the image's `CMD` | `… services.<name>.command must be a nonempty list` |

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
| (shape) | at least one phase of `run` checks before it | `…: at least one phase of run checks must come before the claims phase` |

A check holding the key `claims` is a claims check; any other check is a run check.

### Run checks

| Key | Rule | Factory error |
|---|---|---|
| (keys) | only `name` and `run` | `… phases[<i>].checks[<j>] has unknown key <k>; allowed keys: name, run` |
| `run` | one string, run with `bash -c` from the worktree root. The exit code decides | `… check <name> run must be a nonempty string` |

There is no timeout: a watch mode or a foreground server hangs the unit. A pipe
returns its last command's code, so `cargo test | tail` is always green unless the
command starts with `set -o pipefail`. Agents run these same commands, exactly as
written.

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
- Each new try starts again from the first phase. `max_tries` in `emanate.json`
  bounds the repairs.
- The claims check runs only once every run check is green.
- Order phases from cheap to expensive: lint and types, then tests, then claims.

Agents cannot change this file during a run: it is a protected path. A wrong
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
and `services.*.env` value, every `healthcheck` and `command` item. A single quote
inside a value is written `''`. Indent with two spaces; tabs are rejected. Write
the keys in the order `image`, `services`, `env`, `setup`, `phases`.

## Worked example

A worked example, and not a rule: React and NestJS in one npm package under
`source/`, with PostgreSQL.

```yaml
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
phases:
  - name: quality
    checks:
      - name: Lint
        run: 'cd source && npm run lint'
      - name: Typecheck
        run: 'cd source && npm run typecheck'
  - name: tests
    checks:
      - name: Unit tests
        run: 'cd source && npx --no-install jest --config jest.config.json --maxWorkers=2'
      - name: E2E tests
        run: 'cd source && npx --no-install jest --config test/jest-e2e.json'
  - name: claims
    checks:
      - name: Claim citations
        claims: ['source/src', 'source/test', 'source/web/test']
```

`--host 127.0.0.1` keeps `pg_isready` from answering through the socket while
Postgres is still initializing. The e2e suite takes no `--maxWorkers`: the flag
overrides the `maxWorkers: 1` its config sets, and the NestJS profile requires 1.
