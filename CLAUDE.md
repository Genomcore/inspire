# INSPIRE — workspace guide for Claude

This repository is the **home of the INSPIRE methodology** (a software
engineering methodology for the agentic era) and a **template** for
bootstrapping new specification-driven projects. It was extracted from
`openbims-pdd` (Genomcore) on 2026-07-20. See [README.md](README.md) for the
full overview.

## Structure

The convention: **dotfolders = INSPIRE scaffolding**, non-dot dirs = the
product you build on top of it.

- `.inspire/` — the **guardrail runtime**, staged dormant (see below):
  - `.inspire/skills/` — the 7 agent skills (`inspire-*`): the judgment half
    (bootstrap · module · feature · object · prototype · screens · workspace).
  - `.inspire/bin/` — the validators + golden fixtures: the mechanical half. Spec
    root is configurable via `SDD_SPEC_ROOT` (defaults to `.inspire_kb/04_specs`).
    Test suite: `bash .inspire/bin/test/run-tests.sh`.
  - `.inspire/hooks/` — git-time enforcement hooks (`pre-commit`, `pre-pr`).
  - `.inspire/install.sh` — the instantiation script.
- `.inspire_kb/` — the **knowledge-base skeleton**: the navigable graph a
  project fills in. One layer per skill (`00_bootstrap`, `01_adr`,
  `02_features`, `03_prototypes`, `04_specs`, `05_screens`, `06_tracker`); each folder
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

### Template vs deployed layout — why the runtime is staged in `.inspire/`

Claude Code auto-loads skills from `.claude/skills/` and runs hooks registered in
`.claude/settings.json`. The skills also reference each other and the validators
via the **deployed** paths (`.claude/skills/…`, `.claude/bin/…`). If the runtime
lived in `.claude/` inside *this* template repo, those skills would fire while we
develop the template itself — so it is staged **dormant** under `.inspire/`.

Instantiating a project (in a fork) is one command:

```bash
bash .inspire/install.sh
```

It copies `.inspire/{skills,bin,hooks}` → `.claude/{skills,bin,hooks}`, makes the
scripts executable, and wires the hooks into `.claude/settings.json`. It is
idempotent — `.inspire/` stays the versioned source of truth; re-run it to refresh
`.claude/` after pulling template updates.

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
      Kratos/Keto specifics, the workspace review report skeleton). The runtime is
      now free of OpenBIMS domain vocabulary.
- [x] Stage the guardrail runtime under `.inspire/` and ship `.inspire/install.sh`
      to instantiate it into `.claude/` on a fork.
- [x] Seed `00_bootstrap` (`stack.md` + `theme.md`, defaulted from the OpenBIMS
      reference) and add the `inspire-bootstrap` skill to configure them.
- [x] Publish the microsite (`.manual/`).

Remaining:

- [ ] Ship a starter `05_screens/patterns/` + `design-system.md` (the module
      ID-prefix convention is already carried by the module/feature skills).

## Provenance

- The microsite (now `.manual/`) was **moved** here from `openbims-pdd` (removal PR: Genomcore/openbims-pdd#58).
- The skills (now `.skills/`), `hooks/` and `bin/` were **copied** from `openbims-pdd/.claude/` and generalized here; the original copies remain in that repo untouched.
- The OpenBIMS-specific alignment ledger (`alineacion-datum-openbims.md`, the *Datum ↔ OpenBIMS* mapping) intentionally **stays** in `openbims-pdd`.
