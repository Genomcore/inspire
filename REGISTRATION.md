# T1 — registration note

Insertions the main session applies at wave close. Nothing here was edited on
this branch: every item below is a **registration point** under the isolation
rules (a list-like shared file), so T1 ships the self-contained files and states
the exact edits rather than making them.

Seven items: `review.sh`'s rule list · three claims in `base/bin/README.md` ·
one claim in `CLAUDE.md` · the two shared references that roster the rules
(`_references/lifecycle-rules.md`, `_references/findings-format.md`, items 7
and 8 — **T2 owns both files in this wave**, so those two apply *after* T2's
version lands and their FIND strings are quoted from T2's HEAD text, not from
`d443db2`). Plus one note about T2's mixed-kind fixture trees, which needs no
action.

---

## 1. `plugin/base/bin/review.sh` — `DEFAULT_RULES`

Three new rules. All three are **lifecycle-progressive** on the content classes
they report — the five old-shape *presence* classes are graced to a flat warning
in 0.8, see item 3's Notes — so they join the tier-3 group at its end, after
`wikilinks-resolve.sh` and before the advisory `prose-style.sh`. Placing them at the end rather than the head keeps this list
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
| `keys-present.sh` | (11) Every section whose format spec declares keyed entries carries them, well-formed: entity `## Invariants` as `I{n}`; action `## Preconditions` / `## Postconditions` present, non-empty and keyed `P{n}` / `Q{n}`; `## Behavior` and use-case `## Main flow` steps keyed `B{n}`; `## Errors` codes unique. Heads are checked against their closed vocabulary. | Two tiers. What a keyed entry **says** (`OS-A2`, `OS-A5`, `OS-A6`, `OS-A8`, `OS-A9`, `OS-E5`, `OS-E6`) is lifecycle-progressive: warning at draft, error at accepted and stable, warning again at superseded. Whether the keyed shape **is there at all** (`OS-A1`, `OS-A3`, `OS-A4`, `OS-E3`) is a flat warning at every lifecycle in 0.8, so an upgraded vault is not red on every descriptor it already had; those four ramp in the release after. Use-case files carry no `lifecycle:` and so land on the warning side throughout, as every finding in that layer does. |
| `constraints-mechanics.sh` | (12) `Constraints:` lines are well-formed: the entity `id` marker is present, every token is a closed-vocabulary word at its own arity, and `nonnull` is rejected on an input line (the `Required` column owns required-ness). A line is read wherever in its H3 it sits; a line that is not the H3's first content line is reported as `OS-E8`. Also emits `W-1`. | Same two tiers. `OS-E2`, `OS-E4` and `OS-E8` are lifecycle-progressive; `OS-E1` (no `Constraints:` line on `id`) is a presence class and so a flat warning at every lifecycle in 0.8. `W-1` (a constraint still narrated in a `Notes` / `Description` cell) is a **flat warning forever**: recognising a constraint word in prose is a heuristic. |
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
> `keys-present.sh`'s, and there it is one of the five old-shape presence
> classes — a **warning at every lifecycle state in 0.8**, at pre-commit,
> pre-PR and `promote` alike, so a vault upgraded to 0.8 is not red on every
> descriptor it already had. What a keyed entry *says* is a different tier:
> error from `accepted` onward, everywhere the rule runs. `derive` refuses an
> old-shape descriptor regardless, and the presence classes ramp with the
> lifecycle in the release after 0.8.

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

More generally, **T1 migrated no pre-existing fixture's tree.** The three new
rules ship their own fixture directories, and the two `sections-present`
additions are new directories. Nothing in the estate needed its markdown
rewritten, because the presence half of the format move deliberately did not
land in `sections-present.sh`'s flat-error list.

Nine pre-existing `expect.json` files did change, and none of them is a tree
migration: seven flip an asserted `error` to `warning` under the 0.8 presence
grace (item 1), and two key an assertion on a class id the finding now carries.
They are listed in the rework report.

---

## 7. `plugin/base/skills/_references/lifecycle-rules.md` — the tier tables

**Applies after T2's version of this file lands.** Both FIND strings below are
quoted from T2's HEAD (`emanation/t02-screens` @ `aaf201d`), where each occurs
exactly once; neither sits in the screen block T2 rewrites.

**(a)** Three tier-3 rows. FIND (once):

```
| `wikilinks-resolve` (every `[[wikilink]]` resolves to a file) | warning | error | error | warning |
```

INSERT the three rows below **immediately after** it:

