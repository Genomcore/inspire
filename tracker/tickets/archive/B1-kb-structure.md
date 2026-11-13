---
id: B1-kb-structure
title: "B1 — revamp the KB: one spec directory by module, typed file extensions"
created: 2026-10-23
updated: 2026-11-11
reporter: "@dario.blasco"
closed_by: "@irene.gonzalez"
closed_at: 2026-11-11
epic: roadmap
size: XL
importance: High
skills: [module, feature, domain, screens, adr, surface]
status: Done
blocked_by: []
related_to: [B1-adr-decision-rationale, B1-spikes-out-of-the-kb, B3-entry-points]
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

The design session of 2026-11-04 answered this part: see the amendment of that date in
the Notes.

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

The design session of 2026-11-04 chose the first option and ruled out the third: see
the amendment of that date in the Notes.

## Acceptance criteria

Amended 2026-11-04: this ticket covers the whole change, not only the ADR. It closes when
the new layout ships in INSPIRE and in the INSPIRE Factory, together with the migration.

- [x] A core ADR in `docs/adr/` records the new layout and why it was chosen. It also
      covers the alternatives weighed: the current layout, the `--module` selector and
      the read-only module view.
- [x] The ADR defines modules, bundles, faces and processes,
      one definition each, so that a reader can tell for any artifact which one it
      belongs to. It states what this changes in `adr-suites-and-surfaces.md`, and
      amends or supersedes it.
- [x] The ADR defines the typed extension for every KB artifact type, together with the
      naming rule and the uniqueness rule for each type.
- [x] The ADR lists the validators, `sdd_find_*` helpers, templates and skills that
      change because of the extensions and the new layout.
- [x] The ADR names where global ADRs, the design system and the global tokens live, and
      how links across modules, bundles, faces and processes resolve.
- [x] The ADR states how an existing project reaches the new layout, and how that path
      fits the KB-additive upgrade rule.
- [x] INSPIRE ships the new layout: the KB skeleton, the templates, the skills and the
      validators use `01_spec/` and the typed extensions.
- [x] The INSPIRE Factory finds its units by a recursive search on the typed extensions,
      not by layer directory, in a matching change in Genomcore/inspire-factory.
- [x] An explicit migration command, `/inspire:migrate`, moves an existing project to the
      new layout, and `/inspire:update` tells the operator that the migration is mandatory.
- [x] The migration never makes a realized unit unrealized. After it, the only new pending
      units are the grouping bundles, each with one `{bundle}/mount/every-action` claim, and
      their run changes test files only. If anything else rebuilds, the close note records
      why, and which units rebuild.
- [x] The ADR amends D2 of `docs/adr/adr-upgrade-path.md`: `inspire_version` in
      `.inspire.lock` is no longer provenance only.
- [x] The INSPIRE Factory accepts only INSPIRE 0.15.0 or later. It reads `inspire_version`
      from `.inspire.lock`, refuses a project without it, and asks for `/inspire:migrate`
      when the KB is not migrated.
- [x] "Surface" is renamed to "face" everywhere it reaches: the `surfaces:` frontmatter
      field, `00_bootstrap/surfaces.md`, `/inspire-surface`,
      `_references/surface-scope.md` and `adr-suites-and-surfaces.md`.

## Notes

