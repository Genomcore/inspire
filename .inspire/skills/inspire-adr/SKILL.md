---
name: inspire-adr
description: "ADR lifecycle for architectural decisions that span ≥2 modules: create / update / promote / supersede along a maturity ladder (design → prototyped → implemented). Use when proposing, recording, advancing, or retiring an architectural decision."
---

# /inspire_adr — Architecture Decision Records

## Scope

An **ADR** records an architectural decision that spans **≥2 modules**, stored in
[`.inspire_kb/01_adr/`](../../../.inspire_kb/01_adr). This skill owns their full
lifecycle. It does **not** run the global review — [`/inspire_workspace review`](../inspire-workspace/SKILL.md)
checks that an ADR's consequences have actually propagated; this skill authors and
advances the decisions themselves.

## The maturity ladder

ADR `Status` is a **maturity ladder**, not a binary — it declares how far the
decision has been realized, and therefore how far its consequences should have
propagated (the *propagation contract*):

- `design` — design reasoning. Reach: the whole **design workspace** — features
  (`03_features`) + screens (`05_screens`) + the **horizontal prototype**
  (`/prototype`, a *non-functional* interactive mock) + specs (`04_domain`).
  Refined **in place** on new evidence.
- `prototyped` — additionally **validated in an external functional prototype**:
  real running code in a vertical spike repo has proven the architecture works
  (record it with a `**Prototype:**` pointer to that repo). The horizontal
  prototype does **not** count. Still refined in place.
- `implemented` — additionally realized in the **product codebase**. **Immutable —
  `supersede` to change.**
- `superseded` (by [[x]]) / `rejected` — terminal.

There is no `proposed`/`accepted` state: an ADR present and not
superseded/rejected **is** the current decision at its maturity; the debate
happens in chat before authoring.

## Invocation

- `/inspire_adr create {prefix-slug}` — new ADR (defaults to `Status: design`)
- `/inspire_adr update {id}` — modify an ADR (supersede required only at `implemented`)
- `/inspire_adr promote {id} {maturity}` — advance maturity and propagate consequences
- `/inspire_adr supersede {id} {new-id}` — mark old ADR superseded and wire the wikilink

## Subcommand: create {prefix-slug}

### Conventions

- **Filename:** `adr-{module-prefix}-{slug}.md` for module-specific, or
  `adr-{slug}.md` for cross-cutting. Slug-only — no numeric prefix.
- **Slug uniqueness:** unique within a prefix; cross-cutting slugs unique
  vault-wide.
- **Location:** `.inspire_kb/01_adr/`.
- **Canonical ID:** the filename (without `.md`). The H1 is the human title.

**Rationale.** Numeric prefixes collide under parallel work (two branches grab the
same next number). Slug-only filenames are collision-free by construction
(mirroring the `TASK-{id}` convention).

### Template

```markdown
# {Title}

**Status:** design
**Modules affected:** [[module-a]], [[module-b]]
<!-- Status maturity ladder: design | prototyped | implemented | superseded by [[x]] | rejected.
     design = the design workspace (features + screen spec + horizontal prototype + specs).
     prototyped = validated in an EXTERNAL functional prototype (a vertical spike repo,
       NOT the horizontal prototype) — add: **Prototype:** `repo-or-env` — what it validated. -->

## Context
What problem or question prompted this decision.

## Decision
What we decided and why.

## Consequences
What follows — positive and negative. Include breaking changes.

### Breaking changes
- ...

## Alternatives considered
1. **{alternative}.** Why rejected.

## Related ADRs
- [[adr-xxx]] — {relation}
```

### Steps

1. **Ask** the user: short title, modules affected, context, the decision, key
   consequences, alternatives considered.
2. **Write the ADR file** at the computed path.
3. **Update `.inspire_kb/01_adr/_index.md`** — add a row to the appropriate module
   section (or Transversales for cross-cutting).
4. **Propose ADR references** in the feature files that should link to it: list
   files to edit, wait for approval.
5. Set `**Status:** design` by default. Use `promote` later to advance.

## Subcommand: update {id}

Modify an ADR in place. At `design` / `prototyped` maturity this is the **normal
path** — freely edit any section, including `Decision`; record new evidence (e.g. a
`**Prototype:**` pointer) when it drove the change.

**Only at `Status: implemented`** does a change to the `Decision` section require
`supersede` (product code depends on it — preserve the audit trail): present a
warning and offer to switch approach. `supersede` also stays available at any
maturity for a genuine reversal you want recorded as a distinct decision.

## Subcommand: promote {id} {maturity}

Advance an ADR along `design → prototyped → implemented` and propagate its
consequences to the layers the new maturity reaches.

1. Verify the ADR exists and the transition is a **forward** step. Reject skips and
   downgrades — refine the `Decision` in place with `update` instead.
2. Update `**Status:** {maturity}`. For `prototyped`, require a `**Prototype:**`
   pointer (which external repo validated it, and the evidence); for `implemented`,
   note where in the codebase it lives.
3. **Propagate / record evidence:** confirm the design workspace reflects the
   decision, then for each affected module invoke `/inspire_module review {module}`
   to detect where the ADR's consequences are not yet reflected. Surface the gaps
   as follow-up actions.

## Subcommand: supersede {id} {new-id}

Replace an ADR with a new one that changes its decision (create the new ADR first
via `create`).

1. Verify both ADRs exist (the old one at any non-terminal maturity).
2. Update the old ADR: `**Status:** superseded by [[{new-id}]]`.
3. Update the new ADR's header: `Supersedes: [[{old-id}]]`.
4. Grep `.inspire_kb/` for references to the old ADR; propose updates.
5. Update `.inspire_kb/01_adr/_index.md` (move the old entry to the superseded
   section).

## Rules

> **Output language.** Write every ADR in the project's declared `output_language`
> (default English), per
> [`_references/output-language.md`](../_references/output-language.md). Applies
> whatever language the conversation is in; machine-read tokens (frontmatter
> keys/values, wikilink slugs, filenames) stay verbatim.

1. **ADR maturity is explicit.** Advancing `design → prototyped → implemented`
   requires `promote`; `create` defaults to `design`.
2. **Only `implemented` ADRs are immutable in content.** Supersede to change their
   `Decision`; `design` / `prototyped` ADRs are refined in place with `update`.
3. **Propagate to the maturity's reach.** Design-workspace coherence (features +
   screen spec + horizontal prototype + specs) is required at every maturity;
   `prototyped` adds a pointer to an external functional prototype, `implemented` a
   codebase reference. Surface gaps within that reach.
4. **Grep references on rename/supersede.** Always scan the vault when renaming an
   ADR or changing its ID.
5. **No historical language in ADRs.** ADRs describe the decision context at the
   time it was made; don't narrate migration history.
6. **Consult the task tracker** ([`/inspire_task list`](../inspire-task/SKILL.md))
   for tracked items; don't re-open what's already ticketed.

## Related skills

- `/inspire_workspace` — the global review checks ADR-propagation alignment (that
  consequences cohere across the design workspace within each ADR's maturity reach).
- `/inspire_module` — `promote` propagates by invoking module review to surface
  where an ADR's consequences aren't yet reflected.
