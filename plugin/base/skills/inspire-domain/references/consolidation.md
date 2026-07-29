# Consolidation step

After any subcommand that changes a descriptor (`define`, `update`, `refactor`, `delete`, `promote` to stable or superseded, `demote` across the stable↔accepted boundary), the agent reconciles the affected entity document. The entity document is itself an authored object — consolidation does **not** rewrite it from scratch. It rebuilds only the two derived sections (`## Fields` and `## Touched by`) by joining every action descriptor in `{module}/{entity}/` and re-projecting the field-touch and action-touch data. The operator-authored sections (`## Purpose`, `## Rationale`, `## Invariants`, and any per-field `### {field-name}` H3 sub-sections) are preserved untouched.

## What consolidation updates

- `.inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.md` — surgical rewrite of the `## Fields` table (one row per field, deduped across actions, types reconciled) and the `## Touched by` table (one row per action touching this entity, with the touch verb and a short note). Other sections are left exactly as the operator wrote them.

## Discussion-forcing field additions

When a descriptor change introduces a field that does not yet appear in the entity document's `## Fields` table, the agent does not silently append the row. Instead it pauses and surfaces the rationale question to the operator:

> "This descriptor adds `signup_ip` to `auth::user`. What's the rationale? — I'll fold it into `## Rationale` before adding the field row."

The new row lands in `## Fields` only after `## Rationale` has been updated. This is the **discussion-forcing discipline** at work — entities stay design-discipline artefacts rather than accumulating residue.

## Show-then-approve gate

Consolidation goes through show-then-approve — the agent shows the diff (the rationale update + the new Fields/Touched-by rows) and asks the operator to confirm before writing. Only one entity document is reconciled per action change, so the gate is a single decision.

## When consolidation runs

| Trigger | Runs consolidation? |
|---|---|
| `define` writes a new action | yes |
| `define` writes a new entity | no — there's nothing to reconcile yet |
| `update` writes changes to an action's `## Entities` | yes |
| `update` writes changes that don't touch `## Entities` | no |
| `refactor` (rename / split / merge) | yes — affected entities |
| `delete` action | yes — removes the action's Touched-by row + reconciles Fields |
| `promote` action to `stable` or `superseded` | yes — Touched-by tracks lifecycle |
| `promote` action to `accepted` | no |
| `demote` across `stable ↔ accepted` boundary | yes |
| `demote` `accepted → draft` | no |
| `promote` / `demote` entity | no — entity changes don't reshape derived tables |
