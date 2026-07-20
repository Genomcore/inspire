# INSPIRE — workspace guide for Claude

This repository is the **home of the INSPIRE methodology** (a software
engineering methodology for the agentic era) and a **template** for
bootstrapping new specification-driven projects. It was extracted from
`openbims-pdd` (Genomcore) on 2026-07-20. See [README.md](README.md) for the
full overview.

## Structure

The convention: **dotfolders = INSPIRE scaffolding**, non-dot dirs = the
product you build on top of it.

- `.skills/` — the 6 agent skills (`inspire-*`): the guardrail layer's judgment
  half (module · feature · object · prototype · ui · workspace).
- `.inspire_kb/` — the **knowledge-base skeleton**: the navigable graph a
  project fills in. One layer per skill (`00_tech_stack`, `01_adr`,
  `02_features`, `03_prototypes`, `04_specs`, `05_ui`, `06_tracker`); each folder
  carries a README explaining its purpose and layout.
- `.manual/` — the INSPIRE **microsite / manual** (canonical explanation; open
  `.manual/index.html`).
- `prototype/` — the **horizontal prototype** (product-side, non-dot): the wide,
  shallow, mocked working model of the whole product. Its *learnings* live in
  `.inspire_kb/03_prototypes/horizontal.md`; vertical prototypes live in their own
  external repos, indexed under `.inspire_kb/03_prototypes/verticals/`.
- `source/` — the **production monorepo** (product-side, non-dot): the root of the
  actual product code, realized from the KB. An ADR reaches `implemented` maturity
  when it lands here.
- `bin/` — the validators + golden fixtures: the guardrail layer's mechanical
  half. Spec root is configurable via `SDD_SPEC_ROOT` (defaults to
  `.inspire_kb/04_specs`). Test suite: `bash bin/test/run-tests.sh`.
- `hooks/` — git-time enforcement hooks (`pre-commit`, `pre-pr`).

### Template vs deployed layout

Skills reference each other and the validators via the **deployed** `.claude/`
layout (`.claude/skills/…`, `.claude/bin/…`) — that is where they execute in a
real project. In *this* template repo they stage at `.skills/` and `bin/`, so
Claude Code does not auto-load them here. Instantiating a project means copying
(or linking) `.skills/` → `.claude/skills/`, `bin/` → `.claude/bin/`, and wiring
the hooks (see README → *Using this as a template*).

## Pending — generalization work

The guardrail layer is being generalized from its OpenBIMS origin. Done so far:

- [x] Delete OpenBIMS-only skills (`video`, `docs`, `mockdata`).
- [x] Rename skills `openbims-*` → `inspire-*` (directories, frontmatter, cross-refs).
- [x] Decouple validators/hooks from hard-coded `spec/sdd/` — rewired to the
      `.inspire_kb/` layout; `SDD_SPEC_ROOT` configurable; test suite green (43/43).
- [x] Establish the `.inspire_kb/` KB skeleton and move `site/` → `.manual/`.
- [x] Define the prototype model — horizontal at `/prototype`, verticals as
      external repos, learnings in `.inspire_kb/03_prototypes/`.
- [x] Rewrite the `inspire-prototype` skill to that model (stack-agnostic).
- [x] Reconcile `inspire-module` / `inspire-feature` to the flat
      `.inspire_kb/02_features/{module}/{use-case}.md` layout (drop PDD /
      core-satellite / submodules).
- [x] Strip the residual OpenBIMS **domain content** from all skill prose (the
      React "console", PDD vocabulary, the dangling
      `openbims-console/-cli/-pdd/-portal` refs, the mock-data / manual layers,
      Kratos/Keto specifics, the workspace review report skeleton). `.skills/` is
      now free of OpenBIMS domain vocabulary.

Remaining:

- [ ] Ship a runnable `.claude/` (or an instantiation script) that wires
      `.skills` → `.claude/skills`, `bin` → `.claude/bin`, and registers hooks.
- [ ] Fill in the project-specific KB conventions a real project needs (module ID
      prefixes, a starter `patterns/` + `design-system.md`, `00_tech_stack`).
- [ ] Publish the microsite.

## Provenance

- The microsite (now `.manual/`) was **moved** here from `openbims-pdd` (removal PR: Genomcore/openbims-pdd#58).
- The skills (now `.skills/`), `hooks/` and `bin/` were **copied** from `openbims-pdd/.claude/` and generalized here; the original copies remain in that repo untouched.
- The OpenBIMS-specific alignment ledger (`alineacion-datum-openbims.md`, the *Datum ↔ OpenBIMS* mapping) intentionally **stays** in `openbims-pdd`.
