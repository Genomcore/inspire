# Bootstrap — review checklist
> Part of [inspire-bootstrap](../SKILL.md). Read when the entry's index routes here.

## Subcommand: review

- `project.md` and `stack.md` exist and parse, and so does
  `01_spec/_design-system/theme.md`.
- `project.md` declares a valid `output_language`. Flag if missing/empty.
- `glossary.md` exists and parses — a header row and its separator, then zero or more
  data rows. That is the shape R4 of
  [`_references/writing-style.md`](../../_references/writing-style.md) consumes. **Zero
  data rows is valid**, not a finding: an empty term list binds nothing and is the
  honest state of a project that has settled no naming question yet. Flag a missing
  file, a broken table, or a row whose approved term also appears in another row's
  rejected synonyms.
- `style-tokens.md` exists and parses — a `| Check | Token |` header, its separator,
  then zero or more rows whose check is `R6` or `R7`. **Zero rows is valid.** Flag a
  missing file, a row with another check, and, when `output_language` is not English,
  an empty table: R6 and R7 then check nothing but strikethrough, so offer to propose
  tokens.
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
- No load-bearing stack choice contradicts a current global ADR (`*.adr.md` in
  `01_spec/_adr/`) — one present and not superseded or rejected.
- `01_spec/_design-system/design-system.md` exists (it should have been seeded from `theme.md`
  at install); flag if missing. It is expected to **diverge** from the default
  `theme.md` as the project evolves — divergence is not drift.
- `design-system.tokens.json` exists beside it, and `design-system.md` carries
  `## Supported viewports`, `## Icons` and `## Reference` — run
  `.inspire/bin/design-system-coherence.sh`; anything it reports missing is closed
  by the `design-system backfill` flow. Report its count of `generated` tokens as
  values still awaiting a decision.
- **No second design-system file exists**, anywhere under `01_spec/` — no
  `design-system.*.md`, and no `design-system.md` inside a face. One is an override
  attempt by another name; flag it and offer to fold what it holds back
  into the one file as a named variant section (see the `design-system` flow in
  [`../SKILL.md`](../SKILL.md) § Subcommand: design-system).
- A face's `{face}.tokens.json` adds tokens only: flag one that redefines a path
  `design-system.tokens.json` already defines.
- No `theme.md`, `theme.tokens.json` or roster file sits in `00_bootstrap/`: the
  theme lives in `01_spec/_design-system/`, and faces and bundles carry their own
  packaging. A leftover means the KB was not migrated — point to `/inspire:migrate`.
- The coherence of faces and bundles is `/inspire-face review`'s check, not this
  one — point there rather than duplicating it.
- Flag any stack layer still on the seeded default when the project has clearly
  moved past it.
