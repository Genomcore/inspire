# Module — create · update · delete
> Part of [inspire-module](../SKILL.md). Read when the entry's index routes here.

## Subcommand: create

Scaffold a new module across the layers. The user provides the module name, an ID
prefix (e.g. `MYM`), and a description.

0. **Name gate — before scaffolding anything.** Reject a module name broad enough to
   describe the whole product (`analytics`, `platform`, `core`): a name every future
   feature could plausibly live under names nothing, and renaming later is a
   whole-vault propagation. Default to the plural of the module's primary resource
   unless the capability genuinely spans several entities, and follow the stack's own
   naming convention where it has one. Surface the concern and the suggested
   alternative; the operator decides.
1. **Module hub:** `inspire_kb/02_modules/{module}.md` from the hub template
   ([`templates/module-hub.md.template`](../templates/module-hub.md.template)) —
   overview, relationships, the ID prefix, and empty link sections (features,
   screens, specs, ADRs). This is the module's home; writing it here **is** the
   registration (module hubs are `inspire_kb/02_modules/*.md` excluding `_*.md`
   and `README.md` — the glob is the registry).
2. **Features folder:** `inspire_kb/03_features/{module}/` — empty; use cases are
   added via `/inspire-feature create`.
3. **screen spec:** not created here. `inspire_kb/05_screens/{module}/` (flat or
   surface-first per the roster's UI count — see
   [`_references/surface-scope.md`](../../_references/surface-scope.md)) is created
   lazily by [`/inspire-screens`](../../inspire-screens/SKILL.md), per surface, on the
   module's first screen. `create` never pre-guesses which surfaces the module will
   reach.
4. Point the user to `/inspire-feature create` for the first use cases, and
   `/inspire-prototype` once screens exist.

Report what was created and the next steps.

## Subcommand: update

Modify an existing module. Use for: adding/removing use cases, renaming a feature
ID globally, renaming the module itself, restructuring, or realigning after a new ADR.

Operate transactionally:
1. Read the current state (features + screen spec + specs).
2. Present the diff proposal to the user.
3. On approval, apply edits across the affected layers.
4. Run [`review {module}`](module-review.md) to verify no drift was introduced.

**Renaming the module** is an update, and it is atomic across the vault and the
source: the hub file and its ID prefix, `03_features/{module}/` and every feature ID,
`04_domain/{module}/` descriptor filenames and their ids, the screens tree, tracker
epics and wikilinks, ADR references, the source module directory, and every test
annotation that claims a feature's criteria (`@covers`). Move files with `git mv` so
history follows the rename. Leave prose that describes the *product* rather than the
module untouched — the two share words more often than they share meaning. Verify
with [`review {module}`](module-review.md) plus the project's traceability gates
before calling it done.

## Subcommand: delete

Remove a module across all layers. Use with caution.

1. **Confirm** with the user: list every file and feature about to be deleted.
2. **Hub:** delete `inspire_kb/02_modules/{module}.md`.
3. **Features:** delete `inspire_kb/03_features/{module}/`.
4. **screen spec:** sweep every surface tree, not just one — delete
   `inspire_kb/05_screens/*/{module}/` (every surface directory, including
   `05_screens/shared/{module}/`) under a surface-first shape, or the flat
   `inspire_kb/05_screens/{module}/` while the suite is still flat (see
   [`_references/surface-scope.md`](../../_references/surface-scope.md)). A module
   reaches the suite as a whole, so its deletion does too.
5. **Specs:** delete `inspire_kb/04_domain/{module}/`.
6. **Prototype:** remove the module's screens and routes from every shell that
   serves it (all shells in a multi-surface suite, the one root otherwise); note
   any `inspire_kb/06_spikes/` entry that referenced this module.
7. **Cross-references:**
   - Grep the whole `inspire_kb/` for `[[{module}]]` or feature-ID references —
     flag and offer fixes.
   - Check ADRs under `inspire_kb/01_adr/` for references to this module.
   - Check other modules' relationship sections.
