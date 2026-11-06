# ADR — The KB by concept: modules, bundles, faces and processes, found by typed extension

- **Status:** Proposed — 2026-11-06 (draft for review by Darío Blasco and Djessy
  Czaplicki; ticket `B1-kb-structure`)
- **Supersedes:** [[adr-suites-and-surfaces]]. The model moves from two concepts
  (module, surface) to four, so that ADR is replaced rather than amended.
- **Amends:** [[adr-upgrade-path]] **D2** (`inspire_version` in `.inspire.lock` becomes a
  contract). Upholds its **D10** (`/inspire:update` stays additive on the KB) and **D11**
  (git is read-only against the operator's repository).
- **Builds on:** [[adr-plugin-delivery]] **D4e** (the KB is `inspire_kb/`, visible and the
  operator's) and [[adr-decision-record-ids]] (ids are slugs).
- **Scope:** How the specification is laid out under `inspire_kb/01_spec/`, what each
  artifact type is called, how tools find artifacts and resolve links, and how an
  existing project reaches the new layout without rebuilding code that is already
  built. Also which INSPIRE versions the INSPIRE Factory accepts. Not the navigation map
  (`B3-navigation-map`), not bundle versioning, not spikes (`B1-spikes-out-of-the-kb`).
  The split of an ADR into a decision and a rationale is already on `release/0.15.0`;
  this ADR only renames the two files.

---

## Context

The KB is laid out by **layer**: `01_adr`, `02_modules`, `03_features`, `04_domain`,
`05_screens`. One module's content is spread over five trees, and nothing shows a person
the whole of a module in one place. Reviewing a module means walking all five.

The tools are coupled to that layout in every direction:

- the finders in `_lib.sh` identify an artifact by its layer directory and by the
  number of dots in its file name (`{module}.{entity}.md` is an entity,
  `{module}.{entity}.{action}.md` an action);
- almost every validator names a layer path;
- the INSPIRE Factory hardcodes the same paths in its scanner and its deriver
  (`kb/referenced-kind.ts`, `contracts/derivation-context.ts`, `planner/find-frontier.ts`).

So any change to the layout is a change to every reader, and the layout cannot be
improved for people without breaking the machines.

The surface model of [[adr-suites-and-surfaces]] also carries two meanings in one word.
A `ui` surface is an application a person uses. A `headless` surface is a set of
exposed capabilities. They have different owners, different lifecycles and different
emanation, and the roster in `00_bootstrap/surfaces.md` holds both. Behaviour that no
actor invokes (a scheduled job, a token refresh, the first load of the database) has no
place at all.

Two projects already emanate code with the INSPIRE Factory. genomics-suite
(`release/GSTKT-31`: 26 screens, 40 entities, 113 actions, about 3,100 `@claim`
citations in 170 test files) must not rebuild what is built because the folders move.
That constraint shapes D5, D6 and D10.

A design session on 2026-11-04 (Irene González, Darío Blasco, Djessy Czaplicki) took the
direction. This ADR records it and the decisions that followed.

## Decisions

Decision numbers are scoped to this ADR. A reference to another ADR's decision is always
qualified.

### D1 — Four concepts, one definition each

| Concept | What it is | Holds | Emanated as |
|---|---|---|---|
| **Module** | A functional package of capabilities: entities, actions and invariants. Like one tag group in an API's reference. | Its hub, its features, its domain, its ADRs and processes | Its entities and actions, as today |
| **Bundle** | A headless grouping of actions from one or more modules: an API, an SDK, a library, a backend for a frontend. | One file that names its actions (or whole modules), its package and its profiles | One unit (D6) |
| **Face** | An application a person uses: a web portal, a back office, a mobile app. Formerly a `ui` surface. | Its screens, its shell, its tokens, its ADRs and processes; it declares the bundles it uses | Its screens, as today. The face itself is not a unit |
| **Process** | System behaviour that no actor invokes directly: a scheduled job, a token refresh, the first population of the database. | One file: its trigger, the actions it requires, its pre- and post-actions, the domain it affects | One unit (D7) |

**Which concept an artifact belongs to.** Ask, in order:

1. Does a person see it? It belongs to a **face** (a screen, a face-level token, a
   face's shell).
2. Does it describe what the system can do or hold? It belongs to a **module** (an
   entity, an action, a feature, an invariant).
3. Does it say which capabilities are exposed together, to whom, as one package? It is a
   **bundle**.
4. Does it run without an actor? It is a **process**, scoped to the module or face whose
   domain it touches, or global.
5. Does it cross several of these? It is global: a global ADR, or a design-system entry.

A module holds no screens. A face holds no domain. The domain never says which face or
bundle uses it: a face reaches domain only through the bundles it declares, so domain
that only some applications use needs no attribute on the entity. That keeps
[[adr-suites-and-surfaces]] **D1** ("the domain layer is never touched by surface
scoping"), which is the part of that ADR this one keeps.

**The suite-of-one disappears.** [[adr-suites-and-surfaces]] **D2** made a project
without a roster a single implicit surface. Here a project with screens always has at
least one face file, and a project without screens has none. There is one shape, and
nothing is implicit.

### D2 — The layout: one directory per concept inside `01_spec/`

```
inspire_kb/
├── 00_bootstrap/             ← unchanged, minus surfaces.md and theme.*
├── 01_spec/
│   ├── _adr/                 ← global ADRs
│   ├── _design-system/       ← design-system.md, global tokens, components/, layouts/, patterns/
│   ├── _modules/
│   │   └── {module}/
│   │       ├── {module}.module.md
│   │       ├── _adr/
│   │       ├── _features/
│   │       ├── _domain/{entity}/   ← {entity}.entity.md and its actions
│   │       └── _processes/
│   ├── _bundles/
│   │   └── {bundle}.bundle.md
│   ├── _faces/
│   │   └── {face}/
│   │       ├── {face}.face.md
│   │       ├── {face}.tokens.json
│   │       ├── _adr/
│   │       ├── _screens/
│   │       └── _processes/
│   └── _processes/           ← global processes
├── 06_spikes/                ← unchanged
├── 98_lessons/               ← unchanged
└── 99_tracker/               ← unchanged
```

- **The layout is for people.** What belongs together sits together, so reviewing a
  module or a face is one directory. **No tool depends on it** (D4).
- **The KB root does not change.** `00_bootstrap/`, `06_spikes/`, `98_lessons/` and
  `99_tracker/` keep their names and places. `01_spec/` replaces `01_adr/` to
  `05_screens/`.
- **ADRs have three scopes:** global, a module, a face. Bundles and processes hold no
  ADRs for now.
- **Tokens have two scopes:** global, in `_design-system/`, and per face.
- **Processes have three scopes,** like ADRs.

**A leading `_` on a directory means INSPIRE structure.** A project can have a domain
module called `processes`, `bundles` or `adr`. INSPIRE's directories carry a `_` so they
never collide with a name the operator chose, and they sort first without numbering.

- A user-chosen id (module, face, bundle, entity, action, process, screen) never starts
  with `_`. A validator checks it.
- A leading `_` on a **file** keeps its current meaning: navigation (`_index.md`). No
  finder filters on `_` in a directory segment, only on the file name. The current
  checks (`sdd_find_screens`, `sdd_find_catalog`, `trust.sh`, and the Factory's
  `find-frontier.ts`, `scan-kb.ts`, `referenced-kind.ts`) already look only at the file
  name.
- Templates stop using the `_` prefix (D3), so after this change the `_` file
  convention covers `_index.md` only. Screens keep one per face, `_faces/{f}/_index.md`,
  until `B3-navigation-map` replaces it (D10).

### D3 — Every artifact type has a typed extension

| Type | File | Id | Unique within | Template |
|---|---|---|---|---|
| Module hub | `{module}.module.md` | `{module}` | project | `module.template.md` |
| Feature (use case) | `{use-case}.feature.md` | `{use-case}` | module | `feature.template.md` |
| Entity | `{entity}.entity.md` | `id:` (`{module}.{entity}`) | module | `entity.template.md` |
| Action | `{entity}.{action}.action.md` | `id:` (`{module}::{entity}::{action}`) | entity | `action.template.md` |
| ADR (decision) | `{slug}.adr.md` | `adr-{slug}` | project | `adr.template.md` |
| ADR (rationale) | `{slug}.adr.rationale.md` | `adr-{slug}.rationale` | project | `adr.rationale.template.md` |
| Bundle | `{bundle}.bundle.md` | `{bundle}` | project | `bundle.template.md` |
| Face | `{face}.face.md` | `{face}` | project | `face.template.md` |
| Screen | `{slug}.screen.md` | `id:` (`{face}.{slug}`, D5) | face | `screen.template.md` |
| Process | `{process}.process.md` | `id:` (`{scope}.{process}`) | project | `process.template.md` |
| Component | `{name}.component.md` | `{name}` | project | `component.template.md` |
| Layout | `{name}.layout.md` | `{name}` | project | `layout.template.md` |
| Pattern | `{name}.pattern.md` | `{name}` | project | `pattern.template.md` |
| Design system | `design-system.md` | — (one per project) | project | — |
| Tokens | `{scope}.tokens.json` | — | scope | — |

Reserved, not implemented here: `.navigation.md` (`B3-navigation-map`).

- **The typed extension is never part of an id.** When an id comes from the file name,
  it is the name without `.{type}.md`: `list.pattern.md` is the pattern `list`, not
  `list.pattern`. This is load-bearing. The Factory identifies catalog units by file
  name, and genomics-suite has 159 citations of catalog units by bare id. With the
  extension in the id, every one of them would go stale.
- **Where the frontmatter has `id:`, it wins.** Entities, actions, screens and processes
  carry one. The others take their id from the file name.
- **ADR ids do not change.** [[adr-decision-record-ids]] makes the id `adr-{slug}`. The
  file becomes `{slug}.adr.md`: the extension already says it is an ADR, so the file
  name does not repeat `adr-`. The prefix is added back when the id is derived, so
  `[[adr-foo]]` still resolves and no link is rewritten. The rationale beside it
  becomes `{slug}.adr.rationale.md`: it is the rationale of an ADR, and the name says
  so. A search for `*.adr.md` never matches it. Its id stays `adr-{slug}.rationale`, so
  `**Rationale:** [[adr-foo.rationale]]` still resolves too. An ADR written before the
  split is still one file. The migration renames it to `{slug}.adr.md` and does not split
  it: that stays `/inspire-adr migrate`'s job.
- **Templates have their own extension,** `{type}.template.md`, instead of
  `_template.md` or the skills' `*.md.template`. A finder selects units by extension,
  so a template can never be mistaken for a unit, with no special case. `trust.sh` and
  the Factory's `scan-kb.ts`, which skip `_template.md` today, stop needing to.
- **An action's file name keeps its entity:** `{entity}.{action}.action.md`. Action
  names repeat across entities (`create`, `update`, `close`), so `create.action.md` in
  every entity directory would make the file-name fallback in link resolution
  ambiguous inside a module.
- **Uniqueness is checked by a validator,** within the scope the table names. Two files
  with the same type and id in the same scope are a finding.
- **The frontmatter `type` field**, where it exists, must agree with the extension. A
  disagreement is a finding.

### D4 — Tools find artifacts by extension and resolve links by id, never by directory

- Every finder is a recursive search on `01_spec/` by typed extension
  (`find "$SDD_SPEC_ROOT" -name '*.entity.md'`). Scoping a finder to a module or a face
  is a path filter on top, never a different shape.
- Links resolve by id first, through the index built from frontmatter and file names,
  and by file name only as a fallback. `wikilinks-resolve.sh` and the Factory's
  `resolve-reference.ts` already work this way. What goes is every place that builds a
  path from a layer name (`sdd_resolve_entity_id` builds
  `04_domain/{m}/{e}/{m}.{e}.md` today).
- **A link to something that does not exist yet requires its file,** created from its
  template with `lifecycle: draft`. A missing target then always means a broken link,
  never a concept nobody wrote down. Every skill that writes a link creates the draft
  target when it is missing.
- **Nothing is indexed by hand** if it can be found by its extension. There is no
  roster, no registry and no list of bundles to keep in sync.

Because the Factory finds units by extension, a later change to the directory layout
does not reach it. The same search lets a converter bring in a project that was not
written with INSPIRE.

### D5 — A screen's id is `{face}.{slug}`, and its route does not change

Today a screen's id is `{module}.{screen}`. Screens now live in a face, so the id says
the face: **`{face}.{slug}`**, where `slug` is the file's slug, unique within the face.

- **`module:` and `screen:` stay on the screen.** The route still derives from them
  (`{shell}/{module}/{screen}`), so no URL changes.
- **The id and the route segment are now two things.** `screen:` is unique within a
  module and is a route segment. `slug` is unique within the face and is an identity.
  genomics-suite shows why they cannot be the same: its face `studio` has five screens
  with `screen: detail`, four with `list` and three with `create`. Their file slugs
  (`study-detail`, `case-detail`, `studies-list`…) are unique, so the migration takes
  the slug from the file name: `studies.detail` becomes `studio.study-detail`.
- **Screen ids are write-once** (`format-screen.md`), and this is the one time they
  change. The migration writes an explicit `id:` on every screen before moving it, and
  records every change in an id map (D10).
- **A changed id would mean rebuilding every screen.** In the Factory every claim id
  carries the unit id as a prefix (`{screen-id}/data/…`). The Factory release that goes
  with this one reads the id map and rewrites the built code instead (D10): the
  `@claim` citations, the fingerprints that include a screen id (navigation claims), and
  the screen ids quoted in the application's code. No screen is rebuilt.
- **No `05_screens/shared/`.** When the same screen appears in two faces, what they
  share is its structure, not the screen. The structure becomes a layout or a pattern
  in `_design-system/`, and each face keeps its own screen. A validator warns, without
  blocking, when a screen is used by a face other than its own.

### D6 — Bundles: exposure stays on the action; a grouping bundle has one mount claim

A bundle is the unit of **exposure**: which actions are published together, by which
package. Which actions go into which bundle is a specification decision, made from the
use cases. INSPIRE can suggest a grouping (one bundle per module), but does not decide
it.

```
---
id: api
package: apps/studio/api
profiles: [nestjs]
---
# Bundle: api
## Actions
- [[studies]] (whole module)
- [[cases::case::close]]
```

A face declares the bundles it uses (`bundles: [api]` in `{face}.face.md`). That gives
a check: **a screen that depends on an action outside its face's bundles is a
finding.**

Four rules. They are what keeps code that is already built from being rebuilt, so they
are not open to trade-off:

- **R1 — Exposure stays on the action.** An action's route, dispatch and guard claims
  (`{action}/binding/route|dispatch|guard`, derived from the stack skill's
  `## Bindings`) neither move to the bundle nor change id. A bundle never redefines a
  route. Moving them would leave genomics-suite with 778 dangling citations, and no id
  map can fix that: it would be moving claims between units, not renaming them.
- **R2 — A bundle that only groups actions has exactly one claim,
  `{bundle}/mount/every-action`.** It is an aggregate claim on the model of the shell's
  `shell/mount/every-route`, cited by a test that starts the bundle's application and
  checks that every action in the bundle is exposed by it.
  - It is an ordinary unit, so "a unit without claims is never realized" holds, and
    the planner needs no exception.
  - It checks something nothing checks today: an action's `binding/route` proves the
    action is exposed somewhere, not that this bundle's package exposes it.
  - Its payload is the sorted list of member action ids plus the bundle's `package`.
    Adding an action makes this one claim stale. The normal loop realigns it: the bundle
    requires its actions, so the planner schedules it after the new action, and its run
    adds the action to the mount test. Nothing else goes stale.
  - Its run changes test files only. The unit's task says so, and the Factory's deviation
    check on the required actions catches a broken citation.
- **R3 — Only a bundle that produces its own artifact has more claims.** An SDK, a
  library or a backend for a frontend has code of its own, and its claims describe it.
  The migration never creates one of these.
- **R4 — A face has no claims of its own.** Its screens do.

**A bundle has no version in the specification.** Its id is `api`, never `api@v1`, so
the specification does not change when a new version is published. Detecting that a
bundle has drifted and publishing a new version is the Factory's job, outside this ADR.

### D7 — Processes

A process file states:

- its **trigger**: a schedule, an event, start-up, or another process;
- the **actions it requires**;
- its **pre-actions** and **post-actions**;
- the **domain it affects**.

It is an emanable unit, and its claims follow the action's model: one claim per keyed
entry.

- `{process}/trigger`: one claim for its trigger;
- one claim per behaviour step (`B{n}`);
- one claim per pre-action and per post-action, so their order is tested.

The **actions it requires** are dependencies (`requires`), not claims: each action is
already tested as its own unit. The **domain it affects** produces no test either: a
validator checks it against what the required actions touch. A process without a trigger
or without actions is a finding.

Processes are scoped like ADRs: global, a module, or a face. Interceptors can live at
face level. This covers part of what `B3-entry-points` calls entry points with no person
behind them. That ticket is not changed here.

### D8 — No roster: each face and bundle carries its own packaging

`00_bootstrap/surfaces.md` is removed. [[adr-suites-and-surfaces]] **D7** made it the one
file that declared surfaces, for three reasons. None of them survives:

- *It was the closed set of valid ids.* The set is now the `*.face.md` and `*.bundle.md`
  files, and a link to a missing one requires a draft file (D4).
- *It was a cheap index.* A search by extension is just as cheap.
- *Its absence meant a suite-of-one.* There is no suite-of-one (D1).

`package`, `profiles` and `shell` move to the face's or bundle's own frontmatter. The
checks across the whole set (unique ids, no reserved ids, unique shells, packages
present) become one validator over all `*.face.md` and `*.bundle.md` files.
`inspire-face` is the only skill that creates or retires a face, as `inspire-surface` was
for the roster.

### D9 — `surfaces:` splits into `faces:` and `bundles:`

The blast-radius field of [[adr-suites-and-surfaces]] **D3** stays as an idea and
changes shape:

- Where the placement already says the scope (a screen in a face, an ADR in a module),
  the field goes away.
- On global ADRs, features and design-system entries, it splits by the kind of each id:
  ui ids go to `faces:`, headless and lib ids go to `bundles:`.
- `all` goes away. An absent field means the whole project, as before.

### D10 — Existing projects: one explicit migration that rebuilds nothing

A project reaches the new layout with **`/inspire:migrate`**, run by the operator.

- **Why not `/inspire:update`.** [[adr-upgrade-path]] **D10** says the upgrade never
  moves, replaces or deletes anything in `inspire_kb/`. That rule stays. The migration
  is a separate command, run on purpose, with a dry run first. `/inspire:update` to
  0.15.0 detects the old layout and tells the operator that the migration is mandatory.
  It moves nothing itself.
- **Why not a period that reads both layouts.** The old layout has no typed extensions,
  so a reader of both would keep every path-shaped finder alive next to the new ones,
  in INSPIRE and in the Factory. Rejected.
- **Git stays read-only** ([[adr-upgrade-path]] **D11**). The migration moves files on
  disk and does not run `git mv`. Git detects the renames when the operator commits, and
  the dry run tells the operator to commit the moves on their own, before any edit.

**What it maps:**

| Today | Becomes |
|---|---|
| `01_adr/adr-{slug}.md` and `adr-{slug}.rationale.md` | `_adr/{slug}.adr.md` and `{slug}.adr.rationale.md` (global), or the same pair under `_modules/{m}/_adr/` or `_faces/{f}/_adr/` (scoped, from the frontmatter) |
| `02_modules/{m}.md` | `_modules/{m}/{m}.module.md` |
| `03_features/{m}/{uc}.md` | `_modules/{m}/_features/{uc}.feature.md` |
| `04_domain/{m}/{e}/{m}.{e}.md` and its actions | `_modules/{m}/_domain/{e}/{e}.entity.md`, `{e}.{action}.action.md` |
| `05_screens/{surface}/{m}/{s}.md` | `_faces/{surface}/_screens/{s}.screen.md`, with `id: {surface}.{s}` |
| `05_screens/{components,layouts,patterns}/` and `design-system.md` | `_design-system/…` with typed extensions |
| `00_bootstrap/theme.*` | `_design-system/` |
| Roster, `ui` surface | One face |
| Roster, `headless` surface | One bundle, with its package and profiles |
| Roster, `lib` surface | A bundle, or the design system; the migration asks |
| No roster, no screens | No face: modules and domain only |
| No roster, with screens | One face holding every screen, plus one bundle with every module. The migration asks for the face's id and proposes the project's name |
| `05_screens/shared/{m}/{s}.md` | Moved, id unchanged, to the one face the operator picks. Nothing is extracted |
| `05_screens/{surface}/{m}/_index.md` | Merged into one `_faces/{surface}/_index.md`. Each module's `## Navigation` prose is kept; the screens table is dropped, since a search by extension gives it |
| `surfaces:` | `faces:` and `bundles:` (D9) |

**What it never does:**

- rename a module, an entity or an action;
- change any id other than a screen's (D5), and every screen id it changes goes into the
  id map;
- rewrite link text inside a screen's `## Bindings` (it would change the fingerprint of
  a claim whose meaning did not change);
- extract a shared screen into a pattern;
- create a process, or a bundle with an artifact of its own (D6, R3).

**The id map** (`inspire_kb/01_spec/_migration/id-map.json`, written once) lists each
old screen id and its new one. The Factory release that goes with INSPIRE 0.15.0 reads
it and, without running any agent:

- rewrites the citations of claims whose payload does not contain a screen id, and
  recomputes their fingerprints;
- recomputes the fingerprints of claims whose payload names a screen (navigation);
- rewrites the screen ids quoted in the application's code;
- commits the result as a branch for the operator to review.

**The acceptance rule.** After migrating a project that the Factory has built:

- every unit that was realized is still realized;
- the only new pending units are the grouping bundles, each with its one mount claim;
- running those bundle units changes test files only.

genomics-suite is the release check. If it fails, the release does not go out. If a
rebuild cannot be avoided in some other project, the release notes say why and which
units rebuild.

### D11 — The INSPIRE Factory declares which INSPIRE versions it accepts

INSPIRE 0.15.0 and the matching Factory release go out together. That Factory is the
first one that cannot read an older KB, so it accepts **INSPIRE 0.15.0 and later**.

- The range is **a floor only**, declared once in the Factory and stated in its README
  and in each release note that changes it. When an INSPIRE release breaks the Factory,
  the Factory release that follows raises the floor. A ceiling set today would also
  block every compatible INSPIRE release.
- Before planning, the Factory reads `inspire_version` from `.inspire.lock`. No lock, no
  field, or a version below the range: it refuses, names both versions, and asks for
  `/inspire:update`. A project with no version is always an install older than 0.15.0,
  so there is nothing to warn about.
- The lock says 0.15.0 as soon as `/inspire:update` runs, but the migration is a separate
  step. So the Factory then checks the layout: no `01_spec/`, or a `04_domain/` still
  there, means it refuses and asks for `/inspire:migrate`.

**This amends [[adr-upgrade-path]] D2.** That decision made the lock "provenance only …
a version hint, never load-bearing", for three reasons: the operator can edit it,
pre-0.3 installs often have none, and per-file hashes belong in the shipped manifests.
All three still hold for what the lock says about files. They do not stop
`inspire_version` from being read as a contract: an edited version only hurts the
operator who edited it, and a missing one is refused. So `inspire_version` becomes the
version the Factory checks. The rest of the lock stays provenance, and upgrade
detection still fingerprints the project ([[adr-upgrade-path]] **D3**).

---

## What changes

**INSPIRE runtime (`plugin/base/bin/`)**

- `_lib.sh`: `SDD_SPEC_ROOT` becomes `inspire_kb/01_spec`; `SDD_FEATURES_ROOT` and
  `SDD_ADR_ROOT` go away. Every `sdd_find_*` becomes a search by extension:
  `sdd_find_actions`, `_entities`, `_features`, `_adrs`, `_screens`, `_catalog`, plus new
  `sdd_find_modules`, `_bundles`, `_faces` and `_processes`. `sdd_resolve_entity_id`
  resolves through the id index instead of building a path.
- Validators: every one that names a layer path or calls a finder, which is all of them
  except `_keyed-heads.sh`. The most coupled are `screen-coherence.sh`,
  `wikilinks-resolve.sh`, `adr-maturity-matches-features.sh`, `sections-present.sh`,
  `prose-style.sh`, `keys-present.sh` and `trust.sh`.
- New checks: user ids never start with `_`; uniqueness per type and scope; extension
  and frontmatter `type` agree; a screen uses no action outside its face's bundles; the
  set of faces and bundles (unique ids and shells, packages present); a process has a
  trigger and actions; a screen used by another face (warning).

**Skeleton and templates**

- `plugin/base/kb/`: the new `01_spec/` tree, with a README per directory. `list` and
  `detail` move to `_design-system/patterns/` as `list.pattern.md` and
  `detail.pattern.md`.
- Every template becomes `{type}.template.md`. New: `bundle`, `face`, `process`.

**Skills**

- `inspire-surface` becomes `inspire-face`, and `_references/surface-scope.md` becomes
  `face-scope.md`.
- Bundles and processes get their own skills (`inspire-bundle`, `inspire-process`),
  because they are units of their own.
- Every skill that writes files (`adr`, `bootstrap`, `config`, `domain`, `extract`,
  `feature`, `module`, `prototype`, `screens`, `task`, `workspace`) takes the new paths
  and extensions and creates a draft target for a missing link (D4).
- The stack skills (`inspire-code-*`) that name layer paths.
- New plugin skill `/inspire:migrate` (D10), and `/inspire:update` detects the old layout
  and asks for it.

**INSPIRE Factory (`orchestrator/src`)**

- `config`: `specRoot` defaults to `<kb>/01_spec`.
- `kb/scan-kb.ts`, `planner/find-frontier.ts`: a recursive search by extension.
- `kb/referenced-kind.ts`, `kb/identity-kind.ts`: the type comes from the extension.
- `kb/resolve-reference.ts`, `contracts/derive-screen.ts`: ids without the extension.
- `contracts/derivation-context.ts`, `validate-screen.ts`, `planner/derive-units.ts`:
  resolve the catalog through the graph, and the screen identity becomes face + slug.
- New unit kinds `bundle` and `process`, with their derivers (D6, D7).
- The id-map rewriter and its commit-without-run entry point (D10).
- The INSPIRE version check and the layout check (D11).

**Rename.** "Surface" becomes "face" wherever it reaches: the field, the roster (removed),
the skill, the reference, and the docs. Afterwards `git grep -i surface` finds only other
meanings and this ADR's history.

## Alternatives considered and rejected

- **Keep the layer layout.** It costs nothing now and keeps a module spread over five
  trees forever, with every reader coupled to the paths.
- **A `--module` selector on the tools.** It served "emanate one module", which left with
  the in-repo emanation loop. It does nothing for a person reviewing a module.
- **A read-only module view** generated over the layer layout. It fixes reading and
  leaves the coupling, and it is one more artifact to keep in sync.
- **A period that reads both layouts.** See D10.
- **Keep `{module}.{screen}` as the screen id.** It would avoid the id map in this
  change. It was rejected to settle the model now, before more people learn the old one,
  and because the id map is the same tool that day-to-day renames need anyway.
- **Use `screen:` as the new id's slug.** genomics-suite has twelve collisions inside one
  face (D5).
- **Move exposure to the bundle.** See R1.
- **A bundle whose state is derived from its actions, with no claim.** Nothing to run
  after migrating, but the planner needs an exception, and membership is never checked.
- **The name "facet".** The design session chose it. genomics-suite's domain has faceted
  filtering (`FacetCounts`, `facet_counts`, `facet-colours.css`, about 70 KB mentions),
  so `facets:` and `.facet.md` would sit next to filter facets. "Face" appears there
  only in CSS `font-face` and in prose.
- **A version in the bundle id** (`api@v1`). A new version would change the id, and with
  it every reference.
- **Keep a central roster.** See D8.
- **Rename the KB root** (`00_bootstrap/` and the rest). Out of scope for now. `01_spec/`
  is where the domain names live, so that is where the `_` convention is needed.

## Consequences

- A person reviews a module, or a face, in one directory.
- The tools stop caring where a file is. A later change to the directory layout touches
  the skeleton, the skills' wording and the migration, not the finders or the Factory.
- Every project has to migrate once, on purpose. Until it does, the new Factory refuses
  it with a message that says what to run.
- A built project rebuilds nothing. Its only new work is one small run per grouping
  bundle, which writes a test.
- Screen ids change once. The id map is part of the project's history.
- Packaging moves from one file to many. A question across all faces is a search by
  extension.
- `.inspire.lock` gains a reader outside INSPIRE. Changing what `inspire_version` means
  is now a breaking change for the Factory.

## Staging

All of it ships together, in INSPIRE 0.15.0 and the matching Factory release: the
layout, the extensions, the finders and validators, the templates and skills, the
rename, the migration, the bundle and process units, the id-map rewriter and the version
check. There is no intermediate state in which only some readers know the new layout.

Not built here:

- **Bundle versioning by drift** — a Factory topic.
- **The navigation map**, which replaces the face's `_index.md` — `B3-navigation-map`.
- **Renames after the migration** (`renamed_from`, stable UUIDs) — the Factory's
  control-plane design.
- **Extracting shared screens into patterns** — a deliberate change per project, later.
