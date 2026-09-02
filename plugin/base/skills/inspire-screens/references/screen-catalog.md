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
component; document purpose, structure (textual), variants and instances; if the
underlying prototype component doesn't exist yet, set the entry's
`**State:** to-extract` and list adopters. Prefer adding a variant to an existing
pattern over creating a new one.

**What each entry declares is not the same thing.** A pattern declares
`## Regions`: named holes, each with a `Fill` (`required` | `optional`) and an
`Accepts` (`data` · `dispatch` · `nav` · `static`) — geometry and nothing more. A
component declares `## API / Slots`: its own props, and optionally a `## States`
table keyed the way a screen's `### States` is, for the renderings every screen
instantiating it inherits. The two never mirror each other. A region called
`columns`, or any region naming the fields its content shows, is a component
prop that leaked into a layout: put it back in the component's entry, where the
screen's wiring can reach it.

## `**State:**` is the entry's lifecycle

Both kinds of entry carry one, and the vocabulary is closed:

| `**State:**` | means | to the emanation loop |
|---|---|---|
| `to-extract` | the entry is authored; no code stands behind it yet | frontier-eligible — the analogue of a domain artifact's `accepted` |
| `implemented` | the shared layout or component exists in the code | delivered — the analogue of `stable`, satisfying a screen's edge out of band |

A catalog entry carries no `lifecycle:` field and needs the same answers one
gives, so this line is where they live. Anything else — a third word, or no line
at all — states neither, and a screen declaring such an entry is not ready
(`PR-04` for a component, `PR-05` for a pattern): there is nothing to wait for
and no delivery to lean on. Both shipped starters (`list`, `detail`) ship at
`to-extract`, which is what they are in a project that has not built them.

**An entry at `to-extract` is a unit the loop emanates**, never a blocker on the
screens that name it — those wait for its wave
([`_references/emanation-plan.md`](../../_references/emanation-plan.md)). Which
is also why both shapes are read strictly at emanation: an entry with no props
table, or a layout with no regions, is a rendering the contracter would have to
invent.

Extracting a pattern out of screens that already declare bindings changes nothing
about those bindings — they are screen-owned, and the promoted layout only gains
the regions their content sits in. The screens do re-enter the emanation frontier,
because their composition changed; their unchanged claims stay covered
([`screen-lifecycle.md`](screen-lifecycle.md) § How the frontier reads it).
