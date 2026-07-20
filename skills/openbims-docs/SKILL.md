---
name: openbims-docs
description: "Lifecycle of the HTML user manual: review drift, apply updates, capture screenshots, sync. Use when creating/updating/auditing user-facing docs against the PDD or the canonical format."
---

# /openbims_docs — User Manual

Lifecycle skill for `manual/` — the static HTML user manual generated for end users (product engineers, admins, clinicians). PDD is the source of truth; this skill keeps the manual aligned with it and with the canonical format below.

## Subcommands

| Subcommand | Purpose | Writes? |
|------------|---------|---------|
| `review [module\|--pdd\|--format]` | Audit drift. No files modified. | No |
| `update [module]` | Apply fixes: create missing stubs, regenerate nav entries, fix taxonomy violations. | Yes |
| `screenshots {module}` | Capture screenshots via Playwright against the running prototype. | Yes |
| `sync` | Run `sync-docs.sh` to publish `manual/` → `public/docs/`. | Yes |

Reviews are **read-only**. They flag issues and recommend which subcommand (or sibling skill) to run next. Updates are the author's responsibility.

### `review` — drift audit

Two axes, run together by default:

- **`--pdd`** — does the manual mirror `spec/pdd/`?
  - Every `spec/pdd/core/{module}/` has `manual/modules/{module}.html`.
  - Every submodule `.md` (excluding `_index.md`) has `manual/modules/{module}/{submodule}.html`.
  - Every `spec/pdd/satellite/{name}[.md|/]` has its mapped page (CLI → `manual/cli.html`, others → `manual/ecosystem/{name}.html`).
  - No manual page exists for a module/submodule/satellite that isn't in the PDD (stale pages).

- **`--format`** — does the manual follow the canonical structure (see below)?
  - `nav.js` top-level sections are exactly: `Getting Started`, `Modules`, `Ecosystem`, `Developers` (in that order).
  - `Module Map` (`modules/overview.html`) lives under `Getting Started`, not `Modules`.
  - No `Optional Modules` section, no `core`/`optional` badges in nav (activation group ≠ taxonomy).
  - Every submodule page has `<div class="breadcrumb">` and a `What it does` section.

**Runner:** `node manual/scripts/drift-report.mjs [--pdd] [--format] [--json]`. Exits non-zero if findings.

### `update` — apply fixes

When `review` flags issues, `update` resolves them:

1. Re-run `manual/scripts/generate-stubs.mjs` to materialize missing submodule / ecosystem stub pages. The generator is idempotent (never overwrites).
2. If `nav.js` violates the canonical structure, edit it to match (move items between sections, remove badges, restore section order).
3. If a manual page exists for a module that's gone from the PDD, flag for removal (but don't auto-delete unless user confirms — deletions are destructive).
4. Run `sync-docs.sh` at the end so `public/docs/` is up to date.

When run with a module argument (`update {module}`), scope the fixes to that module's pages + submodules.

### `screenshots {module}` — capture UI

Uses Playwright against the running `openbims-console` dev server (port 5173).

- Entry points are declared in `manual/scripts/capture-screenshots.mjs` under `MODULES`.
- Screenshots save to `manual/assets/screenshots/{module}/{screen}.png` at 1440×900 @2x.
- Embed via `<figure class="screenshot">` with `<img>` + `<figcaption>`. Use `<div class="screenshot-grid">` for galleries.
- Adding a new module means appending an entry to `MODULES` in the capture script — one URL per submodule screen.
- Requires the dev server to be running. Start it via `preview_start` (launch config `openbims-console`).

### `sync` — publish

Run `bash code/openbims-console/scripts/sync-docs.sh`. Copies the full `manual/` tree into `public/docs/`. Never edit `public/docs/` directly.

## Canonical structure (source of truth for `--format` checks)

Exactly four top-level sections, in this order:

1. **Getting Started**
   - `index.html` — landing
   - `architecture.html`
   - `infrastructure.html`
   - `deployment.html`
   - `modules/overview.html` — **Module Map** (how modules compose, what exists). This is the "how OpenBIMS is structured" page — it belongs here, not under *Modules*.

2. **Modules** — one entry per core module (except Marketplace, which lives in Ecosystem). Each module has:
   - A **main page** (`manual/modules/{module}.html`) with: user-facing description, screenshot (hero), links to submodules, architecture/diagram, tier behavior, activation behavior (if optional group), "How it connects" to other modules.
   - One **submodule page** per `.md` file (excluding `_index.md`) at `manual/modules/{module}/{submodule}.html`. Each submodule page walks the user through the feature with **screenshots per function** captured from the prototype.

3. **Ecosystem** — products adjacent to the core platform.
   - `modules/marketplace.html` (Marketplace is core-facing functionally but ecosystem-facing taxonomically)
   - `ecosystem/genomcore-cloud.html`
   - Additional satellite products from `spec/pdd/satellite/` (Marketplace Portal, Portals SDK…)

4. **Developers**
   - `developer-experience.html`
   - `cli.html` — OpenBIMS CLI (satellite product, but surfaced here for devs)
   - `api.html` — API Reference
   - `glossary.html`

