# Keyed entries and machine-readable heads

The shared grammar behind every *named* claim in the domain (`04_domain`) and
feature (`03_features`) formats: how an entry is keyed, what a machine-readable
head may say, which claim id an entry derives, and — at the foot of this file —
the exhaustive catalogue of **old shapes**, the pre-keying spellings that a
strict reader refuses rather than silently reads as empty.

Scope: entity documents, action descriptors and use-case files. Screen files
declare their own keys and their own bindings; `inspire-screens` owns that half
and states it there.

Referenced, never restated: the format specs
([`format-entity.md`](../inspire-domain/references/format-entity.md),
[`format-action.md`](../inspire-domain/references/format-action.md), the
use-case template) say *which* sections carry keyed entries; this file says what
a keyed entry **is**.

## Why keys exist

A claim about the system has to be nameable to be tracked. An unkeyed bullet is
identified only by its position, so inserting a second invariant above it
renames it — and anything that had cited it now cites something else. Keys make
the referent explicit, which is what lets a change to one entry leave every
other entry's derived claim untouched.

**The key contract, identical to the `AC-N` contract use-case files already
carry:**

- **Write-once.** A key is minted when the entry is written and never changes.
- **Never renumbered.** Deleting `I2` leaves a gap between `I1` and `I3`. Gaps
  are the contract working, not a defect.
- **Never reused.** A deleted key is retired; the next entry takes the next
  free number.
- **Unique within its keyspace, per file.** Two `B2` steps in one descriptor is
  an error — the file has two entries with one name.

For numbered-list sections (`## Behavior`, `## Main flow`) the markdown ordinal
is **presentation only**. A reader takes the key and never the ordinal, so
`3. `B7` — …` is well-formed: the list renumbers itself, the key does not.

## The entry grammar

Two shapes, and only two:

```markdown
- `{key}` — {head} — {prose}
- `{key}` — {prose}
```

…and the same two for a numbered-list section:

```markdown
1. `{key}` — {head} — {prose}
2. `{key}` — {prose}
```

- The key is **backticked**, sits first, and is followed by the separator.
- The separator is ` — ` — space, em dash, space. It is the separator the
  shipped `## Errors` convention already uses.
- The **head is bare** (never backticked) and is recognized by shape: a segment
  is a *head attempt* when it is nothing but a lowercase identifier, optionally
  followed by a parenthesized argument list — `unique`, `actor(admin)`,
  `len(3, 64)`, `pattern(/.+@.+/)`. Prose never has that shape, so the two never
  collide.
- A head attempt whose identifier is **outside the section's vocabulary**, or
  whose argument count is wrong for it, is a defect — not prose. This is what
  keeps a typo (`uniqe`) from silently degrading a store-oracle claim into a
  prose one.
