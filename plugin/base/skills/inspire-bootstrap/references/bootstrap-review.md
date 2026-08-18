# Bootstrap — review checklist
> Part of [inspire-bootstrap](../SKILL.md). Read when the entry's index routes here.

- `project.md`, `stack.md` and `theme.md` exist and parse.
- `project.md` declares a valid `output_language`. Flag if missing/empty.
- `glossary.md` exists and parses — a header row and its separator, then zero or more
  data rows. That is the shape R4 of
  [`_references/writing-style.md`](../../_references/writing-style.md) consumes. **Zero
  data rows is valid**, not a finding: an empty term list binds nothing and is the
  honest state of a project that has settled no naming question yet. Flag a missing
  file, a broken table, or a row whose approved term also appears in another row's
  rejected synonyms.
- `stack.md` has a `## Shape` section, and the declared layers are coherent with
  it (no frontend stack on a backend-only product; a data layer iff the shape
  deploys a database; a mobile stack iff mobile is in scope). Flag a `shape:
  undecided` platform as still-open, to revisit.
- `stack.md` declares `source_root` and `prototype_root` (frontmatter). Flag if
  missing. `source_root: .` and `prototype_root: none` are valid (brownfield); a
  relative path must not escape the repo.
- The project's root `README.md` exists and is the project's own (not the
  template's methodology README, which install removes). Flag if missing and offer
  to run the `readme` flow.
- No load-bearing stack choice contradicts a current ADR in `01_adr` — one present
  and not superseded or rejected.
- `05_screens/design-system.md` exists (it should have been seeded from `theme.md`
  at install); flag if missing. It is expected to **diverge** from the default
  `theme.md` as the project evolves — divergence is not drift.
- **No `design-system.*.md` sibling exists**, anywhere under `05_screens/`. One is
  an override attempt by another name; flag it and offer to fold what it holds back
  into the one file as a named variant section (see the `design-system` flow in
  [`../SKILL.md`](../SKILL.md) § Subcommand: design-system).
- If `inspire_kb/00_bootstrap/surfaces.md` exists, the roster's own coherence is
  `/inspire_surface review`'s check, not this one — point there rather than
  duplicating it.
- Flag any stack layer still on the seeded default when the project has clearly
  moved past it.
