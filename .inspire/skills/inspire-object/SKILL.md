---
name: inspire-object
description: "SDD object lifecycle for both action descriptors (.inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.{action}.md) and entity documents (.inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.md). Interview-driven authoring → consolidation; after operator approval the agent reconciles the affected entity document's Fields + Touched by tables. Use for define, show, update, refactor, delete, promote, demote, review, source, graph subcommands."
argument-hint: "<subcommand> [<id>|<scope>] [args]"
user-invocable: true
---

# /inspire_object — SDD Object Lifecycle

Every file in the SDD layer is an **object**: either an **action descriptor** (`.inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.{action}.md`) or an **entity document** (`.inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.md`, one fewer dotted segment). An action descriptor is a pure behavioral contract — what an action does, what it consumes and returns, which entities it touches, what invariants it upholds. An entity document is a design-discipline artefact — *why* the entity exists as a discrete object and *what motivates* its field shape. Neither is derived from the other; "object" is the umbrella term.

This skill owns the full lifecycle of both kinds — from first interview through promotion to stable. **Authoring is an interview, not a fill-in-the-blanks.** The single most important thing this skill does is run a socratic per-section walk; the on-disk format is secondary and lives in references.

## Conversational ownership

This skill **owns its conversational frame**. While inside any `/inspire_object` subcommand:

- **Do NOT invoke `superpowers:brainstorming`** or any meta-skill that imposes its own dialogue shape. Authoring an SDD object is creative work, but it is **this skill's** creative work, and its protocol is the interview cadence below.
- **Do NOT present numbered decision trees or "must resolve before X" walls.** When you hit ambiguity (naming, type, effect), surface it as one focused question and let the operator drive.
- **Default to natural conversation.** Reach for `AskUserQuestion` (closed-set) only after dialogue has narrowed a choice to 2–4 mutually exclusive options — never as a first move.

This overrides any default "structured proposal" behavior the agent might reach for.

## Interview cadence

`define` and content-adding `update` are **interview-driven**. The cadence below is load-bearing — skipping it (jumping to a drafted structure after one question) is the exact drift this skill guards against.

**Step 0 — Authoring-contexts gate.** Before any design question, establish which context the interview runs in:

- **Fresh authoring** — the object doesn't exist yet. Walk every section.
- **Field-addition mid-flow** — an action introduced a field not yet in the entity doc. Interview *only* the entity's `## Rationale` (+ maybe a per-field H3) before the row lands.
- **Targeted revision** — `update` against named sections. Walk only those.

A bare `define <id>` is almost always fresh authoring; surface it explicitly so the walk is scoped right. Never skip this gate.

**Step 1 — Load the prompt catalogue.** Read [`references/interview-prompts-action.md`](references/interview-prompts-action.md) (action id) or [`references/interview-prompts-entity.md`](references/interview-prompts-entity.md) (entity id) *before* asking the first design question. These catalogues carry the categorical prompts + design-forcing probes per section.

**Step 2 — Ground, don't draft.** Read the feature row and any ADRs it references. Produce a short grounding digest so the operator sees your anchor. This is reading only — no structure proposal yet.

**Step 3 — Walk the sections, one question at a time.** Weave the operator's own language into each question:

- **Action**: Purpose → Inputs → Outputs → Entities (effect verb + field touches) → Behavior → `requires` → Errors.
- **Entity**: Purpose → Rationale → Invariants → Fields → per-field H3.

Capture each resolved section incrementally (see Conversation capture). Only after the operator confirms the whole shape do you run consolidation.

The full annotated example is in [`examples/define-interview.md`](examples/define-interview.md) — read it to feel the rhythm.

## Anti-patterns to avoid

- ❌ **Proposing a draft field-list / structure before walking the sections.** This is *the* drift. Walk Purpose → … one question at a time; do not emit a populated descriptor after a single probing question.
- ❌ **Discussing storage, runtime, boot mechanics, or surface bindings** (HTTP route, CLI command, MCP tool, workflow node, agent tool). These are not SDD-layer concerns — the descriptor is a pure contract; exposure and implementation live in other modules' artifacts.
- ❌ **Skipping the Authoring-contexts gate** (Step 0). Establish fresh / field-addition / targeted-revision before any design question.
- ❌ "Before drafting, we need to resolve X, Y, Z." Operators experience this as a wall. Pick the one that blocks progress, ask about it, defer the others.
- ❌ "I see three options: (1) …, (2) …, (3) …". The brainstorming reflex. Unless the operator asked for options, don't enumerate.
- ❌ Restating the operator's request in your own taxonomy. If they said "the user create action," don't reframe it as "the auth subsystem's user-provisioning verb." Use their language.
- ❌ Long preambles before a question. Ask, then explain if asked back.

