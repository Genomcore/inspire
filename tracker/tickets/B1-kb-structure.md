---
id: B1-kb-structure
title: "B1 — revamp the KB: one spec directory by module, typed file extensions"
created: 2026-10-23
updated: 2026-10-23
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: XL
importance: High
skills: [module, feature, domain, screens, adr, surface]
status: Open
blocked_by: []
related_to: [B1-adr-decision-rationale, B1-spikes-out-of-the-kb]
---

## Origin

The INSPIRE maintainers held a design review on 2026-10-23 while preparing the training of
new INSPIRE operators. This ticket records one of its decisions. The review's working notes
are not public, so this ticket states everything needed to act on the decision.

**Decision:** revamp how the knowledge base (KB) is layered. This is a full
restructuring, not a rename. It has three parts:

1. **One spec directory, organized by module.** The whole specification lives under
   `inspire_kb/01_spec/`, grouped by module. Spec content does not sit at the KB root
   beside bootstrap, lessons and the tracker.
2. **Typed file extensions.** Each artifact type gets its own file extension, such as
   `.adr.md`, `.entity.md` and `.action.md`, so a file's type no longer depends on the
   directory it sits in.
3. **Surfaces and modules.** Define the difference between a surface and a module. The
   review found that the two concepts may overlap, and the new layout depends on
   whether they are two concepts or one.

## Description

### Today: one top-level directory per artifact type

The top-level split of `inspire_kb/` is the artifact type. A module is a name that
repeats inside each layer. For a module called `agenda`, its content sits in five
places:

```
inspire_kb/
├── 01_adr/adr-agd-*.md
├── 02_modules/agenda.md   ← hub, links to the rest
├── 03_features/agenda/
├── 04_domain/agenda/
└── 05_screens/agenda/
```

Two tasks are harder than they need to be:

- **Reviewing a module** means walking five directories. The hub file links to them but
  does not collect their content.
- **Emanating a module** means passing one `--scope` per layer to `emanate-plan.sh`, and
  the operator has to know which layers hold units that can be emanated. (Emanation is
  the unattended loop that turns KB artifacts into production code.)

History: the layout came from the import of the OpenBIMS reference project in commit
`246ace5`, where the domain tree was `spec/sdd/{module}/{entity}`. PR #4 added
`02_modules` as a cross-layer hub and left `04_domain` and `05_screens` in place so the
validators kept passing. That PR does not discuss a module-first alternative, and no ADR
records the choice.

### Part 1: one spec directory, organized by module

```
inspire_kb/
├── 00_bootstrap/            ← project-wide configuration
├── 01_spec/                 ← the whole specification
│   ├── adr/                 ← decisions that span modules
│   ├── agenda/
│   │   ├── adr/
│   │   ├── features/
│   │   ├── domain/
│   │   └── screens/
│   └── …                    ← other modules, the shared catalog
├── 98_lessons/
└── 99_tracker/
```

The KB root holds only `01_spec/` and the project-wide layers that are not
specification. Two smaller options were considered and rejected, because both keep
today's layout:

- a `--module <name>` selector for `emanate-plan.sh`;
- a read-only command that prints one module's content from all layers.

### Part 2: typed file extensions

Today a file's type comes from its location. An entity is an entity because it sits
under `04_domain/{module}/{entity}/` and is named `{module}.{entity}.md`. An ADR is an
ADR because it sits in `01_adr/` and is named `adr-{slug}.md`. Every validator finds
artifacts through an `sdd_find_*` helper in `plugin/base/bin/_lib.sh` that walks one
layer root; the domain root, for example, is `inspire_kb/04_domain`, set by
`SDD_SPEC_ROOT`.

Under Part 1, a file's directory is its module, so the location can no longer carry the
type. The decision is that the file extension carries it:

| Artifact | Extension |
|---|---|
| ADR | `.adr.md` |
| Module hub | `.module.md` |
| Feature | `.feature.md` |
| Entity | `.entity.md` |
| Action | `.action.md` |
| Screen | `.screen.md` |
| Component, layout, pattern | `.component.md`, `.layout.md`, `.pattern.md` |

The design completes this list for every artifact type the KB has. It also states what
the extensions change:

- **Finding artifacts.** `sdd_find_*` helpers select by extension across all of
  `01_spec/` instead of walking one layer root. `SDD_SPEC_ROOT` and `SDD_KB_ROOT` are
  redefined or retired.
