# 01 · Architecture Decision Records

The **why** behind the system's shape. One file per decision, capturing the
context, the options weighed, the choice, and its consequences.

- **Skill:** `inspire-workspace` (ADR lifecycle — create / update / promote /
  supersede).
- **Maturity ladder:** `design → prototyped → implemented`. A decision moves
  up the ladder as it is validated; superseded decisions stay in the tree with
  a pointer to what replaced them.
- **Layout:** one `{id}-{slug}.md` per ADR, plus an `_index.md` catalog.

ADRs constrain the layers below them: specs, prototypes and UI must stay
aligned with any decision within its maturity's reach.