## Conversation capture

The interview produces files **incrementally as the dialogue unfolds**, not in a big-bang write at the end. The operator watches the objects grow turn by turn.

- **Incremental writes during the interview.** Once a section resolves in dialogue (`## Purpose` settled, an effect verb confirmed, a field row decided), write it immediately. No "draft staging buffer." Later turns may revise prior sections in place — that's expected.
- **Cross-document capture is the agent's responsibility.** When an action interview implies an entity change (operator: "add `last_login_at` to the user row"), update **both** files in the same flow — the action's `## Entities` table gets the touch row, the entity doc's `## Fields` table gets the field row plus the rationale prompt. Do **not** ask "should I also update the entity doc?" — co-evolution is the contract.
- **Hybrid reflection volume.** Default is **quiet**: just write; the operator sees the edit in the tool-call stream and pushes back if wrong. Switch to **loud** ("capturing `X` in `Y` — sound right?") only at genuine attribution ambiguity (an invariant that could belong to either of two entities, a field that could live on `auth::user` or `auth::session`).
- **Only resolved decisions land in files.** False starts, hypotheticals, "wait, actually no" pivots stay in conversation. Recognize when the operator has *settled* (verbal confirmation, "yes do that," moving on) and only then capture.
- **In-session revisions are in-place.** Operator can revise captured content anytime ("change that purpose sentence to …"). Edit the file directly; no separate "revise mode." Commits remain operator-only — the agent never `git add` / `git commit` as a side-effect of capture.

## Scope

