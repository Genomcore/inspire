# Workspace — review (cross-cutting phases)
> Part of [inspire-workspace](../SKILL.md). Read when the entry's index routes here. Phases 1–2 (scope + module fan-out) are performed by the caller — the entry, or `review.workflow.mjs`. The validators run here, before the cross-cutting phases.

### Validators

Run the mechanical rules over the whole KB, whatever the module scope:

```bash
.inspire/bin/review.sh inspire_kb
```

It runs every rule in `review.sh`'s list, `spec-identity.sh`, `face-exposure.sh` and
`process-shape.sh` among them. Report each error as `critical` and each warning as
`important`, under the section its file belongs to, and name the rule. The judgment
phases below never restate a finding a validator already made.

### Phase 3 — Cross-module consistency

- **Dependency validation:** feature IDs referenced as dependencies in one module
  exist in the target.
- **ADR references:** all `[[adr-xxx]]` wikilinks resolve to an `*.adr.md` under
  `inspire_kb/01_spec/` — global, a module's `_adr/` or a face's `_adr/`.
- **ADR propagation alignment:** at *every* maturity, an ADR's consequences must
  cohere across the **in-repo design workspace** (features + screen spec + horizontal
  prototype + specs) — a contradiction there is critical. Higher maturities add
  *external* evidence checked only by pointer, never by inspecting the external
  artifact: `prototyped` needs a `**Prototype:**` pointer; `implemented` a codebase
  reference. A `design` ADR merely lacking external validation is NOT a finding; a
  `design` ADR that contradicts the horizontal prototype IS.
- **Face and bundle references:** every `faces:` and `bundles:` value in the vault
  names an existing `*.face.md` or `*.bundle.md`. An unknown id is critical — it
  scopes the artifact to nothing. An **absent** field is never a finding: it means
  the whole project. (`/inspire-face review` runs the same check on the face and
  bundle side; here it is part of the pre-merge gate, over every artifact in scope.)
- **Exposure across faces:** `face-exposure.sh` reports each screen that binds an
  action its face's bundles do not expose. Here, judge the pattern: many findings on
  one face usually mean one missing bundle in its `bundles:`, not many wrong screens.
- **Processes across modules:** a module-scoped process whose `## Requires` reaches
  into another module is global in fact — route to `/inspire-process`.
- **No undocumented circular dependencies.**

### Phase 4 — Vault structure

**Specification tree:**
- Repo structure matches CLAUDE.md.
- No scripts, `.py`, `.xlsx`, `.deprecated`, or `.DS_Store` files in `inspire_kb/`.
- Every module has one `*.module.md`; its features (`*.feature.md`), entities
  (`*.entity.md`) and actions (`*.action.md`) sit under its directory. Tools find
  them by extension, so placement is for people: run the placement checks in
  [`workspace-structure.md`](workspace-structure.md), never a second set here.
- A module's screens live in faces, never in the module. A module whose actions no
  face binds and no bundle exposes is reachable by nobody — `verify`.
- ADRs are `*.adr.md`, each with its `*.adr.rationale.md` beside it. Read the
  decision for what binds.

**Design system and screens:**
- `inspire_kb/01_spec/_design-system/design-system.md` and
  `design-system.tokens.json` exist.
- `_design-system/patterns/`, `layouts/` and `components/` hold the catalog entries
  (`*.pattern.md`, `*.layout.md`, `*.component.md`), never inside a face.
- **No screen is shared between faces.** A screen that links or embeds another
  face's screen is shared structure that belongs in a layout or a pattern; hand it to
  `/inspire-screens`. This check lives here because it is the only pass that sees
  every face at once — a module review sees one module.
- Every pattern/component referenced by a screen exists; no orphans (on disk, not
  referenced) — orphan counting respects blast radius, see Phase 6.

### Phase 5 — Prototype component adoption

- Enumerate the shared components: every `*.component.md` under
  `inspire_kb/01_spec/_design-system/`.
- For each, count adoption in the horizontal prototype at its configured root
  (`/prototype` by default — resolve `prototype_root` per
  [`_references/product-roots.md`](../../_references/product-roots.md); `none` means
  this phase has nothing to count and reports so): pages using the canonical
  component vs pages still inlining an equivalent.
- **From two faces on, count per shell.** The prototype holds one shell per face, so
  report one line per shell rather than a single project-wide ratio: a component
  adopted throughout one shell and absent from another is a different problem from a
  migration progressing evenly everywhere, and a pooled ratio reads the same for
  both. A component whose `faces:` list narrows it is counted only against the
  shells of those faces.
- Report consolidated drift. High drift is `important` (not critical) — migration
  progresses over time.

### Phase 6 — Catalog coherence

- Patterns catalog: for each pattern file, count references from screens.
- Components catalog: for each component file, count usages in the prototype.
- Flag patterns/components with 0 references (unused or not migrated yet).
- **Judge an entry inside its own blast radius.** A catalog entry carrying `faces:`
  is counted only against the faces it names — a `faces: [admin]` pattern used
  across the admin face and nowhere else is fully adopted, not an orphan. Zero
  references *within its blast radius* is the finding. An absent field means the
  whole project.
- Flag screens claiming a pattern/component that doesn't exist.
- **Design-system variance signal.** Report how many per-face variant sections
  `01_spec/_design-system/design-system.md` carries and how much of the file they occupy. Those
  sections are defined by
  [`/inspire-bootstrap design-system`](../../inspire-bootstrap/SKILL.md), which allows
  them deliberately and expects them to stay rare; a count that keeps climbing is the
  early shape of a design system splitting in place, which is why it is worth
  counting. It is a **signal, not a finding**, and is treated as every signal is —
  see the signals rule in [`../SKILL.md`](../SKILL.md) § Review rules.

### Signals

Alongside the findings above, this review runs `.inspire/bin/trust.sh report` and pastes
its output verbatim — the artifact-trust groups, machine-computed; see
[trust-stamps](../../_references/trust-stamps.md#report) for what each group means. The
design-system variance count (Phase 6) is reported here too, not under Catalog Coherence.
