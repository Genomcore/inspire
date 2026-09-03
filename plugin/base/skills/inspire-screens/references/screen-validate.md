# Screens — validate
> Part of [inspire-screens](../SKILL.md). Read when the entry's index routes here, together with [`screen-checks.md`](screen-checks.md).

## Pattern / component drift

- **Pattern drift:** the screen names pattern X but its deviations would
  fundamentally change that layout → add a variant to the pattern, or drop the
  `**Pattern:**` line: a screen with no shared layout is an ordinary screen, and
  its bindings stand unchanged either way.
- **Region drift:** the pattern's regions and the screen's bindings no longer meet
  — a required region accepting data with no data binding behind it, or a binding
  no region can hold. Fix whichever side is wrong; the join is a check, never a
  transfer of ownership.
- **Component drift:** the screen describes behavior that contradicts a
  component's canonical spec → update the component spec or fix the screen. A
  binding table restating a component's props is drift in the screen: props belong
  to the component's entry.

**Legacy check.** A kept legacy `patterns/` or `components/` `_index.md` is
operator-owned — the skill no longer reads or maintains it. An entry missing its
`**Purpose:**` line (or, for components, its `**State:**` line) draws a
suggest-on-next-touch note; never machine-edit it in.

## Live prototype browse — reverse-drift detection

Features often land in the prototype before the screen spec catches up. `validate` and
`audit` should **run the prototype** when possible to surface this **reverse
drift** (prototype ahead of spec).

1. **Run the prototype** (use the `run` / `verify` skills to launch it at the
   project's prototype root — `/prototype` by default; resolve `prototype_root` per
   [`_references/product-roots.md`](../../_references/product-roots.md), and treat
   `none` as nothing to browse). If it can't be launched, skip this section and note
   it — don't block the audit.
   With two or more UI surfaces the prototype is one shell per surface behind a
   suite landing: start the browse at that landing and walk the shell owning the
   tree being audited, every shell in turn when the audit spans the suite.
2. **Enumerate routes** by deriving them — `/inspire-screens routes` over the
   scope being audited ([`screen-routes.md`](screen-routes.md)), plus each tab
   variant and a representative record for a detail screen. A `shared/` screen is browsed in every
   shell that serves it — the same spec, one visit per shell, since a shell can
   drift on its own.
3. **For each route:** navigate and read what renders (prefer the accessibility
   tree; screenshots only when layout matters).
4. **Compare** against the spec, applying the triangulation matrix in the entry
   ([`inspire-screens/SKILL.md`](../SKILL.md) § Triangulation matrix):
   - Tabs/sections/controls in the prototype but absent from the spec → spec stale.
   - Spec describes UI not rendered → prototype regression, or spec ahead of code.
   - A prototype feature not traceable to any feature file → **WARN**, ask the user.
   - A prototype violating a canonical pattern/component/UX ADR → code regression;
     suggest `/inspire-prototype`.
5. **Report reverse drift separately** from forward drift, with severity
   (Important = a whole feature/tab missing from the spec; Minor = a column, label,
   or control).
6. **Resolution:** reverse-drift findings suggest `/inspire-screens validate`
   to update the spec (the prototype is already correct) — the spec catches up to
   the code, not the other way around.

Preview snapshots are point-in-time — re-run navigation after every prototype
change.

## Cross-screen coherence

- Screens naming the same pattern in a module share their UX (control positions,
  search placement, tab ordering).
- Similar resources across modules share status vocabulary — and, where the same
  state recurs, the same state **key**.
- Transitions form a connected graph: every screen a user can reach is targeted by
  some navigation binding or dispatch outcome, by id. `routes` reports the
  unreachable ones ([`screen-routes.md`](screen-routes.md)).