- An entry with no head is **prose-only** and legal. It derives a test-oracle
  claim rather than a store-oracle one (see [Oracles](#oracles)).

**Declared-none bodies.** A section with genuinely nothing to say declares that
explicitly rather than standing empty: a body whose single content line begins
with `None` and ends with a period. The shipped `None beyond Fields
constraints.` is the entity-invariant spelling; `None.` is the general one. The
section still has to be present — an absent section and a section that says
"nothing holds here" are different claims.

## Keyspaces

| host section | artifact | key | derived claim id |
|---|---|---|---|
| `## Invariants` | entity | `I{n}` | `{module}.{entity}/inv/I{n}` |
| `## Fields` → per-field H3 `Constraints:` | entity | the field name | `{module}.{entity}/field/{field}/{op}` |
| `## Behavior` | action | `B{n}` | `{module}.{entity}.{action}/step/B{n}` |
| `## Preconditions` | action | `P{n}` | `{module}.{entity}.{action}/pre/P{n}` |
| `## Postconditions` | action | `Q{n}` | `{module}.{entity}.{action}/post/Q{n}` |
| `## Errors` | action | the error code | `{module}.{entity}.{action}/error/{code}` |
| `## Inputs` → per-input H3 `Constraints:` | action | the parameter name | `{module}.{entity}.{action}/input/{param}/{op}` |
| `## Main flow` | use case | `B{n}` | `{feature-id}/step/B{n}` |
| `## Preconditions` | use case | `P{n}` | `{feature-id}/pre/P{n}` |
| `## Postconditions` | use case | `Q{n}` | `{feature-id}/post/Q{n}` |
| `## Acceptance criteria` | use case | `AC-{n}` (unchanged) | `{feature-id}/ac/AC-{n}` |

`P` and `Q` are the Hoare-triple letters: a descriptor reads `{P} B {Q}` — what
must hold, what happens, what holds afterwards. `I` is the invariant, which by
definition holds on both sides of every `B`.

Claim ids use the **dotted** id form (`auth.user`, `auth.user.create`), matching
the on-disk filename, never the colon display form. `{op}` in a field claim is
the constraint word itself (`auth.user/field/email/unique`). Changing a
constraint therefore changes the claim: the old claim retires and a new one
enters, which is the correct reading of a changed constraint.

## Vocabularies

Every vocabulary below is **closed**. A project extends its semantic *types*
(that is what `00_bootstrap` and the language profiles are for); it does not
extend these words, because a word a downstream reader has never heard of
carries no meaning it could act on. Adding one is a runtime change.

### V1 — field and input constraints

The `Constraints:` line's vocabulary — the first line of a per-field or
per-input H3, a comma-separated list inside a single backtick span:

```markdown
### email
Constraints: `nonnull, unique, pattern(/.+@.+/)`
```

| word | arity | means |
|---|---|---|
| `nonnull` | 0 | a value is required |
| `unique` | 0 | no two rows share this value |
| `immutable` | 0 | set once, never updated afterwards |
| `default(v)` | 1 | absent input takes `v` (`now`, `false`, a literal) |
| `enum(a\|b\|…)` | 1 (`\|`-separated members) | the value space is exactly these members |
| `min(n)` | 1 | lower bound (numeric value, or length for a string type) |
| `max(n)` | 1 | upper bound |
| `len(n,m)` | 2 | length between `n` and `m` inclusive |
| `pattern(/…/)` | 1 | the value matches this regular expression |
| `references({module}.{entity})` | 1 | the value is a key into that entity |

**Fields are nullable by default.** There is no `nullable` word: absence of
`nonnull` *is* nullability. This makes the common case the quiet one and the
requirement the marked one.

Two locality rules follow from where the line lives:

- **A field's own H3 is the only home for its single-field constraints.** A
  constraint spanning two or more fields cannot be written there, and is a named
  invariant instead (V2).
- **`## Inputs` keeps its `Required` column** and that column is the *only*
  home for an input's required-ness. `nonnull` on an input's Constraints line is
  therefore not allowed: two spellings of one fact drift.

### V2 — invariant heads

A named invariant carries a head when a single relational or multi-field
predicate captures it. The words are V1's, restricted to the forms that a single
field's own line cannot express, with an argument list of **this entity's field
names**:

| head | means |
|---|---|
| `unique(f1, f2, …)` | the tuple is unique across rows |
| `nonnull(f1, f2, …)` | none of these may be null (typically a co-presence rule) |
| `immutable(f1, f2, …)` | none of these may be updated after insert |
| `references({module}.{entity})` | referential integrity toward that entity |

Anything narrower than that — a bound, a pattern, an enum, a default — belongs
on the field's own `Constraints:` line, where it stays next to the field it
constrains. An invariant that no head captures is written **prose-only**, and
that is the normal case for the interesting ones.

### V3 — precondition heads (`P{n}`)

| head | means |
|---|---|
| `actor({role})` | only that role may invoke the action |
| `exists({module}.{entity})` | the row the inputs identify must already exist |
| `absent({module}.{entity})` | no row may exist for the identifying inputs |
| `state({module}.{entity}, {value})` | that row must be in the named state |

`actor(...)` is where a trust-boundary claim belongs. "Only an administrator may
suspend a tenant" is true wherever the action runs, so it is a precondition of
the action and never a surface-side annotation.

### V4 — postcondition heads (`Q{n}`)

| head | means |
|---|---|
| `created({module}.{entity})` | a row now exists that did not before |
| `updated({module}.{entity})` | an existing row's declared fields changed |
| `deleted({module}.{entity})` | the row no longer exists |
| `unchanged({module}.{entity})` | that entity was **not** written — the regression guard, and the one head that legitimately names an entity outside `## Entities` |
| `returns({field})` | the named `## Outputs` field is populated |

### V5 — error heads

An error's head names **the thing whose violation this error reports**, so its
vocabulary is V1 ∪ V3:

```markdown
- `email_exists` — unique(email) — operator-facing message: "An account already exists with that email."
- `forbidden` — actor(admin) — operator-facing message: "Only an administrator may do that."
```

A head is optional here too, and a bullet that is not an error at all (an
inheritance note, a pointer at another descriptor's catalogue) stays plain
prose.

## Oracles

Which oracle can assert a derived claim is decided by its head, and this split
is what makes the head worth writing:

| oracle | claims |
|---|---|
| **store** — asserted against the schema | `unique` · `nonnull` · `default` · `references` (V1 and V2 alike) |
| **test** — asserted by the suite | `immutable` · `enum` · `min` · `max` · `len` · `pattern`; every V3, V4 and V5 head; **every prose-only entry** |

A prose-only entry is therefore never worthless — it is a test-oracle claim
whose assertion a human or an agent has to write, rather than one a schema
carries for free.

## Coherence, beyond grammar

Four joins are checkable once the heads exist, and each one is a real defect
when it fails:

1. **`unique` implies a conflict error.** A field carrying `unique` — on its own
   `Constraints:` line or inside a `unique(...)` invariant head — that some
   action *writes* obliges that action to declare an error whose head is
   `unique(...)` covering the field. A uniqueness constraint with no error path
   is a constraint whose violation the contract does not describe. **`id` is
   exempt**: every entity's `id` carries `unique` by construction, and its
   uniqueness is structural rather than a business rule — the action mints the
   value, so no caller can collide with it. The join is about business-key
   uniqueness: the email, the slug, the external id a caller supplies.
2. **An invariant head names real fields.** Every argument of a V2 head is a row
   in that entity's `## Fields` table.
3. **A `P`/`Q` head names a touched entity.** Every entity id inside a V3 or V4
   head appears in the descriptor's `## Entities` section. A postcondition about
   an entity the action never declares touching is one of the two documents
   being wrong. **`unchanged(...)` is the exception, necessarily**: its whole
   point is naming an entity the action does *not* touch, so it is checked
   against the entity documents on disk instead — a guard about a nonexistent
   entity asserts nothing.
4. **`returns({field})` names a real output.** The field is a row in
   `## Outputs`.

## Old shapes — the refusal catalogue

A strict reader (the derived-contract parser) **refuses** an artifact in any of
the classes below and names the skill to touch it with; it never reads the
section as silently empty. Authoring-time review reports the same classes as
findings, ramping with the artifact's own lifecycle where it has one — a draft
is design space, an `accepted` artifact has been declared emanable.

The class ids are stable; they are what a reader's own goldens are keyed on.

### Entity document

| id | old shape |
|---|---|
| `OS-E1` | the `id` field row carries no per-field H3 whose first line is a `Constraints:` line — the deterministic marker of a pre-keying entity |
| `OS-E2` | `## Fields` has no `id` row at all (its own class, so `OS-E1` can never be vacuous) |
| `OS-E3` | `## Invariants` carries content that is neither a declared-none body nor keyed `I{n}` entries — prose invariants |
| `OS-E4` | a `Constraints:` line carries a word outside V1, or a V1 word at the wrong arity |
| `OS-E5` | a keyed invariant's head attempt is outside V2 |
| `OS-E6` | two entries share one key in one keyspace |
| `OS-E7` | a `references(...)` argument resolves to no entity document |

### Action descriptor

| id | old shape |
|---|---|
| `OS-A1` | the first `## Behavior` step carries no `B{n}` key — the deterministic marker of a pre-keying descriptor |
| `OS-A2` | `## Behavior` mixes keyed and unkeyed steps |
| `OS-A3` | `## Preconditions` absent |
| `OS-A4` | `## Postconditions` absent |
| `OS-A5` | `## Preconditions` / `## Postconditions` carries content that is neither a declared-none body nor keyed `P{n}` / `Q{n}` entries |
| `OS-A6` | a `P` / `Q` head attempt is outside V3 / V4 |
| `OS-A7` | a per-input `Constraints:` line is outside V1, or carries `nonnull` (the `Required` column owns required-ness) |
| `OS-A8` | an `## Errors` head attempt is outside V5 |
| `OS-A9` | two entries share one key in one keyspace |
| `OS-A10` | `## Preconditions` / `## Postconditions` sit outside the canonical section order |

### Use-case file

| id | old shape |
|---|---|
| `OS-F1` | the first `## Main flow` step carries no `B{n}` key |
| `OS-F2` | `## Main flow` mixes keyed and unkeyed steps |
| `OS-F3` | `## Preconditions` / `## Postconditions` carries content that is neither a declared-none body nor keyed entries |
| `OS-F4` | two entries share one key in one keyspace |
| `OS-F5` | an acceptance criterion is not of the `- [ ] AC-N: …` shape |

### Cross-artifact

| id | old shape |
|---|---|
| `OS-X1` | a written `unique` field's action declares no `unique(...)` error head covering it |
| `OS-X2` | an invariant head names a field absent from `## Fields` |
| `OS-X3` | a `P` / `Q` head names an entity absent from `## Entities` |
| `OS-X4` | `returns({field})` names a field absent from `## Outputs` |

### The one warning-only class

| id | shape |
|---|---|
| `W-1` | constraint words lingering in a `Notes` or `Description` cell, or in per-field prose, after the constraint itself moved to a `Constraints:` line |

`W-1` is **never** a refusal. Detecting it means scanning prose for words that
have legitimate prose uses, so it is a heuristic, and a heuristic does not get
to block anything. It is a flat warning at every lifecycle — the same posture
the prose-style heuristics carry.

## Remediation

Every class above is fixed the same way: **touch the artifact through its owning
skill** — `/inspire_domain update` for an entity or action, `/inspire_feature
update` for a use case. The touch flow rewrites the artifact in the current
format and refreshes its trust stamp; naming an invariant or stating a
postcondition is judgment, and judgment happens inside the interview where it
already lives. Nothing machine-edits the knowledge base.
