# Manifest format — slices, consolidated manifest & provenance

Two shapes: the **per-scanner slice** each of the four scanners returns (Phase 1),
and the **consolidated manifest** the synthesis builds from them (Phase 2). Both are
**working state**, staged in the session scratchpad (or an operator-named path) —
**never committed into `.inspire_kb/`**. The KB holds blessed artifacts; the
manifest is the raw archaeology behind them.

Throughout, a candidate carries a stable local key (`c1`, `c2`, …) used to refer to
it in the review dialogue and in cross-links.

## Per-scanner slice (Phase 1 return value)

Each scanner returns a structured object, never prose. The `slice` names match the
four scanners: `stack` · `screens` · `logic` · `styles`. Every candidate pins to
`file:line` evidence and a `confidence` (`high` = unambiguous signal · `medium` ·
`low` = inference). The exact fields per slice are listed at the end of each
`scanner-*.md` brief; the shared envelope is:

```yaml
slice: screens                 # stack | screens | logic | styles
scanner: B
candidates:
  - key: c7
    kind: screen               # screen | entity | action | pattern | component | token | stack-choice | infra
    ...slice-specific fields...
    evidence: [apps/web/src/pages/billing/InvoicesList.tsx:1]
    confidence: high
consolidations:                # analogous artifacts this scanner found
  - collapse: [c7, c9, c14]    # keys that are the same thing
    into: pattern:list
    note: three list views share one structure
```

## Consolidated manifest (Phase 2 output)

One document per scan. YAML front matter for the run, then per-module groupings,
then the cross-cutting graph, verdicts, and gaps.

```yaml
---
source: ../legacy-app            # scanned path or repo URL
scanned_at: 2026-07-20           # from CLAUDE.md currentDate / date
stack: "TypeScript · NestJS + React · PostgreSQL (Prisma)"
scanners: [stack, screens, logic, styles]
modules_inferred:
  - slug: billing
    prefix: BIL
    source_roots: [src/billing, apps/web/src/pages/billing]
---

## Module: billing

### Features (derived)
- key: f1
  proposed_id: BIL-01
  name: Issue an invoice
  realized_by: {screens: [c7], actions: [c18]}   # the derivation
  actor: billing-admin           # from the auth gate on the endpoint
  ui_expected: true
  confidence: high
  decision: keep                 # keep | merge:<key> | rename:<new> | drop | defer

### Screens
- key: c7
  proposed_id: invoices-list
  route: /billing/invoices
  candidate_pattern: list        # consolidated from pattern:list
  covers_features: [f1]
  data_source: billing::invoice
  evidence: [apps/web/src/pages/billing/InvoicesList.tsx:1]
  decision: keep

### Domain — entities
- key: c12
  proposed_id: billing::invoice
  fields:                        # reconciled across schema + validator
    - id: uuid — PK
    - number: string — UNIQUE, NOT NULL
    - status: enum(draft|issued|paid|void) — NOT NULL, default draft
    - total_cents: integer — NOT NULL, CHECK >= 0
  invariants: [number unique per tenant]
  aliases: [InvoiceDTO]
  conflicts: []                  # e.g. total: integer (schema) vs number (DTO)
  evidence: [prisma/schema.prisma:120, src/billing/invoice.validator.ts:15]
  decision: keep

### Domain — actions
- key: c18
  proposed_id: billing::invoice::create    # plural→singular applied
  verb: create
  touches: [billing::invoice: written, billing::customer: read]
  requires: []
  endpoint: "POST /invoices"     # how B ↔ C was matched
  back_source_feature: f1        # REQUIRED — set during derivation
  evidence: [src/billing/invoice.service.ts:88]
  decision: keep

### Patterns / components (consolidated)
- key: p1
  kind: pattern
  name: list
  instances: [c7, c9, c14]
- key: k1
  kind: component
  name: status-badge
  adopters: [c7, c22]

## Traceability graph
- c7 (invoices-list) → c18 (invoice::create) → billing::invoice → [number, status, total_cents]

## Bootstrap verdicts
- stack.md: keep local — source is a Vite scaffold, less elaborated than the KB.
- design-system.md: migrate (needs ADR) — source has a full token system.

## Gaps
- c31 (screen settings) references GET /prefs — no action explains it (unresolved cross-link).
- billing::invoice::void — action with no screen and no derived feature (orphan).
```

## Field rules

- **`key`** — stable within one manifest; cross-references (`covers_features`,
  `realized_by`, `back_source_feature`, `collapse`, `merge:<key>`) use keys.
- **`evidence`** — `file:line` pointers into the **source** (never into
  `.inspire_kb/`). This is *provenance* — it explains why a candidate surfaced; it is
  **not** a back-source.
- **`confidence`** — `high` / `medium` / `low`. Low is a reason to ask, not to hide.
- **`decision`** — set in Phase 3. Only `keep` / `rename` / `merge` are authored;
  `drop` is dropped; `defer` gets a tracker ticket so it isn't lost.
- **`back_source_feature`** (actions) — **required**. An action with no feature is a
  gap: derive/create the feature first (upstream invariant).
- **`realized_by`** (features) — the screens + actions the feature was derived from;
  drives the authoring order and the cross-layer links.

## Provenance in authored artifacts

When a `keep` candidate is authored (Phase 4), the created KB artifact carries a
**lightweight, clearly non-authoritative** provenance trail:

```markdown
## Notes

> Extracted from `../legacy-app` on 2026-07-20 — archaeology, confirm or remove on review.
> Evidence: `src/billing/invoice.service.ts:88`, `prisma/schema.prisma:120`.
```

Lives in `## Notes` — never in a `## Why` / `## Purpose` / `## Rationale`, which must
carry a real feature wikilink. It is a prompt to verify, not authority; it resolves
as the artifact is promoted.

## Durable record

The manifest is transient. The durable record of *what was extracted* is the **task
tracker**: one ticket per authored artifact via
`/inspire_workspace task create --epic extract`. No new KB structure — extract reuses
the tracker like the other skills.