## File structure

```
manual/
├── index.html, architecture.html, infrastructure.html, deployment.html
├── developer-experience.html, cli.html, api.html, glossary.html
├── modules/
│   ├── overview.html                  # Module Map (shown under Getting Started in nav)
│   ├── {module}.html                  # One per core module — overview
│   └── {module}/
│       └── {submodule}.html           # One per PDD submodule file
├── ecosystem/
│   └── {product}.html                 # genomcore-cloud, marketplace-portal, portals-sdk…
├── assets/
│   ├── styles.css                     # includes .breadcrumb, .screenshot, .stub-notice, tree nav
│   ├── nav.js                         # NAV_STRUCTURE — source of navigation
│   ├── openbims-logo.svg
│   └── screenshots/{module}/*.png     # Playwright output
└── scripts/
    ├── capture-screenshots.mjs        # Playwright → PNG
    ├── generate-stubs.mjs             # Idempotent stub creator
    └── drift-report.mjs               # Audit (PDD + format axes)
```

**Never edit** `code/openbims-console/public/docs/` directly — it is the publish target of `sync-docs.sh`.

## Canonical page templates

### Module overview page (`modules/{module}.html`)

Sections, in order:
- `<h1>` + badges (activation group if applicable — `Optional | Group: ai` is fine; it describes deployment, not taxonomy)
- Hero screenshot (`figure.screenshot`) — the module's main list screen
- `What it does` — 2-3 paragraphs, user-facing
- `Key concepts` — bulleted, bolded term + short explanation each
- Secondary screenshot showing detail/depth (optional)
- `How it connects` — two columns: *Depends on* / *Consumed by*
- `Key capabilities` — `.capabilities-grid` with one card per top-level feature (user-friendly name, not feature ID)
- `Around the module` — `.screenshot-grid` with submodule screenshots
- `What happens when disabled` (only for modules in an activation group)
- `Tier behavior` (Dev / Single-server / Production K8s)
- `Architecture diagram` — Mermaid

### Submodule page (`modules/{module}/{submodule}.html`)

- `.breadcrumb` link back to the module overview
- `<h1>` — submodule title
- `What it does` — 1-2 paragraphs
- One section per **user-facing function** with inline screenshot(s) showing that function in action
- Optional: `.stub-notice` while content is still being written

### Ecosystem page (`ecosystem/{product}.html`)

Same shape as a module overview but adapted: no activation group badge, "How it connects to OpenBIMS" instead of "How it connects".

## CRITICAL: Abstraction level

The manual is for **product engineers and administrators**, not internal developers. Translate PDD content (technical) to user-facing docs (functional).

| PDD concept | Manual concept |
|-------------|---------------|
| Feature ID (UMD-KG-03) | Never exposed |
| Subsystem name | Section heading |
| Implementation detail (Restate, V8, DuckDB) | Omitted or mentioned as "powered by X" |
| Connector → Server → Resource | "Connect your data sources" |
| Permission Set `module.resource.verb` | "Role-based access control" |
| ADR reference | Omitted (manual is not the architecture log) |

## Rules

1. **PDD is the source of truth.** Never invent features. If the manual mentions something, it exists in the PDD.
2. **User-facing language only.** No feature IDs, no subsystem names, no architectural jargon.
3. **English.** PDDs are Spanish; the manual is English.
4. **No historical language.** The manual describes current capabilities. Never "previously", "now replaces", "was removed".
5. **Taxonomy:** 12 core modules (PDD `spec/pdd/core/`) + satellite products (`spec/pdd/satellite/`). Never "Optional Modules" as a taxonomy bucket. "Optional" in a module badge refers to deployment activation groups, not categorization.
6. **Screenshots capture live state.** Don't run `screenshots` until the prototype screen is stable (matches its UISpec + canonical components).
7. **Editing nav = editing `nav.js` only.** Don't hand-edit sidebar HTML in pages.
8. **Idempotent generators.** `generate-stubs.mjs` must never overwrite existing pages; it only creates missing ones.

## Position in the workflow

Typically the second-to-last step before merge:

1. `/openbims_module` or `/openbims_feature` (PDD)
2. `/openbims_ui` (UISpec)
3. `/openbims_prototype` (React)
4. `/openbims_mockdata` (schema/data)
5. `/openbims_object` (SDD action descriptors + entity documents + consolidation; surfaces drive API/SDK/CLI/MCP slices)
6. **`/openbims_docs`** — `screenshots` + `update` for the changed module
7. `/openbims_workspace review` — final coherence check

## Quick reference

| Task | Command |
|------|---------|
| Audit everything | `node manual/scripts/drift-report.mjs` |
| Audit PDD alignment only | `node manual/scripts/drift-report.mjs --pdd` |
| Audit format only | `node manual/scripts/drift-report.mjs --format` |
| Machine-readable audit | `node manual/scripts/drift-report.mjs --json` |
| Capture screenshots | `node manual/scripts/capture-screenshots.mjs {module}` |
| Generate missing stubs | `node manual/scripts/generate-stubs.mjs` |
| Publish | `bash code/openbims-console/scripts/sync-docs.sh` |
