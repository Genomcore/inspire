# Screens — catalog
> Part of [inspire-screens](../SKILL.md). Read when the entry's index routes here.

## When adding a new pattern, layout or component

New shared artifacts require evidence:

- **Pattern:** appears in ≥2 actual or planned screens.
- **Layout:** frames ≥2 screens, or is a face `shell`, which frames every route
  and so needs no second adopter. A screen whose frame no entry holds still gets one,
  with a single adopter: the alternative is a measurement in the screen.
- **Component:** appears in ≥2 pages (≥3 if trivial) — when the block is being
  *extracted* from screens that each hold their own copy. A component a screen
  **names** needs no evidence: its entry is written in the same turn, at
  `to-extract`, because a named component with no entry is rebuilt from the tokens
  by whoever implements it.

With two or more faces that evidence is also **structural** — the faces the
instances sit in are what the promoted entry is scoped to, and nothing else needs
to be inferred. Instances in every face promote with no `faces:` field: absent
means the whole project. Instances confined to some faces promote with
`faces: [{face}, …]`, and widen only when another face earns it. Pattern, layout
and component entries carry the field per
[`_references/face-scope.md`](../../_references/face-scope.md); the catalog stays
one, in `_design-system/`, however its entries are scoped.

**Two faces showing the same thing is the main case.** There are no shared
screens: what the faces share is the structure, so it becomes a pattern or a
layout here, and each face keeps its own screen naming it.

Process: write `{name}.pattern.md` in `_design-system/patterns/`,
`{name}.layout.md` in `_design-system/layouts/` or `{name}.component.md` in
`_design-system/components/`. The name is the entry's id, and screens link its file
(`[{name}](../../../_design-system/patterns/{name}.pattern.md)`). Copy
[`pattern.template.md`](../templates/pattern.template.md) for a pattern,
[`layout.template.md`](../templates/layout.template.md) for a layout,
[`component.template.md`](../templates/component.template.md) for a
component; document purpose, structure (textual), variants and instances; measure a
layout's geometry and breakpoints from the reference
([`_references/ui-reference.md`](../../_references/ui-reference.md)); if the
underlying prototype component doesn't exist yet, set the entry's
`**State:** to-extract` and list adopters. Prefer adding a variant to an existing
pattern over creating a new one.

**A link creates its entry.** Whenever a screen, a layout or a pattern links a
pattern, layout or component no `*.pattern.md`, `*.layout.md` or `*.component.md`
declares, the entry is created in the same turn from its template at
`**State:** to-extract`. A missing target is then always a broken link, never a
concept nobody wrote down.

**What each entry declares is not the same thing.** A pattern declares
`## Regions`: named holes, each with a `Fill` (`required` | `optional`) and an
`Accepts` (`data` · `dispatch` · `nav` · `static`) — which holes exist and nothing
more. A component declares `## API / Slots`: its own props, and optionally a
`## States` table keyed the way a screen's `### States` is, for the renderings every
screen instantiating it inherits; a state reached by hover names its touch
equivalent there. A layout declares `## Geometry` and `## Breakpoints`: one row per
element and per range, each carrying a `Source`. The three never mirror each other.
A region called `columns`, or any region naming the fields its content shows, is a
component prop that leaked into a pattern: put it back in the component's entry,
where the screen's wiring can reach it. A pixel value in a `## Regions` table is a
measurement that leaked the same way: it belongs to the layout.

## `**State:**` is the entry's lifecycle

All three kinds of entry carry one, and the vocabulary is closed:

| `**State:**` | means | the `lifecycle:` it stands in for |
|---|---|---|
| `to-extract` | the entry is authored; no code stands behind it yet | `accepted` |
| `implemented` | the shared pattern, layout or component exists in the code | `stable` |

A catalog entry carries no `lifecycle:` field and needs the same answers one
gives, so this line is where they live. The vocabulary is closed: anything else
— a third word, or no line at all — states neither, so nothing can place the
entry. Both shipped starters (`list`, `detail`) ship at `to-extract`, which is
what they are in a project that has not built them. A layout is `implemented` only
when no row of its `## Geometry` or `## Breakpoints` table is still sourced
`generated` or `undecided`: a frame nobody decided is not a frame the code stands
behind.

**A pattern, layout or component entry at `to-extract` is a unit INSPIRE
Factory emanates**, never a blocker on the screens that name it — the shell
included, which every screen waits for. Its deriver reads these shapes strictly:
an entry with no props table, a pattern with no regions or a layout with no
geometry is a rendering the unit's agent would have to invent.

Extracting a pattern out of screens that already declare bindings changes nothing
about those bindings — they are screen-owned, and the promoted layout only gains
the regions their content sits in. The screens do re-enter the emanation frontier,
because their composition changed; their unchanged claims stay covered
([`screen-lifecycle.md`](screen-lifecycle.md) § How the frontier reads it).
