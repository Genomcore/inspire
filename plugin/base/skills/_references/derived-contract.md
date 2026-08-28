# The derived contract

The structured, language-neutral projection of one **unit** — what
`.inspire/bin/emanate-derive.sh` prints on stdout, and the single input both the
readiness gate and the contracter agent read. This file owns its JSON shape, the
fingerprint rule, the exit codes and the refusal classes derive names itself.

The old-shape catalogue it shares with authoring-time review is
[`keyed-heads.md`](keyed-heads.md) § "Old shapes"; the `OS-*` rows are never
copied here, because two catalogues of one class is one catalogue too many.

## What a unit is

Three kinds, and the kind is always given explicitly:

| kind | artifact | id |
|---|---|---|
| `entity` | `04_domain/{module}/{entity}/{module}.{entity}.md` | `auth.user` |
| `action` | `04_domain/{module}/{entity}/{module}.{entity}.{action}.md` | `auth.user.create` |
| `screen` | `05_screens/[{surface}/]{module}/{screen}.md` | `users.list` · `admin.users.list` |

The kind is positional rather than inferred because a 2-segment id is an entity
*or* a screen and a 3-segment id an action *or* a collision-minted screen.

**Patterns and components are not derive kinds.** A screen's contract lists them
as declared dependencies — id, resolved path, and a component's `**State:**`
line — and reading readiness off those states is `emanate plan`'s question, not
this one's. A use-case file is not a unit either: its `OS-F*` classes are
review's, and nothing emanates from a use case directly.

## CLI

```
emanate-derive.sh <entity|action|screen> <id>
emanate-derive.sh <entity|action|screen> --file <path>
```

The current working directory is the repo root; `SDD_SPEC_ROOT` (default
`inspire_kb/04_domain`) and `SDD_KB_ROOT` (default `inspire_kb`) name the two
layers, as everywhere in `.inspire/bin/`.

**It writes nothing** — no file, no log, no KB edit. Stdout is JSON, stderr is
the grouped human report.

| exit | meaning |
|---|---|
| `0` | derived; the contract is on stdout |
| `2` | usage — bad kind, missing id, unknown flag, an id *and* `--file` |
| `3` | unit not found. A screen deeper than `05_screens/{surface}/{module}/{screen}.md` lands here: the screen finders do not reach past that depth, so nothing in the vault can see it |
| `4` | **refused** — see below |
| `5` | roots missing: `$SDD_KB_ROOT`, or `$SDD_SPEC_ROOT` for a domain kind, is not a directory |
| `127` | a required tool is missing (`jq`, `yq`, or a sha256 digest) |

## The contract

```json
{ "schema": "inspire.derived-contract/1",
  "unit": { "kind", "id", "path", "lifecycle", "module",
            "entity"? , "action"?, "screen"? },
  "purpose": "…",
  "requires": [ { "kind", "id" } … ],
  … kind-specific sections …
  "claims": [ { "id", "oracle", "fingerprint" } … ] }
```

- **`unit`** carries the identity as declared, never as inferred from location.
  A screen with no identity block is refused, not renamed.
- **`purpose`** is the `## Purpose` prose, whitespace-collapsed to one line. It
  is the unit's intent, which the contracter would otherwise have to
  reconstruct from links.
- **`requires`** is the dependency edge set, deduplicated and sorted: an
  action's frontmatter `requires:` plus every entity it touches; an entity's
  `references(…)` targets; a screen's data and dispatch actions, its navigation
  targets (including a dispatch outcome that navigates), its pattern and its
  components. Whether a required id exists is `emanate plan`'s question — derive
  records the edge.
- **`claims`** is every claim the unit makes, in derivation order: for an entity
  the field constraints in table order then the invariants; for an action the
  input constraints, preconditions, behavior steps, postconditions and errors;
  for a screen the data, dispatch, navigation and state bindings.

### Shared shapes

A **keyed entry** (invariant · precondition · behavior step · postcondition ·
error) is:

```json
{ "key": "I1", "head": { "word": "unique", "args": ["org_id", "email"] },
  "prose": "…", "oracle": "store" }
```

`head` is `null` for a prose-only entry and for every behavior step (a step
carries no head by design). `oracle` is `keyed-heads.md`'s split: `store` for
`unique` · `nonnull` · `default` · `references`, `test` for everything else and
for every prose-only entry.

A **type** is `{ "name", "base" }`, always. Every `Type` cell must resolve —
`## Entities` field-touch rows included — and an empty one is `DR-T2` rather than
a `null`: a field whose type nothing states is a rendering the contracter would
have to guess at. `base` is the universal semantic type from
[`type-mapping.md`](../inspire-domain/references/type-mapping.md); a project's
own type from `00_bootstrap/semantic-types.md` resolves to its declared base
type. The parametric universal row `enum<A,B,C>` has base name `enum`, so a
field typed `enum<draft|active>` resolves to `{"name": "enum<draft|active>",
"base": "enum"}`.

