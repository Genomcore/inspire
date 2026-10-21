---
id: 0100-orphan-field-section
title: "0100 — a `### {field}` sub-section with no row in `## Fields` passes review"
created: 2026-10-21
updated: 2026-10-21
reporter: "@irene.gonzalez"
closed_by: "@irene.gonzalez"
closed_at: 2026-10-21
epic: follow-up
size: S
importance: Mid
skills: [domain]
status: Done
blocked_by: []
related_to: []
---

## Description

An entity document declares each field once as a row of `## Fields`, and a
constrained field carries a `### {field}` sub-section under the table whose first line
is its `Constraints:` line (`format-entity.md`). `constraints-mechanics.sh` checks
that every such sub-section is well formed. No rule checks that the sub-section names a
field the table declares.

Reproduced on 0.10.0, in a copy of a project, by adding a sub-section for a field that
exists nowhere:

```
### ghost_field
Constraints: `nonnull, unique`
```

`review.sh` reports nothing about it and exits 0. The constraints it declares bind
nothing and are never read as a field.

It also happens by deletion, which is how it was found: removing the `cancelled_by`
row from `## Fields` while leaving its `### cancelled_by` sub-section in place.
`action-fields-in-entity` reports the missing row, because an action still writes the
field; the orphaned sub-section and its `immutable` constraint are reported by no rule.
For a field no action touches, nothing is reported at all.

## Acceptance criteria

- A `### {field}` sub-section under `## Fields` whose name matches no row of the table
  is reported, naming the file and the sub-section.
- Its severity follows the rule that owns it — lifecycle-progressive or flat — and the
  choice is stated in the rule's header.
- A golden fixture pins both shapes: a sub-section for a field that exists nowhere, and
  one left behind after its row was deleted.

## Resolution

Fixed in 0.11.1 (#56). `constraints-mechanics.sh` reports `OS-E9` for every
`### {field}` sub-section under `## Fields` whose name is no row of the table. It is a
content class beside `OS-E4`–`OS-E8`: lifecycle-progressive in review, and a refusal
in derive, which runs this rule.

Every acceptance criterion holds:

- Both shapes are reported, naming the file and the sub-section.
- The severity choice is stated in the rule's header: lifecycle-progressive, for the
  reason `OS-E8` is.
- Golden fixtures pin both shapes — `entity-orphan-h3-accepted`,
  `entity-orphan-h3-draft-warns` and `entity-orphan-h3-row-deleted` in review,
  `os-e9-field-section-without-row` in derive. Each fails against the rule without
  the check.

## Notes

INSPIRE Factory implements the `OS-E*` classes in its own deriver
(`orchestrator/src/contracts/validate-domain.ts`); `OS-E9` reaches it in a factory
change.
