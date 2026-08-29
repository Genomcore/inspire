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
   - If UI-facing → `/inspire-screens` to add a screen spec.
   - If it describes a behavior/endpoint → `/inspire-domain define
     {module}::{entity}::{verb}` to author the action descriptor.
   - Prototype → `/inspire-prototype` when ready.

**Feature ID convention:** the module's prefix + the next available number (scan
existing IDs), per the convention recorded in the module hub /
`00_bootstrap`.

**Every criterion carries a stable `AC-n` id** — upstream's own template form — and it is
not decoration: `criteria-have-tests.sh` requires a test to claim it, so an untested
criterion becomes a blocking finding instead of something a reviewer has to notice. Three
rules make the id trustworthy:

- **Assigned once, never renumbered.** Deleting `AC-3` retires the number; the next new
  criterion is `AC-11`, not `AC-3`. Positional numbering was rejected on purpose —
  inserting a criterion would silently re-point every test after it, which is the drift
  the gate exists to kill.
- **A test claims it with `@covers`, qualified by the owning feature** — `AC-6` alone
  recurs in every feature, so a bare citation in one feature's tests would silently
  satisfy every other feature's sixth criterion. The `{feature}/{key}` shape is the
  structural-path id convention (identity = what the claim constrains, prefixed by its
  owner):

  ```ts
  /** @covers ANL-02/AC-6 */
  it('returns an empty page rather than an error when nothing matches', …)
  ```

- **The id never goes in the test name.** Test names are read on every CI failure, and an
  opaque token there is noise for whoever arrives next. Keep the name a sentence about
  behavior — ideally the criterion's own words, which is what makes the pair legible
  without the id being visible at all.

One criterion may be claimed by several tests, and one test may claim several ids
(`@covers ANL-01/AC-7 ANL-02/AC-4`) when it genuinely exercises both. What is *not*
allowed is a criterion no test claims.

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

**State advances usually arrive from the coding stage.** `/inspire-code tdd` offers
the ladder's two moves at its cycle's edges — 🟡 → 🔵 when implementation starts,
🔵 → 🟢 when every criterion is claimed by a green test — and chains here on
acceptance: the offer is its, the write is this skill's. A state-only update is the
minimal form of the flow above — read, one-line diff, apply and stamp; the AC gate
does not run because no criterion changed. Step 5 is worth its cost on the 🔵 → 🟢
promotion (that is the claim `adr-maturity-matches-features.sh` starts holding the
feature to) and is noise on 🟡 → 🔵. The ladder moves one rung at a time; a
demotion (a 🟢 that overclaimed) is a legitimate `update` too —
`adr-maturity-matches-features.sh` names it as one of its two fixes — but it is
the operator's to ask for, never an offer the coding stage makes.

## Subcommand: delete

Remove a feature and clean up all references.

1. **Confirm** with the user: list every file touching this feature.
2. Delete the use-case file
   (`inspire_kb/03_features/{module}/{feature-id}.md`).
3. **screen spec:** remove the feature ID from any screen's `**Features:**` line; if a
   screen's only feature was this one, flag it for removal (that's `/inspire-screens`'s
   job) and update the screen spec `_index.md` coverage table.
4. **Prototype:** remove references in the prototype root (`/prototype` by default —
   resolve `prototype_root` per
   [`_references/product-roots.md`](../../_references/product-roots.md); nothing to do
   when it is `none`); note any
   `inspire_kb/06_spikes/` entry that referenced this feature.
5. **ADRs:** grep `inspire_kb/01_adr/`; if an ADR mentions this feature, flag it —
   may need an ADR update.
