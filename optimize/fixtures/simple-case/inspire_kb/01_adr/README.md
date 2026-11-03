# 01 · Architecture Decision Records

The **why** behind the system's shape. One file per decision, capturing the
context, the options weighed, the choice, and its consequences.

- **Skill:** `inspire-adr` (ADR lifecycle — create / update / promote /
  supersede).
- **Maturity ladder:** `design → prototyped → implemented`. A decision moves
  up the ladder as it is validated; superseded decisions stay in the tree with
  a pointer to what replaced them.
- **Layout:** one `adr-{slug}.md` per ADR (or `adr-{module-prefix}-{slug}.md` for
  module-scoped decisions) — the glob is the catalog. Slug-only — no numeric
  prefix: numbers collide when two branches each grab the next one. The
  canonical id is the filename without `.md`.

ADRs constrain the layers below them: specs, prototypes and UI must stay
aligned with any decision within its maturity's reach.
