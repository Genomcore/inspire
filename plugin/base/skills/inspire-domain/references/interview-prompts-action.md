# Interview prompts — action descriptor

A **categorical prompt catalogue** for the action-descriptor socratic interview. The skill loads this file at the start of any `define` / `update` subcommand and uses it as the backbone of the dialogue: one categorical question per section, then 1–3 design-probing follow-ups when the operator's answer surfaces an implicit decision.

These prompts are **not verbatim scripts**. The skill never reads them out as-is. Claude generates *specific* probes from these categorical templates during a real interview, weaving the operator's own language (action id, entity names, feature anchors) into the question. The catalogue's role is to guarantee no section is skipped and every section gets at least one design-forcing pass.

Section structure here mirrors the action descriptor format defined in [`format-action.md`](format-action.md). If sections are added or renamed there, update this catalogue.

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
Ask what the caller provides and which inputs are required vs. defaultable vs. validated where. The answer becomes the `## Inputs` 4-column table, plus a per-input `Constraints:` line for any parameter whose value space is bounded.

### Probes
- **Necessity probe.** "Is `<input>` required, defaultable, or validated where?" Use for every input where the answer isn't obvious from the action's purpose.
- **Constraints probe.** "Bounds on `<input>` — a length range, an enum, a pattern, a default, a reference into another entity? Anything you name goes on a `Constraints:` line under the table, in the closed vocabulary, where a validator can read it. Required-ness stays in the `Required` column; don't say it twice." Use for every input whose type alone does not pin the value space. When the answer is prose ("it has to look like a phone number"), push once for the machine-readable form (`pattern(/…/)`) — and accept prose in the Description if the rule genuinely resists it.
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
Ask which entities the action touches and how — for each: the effect verb (`create` / `read` / `read-whole` / `update` / `delete` / `append` / `replace`) and which fields are read or written. The answer becomes the `## Entities` sub-sections and their field-touch tables.

### Probes
- **Multi-entity probe.** "Does the action touch more than one entity? Audit events, lookup tables, allow-lists are easy to miss — anything outside the headline entity?" Always ask; orchestrators routinely touch 3+ entities.
- **Effect-verb probe.** "Effect on `<entity>` — is it `update` (mutates an existing row) or `append` (adds to a collection-shaped entity like an audit log)? They look similar but the field-touch semantics differ." Use whenever the entity is collection-shaped or append-only.
- **Field-declaration probe.** "You said the action writes `<field>` to `<entity>`. Is `<field>` already declared on the entity doc? If not, we need to update `## Rationale` there before the field lands in `## Fields` — that's the discussion-forcing discipline." Always ask when a write touches a field not visible in the current entity doc.
- **Mapping probe.** "Mapping for `<field>`: `input.<x>`, `uuid()`, `now()`, `current_user`, derived expression? The Mapping column has to read unambiguously to a downstream implementer." Use for every written field.

## Preconditions prompts

### Categorical
Ask what must already be true for the action to be allowed to run at all. The answer becomes the keyed `## Preconditions` list. `None.` is a valid body — but ask before accepting it, because a genuinely unconditional mutation is rare.

### Probes
- **Actor probe.** "Who may invoke this — any authenticated caller, an administrator, the row's own owner? That is `actor(<role>)`, and it belongs here rather than on any surface, because it is true wherever the action runs." Always ask for a mutation. A surface name surfacing in the answer ("admin console only") is the signal that this probe was the missing one.
- **Existence probe.** "Does the action assume a row already exists (`exists(<entity>)`) or that none does (`absent(<entity>)`)? A `create` almost always has an absence precondition — and that absence is usually the uniqueness constraint restated from the caller's side." Use for every action with an `As input` identification.
- **State probe.** "Is there a state the row has to be in — active, not-yet-verified, unlocked? That is `state(<entity>, <value>)`, and it should match a real declared value, not an ad-hoc word." Use whenever the entity is lifecycled.
- **Caller-vs-contract probe.** "Is that a precondition (the action refuses when it does not hold) or a validation step (the action checks it and raises an error)? Both are legitimate; the difference is whether the error is in `## Errors`." Use whenever the operator's answer would fit either section.

## Behavior prompts

### Categorical
Ask for the step-by-step description, in order, with the feature/ADR back-source for each non-obvious claim. The answer becomes the keyed, numbered `## Behavior` list, with wikilinks woven prosaically into each step. Each step carries a `Bn` key; on a revision, an existing step keeps the key it already has and a new step takes the next free number — never renumber, never reuse.

### Probes
- **Sourcing probe.** "Step `<N>` references `<concept>` (validation rules / hashing algorithm / audit emission). Which feature or ADR grounds it? The wikilink weaves into the sentence." Ask for every step that makes a sourceable claim — back-sourcing is not optional.
- **Implicit-side-effect probe.** "Anything implicit in this step — audit emission, event bus publish, cache invalidation, a downstream notification? If yes, it should either be a separate Entity touch in the table above or explicitly out-of-scope here (with the wrapper action linked)." Use whenever a step ends without naming its side-effects.
- **Error-correspondence probe.** "Step `<N>` mentions `<failure condition>`. Does that correspond to a row in `## Errors`, or is it a precondition the caller is expected to handle?" Use when a step describes a failure mode without a paired error code.
- **Conflict-mechanism probe.** "Step `<N>` says the action inserts a row with a unique constraint on `<field>`. Is the DB constraint the conflict-detection mechanism (fall through to error), or is there an explicit pre-check?" Use for any step involving uniqueness or referential integrity.

