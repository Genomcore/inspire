# Findings format (shared reference)

Conversational skills that report SDD-layer issues — `/inspire_domain review`, `/inspire_module scan`, `/inspire_feature scan`, source/show traces — use a single rendering format so operators can read every report the same way.

## Underlying machine format

Bash rule scripts under `.inspire/bin/*.sh` emit findings as **JSON Lines on stderr**, one finding per line:

```json
{"severity":"error","rule":"entity-coherence","target":"auth::user","message":"field-conflict: auth::user.id has differing types across actions: uuid/integer"}
```

Fields:

- `severity` — `error` | `warning` | `info`
- `rule` — short identifier. The quality gate (D24) emits findings under: `lifecycle-valid`, `requires-resolves`, `superseded-by-resolves`, `acyclic-deps`, `sections-present`, `no-todos`, `action-fields-in-entity`, `entity-coherence`, `stable-blockers`, `touched-entity-lifecycle`, `field-coverage`, `rationale-wikilink`, `wikilinks-resolve`, `prose-style`.
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
| `{kind} section order` | sections-present | The known `## Section` headers of an action descriptor or entity document appear in a different relative order than its format spec fixes. Extra and optional sections skip cleanly — only the canonical ones are ordered. `04_domain` only. |
| `field-uncovered` | field-coverage | Entity Fields row declared but no action touches the field. |
| `has no wikilink in '## Rationale'` / `## Purpose` or `## Behavior` | rationale-wikilink | No back-source link in the rationale-bearing section(s). |
| `wikilink does not resolve` | wikilinks-resolve | A `[[wikilink]]` in body cannot be resolved to a file. |

### Standalone warnings

| Type | Rule | Meaning |
|---|---|---|
| `field-orphan-write` | entity-coherence | Field has at least one `Touch=written` declaration but no `Touch=read` declaration. Writing for no-one. |
| `use-case file missing required section(s)` / `has empty section(s)` | sections-present | A `03_features/` use-case file is missing one of `## Actor` · `## Preconditions` · `## Main flow` · `## Alternative flows` · `## Error flows` · `## Postconditions` · `## Acceptance criteria`, or has one with no body. |
| `AC-id format` | sections-present | A top-level bullet inside `## Acceptance criteria` is not of the form `- [ ] AC-N: …`. Indented sub-bullets and wrapped continuation lines are not criteria and are not checked. |
| `AC-id duplicate` | sections-present | One `AC-N` id is used by two criteria in the same use-case file. Gaps in the numbering are never a finding: ids are stable, never renumbered and never reused. Numbers compare as written, so `AC-01` and `AC-1` are two distinct ids rather than a duplicate. |
| `ADR missing required section(s)` / `has empty section(s)` | sections-present | An `01_adr/adr-*.md` is missing one of `## Context` · `## Decision` · `## Consequences` · `## Alternatives considered` · `## Related ADRs`, or has one with no body. |
| `ADR missing required subsection` | sections-present | `### Breaking changes` is nowhere in the ADR. Presence-only: an ADR that breaks nothing still says so. |
| `ADR subsection … is present but not under …` | sections-present | `### Breaking changes` exists but sits under some other `## Section`, where it answers a different question. Distinct from the type above so the operator is told to move a heading rather than write one. |
| `screen file missing required part(s)` / `has empty section(s)` | sections-present | A `05_screens/` screen file is missing its H1 title, its `**Features:**` line, its `**Pattern:**` line or `## Instantiation`, or has an empty `## Instantiation`. `## Module-specific deviations`, `## Current prototype` and `## Notes` are optional and never flagged. |

### Style — the mechanical subset of the writing contract

Every one of these carries the rule id `prose-style`. Each names its contract
rule, the section it was found in and the line, so the message is enough to act
on without re-running anything. R1 and R3 are heuristics and stay warnings at
every lifecycle; R2, R4, R5 and R6 ramp with the object's lifecycle in
`04_domain` and are warnings everywhere else.

| Type | Rule | Meaning |
|---|---|---|
| `R1 passive voice` | prose-style | A be-verb plus a past participle, where the sentence never says who acts. Heuristic — warning always. |
| `R2 sentence cap` | prose-style | A sentence longer than 25 words. The message carries the count and the first words of the sentence. |
| `R3 noun cluster` | prose-style | Four or more stacked nouns, where a preposition would name the relationship. Heuristic — warning always. |
| `R4 glossary synonym` | prose-style | A term the glossary lists as rejected, used in prose. The message names the approved term. Silent when `00_bootstrap/glossary.md` is absent or has no data rows. |
| `R5 paragraph length` | prose-style | A paragraph of more than 6 sentences. A list is not a paragraph: each item is measured on its own. |
| `R6 historical language` | prose-style | One of the closed token list — `previously`, `used to`, `migrated from`, `~~…~~`. An ADR's `### Breaking changes`, its `## Related ADRs`, a `**Status:**` line and a `Supersedes:` line are exempt. |

### Info

One emitter, one message. `prose-style` announces that a project is outside its
reach and stops:

| Type | Rule | Meaning |
|---|---|---|
| `prose-style mechanical checks are en-only in 0.7; the writing contract still binds as authoring judgment` | prose-style | `00_bootstrap/project.md` declares an `output_language` other than `en`. The note is emitted once, no artifact is checked, and the run exits 0. It reports a limit of the checker, never a defect in an artifact — so it is rendered as a run note rather than as a finding with a suggested follow-up. |

## Exit codes

The shared rule library uses these exit codes:

- `0` — no errors (warnings may still have been emitted)
- `1` — one or more errors
- `127` — required tools (yq, jq) not installed
