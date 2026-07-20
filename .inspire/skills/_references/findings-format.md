# Findings format (shared reference)

Conversational skills that report SDD-layer issues — `/inspire_domain review`, `/inspire_module scan`, `/inspire_feature scan`, source/show traces — use a single rendering format so operators can read every report the same way.

## Underlying machine format

Bash rule scripts under `.claude/bin/*.sh` emit findings as **JSON Lines on stderr**, one finding per line:

```json
{"severity":"error","rule":"entity-coherence","target":"auth::user","message":"field-conflict: auth::user.id has differing types across actions: uuid/integer"}
```

Fields:

- `severity` — `error` | `warning` | `info`
- `rule` — short identifier. The quality gate (D24) emits findings under: `lifecycle-valid`, `requires-resolves`, `superseded-by-resolves`, `acyclic-deps`, `sections-present`, `no-todos`, `action-fields-in-entity`, `entity-coherence`, `stable-blockers`, `touched-entity-lifecycle`, `field-coverage`, `rationale-wikilink`, `wikilinks-resolve`.
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
| `missing required section(s)` | sections-present | One or more mandatory `## Section` headers absent from the body. |
| `empty section(s)` | sections-present | Section header present but body has no non-blank content. |
| `body contains TODO marker` / `FIXME` / `XXX` / `HACK` | no-todos | Outstanding-work marker in body. Move to `.inspire_kb/06_tracker/tickets/`. |
| `the entity document's '## Fields' table does not declare it` | action-fields-in-entity | Action touches a field the entity doc has not declared. |
| `no entity document found at expected path` | action-fields-in-entity | Action touches an entity id but no `{module}.{entity}.md` exists. |
| `field-conflict` | entity-coherence | Same field on same entity declared with differing types across actions. |
| `field-unsourced` | entity-coherence | Field has at least one `Touch=read` declaration but no `Touch=written` declaration. |
| `requires target not found` | stable-blockers | A `requires` entry points to an id not present in the SDD tree. |
| `stable action requires X which is at lifecycle: Y` | stable-blockers | A stable action lists a non-stable target in `requires`. |
| `stable action touches entity X which is at lifecycle: Y` | touched-entity-lifecycle | A stable action touches an entity below `accepted`. |

### Lifecycle-progressive (warning at draft, error at accepted+)

| Type | Rule | Meaning |
|---|---|---|
| `field-uncovered` | field-coverage | Entity Fields row declared but no action touches the field. |
| `has no wikilink in '## Rationale'` / `## Purpose` or `## Behavior` | rationale-wikilink | No back-source link in the rationale-bearing section(s). |
| `wikilink does not resolve` | wikilinks-resolve | A `[[wikilink]]` in body cannot be resolved to a file. |

### Standalone warnings

| Type | Rule | Meaning |
|---|---|---|
| `field-orphan-write` | entity-coherence | Field has at least one `Touch=written` declaration but no `Touch=read` declaration. Writing for no-one. |

### Info

Reserved. Not currently emitted by any rule.

## Exit codes

The shared rule library uses these exit codes:

- `0` — no errors (warnings may still have been emitted)
- `1` — one or more errors
- `127` — required tools (yq, jq) not installed
