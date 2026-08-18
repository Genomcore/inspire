# Workspace — review (cross-cutting phases)
> Part of [inspire-workspace](../SKILL.md). Read when the entry's index routes here. Phases 1–2 (scope + module fan-out) are performed by the caller — the entry, or `review.workflow.mjs`.

### Phase 3 — Cross-module consistency

- **Dependency validation:** feature IDs referenced as dependencies in one module
  exist in the target.
- **ADR references:** all `[[adr-xxx]]` wikilinks resolve to files in
  `inspire_kb/01_adr/`.
- **ADR propagation alignment:** at *every* maturity, an ADR's consequences must
  cohere across the **in-repo design workspace** (features + screen spec + horizontal
  prototype + specs) — a contradiction there is critical. Higher maturities add
  *external* evidence checked only by pointer, never by inspecting the external
  artifact: `prototyped` needs a `**Prototype:**` pointer; `implemented` a codebase
  reference. A `design` ADR merely lacking external validation is NOT a finding; a
  `design` ADR that contradicts the horizontal prototype IS.
- **Surface references:** every `surfaces:` value in the vault resolves to an id in
  the roster, or to `all`. An unknown id is critical — it scopes the artifact to
  nothing. An **absent** field is never a finding: it means suite-wide. With no roster
  the check is vacuous, since a suite of one has no ids to resolve against.
  (`/inspire_surface review` runs the same check roster-side; here it is part of the
  pre-merge gate, over every artifact in scope.)
- **No undocumented circular dependencies.**

### Phase 4 — Vault structure

**Features tree:**
- Repo structure matches CLAUDE.md.
- No scripts, `.py`, `.xlsx`, `.deprecated`, or `.DS_Store` files in `inspire_kb/`.
- Every module has a hub in `inspire_kb/02_modules/`; its per-layer subfolders
  (`03_features`, `05_screens`, `04_domain`) stay in sync with it. Under a
  surface-first screens tree a module's screens live in one or more
  `{surface}/{module}/` directories: it owes at least one, never one per surface —
  a module realized on a single surface is normal.
- ADR files are `inspire_kb/01_adr/adr-*.md`.
- Modules are the module hubs: `inspire_kb/02_modules/*.md` excluding `_*.md`
  and `README.md`.

**screen spec tree:**
- `inspire_kb/05_screens/design-system.md` exists.
- `inspire_kb/05_screens/patterns/` and `components/` exist with entry files,
  at top level — beside any surface trees, never inside one.
- **The tree is in the shape the roster implies.** Both shapes are legitimate: flat
  `{module}/` with no roster or a single `kind: ui` surface, surface-first
  `{surface}/{module}/` (plus `shared/{module}/`) from two UI surfaces on. Derive
  which applies from [`_references/surface-scope.md`](../../_references/surface-scope.md)
  — never from what the tree used to be. Under 2+ UI surfaces, a flat `{module}/`
  directory is a **pre-split leftover** in either of its instances: the whole tree
  still flat, or one flat directory sitting beside surface trees. Name the instance
  and hand the roster-side diagnosis and the corrective sweep to
  [`/inspire_surface review`](../../inspire-surface/SKILL.md) (its
  pre-split-leftover check); this phase reports, it does not re-derive the fix.
  The check lives here because this is the only pass that walks the whole screens
  tree — a module review sees one module's directory.
- Every pattern/component referenced by a screen exists; no orphans (on disk, not
  referenced) — orphan counting respects blast radius, see Phase 6.

### Phase 5 — Prototype component adoption

- Enumerate the shared components catalogued in `inspire_kb/05_screens/components/`.
- For each, count adoption in the horizontal prototype at its configured root
  (`/prototype` by default — resolve `prototype_root` per
  [`_references/product-roots.md`](../../_references/product-roots.md); `none` means
  this phase has nothing to count and reports so): pages using the canonical
  component vs pages still inlining an equivalent.
- **From two UI surfaces on, count per shell.** The prototype holds one shell per UI
  surface, so report one line per shell rather than a single suite-wide ratio: a
  component adopted throughout one shell and absent from another is a different
  problem from a migration progressing evenly everywhere, and a pooled ratio reads the
  same for both. A
  component whose `surfaces:` list narrows it is counted only against the shells in
  that blast radius.
- Report consolidated drift. High drift is `important` (not critical) — migration
  progresses over time.

### Phase 6 — Catalog coherence

- Patterns catalog: for each pattern file, count references from screens.
- Components catalog: for each component file, count usages in the prototype.
- Flag patterns/components with 0 references (unused or not migrated yet).
- **Judge an entry inside its own blast radius.** A catalog entry carrying `surfaces:`
  is counted only against the surfaces it names — a `surfaces: [admin]` pattern used
  across the admin shell and nowhere else is fully adopted, not an orphan. Zero
  references *within its blast radius* is the finding. An absent field still means
  suite-wide, so an unscoped entry is judged as before.
- Flag screens claiming a pattern/component that doesn't exist.
- **Design-system variance signal.** Report how many per-surface variant sections
  `05_screens/design-system.md` carries and how much of the file they occupy. Those
  sections are defined by
  [`/inspire_bootstrap design-system`](../../inspire-bootstrap/SKILL.md), which allows
  them deliberately and expects them to stay rare; a count that keeps climbing is the
  early shape of a design system splitting in place, which is why it is worth
  counting. It is a **signal, not a finding**, and is treated as every signal is —
  see the signals rule in [`../SKILL.md`](../SKILL.md) § Review rules.

### Signals

Alongside the findings above, this review runs `.inspire/bin/trust.sh report` and pastes
its output verbatim — the artifact-trust groups, machine-computed; see
[trust-stamps](../../_references/trust-stamps.md#report) for what each group means. The
design-system variance count (Phase 6) is reported here too, not under Catalog Coherence.
