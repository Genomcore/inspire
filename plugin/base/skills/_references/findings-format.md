# Findings format (shared reference)

Conversational skills that report SDD-layer issues — `/inspire_domain review`, `/inspire_module scan`, `/inspire_feature scan`, source/show traces — use a single rendering format so operators can read every report the same way.

## Underlying machine format

Bash rule scripts under `.inspire/bin/*.sh` emit findings as **JSON Lines on stderr**, one finding per line:

```json
{"severity":"error","rule":"entity-coherence","target":"auth::user","message":"field-conflict: auth::user.id has differing types across actions: uuid/integer"}
```

Fields:

- `severity` — `error` | `warning` | `info`
- `rule` — short identifier. The quality gate (D24) emits findings under: `lifecycle-valid`, `requires-resolves`, `superseded-by-resolves`, `acyclic-deps`, `sections-present`, `no-todos`, `action-fields-in-entity`, `entity-coherence`, `stable-blockers`, `touched-entity-lifecycle`, `screen-coherence`, `field-coverage`, `rationale-wikilink`, `wikilinks-resolve`, `keys-present`, `constraints-mechanics`, `head-referents`, `prose-style`.
- `target` — path or id the finding applies to (a file path or a `module::entity[::action]` id)
- `message` — human-readable description prefixed with the finding *type* (e.g. `field-conflict:`, `self-loop detected:`)

## Operator-facing rendering

When skills surface findings in conversation, render each one as a markdown sub-section. One sub-section per finding — never a wall of JSON, never a flat bullet list when there's more than one.

```markdown
### error · entity-coherence — auth::user

**Issue.** field-conflict: `auth::user.id` has differing types across actions (`uuid` in `auth::user::create`, `integer` in `auth::user::read`).

**Suggested follow-up.** Reconcile the type. Either rewrite the read action to expect `uuid`, or change create to write `integer`. Re-run `/inspire_domain review auth::user` after.
```

Three required slots:

1. **Heading** — `### {severity} · {rule} — {target}`
2. **Issue** — the message, lightly humanized (resolve ids to wikilinks where helpful)
3. **Suggested follow-up** — what action to take. If the rule's catalog entry doesn't supply one, ask the operator.

## Finding type catalog (closed set)

The set of finding types is closed — every rule emits one of these. If a rule needs a new type, add it here first.

### Mechanical-blocker errors (always)

| Type | Rule | Meaning |
|---|---|---|
| `missing required frontmatter field: lifecycle` | lifecycle-valid | Frontmatter has no `lifecycle:` key. |
| `invalid lifecycle value` | lifecycle-valid | `lifecycle:` set but value is not one of `draft / accepted / stable / superseded`. |
| `requires target does not resolve` | requires-resolves | A `requires:` entry points to an id not present in the SDD tree. |
| `superseded_by target does not resolve` | superseded-by-resolves | `superseded_by:` is set but the pointed id is not present in the SDD tree. |
| `self-loop detected` | acyclic-deps | Action's `requires` list contains its own id. |
| `cycle in requires graph` | acyclic-deps | Action participates in a multi-node cycle in the action→action graph. |

### Coherence-blocker errors (from draft+)

| Type | Rule | Meaning |
|---|---|---|
| `missing required section(s)` | sections-present | One or more mandatory `## Section` headers absent from the body. Error in `04_domain`; the other KB layers emit the warning variants below. `## Touched by` counts as present when the header is there — consolidation owns its body, so an empty one is not a finding. |
| `empty section(s)` | sections-present | Section header present but body has no non-blank content. Error in `04_domain`; warning elsewhere. |
| `body contains TODO marker` / `FIXME` / `XXX` / `HACK` | no-todos | Outstanding-work marker in body. Move to `inspire_kb/99_tracker/tickets/`. |
| `the entity document's '## Fields' table does not declare it` | action-fields-in-entity | Action touches a field the entity doc has not declared. |
| `no entity document found at expected path` | action-fields-in-entity | Action touches an entity id but no `{module}.{entity}.md` exists. |
| `field-conflict` | entity-coherence | Same field on same entity declared with differing types across actions. |
| `field-unsourced` | entity-coherence | Field has at least one `Touch=read` declaration but no `Touch=written` declaration. |
| `requires target not found` | stable-blockers | A `requires` entry points to an id not present in the SDD tree. |
| `stable action requires X which is at lifecycle: Y` | stable-blockers | A stable action lists a non-stable target in `requires`. |
| `stable action touches entity X which is at lifecycle: Y` | touched-entity-lifecycle | A stable action touches an entity below `accepted`. |

