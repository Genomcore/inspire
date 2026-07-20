# Interview prompts — action descriptor

A **categorical prompt catalogue** for the action-descriptor socratic interview. The skill loads this file at the start of any `create` / `update` subcommand and uses it as the backbone of the dialogue: one categorical question per section, then 1–3 design-probing follow-ups when the operator's answer surfaces an implicit decision.

These prompts are **not verbatim scripts**. The skill never reads them out as-is. Claude generates *specific* probes from these categorical templates during a real interview, weaving the operator's own language (action id, entity names, feature anchors) into the question. The catalogue's role is to guarantee no section is skipped and every section gets at least one design-forcing pass.

Section structure here mirrors the action descriptor format defined in [`../SKILL.md`](../SKILL.md) under *Action descriptor format*. If sections are added or renamed there, update this catalogue.

The interview cadence is **one question at a time**. Never present a numbered decision tree or a "before drafting we must resolve X, Y, Z" wall. When two probes are both relevant, pick the one that blocks progress and defer the other. `AskUserQuestion` is reserved for closed-set choices that natural dialogue has already narrowed (typically: lifecycle target, effect verb per entity).

## Purpose prompts

### Categorical
Ask what the action accomplishes in one sentence, and which feature / ADR grounds it. The answer becomes the body of `## Purpose` plus the wikilinks woven into its prose.

### Probes
- **Boundary probe.** "Could this be a parameter of an existing action on the same entity, or is the verb load-bearing?" Use when the proposed verb is close in shape to an existing one (e.g. `update-status` vs. `update`).
- **Necessity probe.** "Is this an admin-side action, a public-facing one, or both? If both, do the caller threat models differ enough that two descriptors are warranted?" Use whenever the operator's framing hints at multiple callers.
- **feature-grounding probe.** "Which feature anchors this — the user-management subsystem, the identity model, something else? Prosaic back-source goes into the Purpose sentence, so I need the link to weave in."

## Inputs prompts

### Categorical
Ask what the caller provides and which inputs are required vs. defaultable vs. validated where. The answer becomes the `## Inputs` 4-column table.

### Probes
- **Necessity probe.** "Is `<input>` required, defaultable, or validated where?" Use for every input where the answer isn't obvious from the action's purpose.
- **Type probe.** "You said `email` — that maps to the canonical semantic type, validation rules sourced from the feature email-validation section. Is that the type, or is this a free-form string with action-local rules?" Use to surface where validation lives (here vs. feature vs. entity invariant).
- **Implication probe.** "If the caller passes `<input>` with `<edge-case-value>`, should the action accept it, reject it, or normalize it?" Use when an input has a non-trivial value space (empty strings, whitespace, mixed case, unicode).

## Outputs prompts

### Categorical
Ask what the caller gets back, and which of the three output patterns applies: whole entity (or array), subset of an entity, or derived / multi-entity shape. The answer determines whether `## Outputs` is a one-line reference, a subset table, or a derived table.

### Probes
- **Pattern probe.** "Are you returning the whole `<entity>` row, a subset, or a derived shape that joins multiple entities? Each pattern has a different rendering — I want to use the right one." Always ask when outputs aren't trivially a scalar id.
- **Drift probe.** "If we inline the full entity shape here, every field change on the entity doc forces a descriptor edit. Want a 1-line reference (`An array of [[module.entity|module::entity]] entities.`) instead?" Use whenever the operator proposes inlining a full whole-entity table.
- **Field-coverage probe.** "Output field `<field>` — is it declared on the entity doc? If not, is it derived (computed here) or should it be added to the entity Fields table?" Use whenever an output field name doesn't match an obvious entity field.

## Entities prompts

### Categorical
Ask which entities the action touches and how — for each: the effect verb (`create` / `read` / `update` / `delete` / `append`) and which fields are read or written. The answer becomes the `## Entities` sub-sections and their field-touch tables.

### Probes
- **Multi-entity probe.** "Does the action touch more than one entity? Audit events, lookup tables, allow-lists are easy to miss — anything outside the headline entity?" Always ask; orchestrators routinely touch 3+ entities.
- **Effect-verb probe.** "Effect on `<entity>` — is it `update` (mutates an existing row) or `append` (adds to a collection-shaped entity like an audit log)? They look similar but the field-touch semantics differ." Use whenever the entity is collection-shaped or append-only.
- **Field-declaration probe.** "You said the action writes `<field>` to `<entity>`. Is `<field>` already declared on the entity doc? If not, we need to update `## Rationale` there before the field lands in `## Fields` — that's the discussion-forcing discipline." Always ask when a write touches a field not visible in the current entity doc.
- **Mapping probe.** "Mapping for `<field>`: `input.<x>`, `uuid()`, `now()`, `current_user`, derived expression? The Mapping column has to read unambiguously to a downstream implementer." Use for every written field.

