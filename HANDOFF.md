# T1 handoff — usage-limit checkpoint (commit 9609f7c)

## Done (suite green: `run-tests.sh` = Total 163 · Failed 0; baseline was 107)

- **New shared reference** `plugin/base/skills/_references/keyed-heads.md` — the
  single contract: entry grammar, 5 closed vocabularies (V1 constraints, V2
  invariant heads, V3 pre, V4 post, V5 error), claim-id table, oracle split,
  and the **old-shape refusal catalogue** (OS-E1..E7, OS-A1..A10, OS-F1..F5,
  OS-X1..X4, W-1) = T4's golden refusals.
- **Formats:** `inspire-domain/references/format-entity.md` (keyed `I{n}`
  invariants, per-field `Constraints:` H3, `id` marker, nullable-by-default);
  `format-action.md` (8 sections — `## Preconditions` after Entities,
  `## Postconditions` after Behavior; keyed `B{n}` steps; per-input
  `Constraints:` H3; optional error heads).
- **Templates:** `inspire-domain/templates/{entity,action}.md.template`,
  `inspire-feature/templates/use-case.md.template`.
- **Skills:** `inspire-domain/SKILL.md` (walk order, writing contract, refs),
  `inspire-feature/SKILL.md` (keyed sections paragraph).
- **Interview prompts:** `interview-prompts-entity.md` (+ constraints/migration/
  vocabulary-fit/one-field-or-many/head-fit/conflict-error probes),
  `interview-prompts-action.md` (+ `## Preconditions` and `## Postconditions`
  prompt blocks, Inputs constraints probe, error constraint-correspondence probe).
- **Examples migrated:** `canonical-entity.md`, `canonical-action.md`,
  `canonical-action-meta.md`, `orchestrator.md`, `define-interview.md`.
- **New validator lib** `plugin/base/bin/_keyed-heads.sh` (readers, vocab tables,
  head validation, comment stripping, `KH_FS` record separator).
- **New rules** (all executable, all lifecycle-progressive unless noted):
  `keys-present.sh` · `constraints-mechanics.sh` · `head-referents.sh`.
- **`sections-present.sh`** — minimal edit in my owned action block only:
  `ACTION_SECTIONS` gains Preconditions/Postconditions **for the order check**,
  new `ACTION_CORE_SECTIONS` keeps flat-error presence at the pre-0.8 six.
- **Fixtures added (56):** `keys-present/` 24 · `constraints-mechanics/` 17 ·
  `head-referents/` 13 · `sections-present/{action-new-format,
  order-action-postconditions-misplaced}` 2. **No pre-existing fixture was
  modified** — my design broke none of the estate.
- **KB READMEs:** `base/kb/04_domain/README.md`, `base/kb/03_features/README.md`.

## In progress (exact remaining work)

1. **`inspire-domain/references/subcommands/review.md`** — line 31 says
   "actions: 6 sections; entities: 4 sections"; needs the 8/4 correction plus
   three new rows in its rule table for `keys-present`,
   `constraints-mechanics`, `head-referents`. NOT yet edited.
2. **`inspire-domain/references/consolidation.md`** — line 3 lists preserved
   operator-authored sections; must add `## Preconditions` / `## Postconditions`
   (and note that a per-field H3's `Constraints:` line is preserved verbatim).
   NOT yet edited.
3. **`REGISTRATION.md` at the worktree root — NOT YET WRITTEN.** Required by the
   brief. Contents needed (exact insertions for the main session):
   - `plugin/base/bin/review.sh` `DEFAULT_RULES`: insert
     `keys-present.sh` and `constraints-mechanics.sh` after
     `sections-present.sh` (tier 2), and `head-referents.sh` after
     `touched-entity-lifecycle.sh` (tier 2, cross-file).
   - `plugin/base/bin/README.md`: 3 new rule rows + `_keyed-heads.sh` library
     row + bump the "12 rule scripts" count to 15.
   - `CLAUDE.md`: `_references/` now ships `keyed-heads.md` alongside
     `surface-scope.md` / `trust-stamps.md`.
   - Mixed-kind fixture trees (T2-owned): **no domain-side migration needed** —
     `sections-present/scope-{domain,features}-only` contain only an entity file
     and my entity section list is unchanged.
4. Optional, deliberately deferred: a `prose-style/` fixture proving keyed
   entries do not trip the style checker. Verified **manually** instead —
   `prose-style.sh` and full `review.sh` both clean against
   `fixtures/keys-present/clean` (warnings only, all pre-existing classes).

## Decisions already fixed in-package (for the plan doc)

- **`Bn` rendering:** `` 1. `B1` — {prose} ``; markdown ordinal is presentation,
  key is identity; applies to action `## Behavior` **and** feature `## Main flow`.
- **Pre/post shape:** two new mandatory action H2s, order
  Purpose · Inputs · Outputs · Entities · **Preconditions** · Behavior ·
  **Postconditions** · Errors (Hoare reading). Entries
  `` - `P1` — {head} — {prose} `` / `` - `Q1` — … ``. `P`/`Q` = Hoare letters.
- **Declared-none body:** one content line starting `None` ending `.`
  (`None.`; the shipped `None beyond Fields constraints.` still qualifies).
- **Separator:** ` — ` (em dash); heads are **bare** (unbackticked) per A19, and
  recognized by *shape* (`^[a-z][a-z_]*(\(.*\))?$`), so a typo'd head is an
  error rather than silently demoted to prose.
- **Actions and features get no `## Invariants`** — invariant keying is the
  entity document's move only.
- **Input constraints** get a per-input H3 mirroring A19; `nonnull` is
  **forbidden** there (the `Required` column owns required-ness).
- **Error heads** name what the error reports the violation of (V5); in V5 a
  field-shaped word takes field names, not the constraint's own values.
- **`## Behavior` / `## Main flow` steps carry no heads** (a head there would
  restate a pre/postcondition).
- **Severity model:** all three new rules lifecycle-progressive (draft warning →
  accepted/stable error); W-1 flat warning forever. Rationale: an upgraded vault
  must not have every existing descriptor blocking every commit; the strict
  refusal lives in T4's parser, not in a commit gate. Presence of the two new
  action sections therefore lives in `keys-present.sh`, **not** in
  `sections-present.sh`'s flat-error list.
- **OS-X1 exempts `id`** (structural PK uniqueness, action-minted → no caller
  collision; otherwise the check fires on every `create`).
- **OS-X3 exempts `unchanged(...)`** from the ##Entities requirement — its point
  is naming an untouched entity; it is resolved against disk instead.
- **Refusal-catalogue home:** `_references/keyed-heads.md`, scoped to domain +
  feature; screen shapes are T2's to add there or in their own reference.
- Comment stripping applied in **all** layers by the new rules (the 0.8
  templates carry guidance comments naming the very keys they look for).
- Record separator `KH_FS=$'\037'`, not tab: tab is IFS whitespace, so
  `IFS=$'\t' read` collapses runs and would read an unkeyed entry's prose as
  its key.

## Decisions still open

- None blocking. (Whether `derive` should treat W-1 as anything other than
  advisory is T4's call; the catalogue says advisory.)
