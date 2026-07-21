# INSPIRE — workspace guide for Claude

This repository is the **home of the INSPIRE methodology** (a software
engineering methodology for the agentic era) and a **template** for bootstrapping
new specification-driven projects. See [README.md](README.md) for the full
overview, or the manual at [inspire.openbims.dev](https://inspire.openbims.dev).

## Structure

The convention: **dotfolders = INSPIRE scaffolding**, non-dot dirs = the product
you build on top of it.

- `.inspire/` — the **guardrail runtime**, staged dormant (see below):
  - `.inspire/skills/` — the 8 agent skills (`inspire-*`): the judgment half
    (bootstrap · module · feature · domain · prototype · screens · workspace ·
    extract — the brownfield entry point that fans out four parallel scanners
    (stack & infra · UI screens · logic·API·DB · styles), consolidates their
    findings into cross-linked KB candidates, and delegates authoring).
  - `.inspire/bin/` — the validators + golden fixtures: the mechanical half. Spec
    root is configurable via `SDD_SPEC_ROOT` (defaults to `.inspire_kb/04_domain`).
    Test suite: `bash .inspire/bin/test/run-tests.sh`.
  - `.inspire/hooks/` — enforcement hooks: git-time `pre-commit` / `pre-pr`, and
    `session-start` (injects the project's `output_language` into every session).
  - `.inspire/templates/` — files materialized on the product side at
    instantiation (the `prototype/` + `source/` README stubs).
  - `.inspire/install.sh` — the instantiation script.
- `.inspire_kb/` — the **knowledge-base skeleton**: the navigable graph a project
  fills in. One layer per skill (`00_bootstrap`, `01_adr`, `02_features`,
  `03_prototypes`, `04_domain`, `05_screens`, `99_tracker`); each folder carries a
  README explaining its purpose and layout.
- `.manual/` — the INSPIRE **microsite / manual** (canonical explanation;
  published at inspire.openbims.dev; source here — open `.manual/index.html`).
The two product-side dirs below **do not exist in this template repo** — they are
the product you build, not INSPIRE. `install.sh` creates them (from
`.inspire/templates/`) when a fork is instantiated:

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
lived in `.claude/` inside *this* template repo, those skills would fire while the
template itself is edited — so it is staged **dormant** under `.inspire/`.

Instantiating a project (in a fork) is one command:

```bash
bash .inspire/install.sh
```

It copies `.inspire/{skills,bin,hooks}` → `.claude/{skills,bin,hooks}`, makes the
scripts executable, wires the hooks into `.claude/settings.json`, seeds
`05_screens/design-system.md` from `00_bootstrap/theme.md`, creates the
product-side `prototype/` + `source/` folders from `.inspire/templates/`, and
removes the template's own methodology `README.md` (a fork gets its own via
`/inspire_bootstrap init`). It is idempotent — `.inspire/` stays the versioned
source of truth; re-run it to refresh `.claude/` after pulling template updates
(existing `prototype/`, `source/` and a project's own `README.md` are left
untouched).

## Working in this repo

- This is the **template**, not a live project. Do **not** run
  `.inspire/install.sh` here — it would activate the runtime against this repo.
- Keep the runtime **generic**: the skills, the validators and the `.inspire_kb/`
  skeleton must stay stack-agnostic and free of any specific product's domain
  vocabulary. Concrete project content belongs in a fork's `.inspire_kb/`, not here.
- The KB ships as a **skeleton** — each layer has a README (and, where useful,
  starter files); a real project fills the rest in via the skills.
- Run the validator suite with `bash .inspire/bin/test/run-tests.sh` after touching
  anything under `.inspire/bin/`.
