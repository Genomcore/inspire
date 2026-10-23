---
id: B1-kb-structure
title: "B1 — the KB is layered by artifact type; gather the spec under 01_spec, by module"
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

**Decision:** restructure the knowledge base (KB) so that the whole specification lives
under one directory, organized by module. This is a full change to how the KB is
layered, not only a change to file names.

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

### Target: one spec directory, organized by module

All specification lives under one directory, `01_spec/`, organized by module. Spec
content does not sit at the KB root. The root holds only `01_spec/` and the
project-wide layers that are not specification: bootstrap, lessons and the tracker.

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

Two smaller options were considered and rejected because both keep today's layout:

- a `--module <name>` selector for `emanate-plan.sh`;
- a read-only command that prints one module's content from all layers.

### What the design has to answer

The current layout has four likely reasons behind it. None of them is documented. Each
one is a constraint the new layout must handle explicitly.

1. **Spec content that belongs to no module.** Cross-module ADRs and the shared component
   and layout catalog are specification but belong to no single module. The design
   names where each one lives inside `01_spec/`.
2. **One skill and one root per layer.** Each layer has an owning skill, and every
   validator walks one layer root through an `sdd_find_*` helper in
   `plugin/base/bin/_lib.sh`. For example, the domain root is `inspire_kb/04_domain`,
   set by `SDD_SPEC_ROOT`. Inside `01_spec/`, a file's directory is its module and no
   longer says what type the file is, so something else has to. Three options:
   - **Typed file suffixes** (the review asked for these to be explored): `.adr.md`,
     `.feature.md`, `.entity.md`, `.action.md`, `.screen.md`, `.module.md`, and so on.
     The `sdd_find_*` helpers would select by suffix across all modules instead of
     walking one layer root.
   - A frontmatter `kind` field.
   - A fixed sub-directory name per type.
3. **Surfaces split screens but never the domain.** A *surface* is one delivery unit of
   the product (`ui`, `headless` or `lib`), declared in `00_bootstrap/surfaces.md`.
   Today screens are placed by surface first, then module:
   `05_screens/{surface}/{module}/{screen}.md`. The review found that surfaces and
   modules may overlap. The design states:
   - the boundary between the two concepts;
   - where surface scoping sits once the module owns the directory under `01_spec/`:
     inside `{module}/screens/`, or in frontmatter;
   - whether `docs/adr/adr-suites-and-surfaces.md` needs an amendment. That ADR
     rejected a `module/surface/screen` order for screens, and this change reopens it.
4. **Emanation works on a dependency graph that crosses modules.** Entities, actions,
   screens, components and layouts depend on each other across modules. The new layout
   must not make those links harder to resolve. Wikilinks, keyed bindings,
   `emanate-derive.sh` and `emanate-plan.sh` all still have to find their targets.

### Existing projects

`docs/adr/adr-upgrade-path.md`, decision D10 ("The KB is additive in both init and
update"), says an upgrade never moves, replaces or deletes anything in `inspire_kb/`.
Moving an existing project's files into the new layout breaks that rule. The design
chooses one of three options:

- a migration the operator runs explicitly, outside `/inspire:update`;
- an amendment to that D10 rule;
- a period during which the runtime reads both layouts.

## Acceptance criteria

- [ ] A core ADR in `docs/adr/` records the new layout and why it was chosen. It also
      covers the alternatives weighed: the current layout, the `--module` selector and
      the read-only module view.
- [ ] The ADR answers each of the four constraints above, naming the directory or rule
      that handles each one.
- [ ] The ADR settles the surface/module boundary. "They do not overlap, and here is the
      boundary" is a valid answer.
- [ ] The ADR states the type-detection rule (suffix, frontmatter `kind`, or path). It
      lists the validators, `sdd_find_*` helpers and skills that change because of it.
- [ ] The ADR states how an existing project reaches the new layout, and how that path
      fits `adr-upgrade-path.md` D10.
- [ ] Implementation tickets are filed for the work the ADR decides. This ticket closes
      when the ADR is accepted, not when the migration ships.

## Notes

- `B1-adr-decision-rationale` adds two ADR file types, and module-scoped ADRs move to
  `01_spec/{module}/adr/`. The type-detection rule has to cover both.
- `B1-spikes-out-of-the-kb` removes `06_spikes`, so the new layout has one fewer layer
  to place.
