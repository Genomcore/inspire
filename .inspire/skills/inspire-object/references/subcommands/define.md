# Subcommand: define

Author a new object from scratch — interview-driven first authoring. Objects are *defined* (not *created*) because the design intention precedes and matters more than the file existing on disk.

**Read the [Interview cadence](../../SKILL.md#interview-cadence) section of SKILL.md before running this.** `define` is where the cadence is load-bearing — the drift this skill exists to prevent (proposing structure before walking sections) happens here.

## Precondition

`define` requires a concrete `{module}::{entity}::{action}` id (for actions) or `{module}::{entity}` id (for entity documents). If the operator says "I want to define an action for the platform module" without naming the action, the right place is `/inspire_module scan platform` — `scan` hosts the candidate-narrowing dialogue and chains to `define` once the id is settled. `define` refuses partial ids (e.g. `define platform`) with a one-line redirect to `scan`.

## Flow

1. **Parse the object id** from the invocation. If absent, ask: "What's the object id? (e.g. `auth::user::create` for an action, `auth::user` for an entity)".
2. **Step 0 — Authoring-contexts gate.** Establish which context this interview runs in (fresh authoring / field-addition mid-flow / targeted revision) before any design question. For a bare `define <id>` this is almost always *fresh authoring*; surface it explicitly so the section walk is scoped correctly. See the Authoring contexts block in the interview catalogue.
3. **Step 1 — Load the interview catalogue.** Read `references/interview-prompts-action.md` (for an action id) or `references/interview-prompts-entity.md` (for an entity id). These are the categorical-prompt catalogues that drive the per-section walk. Do this *before* asking the first design question.
4. **Ground the object.** Read the feature row and any ADRs the feature references. Produce a short grounding digest so the operator sees what you anchored on. This is reading, not drafting — no structure proposal yet.
5. **Walk the sections one question at a time.** Use the catalogue's categorical prompts + probes, weaving the operator's own language into each question:
   - **Action**: Purpose → Inputs → Outputs → Entities (effect verb + field touches) → Behavior → requires → Errors.
   - **Entity**: Purpose → Rationale → Invariants → Fields → per-field H3.
   Capture each resolved section incrementally (see Conversation capture in SKILL.md) — write as the dialogue settles, not in a big-bang at the end.
6. **Use `AskUserQuestion`** only for genuinely closed-set choices after dialogue has narrowed them: lifecycle target (draft by default), effect verb per entity (create / read / update / delete / append / replace). Never as an opening move.
7. **On approval:** the object is written incrementally during the walk; once the operator confirms the whole shape, run the [consolidation step](../consolidation.md) (for actions that touch an entity).

## What gets written

- `.inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.{action}.md` — the descriptor (for actions)
- `.inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.md` — the entity document (for entities)
- Consolidation: the entity document's Fields + Touched by tables reconciled to include this action's field declarations (actions only)

## Hard rules that apply here

- **feature is upstream; no escape hatch.** `define` refuses an action descriptor with no feature wikilink in `## Purpose`. If the verb has no feature home, the operator runs `/inspire_feature create` first.
- **Format details** are in [`format-action.md`](../format-action.md) / [`format-entity.md`](../format-entity.md). Consult them for the on-disk shape — but the *cadence* (this file + SKILL.md) governs how you get there.
