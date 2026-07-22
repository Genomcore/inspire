---
kind: bootstrap-stack
status: default          # default (seeded from the OpenBIMS reference) → adapt per project
profiles: [react, nestjs]   # inspire-code stack profiles to load (see .inspire/skills/inspire-code/profiles)
---

# Tech stack

The application stack the product is built with. This is the single registry of
the official stack; adding a tool is an edit here, replacing a load-bearing choice
is an ADR ([`01_adr`](../01_adr)). Configure with `/inspire_bootstrap`.

> **Default**, seeded from the OpenBIMS reference implementation. Swap any layer
> for your project's choice — the skills are stack-agnostic and read this file.

## Shape

How the product is laid out. Established at `/inspire_bootstrap init`; it frames
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

## Conventions

- Repository layout, build/run commands, naming and formatting conventions, and
  environment setup live here too (add them per project).
- Shared primitives and contracts the system composes on are declared here so
  agents don't reinvent them.
