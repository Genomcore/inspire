---
kind: bootstrap-stack
status: set # confirmed via /inspire-bootstrap init, 2026-09-18 (OpenBIMS reference stack kept as-is)
wire_conventions: [rest]
profiles: [react, nestjs, postgres] # inspire-code stack profiles to load (see .claude/skills/inspire-code/profiles)
source_root: source # where production code lives (inspire-code). "." = repo root (brownfield, in place); a relative path otherwise
prototype_root: prototype # where the horizontal prototype lives (inspire-prototype). "none" = no horizontal prototype
---

# Tech stack

The application stack the product is built with. This is the single registry of
the official stack; adding a tool is an edit here, replacing a load-bearing choice
is an ADR ([`01_adr`](../01_adr)). Configure with `/inspire-bootstrap`.

> Confirmed at `/inspire-bootstrap init` (2026-09-18): the OpenBIMS reference stack
> is kept unchanged. It is the stack the landing page markets, so the demo runs on it.

## Shape

How the product is laid out. Established at `/inspire-bootstrap init`; it frames
which layers below apply. **Load-bearing** — changing it later (adding a backend,
adding mobile, moving off a deployed database) is an ADR.

- **Platform:** monorepo — **frontend + backend**. (Alternatives: frontend-only ·
  backend-only, an API / service · or *undecided* — revisit once the prototype
  clarifies; don't force it.)
- **Frontend targets:** **web**. (Alternatives: mobile-only · web + mobile — mobile
  pulls in a mobile UI stack, e.g. React Native / Expo, ideally sharing
  types/logic with web.)
- **Backend:** yes — an API / service layer (see *Backend / runtime* below).
- **Database provisioning:** **deploy** the metadata database (see *Data*) as part
  of the platform. (Alternative: connect to an **existing external** database — no
  provisioning here, just connection config.)
- **Local dev database:** yes — run it **locally via Docker**, like any other
  service in the dev stack; fall back to deploying it directly on the host only if
  Docker isn't available. (Alternative: no local DB — develop against a
  shared/remote one.)
- **Product roots:** production code at `source_root` (default `source/`) and the
  horizontal prototype at `prototype_root` (default `prototype/`) — set in the
  frontmatter above. A greenfield project keeps the defaults; **brownfield** installing
  into an existing repo sets `source_root: .` (the repo root *is* the code) and often
  `prototype_root: none`.

## Language

- **TypeScript**, end to end (backend and frontend), with shared types across the
  API boundary.

## Frontend

- **React** — the UI library (the app consoles and any embedded frontends).
- **Vite** — dev server + build.
- **Tailwind CSS** — utility-first styling (tokens in [`theme.md`](theme.md)).
- **shadcn/ui** (Radix primitives) — the shared component layer.
- **Lucide** — icon set.
- **Recharts** — charts. **@xyflow/react** — node/graph canvases.
- **react-router** — routing. Path alias `@` → `src/`.

## Backend / runtime

- **Node.js** — the single backend runtime for platform services, shared
  `@scope/*` SDK packages, and the CLI.
- **NestJS** — the backend application framework (modules, DI, controllers/providers).

## Data

- **PostgreSQL** — system metadata database.

## Prototype (mock data)

- The horizontal prototype at [`/prototype`](../../prototype) runs on **mocked
  data, not a real backend** — pick whatever mock-data approach fits the project
  (in-memory fixtures, static JSON, a WASM database, …). Not fixed by default.

## Tooling

- One package manager, one lint/format config, one shared component library across
  consoles, satellites and SDK — `class-variance-authority` / `clsx` /
  `tailwind-merge` for component variants, ESLint for linting.

## Wire conventions

Which convention set the product's transport follows, and the project's answer to
each of that set's `## Project policy` questions — the existence-leak choice, the
validation status, the error body shape. Decided **once**, at
`/inspire-bootstrap stack`, and never re-asked per feature: the ids go in the
frontmatter as `wire_conventions: [<id>, …]`, the answers in the table below. The
catalogue is
[`_references/conventions/`](../../.claude/skills/_references/conventions/README.md).

| Decision | Answer |
|---|---|
| Existence leak (resource exists, caller may not see it) | `404` |
| Validation failure status | `400` |
| Expired credential | `401`, distinct code in the error body |
| Error body shape | `application/problem+json` (RFC 7807) |
| Create with an existing natural key | `409` |
| Pagination contract | cursor |

An unanswered decision is recorded as **not decided yet**, never left out: the
convention's own default then applies, and saying so is what keeps a later test
from pinning a different choice as though it were the contract.
`/inspire-emanate plan` reports these rows so a spawned tester asserts the
project's decision instead of inventing one.

## Test infrastructure

The services the test suites run against — a database, a broker, a cache. Each row
names a **compose service**, so a stack profile's own probe recipe can ask whether
it is up and *healthy* before the first red test. Declared here, realized in the
compose file, and brought up **by the operator** — never started silently: a
connection error is not a red test, it is a test that never ran. A load-bearing
addition is an ADR.