**Closed 2026-11-11: Done.** Every criterion shipped in INSPIRE 0.15.0
(Genomcore/inspire#98, released in #103) and INSPIRE Factory 0.14.0
(Genomcore/inspire-factory#136, released in #147). The ADR is `adr-kb-structure`,
accepted 2026-11-10; it supersedes `adr-suites-and-surfaces` and amends D2 of
`adr-upgrade-path`. The migration criterion was checked end to end on genomics-suite:
after `/inspire:migrate` and the Factory's remap, 187 units stayed realized, and the only
new pending unit was the grouping bundle `api`, whose sandbox run added one test file.
Nothing rebuilt. Two decisions went beyond the criteria: INSPIRE no longer checks the
Factory's version (the Factory declares the oldest INSPIRE it supports), and the plan
schemas moved to `inspire.emanation-plan/4`, where a unit's `surface` field is `face`.

- `B1-adr-decision-rationale` splits each ADR into two files. The extension table has
  to cover both, and module-scoped ADRs move to `01_spec/{module}/adr/`.
- `B1-spikes-out-of-the-kb` removes `06_spikes`, so the new layout has one fewer layer
  to place.

**Amended 2026-10-28 (tracker pass): the INSPIRE Factory reads this layout too.**

- *Motivation.* Emanation is moving to the INSPIRE Factory, where a run starts from a
  plan selected in the Factory's own planner, not from `emanate-plan.sh --scope`. The
  "emanating a module" motivation, and the rejected `--module` selector, stop applying
  once the in-repo loop leaves. "Reviewing a module" stands on its own and carries the
  ticket.
- *Factory port.* The Factory reads the KB with its own scanner and deriver, which
  hardcode today's paths (`orchestrator/src/kb/referenced-kind.ts` and
  `orchestrator/src/contracts/derivation-context.ts` in Genomcore/inspire-factory match
  `05_screens/components/`, `05_screens/patterns/` and `05_screens/layouts/`). The new
  layout and the typed extensions break both, so the ADR's list of what changes names
  them, and the implementation tickets it files include one in the Factory's tracker.

**Amended 2026-11-04 (design session): modules, bundles, faces and processes.**

Irene González, Darío Blasco and Djessy Czaplicki held a design session on 2026-11-04 on
part 3 and on the existing projects. It took these decisions.

*Layout.* `01_spec/` holds one directory per concept, beside the global ADRs and the
design system:

```
inspire_kb/
├── 00_bootstrap/
├── 01_spec/
│   ├── adr/             ← global ADRs
│   ├── design-system/   ← the design system and the global tokens
│   ├── modules/
│   ├── bundles/
│   ├── faces/
│   └── processes/
├── 98_lessons/
└── 99_tracker/
```

- The directory layout is for people: what belongs together sits together. Tooling does
  not depend on it. It follows the knowledge graph, built from wikilinks and declared
  dependencies, and finds files by their typed extension.
- ADRs have three scopes: global (`01_spec/adr/`), inside a module, and inside a
  face. Bundles and processes hold no ADRs for now; they gain them if the need
  appears.
- Design tokens have two scopes: global, in the design system, and per face.

*Part 3: four concepts, not two.*

- **Module.** A functional package of capabilities: entities, actions and invariants,
  like one tag group in an API's Swagger page. A module holds no screens.
- **Bundle (new).** A headless grouping of actions from one or more modules. It links to
  modules that are already defined, and can take a whole module. It is an emanable unit:
  an SDK, a library, a backend for frontend, or an "API v1". It has internal versions,
  so each face can move to a new version on its own schedule. Which actions go in
  which bundle is a specification decision, made from the use cases; INSPIRE can
  suggest a grouping, such as one bundle per module, but does not decide it. The bundle
  takes over the exposure meaning that "surface" carried until now. A bundle is kept
  apart from the faces because one bundle can serve several faces.
- **Face (until now "surface").** A visual application a person uses, such as a web
  portal, a back office or a mobile app. It holds its screens and its shell, and
  declares the bundles it uses. That declaration gives a check: a screen that depends
  on an action outside its face's bundles is a finding. Domain that only some
  applications use needs no attribute on the entity: a face reaches it only through
  the bundles it uses.
- **Process (new).** System behaviour that no actor invokes directly: a scheduled job, a
  token refresh, the initial population of the database. A process file states its
  trigger, the actions it requires, its pre-actions and post-actions, and the domain it
  affects. It is an emanable unit: its trigger and its behaviours are claims, so they
  generate tests. Processes are scoped like ADRs: global, inside a module, or inside a
  face. Interceptors can live at face level. This covers part of what
  `B3-entry-points` calls entry points with no person behind them; that ticket is not
  changed here.

*Typed extensions.* The extension table gains `.bundle.md`, `.face.md` and
`.process.md`. The INSPIRE Factory finds
emanable units by a recursive search on extensions, so a later change to the KB's
directory layout does not reach it. The same search lets a converter bring in a project
that was not written with INSPIRE.

*Links.* A link to an artifact that does not exist yet requires its file, created from
its template in `draft`. A missing target then always means a broken link, never a
concept that was not written down.

*Existing projects.* The answer to "Existing projects" is an explicit migration command.
`/inspire:update` tells the operator that it is mandatory, because the new INSPIRE
Factory finds nothing in the old layout. A period during which both layouts are read is
ruled out: the old layout has no typed extensions, so the Factory cannot stay
backward compatible.

*Execution.* Irene González makes the change in INSPIRE and in the INSPIRE Factory
together, as one piece of work.

*Name.* "Surface" becomes "face". One product, with one domain and one set of
bundles, shows a different face to each kind of person on each medium: the back office
on the web, the end user on a phone. The word pairs with "bundle" (a bundle exposes, a
face presents), reads well in paths and prose (`01_spec/_faces/`, `portal.face.md`,
"the back-office face"), and is almost unused in INSPIRE's runtime and in the Factory's
`orchestrator/src`. The session first chose "facet"; the ADR settled on "face" because
genomics-suite's domain already uses "facet" for faceted filtering
(`adr-kb-structure`, alternatives). The choice
came after two rounds of 20 candidates each. Ruled out because they clash with an
existing concept: `platform` (suggests the backend and mixes bundles back in), `space`
(also a design-token scale, and tokens now live in the face), `shell` (part of a
face), `workspace` (`inspire-workspace`), `frame` (layout geometry), `target` (the
stack skills' targets) and `window` (JavaScript's global).

**Amended 2026-11-06 (Factory review, block 1): the migration keeps built code built, and
the INSPIRE Factory checks the INSPIRE version.**

- *Decision:* the folder change must not force a re-emanation when the spec did not change.
  The migration changes ids, and it is the migration that changes them, so no realized unit
  becomes unrealized. The new layout adds grouping bundles, and each bundle is a new unit:
  emanating it is the only new work, and it is small.
- *Today:* this ticket ships an explicit migration command, and the INSPIRE Factory finds
  units by a recursive search on the typed extensions. The ticket says nothing about what the
  migration does to code that is already built. In the Factory, a unit stays built while its
  claim ids and fingerprints do not change, and the path is not part of them. A screen
  without `id:` takes its id from its parent folder, so moving it changes its ids.
- *Change:* a new acceptance criterion. The migration never makes a realized unit
  unrealized. After it, the only new pending units are the grouping bundles, each with one
  `{bundle}/mount/every-action` claim, and their run changes test files only. If anything
  else rebuilds, the close note records why, and which units rebuild.
- *Version check:* the new INSPIRE Factory supports INSPIRE 0.15.0 or later only. It reads
  `inspire_version` from `.inspire.lock`, so this ticket's ADR amends D2 of
  `docs/adr/adr-upgrade-path.md`, which makes that field provenance only today. The Factory
  refuses a project whose lock has no `inspire_version`, and when the KB is not migrated it
  asks the operator to run `/inspire:migrate`. The Factory half of this check is part of
  this ticket's matching change in Genomcore/inspire-factory.