### Lifecycle-progressive (draft → warning, accepted / stable → error, superseded → warning)

| Type | Rule | Meaning |
|---|---|---|
| `OS-A10: {kind} section order` (action descriptors; entity documents keep the unprefixed form) | sections-present | The known `## Section` headers of an action descriptor or entity document appear in a different relative order than its format spec fixes. Extra and optional sections skip cleanly — only the canonical ones are ordered. `04_domain` only. |
| `field-uncovered` | field-coverage | Entity Fields row declared but no action touches the field. |
| `has no wikilink in '## Rationale'` / `## Purpose` or `## Behavior` | rationale-wikilink | No back-source link in the rationale-bearing section(s). |
| `wikilink does not resolve` | wikilinks-resolve | A `[[wikilink]]` in body cannot be resolved to a file. Four resolution routes, tried in order: an SDD object id, a screen `id`, then — for a path-shaped target such as `../patterns/list` — its last segment, then a bare basename. A path is never resolved relative to the linking file: the name is what the link means, so a `../` depth that shifted with a surface split still names the right file. Screen files are checked alongside `04_domain` objects, so a dangling navigation target is reported here, and both indexes are built vault-wide whatever the scope. |
| `OS-A2` · `OS-A5` · `OS-A6` · `OS-A8` · `OS-A9` · `OS-E5` · `OS-E6` | keys-present | A keyed entry is there but wrong: a step key that is not `B{n}`, a section holding neither a declared-none body nor keyed entries, a head outside its closed vocabulary or at the wrong arity, a key used twice in one keyspace. |
| `OS-E2` · `OS-E4` · `OS-E8` | constraints-mechanics | A `Constraints:` line is wrong: no `id` row to carry the marker, a word outside vocabulary V1 or at the wrong arity (`nonnull` on an input line included), or a line that is not its H3's first content line. |
| `OS-E7` · `OS-X1` · `OS-X2` · `OS-X3` · `OS-X4` | head-referents | A name a head mentions does not exist: an unresolvable `references(...)`, a written `unique` field with no matching `unique(...)` error head, an invariant head naming a non-field, a `P`/`Q` head naming an untouched entity, `returns(...)` naming a non-output. |

### Standalone warnings

| Type | Rule | Meaning |
|---|---|---|
| `field-orphan-write` | entity-coherence | Field has at least one `Touch=written` declaration but no `Touch=read` declaration. Writing for no-one. |
| `OS-A1` · `OS-A3` · `OS-A4` · `OS-E1` · `OS-E3` | keys-present, constraints-mechanics | The keyed shape is absent rather than wrong: no `B{n}` on the first `## Behavior` step, no `## Preconditions` / `## Postconditions`, no `Constraints:` line on `id`, prose or unkeyed `## Invariants`. A **flat warning at every lifecycle in 0.8** — the shapes an upgrade inherits — ramping in the release after. The message ends `— derive refuses old-shape artifacts`. |
| `W-1` | constraints-mechanics | A constraint word still narrated in a `Notes` or `Description` **cell** after the constraint moved to a `Constraints:` line. Table cells only; per-field H3 prose is where a constraint's meaning belongs and is never scanned. A heuristic, so a flat warning forever. |
| `use-case file missing required section(s)` / `has empty section(s)` | sections-present | A `03_features/` use-case file is missing one of `## Actor` · `## Preconditions` · `## Main flow` · `## Alternative flows` · `## Error flows` · `## Postconditions` · `## Acceptance criteria`, or has one with no body. |
| `OS-F5: AC-id format` | sections-present | A top-level bullet inside `## Acceptance criteria` is not of the form `- [ ] AC-N: …`. Indented sub-bullets and wrapped continuation lines are not criteria and are not checked. |
| `AC-id duplicate` | sections-present | One `AC-N` id is used by two criteria in the same use-case file. Gaps in the numbering are never a finding: ids are stable, never renumbered and never reused. Numbers compare as written, so `AC-01` and `AC-1` are two distinct ids rather than a duplicate. |
| `ADR missing required section(s)` / `has empty section(s)` | sections-present | An `01_adr/adr-*.md` is missing one of `## Context` · `## Decision` · `## Consequences` · `## Alternatives considered` · `## Related ADRs`, or has one with no body. |
| `ADR missing required subsection` | sections-present | `### Breaking changes` is nowhere in the ADR. Presence-only: an ADR that breaks nothing still says so. |
| `ADR subsection … is present but not under …` | sections-present | `### Breaking changes` exists but sits under some other `## Section`, where it answers a different question. Distinct from the type above so the operator is told to move a heading rather than write one. |
| `pattern entry declares no '## Regions' table` | screen-coherence | A pattern entry some screen names carries no `## Regions`, so the screen-to-layout join cannot be checked at all. |
| `pattern region value outside the closed vocabulary` | screen-coherence | A `## Regions` row's `Fill` is outside `required` / `optional`, or its `Accepts` names something outside `data` · `dispatch` · `nav` · `static`. The join ignores a token it does not know, so an unrecognized `Accepts` buys the region silence rather than a check. The message names every offending value. |

