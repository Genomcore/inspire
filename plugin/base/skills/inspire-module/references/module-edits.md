# Module — create · update · delete
> Part of [inspire-module](../SKILL.md). Read when the entry's index routes here.

## Subcommand: create

Scaffold a new module across the layers. The user provides the module name, an ID
prefix (e.g. `MYM`), and a description.

1. **Module hub:** `inspire_kb/02_modules/{module}.md` from the hub template
   ([`templates/module-hub.md.template`](../templates/module-hub.md.template)) —
   overview, relationships, the ID prefix, and empty link sections (features,
   screens, specs, ADRs). This is the module's home; writing it here **is** the
   registration (module hubs are `inspire_kb/02_modules/*.md` excluding `_*.md`
   and `README.md` — the glob is the registry).
2. **Features folder:** `inspire_kb/03_features/{module}/` — empty; use cases are
   added via `/inspire_feature create`.
3. **screen spec:** not created here. `inspire_kb/05_screens/{module}/` (flat or
   surface-first per the roster's UI count — see
   [`_references/surface-scope.md`](../../_references/surface-scope.md)) is created
   lazily by [`/inspire_screens`](../../inspire-screens/SKILL.md), per surface, on the
   module's first screen. `create` never pre-guesses which surfaces the module will
   reach.
4. Point the user to `/inspire_feature create` for the first use cases, and
   `/inspire_prototype` once screens exist.

Report what was created and the next steps.

## Subcommand: update

Modify an existing module. Use for: adding/removing use cases, renaming a feature
ID globally, restructuring, or realigning after a new ADR.

Operate transactionally:
1. Read the current state (features + screen spec + specs).
2. Present the diff proposal to the user.
3. On approval, apply edits across the affected layers.
4. Run `review {module}` to verify no drift was introduced.

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