| Component | Purpose |
|---|---|
| `postgres` | metadata database the NestJS e2e suites run against (PostgreSQL 16, `docker compose up -d --wait postgres`) |

## Worktree recipe

What turns a fresh checkout into a tree the suites actually run in — the
**environment** (from a committed, non-`.env` source: an agent's harness refuses
every path whose basename is `.env`, so the operator's own file can neither be
read nor copied), then the **dependencies** and the **generated artifacts** that
are git-ignored and therefore absent from a new worktree. One row per step, run
in the order written. `/inspire-emanate` runs these in every phase worktree
before a persona spawns; without them a run improvises its own, differently each
time. Commands only — no `.env` file is ever written.

| Step | Command |
|---|---|
| environment | `set -a; . ops/emanate.env; set +a` |
| dependencies | `cd source && npm ci` |

`ops/emanate.env` carries `DATABASE_URL` for the compose `postgres` service and
`PORT`. The suites also load it themselves through `source/test/support/env.ts`,
so a run that skipped the first row still reaches the database. There are no
generated artifacts: TypeORM migrations are TypeScript under `source/src/migrations/`
and run at application start.

## Quality gates

The **external** gate: which service keeps the history of the aggregate metrics
(coverage, duplication, bundle size), since the runtime must not store that
baseline in the repository it is judging. The in-repo half — lint rules, runner
thresholds, the CI job — is installed from each resolved profile's own
`## Quality gates` and is not re-listed here.

| Metric | Service | Pass condition |
|---|---|---|
| coverage | not decided yet | not decided yet (tracked: TASK-q7p3vn) |

The in-repo half is installed: `source/eslint.config.mjs` carries every `gates:`
row of the `nestjs` profile, `source/package.json` carries `coverageThreshold` at
the greenfield floor of zero, and `.escape-hatches.json` holds every ceiling at
zero. `.github/workflows/inspire.yml` runs the pre-PR hook and the `source/` suites
on every push and pull request. Branch protection and the coverage service are
human acts (tracked: TASK-q7p3vn).

## Conventions

`source/` holds tooling and configuration only until emanation writes code into
it. Every product file below is emanated from the knowledge base; none is
hand-written.

### Layout

| Path | Holds |
|---|---|
| `source/src/main.ts` | the NestJS bootstrap: creates `AppModule`, applies a global `ValidationPipe` with `whitelist` and `transform`, listens on `PORT` |
| `source/src/app.module.ts` | the root module: `TypeOrmModule.forRoot` from `DATABASE_URL` with `autoLoadEntities`, `synchronize: false`, `migrationsRun: true`; imports every module under `src/{module}/` |
| `source/src/{module}/{layer}/` | one directory per KB module (`samples`), four layers per the `nestjs` profile: `controllers`, `application`, `infrastructure`, `domain` |
| `source/src/{module}/{module}.module.ts` | the Nest module that wires those layers and exports its application services |
| `source/src/migrations/` | TypeORM migrations, one timestamp-named TypeScript file per change, append-only |
| `source/src/data-source.ts` | the TypeORM CLI data source (`DATABASE_URL`, entities `**/*.entity.ts`, migrations `migrations/*.ts`) |
| `source/test/{module}/` | e2e suites (`*.e2e-spec.ts`), one per controller and one per repository |
| `source/test/support/` | the shared e2e harness; `env.ts` is present and loads `ops/emanate.env` |
| `source/web/src/main.tsx` | the React entry: renders `App` into `#root`, imports `index.css` |
| `source/web/src/App.tsx` | the router: one route per emanated screen, derived as `/{module}/{screen}` |
| `source/web/src/{module}/{screen}.tsx` | one component per screen in `05_screens/{module}/` |
| `source/web/src/index.css` | the design tokens of [`05_screens/design-system.md`](../05_screens/design-system.md), present |

### Wire

- The API serves every action under `/api`: `{module}::{entity}::{action}` renders as
  `{verb} /api/{module}/{entities}` per the `rest` convention, and the web dev server
  proxies `/api` to the API on `PORT`.
- Every declared error maps to `application/problem+json` with the error code in
  `type`, per `## Wire conventions` above.

### Commands

Run from `source/`: `npm run build` · `npm run lint` · `npm run typecheck` ·
`npm run test` (unit, `src/**/*.spec.ts`) · `npm run test:e2e` (serial, against
the compose `postgres`) · `npm run dev` (API and web together).

### Persistence

TypeORM, per the `nestjs` profile § Persistence: one table per entity named with the
plural (`samples`), snake_case columns, `unique` as a unique index,
`immutable` as a `BEFORE UPDATE` trigger in the same migration, `id UUID DEFAULT
gen_random_uuid()`. Case-insensitive uniqueness of `code` is a unique index on
`lower(code)`.