## Behavior prompts

### Categorical
Ask for the step-by-step description, in order, with the feature/ADR back-source for each non-obvious claim. The answer becomes the numbered `## Behavior` list, with wikilinks woven prosaically into each step.

### Probes
- **Sourcing probe.** "Step `<N>` references `<concept>` (validation rules / hashing algorithm / audit emission). Which feature or ADR grounds it? The wikilink weaves into the sentence." Ask for every step that makes a sourceable claim — back-sourcing is not optional.
- **Implicit-side-effect probe.** "Anything implicit in this step — audit emission, event bus publish, cache invalidation, a downstream notification? If yes, it should either be a separate Entity touch in the table above or explicitly out-of-scope here (with the wrapper action linked)." Use whenever a step ends without naming its side-effects.
- **Error-correspondence probe.** "Step `<N>` mentions `<failure condition>`. Does that correspond to a row in `## Errors`, or is it a precondition the caller is expected to handle?" Use when a step describes a failure mode without a paired error code.
- **Conflict-mechanism probe.** "Step `<N>` says the action inserts a row with a unique constraint on `<field>`. Is the DB constraint the conflict-detection mechanism (fall through to error), or is there an explicit pre-check?" Use for any step involving uniqueness or referential integrity.

## Errors prompts

### Categorical
Ask which error codes the action emits and the operator-facing message for each. The answer becomes the `## Errors` bullet list.

### Probes
- **Coverage probe.** "Listed errors: `<list>`. Does this cover every failure path described in `## Behavior`? Walk back through the steps — any branch missing its error?" Always ask after errors are drafted.
- **Code-naming probe.** "Error code `<code>` — does it match conventions used elsewhere in this module (snake_case, verb-noun, etc.)? Consistency matters at review time." Use when the proposed code shape diverges from neighboring actions.
- **Message-tone probe.** "Operator-facing message for `<code>` — is it actionable (tells the operator what to do) or just descriptive? UI consumers surface this string verbatim." Use for any message that reads as pure description.
- **Cross-section probe.** "Error `<code>` fires when `<field>` violates `<constraint>`. Is that constraint declared on the entity doc's `## Invariants`, or is it action-local validation? If invariant, the message should align with the invariant's wording." Use whenever an error guards an entity-level invariant.

## Action verb taxonomy

Cross-module convention — **source of truth is [[adr-plt-action-verb-conventions]]**. The interview must land the verb *before* shaping the descriptor; the choice is not free-form.

**Reads.**
- **Collection** (returns many) → **plural** verb (`list`, `versions`, `executions`), **always paginated**: `limit` (default 50, cap 200) + opaque `cursor` → a page + `next_cursor`. Sub-collections use verbs scoped to the *root* entity (`function::versions`), never a sub-entity `::list` in the catalog.
- **Item** (returns one) → **singular** verb (`get`, `version`).
- Per-field touch: `read-whole` (whole entity → enumerate only keys/filters) vs `read` (subset → enumerate surfaced fields). `list` is **not** a per-field touch (only a `## Touched by` value in the entity doc).

**Mutations — split by nature, never a catch-all `update`:**
`create` · `edit` (in-place metadata patch) · `deploy` (mint an immutable version) · `move` (re-parent across namespace/OU — grant on **both** OUs) · `rollback` (forward-create restore, never reactivate) · `enable`/`disable` (activation — a dedicated verb pair, **not** an `edit` field) · `delete`.

### Probes
- **Verb-fit probe.** When the operator proposes a mutation, ask which taxon it *is*. If they say "update," push: metadata (`edit`), a new version (`deploy`), a re-parent (`move`), or activation (`enable`/`disable`)? A single verb spanning two of these is the anti-pattern this taxonomy exists to prevent.
- **Collection/item probe.** "Returns many or one? Many → plural verb + pagination; one → singular verb + the item's key." Always ask for a read.
- **Cross-cutting probe.** Mutations emit `{entity}.{verb-past}` to the Event Bus (Audit subscribes — no direct audit writes); mutable entities carry `created_at` + `updated_at`; OU is derived via namespace/parent (`move` is the only re-attachment).