- **Names.** The name drops what the directory and the extension already say. For
  example, `{module}.{entity}.md` becomes `{entity}.entity.md` inside
  `01_spec/{module}/domain/`. The design states the naming rule for each type and how
  it stays unique across modules.
- **Links.** Wikilinks, keyed bindings and the derived contract resolve to the new
  names.
- **Templates and skills.** Each skill's templates and file-writing steps use the new
  extensions.
- **Frontmatter.** Whether the extension replaces any frontmatter field that records
  type today, or must agree with it.

### Part 3: what is the difference between a surface and a module?

The question is conceptual: what each concept is, and whether INSPIRE needs both.
Where surfaces sit in the new layout follows from the answer.

The current definitions come from `docs/adr/adr-suites-and-surfaces.md`:

- A **module** partitions the domain. It answers *what capabilities exist*. All
  surfaces share one module registry and one domain tree.
- A **surface** is a deliverable that faces someone: `ui` (a person looks at it),
  `headless` (an API, worker or event consumer) or `lib` (a shared package). It answers
  *where a capability is delivered*. A project declares its surfaces in
  `00_bootstrap/surfaces.md`, and a module may be delivered by several surfaces.

On paper, the two are independent axes. In practice, the same ADR ties them together in
three places:

- **Services are partitioned by module.** When several `headless` surfaces own
  capabilities, the split between them is recorded per module ("the admin service
  serves `tenancy` and `quotas`"). With one service per module, a surface and a module
  name the same thing.
- **Service boundaries redraw module boundaries.** The ADR's rule is that one module's
  actions wanting to live in two services means the module is wrong, and the module is
  split. So a surface boundary can force a module boundary.
- **Screens are indexed by both.** Screens are placed by surface, then module:
  `05_screens/{surface}/{module}/{screen}.md`.

The design answers:

- What each concept is, in one definition each, stated so that a reader can tell for
  any artifact whether it belongs to a module, a surface, or both.
- Whether they are two concepts or one. Possible answers:
  - two independent axes, with sharper definitions;
  - one is a view of the other;
  - they merge into one concept.
- What follows for the layout under `01_spec/`, for the `surfaces:` frontmatter field,
  and for `docs/adr/adr-suites-and-surfaces.md`, which may need amending or
  superseding.

### Other constraints the design must handle

- **Spec content that belongs to no module.** Cross-module ADRs and the shared component
  and layout catalog are specification but belong to no single module. The design
  names where each one lives inside `01_spec/`.
- **Emanation works on a dependency graph that crosses modules.** Entities, actions,
  screens, components and layouts depend on each other across modules. The new layout
  must not make those links harder to resolve. `emanate-derive.sh` and
  `emanate-plan.sh` must still find their targets.

### Existing projects

The upgrade rule in `docs/adr/adr-upgrade-path.md`, section "The KB is additive in both
init and update", says an upgrade never moves, replaces or deletes anything in
`inspire_kb/`. Moving an existing project's files into the new layout and renaming them
to typed extensions breaks that rule. The design chooses one of three options:

- a migration the operator runs explicitly, outside `/inspire:update`;
- an amendment to the KB-additive rule;
- a period during which the runtime reads both layouts.

## Acceptance criteria

- [ ] A core ADR in `docs/adr/` records the new layout and why it was chosen. It also
      covers the alternatives weighed: the current layout, the `--module` selector and
      the read-only module view.
- [ ] The ADR defines the typed extension for every KB artifact type, together with the
      naming rule and the uniqueness rule for each type.
- [ ] The ADR lists the validators, `sdd_find_*` helpers, templates and skills that
      change because of the extensions and the new layout.
- [ ] The ADR defines the difference between a surface and a module, and says whether
      INSPIRE keeps both concepts. "Two independent axes, defined as follows" is a valid
      answer. The ADR also states what its answer changes in the layout and in
      `adr-suites-and-surfaces.md`.
- [ ] The ADR names where cross-module ADRs and the shared catalog live, and how
      cross-module links resolve.
- [ ] The ADR states how an existing project reaches the new layout, and how that path
      fits the KB-additive upgrade rule.
- [ ] Implementation tickets are filed for the work the ADR decides. This ticket closes
      when the ADR is accepted, not when the migration ships.

## Notes

- `B1-adr-decision-rationale` splits each ADR into two files. The extension table has
  to cover both, and module-scoped ADRs move to `01_spec/{module}/adr/`.
- `B1-spikes-out-of-the-kb` removes `06_spikes`, so the new layout has one fewer layer
  to place.
