# T1 — registration note

Insertions the main session applies at wave close. Nothing here was edited on
this branch: every item below is a **registration point** under the isolation
rules (a list-like shared file), so T1 ships the self-contained files and states
the exact edits rather than making them.

Five items: `review.sh`'s rule list · three claims in `base/bin/README.md` ·
one claim in `CLAUDE.md`. Plus one note about T2's mixed-kind fixture trees,
which needs no action.

---

## 1. `plugin/base/bin/review.sh` — `DEFAULT_RULES`

Three new rules. All three are **lifecycle-progressive**, so they join the
tier-3 group — at its end, after `wikilinks-resolve.sh` and before the advisory
`prose-style.sh`. Placing them at the end rather than the head keeps this list
in the same order as `base/bin/README.md`'s tier-3 table (item 3), where they
take the next free check numbers; review.sh's own header says order within a
tier is "arbitrary but stable", so nothing else depends on the choice.

Their relative order among themselves *is* meaningful: the two grammar rules run
before the resolution rule, which is the one that depends on the expressions
already being well-formed.

```diff
 field-coverage.sh \
 rationale-wikilink.sh \
 wikilinks-resolve.sh \
+keys-present.sh \
+constraints-mechanics.sh \
+head-referents.sh \
 prose-style.sh"
```

Resulting list, in full, for verification (15 entries):

```
frontmatter-mechanics.sh acyclic-deps.sh sections-present.sh no-todos.sh
action-fields-in-entity.sh entity-coherence.sh stable-blockers.sh
touched-entity-lifecycle.sh field-coverage.sh rationale-wikilink.sh
wikilinks-resolve.sh keys-present.sh constraints-mechanics.sh
head-referents.sh prose-style.sh
```

`_keyed-heads.sh` is **not** in this list and must not be added: it is a sourced
library, like `_lib.sh`, and emits no findings.

---

## 2. `plugin/base/bin/README.md` — the rule count (line 25)

```diff
-The library implements the **quality gate** (per D24 in the SDD V3 reframe addendum): the 12 rule scripts `review.sh` runs, in three severity tiers plus the style checks below them.
+The library implements the **quality gate** (per D24 in the SDD V3 reframe addendum): the 15 rule scripts `review.sh` runs, in three severity tiers plus the style checks below them.
```

## 3. `plugin/base/bin/README.md` — three rows in the Tier 3 table

Append **below** the existing `wikilinks-resolve.sh` row, matching the
`DEFAULT_RULES` order of item 1:

```markdown
| `keys-present.sh` | (11) Every section whose format spec declares keyed entries carries them, well-formed: entity `## Invariants` as `I{n}`; action `## Preconditions` / `## Postconditions` present, non-empty and keyed `P{n}` / `Q{n}`; `## Behavior` and use-case `## Main flow` steps keyed `B{n}`; `## Errors` codes unique. Heads are checked against their closed vocabulary. | Warning at draft; error at accepted and stable; warning again at superseded. Use-case files carry no `lifecycle:` and so land on the warning side, as every finding in that layer does. |
| `constraints-mechanics.sh` | (12) `Constraints:` lines are well-formed: the entity `id` marker is present, every token is a closed-vocabulary word at its own arity, and `nonnull` is rejected on an input line (the `Required` column owns required-ness). Also emits `W-1`. | Same ramp as above — except `W-1` (a constraint still narrated in a `Notes` / `Description` cell), which is a **flat warning at every lifecycle**: recognising a constraint word in prose is a heuristic. |
| `head-referents.sh` | (13) Every name a head mentions exists: a written `unique` field obliges its action to declare a matching `unique(...)` error head (`id` exempt); invariant heads name real fields; `P` / `Q` heads name touched entities (`unchanged(...)` exempt, and resolved against disk instead); `returns(...)` names a real output; `references(...)` resolves. | Same ramp, on the lifecycle of the artifact the finding is reported against. |
```

The existing Tier 3 rows keep their numbering (`field-coverage.sh` = 8,
`rationale-wikilink.sh` = 9, `wikilinks-resolve.sh` = 10), so the three new rows
take 11–13, read in order, and nothing renumbers.

## 4. `plugin/base/bin/README.md` — two smaller claims

**(a)** The `sections-present.sh` row in the Tier 2 table describes the action
section list. Replace the parenthetical

```
(actions: Purpose / Inputs / Outputs / Entities / Behavior / Errors; entities: Purpose / Rationale / Invariants / Fields / Touched by)
```

with

```
(actions: the core six — Purpose / Inputs / Outputs / Entities / Behavior / Errors; entities: Purpose / Rationale / Invariants / Fields / Touched by)
```

and append to that row's Notes cell:

> Order is checked against the full canonical **eight** action sections, which
> include `## Preconditions` and `## Postconditions`; their *presence* is
> `keys-present.sh`'s, at that rule's gentler ramp, so a vault upgraded to 0.8
> does not have every descriptor it already had blocking every commit.

**(b)** The Scope section (line 104) names the rules that reach past the domain
tree. `keys-present.sh` now reaches into `03_features/` too:

```diff
-`sections-present.sh` and `prose-style.sh` reach past the domain tree into `03_features/`, `01_adr/` and `05_screens/`, which makes the scope argument a contract rather than a convention.
+`sections-present.sh` and `prose-style.sh` reach past the domain tree into `03_features/`, `01_adr/` and `05_screens/`, and `keys-present.sh` into `03_features/`, which makes the scope argument a contract rather than a convention.
```

**(c)** One row in the Library table, after `_lib.sh`:

```markdown
| `_keyed-heads.sh` | Shared readers for the keyed-entry grammar the domain and feature formats use — entry parsing, the five closed vocabularies, head validation, `Constraints:` lines, comment stripping. Sourced by `keys-present.sh`, `constraints-mechanics.sh` and `head-referents.sh` so the three cannot drift on what a key or a head is. Deliberately absent from `DEFAULT_RULES`. | (library — not invoked directly) |
```

---

## 5. `CLAUDE.md` — the `_references/` roster (line 94)

```diff
-        `inspire-*` skill dirs (`surface-scope.md`, `trust-stamps.md`); it is
+        `inspire-*` skill dirs (`surface-scope.md`, `trust-stamps.md`,
+        `keyed-heads.md`); it is
```

No other CLAUDE.md claim moves. The skill count is unchanged (no skill was added
or removed), and `base/bin/` is described without a script count.

---

## 6. T2's mixed-kind fixture trees — no action needed

The isolation rules say T1 contributes its domain-side migrations for
mixed-kind fixture trees through this note. **There are none to contribute.**

The two mixed-kind trees under `sections-present/` — `scope-domain-only` and
`scope-features-only` — carry exactly one domain artifact each, an entity
document, and T1 changed neither the entity section list nor anything else
`sections-present.sh` checks about an entity. T1's only edit to that script is
in the action block. Both trees pass unmodified, and did so on every run.

More generally: **T1 modified no pre-existing fixture at all.** The three new
rules ship their own fixture directories, and the two `sections-present`
additions are new directories. Nothing in the estate needed migrating, because
the presence half of the format move deliberately did not land in
`sections-present.sh`'s flat-error list.
