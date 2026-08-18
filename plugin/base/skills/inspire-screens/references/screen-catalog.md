# Screens — catalog
> Part of [inspire-screens](../SKILL.md). Read when the entry's index routes here.

## When adding a new pattern or component

New shared artifacts require evidence:

- **Pattern:** appears in ≥2 actual or planned screens.
- **Component:** appears in ≥2 pages (≥3 if trivial).

In a suite with two or more UI surfaces that evidence is also **structural** —
where the instances sit is what the promoted artifact is scoped to, and nothing
else needs to be inferred. The same screen present in two or more surface trees, or
sitting in `shared/`, is cross-surface evidence: promote with `surfaces: all`.
Evidence confined to one surface tree promotes with `surfaces: [{that-surface}]`,
and widens only when a second tree earns it. Pattern and component entries carry
the field per [`_references/surface-scope.md`](../../_references/surface-scope.md);
the catalogs holding them stay suite-wide however their entries are scoped.

Process: draft the file in `patterns/` or `components/` — copy
[`pattern-entry.md.template`](../templates/pattern-entry.md.template) for a pattern,
[`component-entry.md.template`](../templates/component-entry.md.template) for a
component; document purpose, API/slots, structure (textual), variants,
instances; if the underlying prototype component doesn't exist yet, set the
entry's `**State:** to-extract` and list adopters. Prefer adding a variant to an
existing pattern over creating a new one.
