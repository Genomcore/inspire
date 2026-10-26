# Config — deriving the file
> Part of [inspire-config](../SKILL.md). Read when the entry's index routes here.

`stack.md` and the profiles give the file its structure: paths, services, setup,
commands and claim roots. They never give the image, exact tags, or which commands
block a unit. Those are proposed and confirmed, every time.

## Read the sources

Resolve the roots **as the factory run does**, not as this shell does:
`SDD_KB_ROOT` / `SDD_PROFILES_ROOT` from the checkout's `.env`, then `kb_root` /
`profiles_root` from the committed `.inspire/emanate.json`, then the defaults
`inspire_kb` and `.claude/skills/inspire-code/profiles`. Warn when this shell
carries a different value; the run never sees it.

| Source | What it gives | Key |
|---|---|---|
| `stack.md` frontmatter `profiles` | the framework profiles, plus each one's `language:` profile | all |
| `stack.md` frontmatter `source_root` (default `source`) | the `cd` prefix of every command and every root; `.` means no prefix | `setup`, `run`, `claims` |
| `stack.md` frontmatter `prototype_root` | a tree no root may enter | `claims` |
| `## Shape` | whether the database is local (a service) or external | `services` |
| `## Language`, `## Backend / runtime`, `## Frontend`, `## Data` | runtimes and their major versions, in prose | `image`, `services.*.image` |
| `## Test infrastructure` | one service per row; the Component column is its name | `services` |
| `## Worktree recipe` | the `dependencies` and `generated artifacts` rows; the `environment` row names the variables' file | `setup`, `env` |
| `## Conventions` (`### Layout`, `### Commands`, when the project wrote them) | real commands and test layout | `run`, `claims` |
| `surfaces.md`, when present | each surface's `**Package:**` and `**Profiles:**` (which replace the global list) | per-package `cd`, roots |
| each profile's `## Build & verify` | build, lint, types and test commands | `run` |
| each profile's `## Test conventions` | where tests live | `claims` |

Read the profiles from the project's `profiles_root`, never the plugin's: a project
adds its own. A `profiles:` id with no file (`postgres`, `mongodb`, `sqlite`) is a
hint about the data layer, not an error. `stack.md` carrying `status: default` is a
warning only: ask the operator to confirm `profiles`, since the stack may still be
the seeded one.

## Inspect the repository

Read-only — `ls`, `git ls-files`, `grep`, reading files. Install nothing.

- **Lockfiles** give the strict install: `package-lock.json` → `npm ci`;
  `pnpm-lock.yaml` → `corepack pnpm install --frozen-lockfile`; `yarn.lock` →
  `corepack yarn install --immutable`; `bun.lock` → `bun install --frozen-lockfile`;
  `uv.lock` → `uv sync --locked` (`--frozen` accepts a stale lockfile).
- **`package.json` scripts** (`lint`, `typecheck`, `test`, `test:e2e`) give the real
  commands; a `npm run <x>` with no script `<x>` is an error to raise now.
- **Runner configs** (`jest.config.*`, `test/jest-e2e.json`, `vitest.config.*`,
  `pyproject.toml` `testpaths`) give the test directories and any `maxWorkers`.
- **The compose file** gives each service's `image`, `environment`, `healthcheck`
  and `command`.
- **The `environment` row's file** (for example `ops/emanate.env`) gives `env`.
- **`.gitignore`** must cover everything `setup` and the checks create
  (`node_modules`, `.venv`, `target/`, `dist-newstyle/`). The factory commits with
  `add --all`, so a stray build directory fails the merge.
- **Version pins** — `engines`, `.python-version`, `rust-toolchain*` — give the
  image's runtime versions.
- **A dotenv load with `override: true`**, or test code that rewrites a variable,
  silently ignores `env`; raise it.

## Build each key

- **`image`.** One runtime: the official Debian tag with the full version, for
  example `node:24.22.1-trixie`. A floating tag is a warning, not an error. Never
  `-slim` or `-alpine`. Several runtimes (Node with uv, Node with Rust, Haskell):
  no official image combines them, so propose a custom image and its Dockerfile,
  and ask who builds and publishes it, for which architectures. The official
  `rust` image lacks clippy and rustfmt; with uv set `UV_PYTHON_DOWNLOADS=never`
  in the image, or the downloaded Python is lost with `HOME=/tmp`.
- **`services`.** One per `## Test infrastructure` row, named as the row. Keep the
  major version `stack.md` gives and pin the full tag. Credentials and healthcheck
  come from the compose file when there is one; compose's `CMD` list becomes one
  string. Default healthchecks go over TCP: `pg_isready --host 127.0.0.1 …`,
  `mysqladmin ping --host 127.0.0.1 …`, `redis-cli ping | grep -q PONG`. SQLite
  lives in the process and needs no service.
- **`env`.** Copy each variable from the environment file. Replace
  `localhost:<host port>` with `<service>:<container port>`. Check the credentials
  match the service's own `env`. Never carry the recipe's `environment` row into
  `setup`.