The last two are reported on the **pattern** file — that is the file to change,
and an adopting screen did nothing wrong — and once per pattern however many
screens adopt it. A pattern entry carries no `lifecycle:`, so neither ramps.

### Screens (draft → warning, accepted / stable → error, superseded → warning)

Screen files carry `lifecycle:`, so their shape and coherence findings ramp with
it. A screen with no frontmatter at all reads as `draft`: warnings only.

| Type | Rule | Meaning |
|---|---|---|
| `screen file missing required part(s)` / `has empty section(s)` | sections-present | A `05_screens/` screen file is missing its H1 title, its `**Features:**` line, `## Purpose` or `## Bindings`, or carries one of those two sections with nothing under it. `**Pattern:**`, `**Components:**`, `## Module-specific deviations`, `## Current prototype` and `## Notes` are optional and never flagged. |
| `screen file carries a retired section` | sections-present | `## Instantiation` is still there. Its declarations belong in keyed `## Bindings` rows — see `inspire-screens/references/format-screen.md` § Old shape → new shape. |
| `screen missing frontmatter field` | screen-coherence | One of `id` · `module` · `screen` · `lifecycle` is absent. On a file with no frontmatter at all this is the whole old-shape story, reported once per missing field. |
| `invalid screen lifecycle value` | screen-coherence | `lifecycle:` is set but is not one of `draft / accepted / stable / superseded`. |
| `screen id shape` | screen-coherence | `id` is neither `{module}.{screen}` nor `{surface}.{module}.{screen}` for this file's own declared `module:` and `screen:`. |
| `screen module mismatch` | screen-coherence | `module:` and the module directory in the path name different modules. The module is referent, not position: one of the two is wrong. |
| `screen carries an authored route` | screen-coherence | The H1 holds a path-shaped code span. Routes derive from `module:` + `screen:`, so a written one is a second source of truth. Heuristic, and a **flat warning** at every state. |
| `screen superseded without superseded_by` / `superseded_by target does not resolve` | screen-coherence | A `superseded` screen must point at the screen id that replaced it, and that id must exist. |
| `unknown bindings subsection` | screen-coherence | An H3 under `## Bindings` outside the closed set `Data` · `Dispatches` · `Navigation` · `States`. |
| `binding row has no key` | screen-coherence | A binding table row whose first cell is empty. Every declaration is keyed. |
| `duplicate binding key` | screen-coherence | One key used twice in the same subsection. Keys are screen-local and unique per subsection; a second dispatch of the same action needs its own key. |
| `unresolved outcome` | screen-coherence | A dispatch's `On success` / `On error` is not one of `→ [[{screen-id}]]`, `state \`{key}\``, or `refresh \`{key}\`` — or names a state/data key the screen does not declare. |
| `navigation target is not a screen id` / `navigation target is route-shaped` / `navigate outcome is route-shaped` | screen-coherence | A `### Navigation` target, or a dispatch outcome that navigates, is not a wikilinked screen id — or is one shaped like a route (`[[/users/:id]]`). A screen id carries no slash, so a route in brackets satisfies the form and none of the meaning. The rule reads the FORM only; whether the id exists is `wikilinks-resolve`'s question. |
| `state not anchored` | screen-coherence | A state's `When` references no declared data key, no dispatch key and no deviation. A free-floating state has nothing to observe. The reference anchors only through backticks: `` `main` returns zero rows `` anchors, the same words unbackticked do not. |
| `pattern join` | screen-coherence | The named pattern has a required region accepting `data`, `dispatch` or `nav`, and the screen declares no binding of that kind — a `list` layout with no data binding. |
| `stable screen declares a to-extract component` | screen-coherence | Error at `stable` only, exempt elsewhere: a component still to extract is a promise, not a dependency. |