## Postconditions prompts

### Categorical
Ask what an observer can assert once the action has succeeded. The answer becomes the keyed `## Postconditions` list — and it is the section a test writer works from, so vagueness here becomes a vague test.

### Probes
- **Effect probe.** "For each entity in the table above: `created`, `updated`, `deleted`, or deliberately `unchanged`? The effect verb up there says what the action *does*; this says what an observer can *check*." Always ask; the two lists should agree, and where they disagree one of them is wrong.
- **Regression-guard probe.** "Is there an entity this action could plausibly have touched and does not? Stating `unchanged(<entity>)` turns 'we didn't mean to write that' into something a test asserts." Use for any action near a side-effect-heavy neighbour (audit, cache, notification).
- **Return probe.** "Which output fields are guaranteed populated on success? `returns(<field>)` names them; a field the caller may or may not get is a different claim and needs saying in prose." Use whenever `## Outputs` has more than one row.
- **Observability probe.** "That postcondition — how would anyone check it? If the honest answer is 'you can't', it is prose, and prose is fine: it becomes a claim a human or an agent has to write an assertion for, rather than one the schema carries for free." Use whenever a proposed head does not quite fit and the operator is reaching for one anyway.

## Errors prompts

### Categorical
Ask which error codes the action emits and the operator-facing message for each. The answer becomes the `## Errors` bullet list, each bullet optionally carrying a head naming what it reports the violation of.

### Probes
- **Constraint-correspondence probe.** "Error `<code>` — what exactly does it report the violation of? If it is a uniqueness conflict on `<field>`, the head is `unique(<field>)`; if it is a rejected caller, `actor(<role>)`. The head is what lets the entity's constraint and this error be checked against each other." Always ask for a conflict or authorization error. A written field carrying `unique` with no matching error head is a finding.
- **Coverage probe.** "Listed errors: `<list>`. Does this cover every failure path described in `## Behavior`? Walk back through the steps — any branch missing its error?" Always ask after errors are drafted.
- **Code-naming probe.** "Error code `<code>` — does it match conventions used elsewhere in this module (snake_case, verb-noun, etc.)? Consistency matters at review time." Use when the proposed code shape diverges from neighboring actions.
- **Message-tone probe.** "Operator-facing message for `<code>` — is it actionable (tells the operator what to do) or just descriptive? UI consumers surface this string verbatim." Use for any message that reads as pure description.
- **Cross-section probe.** "Error `<code>` fires when `<field>` violates `<constraint>`. Is that constraint declared on the entity doc's `## Invariants`, or is it action-local validation? If invariant, the message should align with the invariant's wording." Use whenever an error guards an entity-level invariant.

## Action verb taxonomy

The verbs are the **project's**, not INSPIRE's. They come from the application's own domain (a library reserves, cancels and picks up a book), and they stay consistent within it. INSPIRE ships only the generic rules below and a small default set.

**The project's verb record** is the ADR `inspire_kb/01_adr/adr-action-verbs.md`. Read it before landing the verb. When it exists it is the source of truth, cross-cutting rules included. When it does not, use the default set below. The interview lands the verb *before* shaping the descriptor.

**Generic rules.**
- **One target object.** The verb acts on the entity the id names (`module::entity::verb`). Other entities the action touches are effects under `## Entities`, never a second target.
- **Collection reads** (returns many) → a **plural** verb (`list`), paginated in the shape the project's wire convention declares. A sub-collection reads through a plural verb scoped to the root entity (`book::copies`), never a sub-entity `::list`.
- **Item reads** (returns one) → a **singular** verb (`get`).
- Per-field touch: `read-whole` (whole entity → enumerate only keys/filters) vs `read` (subset → enumerate surfaced fields). `list` is **not** a per-field touch (only a `## Touched by` value in the entity doc).
- **One verb per kind of change.** A change the domain names gets its own verb (`reserve`, `cancel`, `approve`), not an `edit` of a status field. A single verb spanning two kinds of change is the anti-pattern this taxonomy exists to prevent.

**Default set**, used when the project has no verb record: `list` · `get` · `create` · `edit` (in-place change of the target's own data) · `delete`.

### Probes
- **Verb-fit probe.** When the operator proposes a mutation, ask what kind of change it *is*. If they say "update", push: an in-place change of the target's own data (`edit`), or a change the domain has its own word for? A domain word becomes the verb.
- **Collection/item probe.** "Returns many or one? Many → plural verb + pagination; one → singular verb + the item's key." Always ask for a read.
- **Record probe.** When the verb is not in the project's record (or, with no record, not in the default set), ask whether it is new vocabulary. If it is, add it to `adr-action-verbs` (create the ADR through `/inspire-adr create action-verbs` if it does not exist yet) before the descriptor lands, so the next action reuses it.
- **Cross-cutting probe.** When the project's verb record attaches a rule to a kind of verb (an event every mutation emits, timestamps every mutable entity carries), confirm the descriptor honours it. With no record there is no cross-cutting rule to apply.