A **constraint** is `{ "word", "args": [...], "oracle" }`, from the closed V1
vocabulary.

### Kind-specific sections

| kind | sections |
|---|---|
| `entity` | `fields` (each `{name, type, notes, constraints[]}`) · `invariants` |
| `action` | `inputs` (each `{name, type, required, description, constraints[]}`) · `outputs` · `entities` · `preconditions` · `behavior` · `postconditions` · `errors` |
| `screen` | `features` · `pattern` · `components` · `bindings` · `route` |

- **`outputs`** is `{ "entity", "fields" }`. The whole-entity one-liner
  (`An array of [[auth.user|auth::user]] entities.`) sets `entity` and leaves
  `fields` empty — the entity document is the canonical field shape and
  duplicating it here would drift.
- **`entities`** is one object per touched entity: `{id, as_input, effect,
  fields}`, and each touched field carries **the entity document's own
  constraints** for that field. They are carried, never claimed: the claim about
  a field belongs to the entity's contract and is minted exactly once, there.
- **`pattern`** is `{id, path}` or `null`; **`components`** is a list of
  `{id, path, state}` where `state` is the entry's `**State:**` line.
- **`bindings`** is `{data, dispatches, navigation, states}`. A dispatch's
  `on_success` / `on_error` are canonicalized to `nav:{screen-id}` ·
  `state:{key}` · `refresh:{key}` · `none`.
- **`route`** is `{module, screen, default}`. The inputs are the declared
  `module:` and `screen:` fields, never the id string, so a collision-minted
  `admin.users.list` still renders `/users/list`. `default` is the
  stack-agnostic rendering `/{module}/{screen}`; the shell prefix and the exact
  rendering belong to the framework profile.

## Claim ids

Domain claim ids are exactly `keyed-heads.md` § Keyspaces, screen claim ids
exactly `format-screen.md` § Claims:

```
{module}.{entity}/field/{field}/{op}     {module}.{entity}/inv/I{n}
{action}/input/{param}/{op}              {action}/pre/P{n}
{action}/step/B{n}                       {action}/post/Q{n}
{action}/error/{code}
{screen-id}/data/{key}                   {screen-id}/dispatch/{key}
{screen-id}/nav/{key}                    {screen-id}/state/{key}
```

`{op}` is the constraint word itself, one claim per word, so changing a
constraint retires that claim and mints the new one while every sibling stays
covered.

## The fingerprint

`sha256:<hex>` over the claim's **payload bytes** — its derived content, with no
trailing newline. Never the raw line, and never the position: the markdown
ordinal is not read at all, so renumbering a list changes nothing.

The payload is the fields below, in that order, joined by **U+001E**, each one
whitespace-collapsed and trimmed:

| claim family | payload fields |
|---|---|
| entity field constraint · action input constraint | the canonical constraint token |
| invariant · precondition · postcondition · error | the canonical head text (empty when there is none) · the prose |
| behavior step | the canonical head text (always empty) · the prose |
| screen data | action id · notes |
| screen dispatch | action id · trigger · canonical `on_success` · canonical `on_error` |
| screen navigation | target screen id · trigger |
| screen state | when · presentation |

The **canonical head text** is `word` or `word(a1,a2)` with each argument
trimmed, so `len(3, 64)` and `len(3,64)` are one claim. A dispatch's outcomes
feed its own fingerprint (A14 §2): changing an outcome re-emanates that one
dispatch and nothing else.

Two consequences worth stating. Two files differing only in whitespace or in
markdown ordinals produce byte-identical claim lists. And two claims with
identical content — `nonnull` on two different fields — carry the same
fingerprint; they are told apart by their ids, which is what ids are for.

## Refusal

An old shape is a **derivation error**, never a silently-empty section (design
D7). On exit `4` stdout carries every class found, not the first, and no
`claims` key at all — a refused unit makes no claims:

```json
{ "schema": "inspire.derived-contract/1",
  "unit": { … },
  "refused": [ { "class", "target", "message", "remedy" } … ] }
```

`remedy` names the owning skill's touch command — `/inspire_domain update {id}`
or `/inspire_screens update {id}`. Nothing machine-edits the knowledge base:
naming an invariant is judgment, and judgment happens inside the touch
interview.

**Derive refuses on every `OS-E*`, `OS-A*` and `OS-X*` class regardless of the
severity review reported it at.** The 0.8 grace that keeps the five presence
classes at warning exists so an upgraded vault is not red everywhere; the
strictness lives here instead. `W-1` is never a refusal — recognising a
constraint word inside prose is a heuristic, and a heuristic does not get to
block anything.

### How the classes are checked