- **`setup`.** The `dependencies` and `generated artifacts` rows, each in its own
  subshell — `(cd source/web && npm ci) && (cd source/api && uv sync --locked)` —
  so one row's `cd` cannot move the next.
- **Run checks.** Phase `quality` first (lint, types, format, build), then phase
  `tests`. Each command starts `cd <source_root>[/<package>] &&`. No watch mode:
  `vitest run`, `npx --no-install jest`. Jest unit suites take `--maxWorkers=2`; a
  suite whose config already sets `maxWorkers` takes no flag. A suite that may
  still be empty takes `--passWithNoTests`, since every unit runs every check.
  Never copy a profile's "machine-readable results" recipe: its `{file}` reaches
  bash literally, and "tolerated non-zero" as `|| true` makes the check always
  green.
- **Review checks.** Optional, and only when the operator wants them (Q13): each
  costs a reviewer session per round and its findings cost repairs. One phase
  named `review`, after `tests`, with one check per concern. The default reads
  `'{profiles}#Review focus'`: today the android, angular, ios, nestjs and react
  profiles carry that section. Add a project skill or a file (`CLAUDE.md`, a
  section of a conventions document) only when the operator names it, and give
  each check a one-sentence `focus`. Every skill and `read` entry must be
  committed before the run.
- **The claims check.** The last phase, alone. Roots are literal directories that
  hold tests: `<source_root>/<package>/test`, plus `src` where tests sit beside the
  code (NestJS `*.spec.ts`, Rust). Never a glob copied from `## Test conventions`,
  never a package root, never `.`.
- **Monorepos.** One image, one `setup` that installs every package, one run check
  per package that exists on disk. A `cd` into a package not created yet turns
  every unit red; re-run this skill when a package appears.

The profile frontmatter `gates:` is not a command. A profile's `## Test
infrastructure` probe does not apply either: the factory starts the services itself.

## Ask

One question at a time, the default in brackets; closed questions through the
harness's question tool with the default marked as recommended. Ask only when the
sources leave it open.

| # | Question | When | Default |
|---|---|---|---|
| Q1 | Which image runs the agents, and from which registry can the run's machine pull it? | always | the full Debian tag; a custom image for several runtimes |
| Q2 | Confirm the image description. | always, after Q1 | one sentence per toolchain and version |
| Q3 | Which tag and test credentials does service `<n>` use? | per row with no compose entry | the `stack.md` major, newest full tag |
| Q4 | The database is external: how do the tests reach it? | `## Shape` says external | none — a service cannot model it |
| Q5 | Which variables does the application read? | no environment file and no `### Layout` | the `### Layout` names |
| Q6 | Which commands block a unit, and in which phase? List every profile command not in the draft (`cargo fmt --check`, `makemigrations --check`, e2e). | always | quality first, then tests |
| Q7 | Which package manager, and how is the monorepo scoped? | no lockfile and `## Tooling` silent | `npm` |
| Q8 | Confirm each claim root. | always | the roots built above |
| Q9 | Exclude the tests that cannot run in a container (browser e2e, Android instrumented, Karma with Chrome)? | a profile lists them | exclude |
| Q10 | Are there generated artifacts (Prisma, codegen)? | the recipe has no such row | none |
| Q11 | Does any test need a real secret, or `setup` a private registry? | the code reads an external credential | no — the factory has no channel for secrets; say so |
| Q12 | Does the machine reach the internet through a proxy or a mirror? | always | no; if yes, `HTTP(S)_PROXY` plus a `NO_PROXY` naming `orchestrator` and every service |
| Q13 | Add a review phase? With which rules: the profiles' `## Review focus`, project skills, other files? | a profile has `## Review focus`, or the operator asks | no review; if yes, `'{profiles}#Review focus'` |

## What is never deduced

| Value | Why |
|---|---|
| `image.name` and its registry | no profile names an image, and an unpullable one stops the run |
| exact service tags | the prose gives only the major version |
| which commands block a unit, and the phase order | the profiles give commands, not policy |
| whether to review, and against which rules | a review is a cost the operator chooses |
| secrets | `env` is committed and shown to every agent |

## An empty project

Today, with no code under `source_root`, the factory scaffolds the project before
the first unit and adapts it to this file. When the profiles match one of its
templates, follow that template's layout: `react-nestjs-npm` keeps one package
(`source/src`, `source/test`, `source/web/test`); `react-fastapi-uv` uses
`source/backend/tests`, `source/web/src`, `source/web/test`. Otherwise warn that the
scaffold will adapt the project to these commands, and that roots not yet on disk
are expected.

## Updating an existing file

- Read the working-tree file and the base branch's committed one; warn when they
  differ.
- Detect the old shapes: no `image` (written before images), and `tests` with
  `roots` (a ticket's wording, never the reader's). Propose a migration.
- Re-derive the proposal from the sources above, then compare key by key. Keep the
  operator's values unless they contradict `stack.md` or a reader rule.
- Show a unified diff with what is added, changed and removed, and the reason for
  each removal. Write nothing without approval.