This skill owns: **action descriptors**, **entity documents**, **consolidation** (rebuilding the entity doc's derived `## Fields` + `## Touched by` tables after a descriptor change), and the **subcommands** below.

This skill does NOT own: **feature authoring** (`/inspire_module` — back-sourcing to feature via wikilinks is required, but the feature is not modified here); **feature-level grouping + prioritization** (`/inspire_feature`); **surface bindings** (HTTP / CLI / MCP / workflow node / agent tool — owned by their respective modules); **implementation** (storage, runtime, SQL/TypeScript shapes).

## Invocation

```
/inspire_object define   <id>              # author a new object (interview-driven)
/inspire_object show     <id>              # render an existing descriptor with resolved cross-refs
/inspire_object update   <id> [args]       # iterate on an existing descriptor (blocks on stable — demote first)
/inspire_object refactor <id> [args]       # rename / split / merge actions
/inspire_object delete   <id>              # remove an action (refuses if any other action requires it)
/inspire_object promote  <id> {accepted|stable|superseded}
/inspire_object demote   <id>              # lifecycle backwards (stable→accepted, accepted→draft)
/inspire_object review   [<scope>]         # run quality_lib checks; show findings
/inspire_object source   <id>              # show the back-source trail for every claim
/inspire_object graph    [<scope>]         # print the action→action requires graph + supersession edges
```

`<id>` is `module::entity::action` (e.g. `auth::user::create`) for actions, or `module::entity` (e.g. `auth::user`) for entities. `<scope>` is `module` or `module::entity`.

Subcommands accept **natural-language continuations** — e.g. `/inspire_object update auth::user::create add ERROR_QUOTA_EXCEEDED to errors` is parsed as "update `auth::user::create`, change: add `ERROR_QUOTA_EXCEEDED` to errors" and applied as a patch without re-asking for the id.

## Subcommands

Each subcommand's full flow lives at `references/subcommands/{name}.md`. **Before executing any subcommand, read its reference file** — the table below is an index, not the flow.

| Subcommand | What it does |
|---|---|
| [`define`](references/subcommands/define.md) | Author a new action or entity from scratch (interview-driven) |
| [`show`](references/subcommands/show.md) | Render an existing descriptor with cross-refs resolved (read-only) |
| [`update`](references/subcommands/update.md) | Iterate on an existing descriptor (blocks on stable) |
| [`refactor`](references/subcommands/refactor.md) | Rename / split / merge actions (walks consumers individually) |
| [`delete`](references/subcommands/delete.md) | Remove an action (refuses if dependents exist) |
| [`promote`](references/subcommands/promote.md) | Walk lifecycle forward (draft → accepted → stable / superseded) |
| [`demote`](references/subcommands/demote.md) | Walk lifecycle backwards (refuses with cascade preview) |
| [`review`](references/subcommands/review.md) | Read-only quality_lib check (10-rule gate) |
| [`source`](references/subcommands/source.md) | Show the back-source trail for every claim (read-only) |
| [`graph`](references/subcommands/graph.md) | Print action→action requires graph + supersession edges (read-only) |

After any descriptor change, the agent reconciles the affected entity document — see [`references/consolidation.md`](references/consolidation.md).

## Object formats

On-disk shape specs (consult when authoring; they govern the file, not the cadence):

- Action descriptor → [`references/format-action.md`](references/format-action.md)
- Entity document → [`references/format-entity.md`](references/format-entity.md)
- Externally populated entities use `population: external` — see `references/format-entity.md`.

## Rules

1. **`review`, `show`, `source`, `graph` are read-only.** They report, resolve, and visualize — never write files.
2. **`define`, `update`, `refactor`, `delete`, `promote`, `demote` require operator approval** of each proposed change before writing.
3. **Back-sourcing is not optional.** Every claim in a body requires an inline prosaic wikilink. The agent prompts for the source; it never invents a link. Enforced at `review` time.
4. **`delete` refuses dependents.** If any action lists the target in `requires:`, delete is blocked — resolve consumers first, or supersede.
5. **`update` refuses stable.** Modifying a stable object requires `demote` → `update` → `promote`. The regression is an explicit, traceable act.
6. **`demote` refuses with cascade preview.** Walking lifecycle backwards refuses if downstream consumers depend on the current state. No `--cascade` flag.
7. **Consolidation follows approval** and goes through show-then-approve. Operator-authored sections (Purpose / Rationale / Invariants / per-field H3) are preserved untouched.
8. **Consult the task tracker** at the start of multi-step subcommands (`define`, `refactor`, `delete`). Surface known items as `(tracked: TASK-{id})`. If a session surfaces friction worth capturing (operator pushback, recurring `AskUserQuestion` patterns, drift the skill didn't anticipate), offer the operator a **skill-feedback ticket** per the convention in `/inspire_workspace` (`epic: skill-feedback`, `skills: [object]`).
9. **No bypassing error findings.** Hard findings from `review.sh` block promotion. The escape hatch is a manual edit outside the skill, accountable via git author.
10. **Features are upstream of specs; no escape hatch.** Every action descriptor must back-source to a feature. No feature home → `/inspire_feature create` first. `define` refuses descriptors with no feature wikilink in `## Purpose`.

## References

- [`references/interview-prompts-action.md`](references/interview-prompts-action.md) / [`references/interview-prompts-entity.md`](references/interview-prompts-entity.md) — socratic prompt catalogues (load at interview Step 1).
- [`references/format-action.md`](references/format-action.md) / [`references/format-entity.md`](references/format-entity.md) — on-disk format specs.
- [`references/consolidation.md`](references/consolidation.md) — the entity-document reconciliation step.
- [`references/subcommands/`](references/subcommands/) — full flow per subcommand.
- [`_references/lifecycle-rules.md`](../_references/lifecycle-rules.md) — 4-state lifecycle, per-state gate table, regression + supersession rules.
- [`_references/findings-format.md`](../_references/findings-format.md) — shared finding rendering format used by `review`.
- [`examples/define-interview.md`](examples/define-interview.md) — annotated interview walkthrough.

## Related skills

- `/inspire_module` — module-level review and scaffolding. Its `scan` subcommand surfaces features↔specs candidate-action gaps and hosts candidate-narrowing dialogue before chaining to `define`.
- `/inspire_feature` — feature-level grouping. Its `scan` subcommand surfaces feature↔action linkback gaps.
