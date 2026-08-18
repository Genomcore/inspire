# Feature — create · update · delete
> Part of [inspire-feature](../SKILL.md). Read when the entry's index routes here.

## Subcommand: create

Create a new feature/use-case file in a module. **Required arg:**
`{module}/{feature-id}` (e.g. `ai-agents/AIA-08`).

1. **Verify** the module exists (`inspire_kb/02_modules/{module}.md`).
2. **Ask** the user: name, description (2–5 sentences), actor/personas,
   dependencies (other feature IDs), priority (Core / Important / Nice-to-have),
   state (🟡 Planned default), ADRs to reference, and the blast radius (the
   `surfaces:` frontmatter of the use case template ([`../SKILL.md`](../SKILL.md)
   § Use case template) — resolved, and only ever asked about, per
   [`_references/surface-scope.md`](../../_references/surface-scope.md)).
3. **Run the acceptance-criteria quality gate**
   ([`feature-ac-gate.md`](feature-ac-gate.md)) on the criteria before writing,
   assigning each new criterion the next free `AC-n` id, then **create the
   use-case file** `inspire_kb/03_features/{module}/{feature-id}.md` from the use
   case template ([`../SKILL.md`](../SKILL.md) § Use case template).
4. **Report next steps:**
   - If UI-facing → `/inspire_screens` to add a screen spec.
   - If it describes a behavior/endpoint → `/inspire_domain define
     {module}::{entity}::{verb}` to author the action descriptor.
   - Prototype → `/inspire_prototype` when ready.

**Feature ID convention:** the module's prefix + the next available number (scan
existing IDs), per the convention recorded in the module hub /
`00_bootstrap`.

## Subcommand: update

Modify an existing feature. Use for: changing the description, adding/removing
dependencies, promoting priority, changing state
(`🟡 Planned` → `🔵 In progress` → `🟢 Implemented`), or renaming.

1. Read the current use-case file.
2. Present a diff proposal to the user. If the `## Acceptance criteria` change, run
   them through the acceptance-criteria quality gate
   ([`feature-ac-gate.md`](feature-ac-gate.md)) before proposing — existing AC ids
   are preserved, a new criterion takes the next free id, never renumbered, never
   reusing a deleted id.
3. On approval, apply it.
4. If renamed: grep `inspire_kb/` (and any project code) for references to the
   old ID and offer fixes.
5. Run [`review {feature-id}`](feature-review.md) to verify no drift.

## Subcommand: delete

Remove a feature and clean up all references.

1. **Confirm** with the user: list every file touching this feature.
2. Delete the use-case file
   (`inspire_kb/03_features/{module}/{feature-id}.md`).
3. **screen spec:** remove the feature ID from any screen's `**Features:**` line; if a
   screen's only feature was this one, flag it for removal (that's `/inspire_screens`'s
   job) and update the screen spec `_index.md` coverage table.
4. **Prototype:** remove references in `/prototype`; note any
   `inspire_kb/06_spikes/` entry that referenced this feature.
5. **ADRs:** grep `inspire_kb/01_adr/`; if an ADR mentions this feature, flag it —
   may need an ADR update.