Each `OS-*` class has exactly one implementation: the review rule that owns it.
Derive **runs those rules** over the unit's own directory and reads their JSON
findings back, filtered to the artifacts this derivation must read. There is no
second copy of a check to drift. The rules consulted, and nothing else:

| kind | rules |
|---|---|
| `entity` · `action` | `keys-present` · `constraints-mechanics` · `head-referents` · `sections-present` |
| `screen` | `screen-coherence` · `sections-present` |

Nothing a consulted rule reports against the unit is ignored. A message carrying
an `OS-*` prefix is filed under that class; the rest map to the `DR-*` ids below;
anything neither is filed under `DR-U1` rather than dropped.

### `DR-*` — the classes derive names itself

`DR-T*` and `DR-R*` are derive-only: no rule owns them, because they are
questions only a reader that has to *render* the unit needs answered. `DR-S*`
and `DR-D1` are shapes the screen and section rules already report and no
catalogue had numbered; derive numbers them so a golden fixture, a finding and
this table name the same thing.

| id | shape | remedy |
|---|---|---|
| `DR-T1` | a `Type` cell names a semantic type in neither the universal vocabulary nor `00_bootstrap/semantic-types.md` | touch the artifact |
| `DR-T2` | a `Type` cell that must declare a type declares none | touch the artifact |
| `DR-T3` | a project semantic type declares no universal base type | declare a `Base type` in `00_bootstrap/semantic-types.md` |
| `DR-R1` | an action's `## Entities` names an entity with no document on disk | touch the artifact |
| `DR-R2` | a screen binding names an action id that resolves to no descriptor | touch the screen |
| `DR-R3` | a transition target — a `### Navigation` row, or a `→ [[…]]` dispatch outcome — resolves to no screen id | touch the screen |
| `DR-R4` | a `**Pattern:**` or `**Components:**` link resolves to no catalog entry | touch the screen |
| `DR-S1` | the screen identity block is absent or incomplete — the pre-0.8 screen | touch the screen |
| `DR-S2` | the identity contradicts itself or the vault: lifecycle enum, id shape, module-versus-path, `superseded_by`, a duplicate id, a route collision | touch the screen |
| `DR-S3` | a route authored into the H1 | touch the screen |
| `DR-S4` | a required screen part absent or empty — the H1, `**Features:**`, `## Purpose`, `## Bindings` | touch the screen |
| `DR-S5` | `## Instantiation`, retired, still present | touch the screen |
| `DR-S6` | a bindings subsection outside the closed set, or rows under none | touch the screen |
| `DR-S7` | a binding row with no key, or a key used twice in one subsection | touch the screen |
| `DR-S8` | a dispatch outcome outside the three declared forms, route-shaped included | touch the screen |
| `DR-S9` | a navigation target that is not a wikilinked screen id | touch the screen |
| `DR-S10` | a state whose `When` anchors nothing declared | touch the screen |
| `DR-S11` | the pattern join: a required region finds no binding of a kind it accepts | touch the screen |
| `DR-S12` | a `stable` screen declaring a `to-extract` component | touch the screen |
| `DR-D1` | a mandatory body section of a domain artifact is absent or empty | touch the artifact |
| `DR-D2` | an entity document's sections sit outside the canonical order (the action shape carries `OS-A10`; the entity one carries no class id of its own) | touch the artifact |
| `DR-U1` | a consulted rule reported a shape this table has no id for | read the message; then give the shape an id here |

`DR-U1` is the catch-all, and it refuses like every other class. A finding derive
cannot name is still a finding: a strict parser that dropped what it did not
recognise would be exactly the silent-green trap the strictness exists to close.

## Consumers

[`emanate plan`](emanation-plan.md) aggregates the stdout objects — it must never
parse stderr — and turns refusals into readiness findings grouped by owning
skill. [`emanate gate`](gate-verdict.md) reads `claims` and matches them against
citing tests. The contracter agent reads everything else. All three read this
file for what a field means.

**Sourcing the units instead of running the entry** is the other way in, and the
line between the two is worth stating. The reuse surface is
`.inspire/bin/lib/derive-*.sh` after `_lib.sh` and `_keyed-heads.sh`:
`derive_scratch` (which must run first — every other unit reads `$DERIVE_TMP`,
and the caller owns the EXIT trap that removes it), the readers, the fingerprint
helpers, and the sweep (`derive_sweep_require` · `derive_sweep_start` ·
`derive_sweep_collect`, which need `$DERIVE_BIN` — it defaults to the directory
holding the rules, so only a caller relocating them has to set it). What belongs
to the entry and not to the surface: the `U_*` globals it fills from the
artifact's identity, and the `derive_*_json` renderers that read them. A
consumer that wants a contract runs `emanate-derive.sh`; a consumer that wants a
reader sources the unit.
