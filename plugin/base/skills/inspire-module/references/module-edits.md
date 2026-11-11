# Module — create · update · delete
> Part of [inspire-module](../SKILL.md). Read when the entry's index routes here.

## Subcommand: create

Scaffold a new module directory and its hub. The user provides the module name, an
ID prefix (e.g. `MYM`), and a description.

0. **Name gate — before scaffolding anything.** Reject a module name broad enough to
   describe the whole product (`analytics`, `platform`, `core`): a name every future
   feature could plausibly live under names nothing, and renaming later is a
   whole-vault propagation. Default to the plural of the module's primary resource
   unless the capability genuinely spans several entities, and follow the stack's own
   naming convention where it has one. A module id never starts with `_`
   (`spec-identity.sh` reports it). Surface the concern and the suggested
   alternative; the operator decides.
1. **Module hub:** `inspire_kb/01_spec/_modules/{module}/{module}.module.md` from
   the hub template ([`templates/module.template.md`](../templates/module.template.md))
   — overview, relationships, the ID prefix, and empty link sections (features,
   screens, domain, ADRs). Writing it **is** the registration: the set of modules is
   the set of `*.module.md` files under `inspire_kb/01_spec/`, and nothing else
   lists them.
2. **The module's subdirectories** (`_features/`, `_domain/`, `_adr/`,
   `_processes/`) are created by the skill that writes the first file in each:
   `/inspire-feature create` for the first use case, `/inspire-domain define` for
   the first entity or action, and so on.
3. **Screens:** not created here. A screen lives in the face that shows it
   (`_faces/{face}/_screens/`) and is created by
   [`/inspire-screens`](../../inspire-screens/SKILL.md) in that face. `create` never
   pre-guesses which faces the module will reach.
4. **Exposure:** not created here. Which bundle publishes the module is the bundle's
   file (`[[{module}]] (whole module)` under its `## Actions`), owned by
   `/inspire-face`.
5. Point the user to `/inspire-feature create` for the first use cases,
   `/inspire-face` for the bundle that exposes the module, and `/inspire-prototype`
   once screens exist.

Report what was created and the next steps.

## Subcommand: update

Modify an existing module. Use for: adding/removing use cases, renaming a feature
ID globally, renaming the module itself, restructuring, or realigning after a new ADR.

Operate transactionally:
1. Read the current state: the hub, everything under the module's directory, and
   the screens (in any face) that use its actions.
2. Present the diff proposal to the user.
3. On approval, apply the edits, update the hub's links to match, and create every
   missing link target in draft (rule 3 of [`../SKILL.md`](../SKILL.md)).
4. Run [`review {module}`](module-review.md) to verify no drift was introduced.

**Renaming the module** is an update, and it is atomic across the vault and the
source: the module directory `_modules/{module}/` and its hub
`{module}.module.md`, the ID prefix and every feature ID, every entity and action id
(`{module}.{entity}`, `{module}::{entity}::{action}`) and the links that carry them,
the `module:` field of every screen that declares it (in every face; it changes the
route), every bundle that lists the module or its actions, tracker epics and
wikilinks, ADR references, the source module directory, and every test annotation
that claims a feature's criteria (`@covers`). The entity and action file names do not
carry the module, so they stay as they are. Move files with `git mv` so
history follows the rename. Leave prose that describes the *product* rather than the
module untouched — the two share words more often than they share meaning. Verify
with [`review {module}`](module-review.md) plus the project's traceability gates
before calling it done.

## Subcommand: delete

Remove a module and everything it holds. Use with caution.

1. **Confirm** with the user: list every file and feature about to be deleted.
2. **Module directory:** delete `inspire_kb/01_spec/_modules/{module}/` — the hub,
   its features, its domain, its ADRs and its processes go together.
3. **screen spec:** sweep every face, not just one. Every `*.screen.md` under
   `inspire_kb/01_spec/` with `module: {module}` is deleted; a screen of another
   module that binds one of this module's actions is flagged for
   `/inspire-screens`. A module reaches every face as a whole, so its deletion does
   too.
4. **Bundles:** every `*.bundle.md` that lists `[[{module}]]` or one of its actions
   is flagged for `/inspire-face`, which owns the bundle files.
5. **Prototype:** remove the module's screens and routes from every face's shell;
   note any `inspire_kb/06_spikes/` entry that referenced this module.
6. **Cross-references:**
   - Search the whole `inspire_kb/` for `[[{module}]]`, its feature IDs and its
     entity and action ids — flag and offer fixes.
   - Check global and face ADRs (every `*.adr.md` outside the deleted directory)
     for references to this module.
   - Check global and face processes (`*.process.md`) that require its actions.
   - Check other modules' relationship sections.