```markdown
| `keys-present` — what a keyed entry says (`OS-A2` · `OS-A5` · `OS-A6` · `OS-A8` · `OS-A9` · `OS-E5` · `OS-E6`) | warning | error | error | warning |
| `constraints-mechanics` — vocabulary, arity and placement (`OS-E2` · `OS-E4` · `OS-E8`) | warning | error | error | warning |
| `head-referents` — every name a head mentions exists (`OS-E7` · `OS-X1`–`OS-X4`) | warning | error | error | warning |
```

**(b)** The grace, as a paragraph. FIND the paragraph that begins
`The tier-3 rules ramp severity by the *current object's* lifecycle` and
APPEND after it:

> Three of the tier-3 rules report a **second, ungraded** class of finding: the
> five *old-shape presence* classes — `OS-A1`, `OS-A3`, `OS-A4` (`keys-present`),
> `OS-E1` (`constraints-mechanics`) and `OS-E3` (`keys-present`) — are flat
> warnings at **every** state in 0.8, columns and all. "New but unkeyed" and
> "pre-0.8" are the same shape on disk, so ramping them would make every
> `accepted` and `stable` artifact of an upgraded vault red at pre-PR and at
> `promote`. `derive` refuses an old-shape artifact regardless; the five ramp
> with this table's columns in the release after 0.8. See
> [`keyed-heads.md`](keyed-heads.md) § "Severity — two tiers".

---

## 8. `plugin/base/skills/_references/findings-format.md` — the rule roster

**Applies after T2's version of this file lands.** All FIND strings are quoted
from T2's HEAD (`emanation/t02-screens` @ `aaf201d`), each occurring once.

**(a)** The exhaustive `rule` list. FIND (once):

```
`rationale-wikilink`, `wikilinks-resolve`, `prose-style`.
```

REPLACE with:

```
`rationale-wikilink`, `wikilinks-resolve`, `keys-present`, `constraints-mechanics`, `head-referents`, `prose-style`.
```

**(b)** Three message rows. FIND (once):

```
### Standalone warnings
```

INSERT the three rows below **immediately before** it, so they close the
Lifecycle-progressive table:

```markdown
| `OS-A2` · `OS-A5` · `OS-A6` · `OS-A8` · `OS-A9` · `OS-E5` · `OS-E6` | keys-present | A keyed entry is there but wrong: a step key that is not `B{n}`, a section holding neither a declared-none body nor keyed entries, a head outside its closed vocabulary or at the wrong arity, a key used twice in one keyspace. |
| `OS-E2` · `OS-E4` · `OS-E8` | constraints-mechanics | A `Constraints:` line is wrong: no `id` row to carry the marker, a word outside vocabulary V1 or at the wrong arity (`nonnull` on an input line included), or a line that is not its H3's first content line. |
| `OS-E7` · `OS-X1` · `OS-X2` · `OS-X3` · `OS-X4` | head-referents | A name a head mentions does not exist: an unresolvable `references(...)`, a written `unique` field with no matching `unique(...)` error head, an invariant head naming a non-field, a `P`/`Q` head naming an untouched entity, `returns(...)` naming a non-output. |
```

**(c)** Two flat-warning rows, in the **Standalone warnings** table. FIND the
row that begins `` | `field-orphan-write` | entity-coherence | `` and INSERT
after it:

```markdown
| `OS-A1` · `OS-A3` · `OS-A4` · `OS-E1` · `OS-E3` | keys-present, constraints-mechanics | The keyed shape is absent rather than wrong: no `B{n}` on the first `## Behavior` step, no `## Preconditions` / `## Postconditions`, no `Constraints:` line on `id`, prose or unkeyed `## Invariants`. A **flat warning at every lifecycle in 0.8** — the shapes an upgrade inherits — ramping in the release after. The message ends `— derive refuses old-shape artifacts`. |
| `W-1` | constraints-mechanics | A constraint word still narrated in a `Notes` or `Description` **cell** after the constraint moved to a `Constraints:` line. Table cells only; per-field H3 prose is where a constraint's meaning belongs and is never scanned. A heuristic, so a flat warning forever. |
```

**(d)** Two existing rows now carry a class-id prefix, and the table should say
so. FIND (once) `` | `AC-id format` | sections-present | `` and replace that
cell with `` | `OS-F5: AC-id format` | sections-present | ``; FIND (once)
`` | `{kind} section order` | sections-present | `` and replace that cell with
`` | `OS-A10: {kind} section order` (action descriptors; entity documents keep the unprefixed form) | sections-present | ``.
