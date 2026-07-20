# INSPIRE — workspace guide for Claude

This repository is the **home of the INSPIRE methodology** (a software
engineering methodology for the agentic era) and a **template** for
bootstrapping new specification-driven projects. It was extracted from
`openbims-pdd` (Genomcore) on 2026-07-20. See [README.md](README.md) for the
full overview.

## Structure

- `site/` — the INSPIRE microsite (canonical explanation; open `site/index.html`).
- `skills/` — the 9 agent skills (the guardrail layer's judgment half).
- `hooks/` — git-time enforcement hooks (`pre-commit`, `pre-pr`).
- `bin/` — the validators + golden fixtures (the guardrail layer's mechanical half).

`skills/`, `hooks/` and `bin/` sit at the **top level** (not under `.claude/`),
so Claude Code does not auto-load them here — this repo is a reference/template,
not a live workspace. Adoption = copy them into a target project's `.claude/`.

## Pending — next session (to be opened from this repo)

The guardrail layer is a **faithful, not-yet-generalized** extraction from
OpenBIMS. Generalizing it is the reason to open a working session here:

- [ ] Rename skills `openbims-*` → `inspire-*` and strip OpenBIMS domain content
      (PDD, the SDD module layout, the React console, DuckDB mock data, the HTML manual).
- [ ] Decouple the validators (`bin/`) and hooks from hard-coded `spec/sdd/`
      paths; make the SDD layout configurable.
- [ ] Ship a runnable `.claude/` so a new project works by copy.
- [ ] Extract the horizontal/vertical prototype conventions as reusable scaffolding.
- [ ] Publish the microsite.

Until then, treat `skills/`, `hooks/` and `bin/` as an OpenBIMS-flavored
reference implementation to adapt, **not** a drop-in.

## Provenance

- The microsite `site/` was **moved** here from `openbims-pdd` (removal PR: Genomcore/openbims-pdd#58).
- `skills/`, `hooks/` and `bin/` were **copied verbatim** from `openbims-pdd/.claude/`; those copies remain in that repo untouched.
- The OpenBIMS-specific alignment ledger (`alineacion-datum-openbims.md`, the *Datum ↔ OpenBIMS* mapping) intentionally **stays** in `openbims-pdd`.
