# Workspace — structure
> Part of [inspire-workspace](../SKILL.md). Read when the entry's index routes here.

Validate the vault structure at the top level (not module-scoped).

### The layout

The specification lives under `inspire_kb/01_spec/`, one directory per concept:

```
inspire_kb/
├── 00_bootstrap/                ← project, stack, glossary, semantic types, style tokens
├── 01_spec/
│   ├── _adr/                    ← global ADRs: {slug}.adr.md, {slug}.adr.rationale.md
│   ├── _design-system/          ← design-system.md, design-system.tokens.json,
│   │                               theme.md, theme.tokens.json,
│   │                               components/, layouts/, patterns/
│   ├── _modules/{module}/       ← {module}.module.md, _adr/, _features/,
│   │                               _domain/{entity}/, _processes/
│   ├── _bundles/                ← {bundle}.bundle.md
│   ├── _faces/{face}/           ← {face}.face.md, {face}.tokens.json, _index.md,
│   │                               _adr/, _screens/, _processes/
│   ├── _processes/              ← global processes
│   └── _migration/              ← written by /inspire:migrate (and a face split)
├── 06_spikes/
├── 98_lessons/
└── 99_tracker/
```

**The layout is for people. No tool depends on it.** Every validator, every skill
and the INSPIRE Factory find an artifact by its **typed extension** (`.module.md`,
`.feature.md`, `.entity.md`, `.action.md`, `.adr.md`, `.adr.rationale.md`,
`.bundle.md`, `.face.md`, `.screen.md`, `.process.md`, `.component.md`,
`.layout.md`, `.pattern.md`) anywhere under `01_spec/`, and resolve a link by its
**id**. A file in an unexpected directory is still found, so a misplaced file is a
`minor` finding for the people who read the tree, never a broken reference.

A leading `_` on a directory is INSPIRE structure; on a file it means navigation
(`_index.md`). A user-chosen id never starts with `_`.

### Checks

1. **CLAUDE.md** is present at the workspace root.
2. **Typed extensions:**
   - Every `.md` under `inspire_kb/01_spec/` is a typed artifact, a `README.md`, a
     face's `_index.md`, or `design-system.md` / `theme.md`. Anything else — a
     file with no typed extension — is a file no tool can find. `_migration/` is
     excepted: what `/inspire:migrate` could not place waits there for the operator.
   - No file carries the old layered names (`adr-{slug}.md`, `{module}.{entity}.md`,
     a screen without `.screen.md`). A layered directory (`01_adr/` … `05_screens/`)
     beside `01_spec/` is a half-migrated KB: `critical`, fix with `/inspire:migrate`.
   - Templates are `{type}.template.md` and live in the skills, never in the KB.
3. **Placement agrees with the concept**, for the people who read the tree:
   - each `*.module.md` sits at `_modules/{module}/`, and the module's features,
     entities, actions, ADRs and processes sit under that directory;
   - each `*.face.md` sits at `_faces/{face}/`, and that face's screens under its
     `_screens/`;
   - each `*.bundle.md` sits in `_bundles/`;
   - a process's placement agrees with the scope of its id (`global`, a module or a
     face).
   A misplaced file is `minor`: it is found anyway.
4. **Faces' navigation:** every face directory that holds screens carries an
   `_index.md` with its navigation prose — never a route column, and never a screen
   table: a search for `*.screen.md` under the face gives the screens, and routes
   derive from `module:` + `screen:`. Existence only; content is `/inspire-screens`'s.
5. **Task tracker:**
   - `inspire_kb/99_tracker/tickets/` has valid `.md` files at top level (open)
     and under `archive/` (closed). Frontmatter parses, enums match, ID format
     `TASK-[a-z0-9]{6}`.
   - `id` matches filename; no duplicate IDs across `tickets/` and `archive/`.
   - **Location ↔ status invariant:** every top-level ticket is `Open`; every
     archived ticket is `Done`/`Cancelled`.
   - `blocked_by` / `related_to` references to other `TASK-*` IDs resolve (warning
     if not).
6. **No orphan files:** no stale `.md` at `inspire_kb/` root (except
   `CONTRIBUTING.md` if present); nothing in `00_bootstrap/` that belongs in
   `01_spec/` (a `theme.md` or a roster file there is a leftover).

Uniqueness of ids, `_`-prefixed ids, and the agreement between extension and
frontmatter `type` are `spec-identity.sh`'s; this check does not repeat them.

### Output

`{severity}` is the same vocabulary the review uses — `critical` · `important` ·
`minor`, and `verify` when a check is inconclusive — per the `### Review rules` in
[`../SKILL.md`](../SKILL.md).

```markdown
# Vault Structure | {date}

## Typed extensions
- Untyped files under 01_spec/: {ok | N}
- Layered leftovers: {none | list}

## Placement
- Modules: {N}, faces: {N}, bundles: {N}, processes: {N}
- Misplaced: {ok | N}

## Faces' navigation
- Faces with _index.md: {N}/{total}

## Task tracker
- tickets/: {N} open
- tickets/archive/: {N} closed ({Done: N, Cancelled: N})

## Issues
- [{severity}] {description}

## OK
```