Two screen findings never ramp, because both need declared frontmatter on both
sides and neither can fire on a pre-0.8 file — they are **errors at every state**:

| Type | Rule | Meaning |
|---|---|---|
| `duplicate screen id` | screen-coherence | Two screen files declare the same `id`. Ids are unique KB-wide; the newcomer mints `{surface}.{module}.{screen}` instead. |
| `route collision` | screen-coherence | Two screens derive the same route in the same shell — same `module:` + `screen:` in one surface tree, or one of them under `shared/`. |

### Style — the mechanical subset of the writing contract

Every one of these carries the rule id `prose-style`. Each names its contract
rule, the section it was found in and the line, so the message is enough to act
on without re-running anything. R1 and R3 are heuristics and stay warnings at
every lifecycle; R2, R4, R5 and R6 ramp with the object's lifecycle in
`04_domain` and are warnings everywhere else. R1, R3, R4 and R6 read the line
with its `` `code spans` `` blanked out — a token quoted as a token is not a
claim about the system — while R2 keeps them, because a code span is still a
word the reader reads.

| Type | Rule | Meaning |
|---|---|---|
| `R1 passive voice` | prose-style | A be-verb plus a past participle, where the sentence never says who acts. Heuristic — warning always. |
| `R2 sentence cap` | prose-style | A sentence longer than 25 words. The message carries the count and the first words of the sentence. |
| `R3 noun cluster` | prose-style | Four or more stacked nouns, where a preposition would name the relationship. Heuristic — warning always. |
| `R4 glossary synonym` | prose-style | A term the glossary lists as rejected, used in prose. The message names the approved term. Silent when `00_bootstrap/glossary.md` is absent or has no data rows. |
| `R5 paragraph length` | prose-style | A paragraph of more than 6 sentences. A list is not a paragraph: each item is measured on its own. |
| `R6 historical language` | prose-style | One of the closed token list — `previously`, `used to`, `migrated from`, `~~…~~`. `used to` fires on the historical construction only: a be-verb immediately before it ("the salt **is used to** derive the key") states present behavior and is not flagged, the same reasoning that keeps `replaces` and `removed` off the list. An ADR's `### Breaking changes`, its `## Related ADRs`, a `**Status:**` line and a `Supersedes:` line are exempt — from R6 alone; those lines are ordinary prose for every other check. |

### Info

One emitter, one message. `prose-style` announces that a project is outside its
reach and stops:

| Type | Rule | Meaning |
|---|---|---|
| `prose-style mechanical checks are en-only in 0.7; the writing contract still binds as authoring judgment` | prose-style | `00_bootstrap/project.md` declares an `output_language` other than English — `en`, `en-*`/`en_*` and `english` all count as English, case-insensitively, because the field is authored by hand and takes a code or a plain name. The note is emitted once, no artifact is checked, and the run exits 0. It reports a limit of the checker, never a defect in an artifact — so it is rendered as a run note rather than as a finding with a suggested follow-up. |

## Exit codes

The shared rule library uses these exit codes:

- `0` — no errors (warnings may still have been emitted)
- `1` — one or more errors
- `127` — required tools (yq, jq) not installed
