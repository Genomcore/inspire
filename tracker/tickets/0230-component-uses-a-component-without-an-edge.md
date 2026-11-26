---
id: 0230-component-uses-a-component-without-an-edge
title: "0230 — a component cannot depend on the components it is built from"
created: 2026-11-25
updated: 2026-11-26
reporter: "@djessy.czaplicki"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: High
skills: [screens]
status: Open
blocked_by: []
related_to: [0180-component-without-props]
---

## Description

Met on the `wishlist-app` bench case (INSPIRE 0.23.0, Factory 0.25.0, 2026-11-25, run
`run-nFlgdn`). The same gap was in the project's first build (INSPIRE 0.18.0, Factory 0.19.0,
2026-11-16, `run-Z9X6tT`), where timing hid it.

### What happened

Five components are built from other components, and their specs say so in
`## CMP1: Structure`:

| Component | Uses |
|---|---|
| `item-form` | `button`, `text-field`, `select-field` |
| `item-row` | `button` |
| `empty-state` | `illustration`, `button` |
| `copy-field` | `text-field`, `button` |
| `wishlist-form` | `text-field`, `button` |

Others do too (`confirm-dialog`, `gift-row`, `select-field` on `text-field`). In both plans
each of them has `requires: []`, so the Factory may start one before the components it uses
exist. On 2026-11-16, `item-form` finished before `select-field` existed and `copy-field` before
`text-field`, and their agents improvised the missing parts. On 2026-11-25, four of these units
stopped: their agents would not build a component that belongs to another unit, and the
Factory's claim tool refused it as "neither the assigned unit, nor one of its members, nor a
unit it requires".

### Every other unit kind already declares what it needs

The derived contract records a `requires` edge for every unit kind, and the Factory orders units
by those edges. Component → component is the one relation with no edge:

| Unit | Declares that it needs | Written as |
|---|---|---|
| Action | other actions, the entities it touches | frontmatter `requires:`, its bindings |
| Entity | the entities it references, its parent when embedded | `references(…)`, `embedded_in` |
| Screen | its actions, its pattern, its layouts, its components, the shell, the store | `**Pattern:**`, `**Layout:**`, `**Components:**`, `## Bindings` |
| Pattern | the components it uses | `**Components:**` |
| Layout | its pattern | `**Pattern:**` |
| Bundle, process, store | their actions | their own sections |
| **Component** | **nothing** | — |

So a screen that shows a `button` waits for the `button`, and a pattern that holds a `filter`
waits for the `filter`. A form component that holds a `text-field` does not wait for it.

### Where A17 comes from

`_references/derived-contract.md` § `requires` says: "A component declares none — A17's rule is
that catalog entries order only by a *declared* edge between them, never by an assumed tier."
`A17` is an id from the maintainers' design notes for the screens layer, and is not defined
anywhere in this repository. The rule it names came in with the screens substrate (`1e22c0ef`,
2026-08-25):

- Before it, `inspire-screens` stacked the screens layer in four **levels**: design system,
  patterns, components, screens. The level was an assumed order: patterns were "above"
  components.
- `1e22c0ef` replaced the levels with three tiers and a **sibling middle**: patterns and
  components are siblings, and "neither depends on the other by construction". Where a pattern
  does use a shared component, "it declares it on a `**Components:**` line like any other
  dependency — an actual declared edge, never an assumed tier". The text is still in
  `inspire-screens/SKILL.md`.
- `b112f791` (2026-09-02, ED10) made components and patterns emanatable units and turned that
  line into an ordering edge, citing "A17: a pattern and a component order only by a DECLARED
  edge between them". The same commit wrote "A component declares none" in the derived
  contract.

A17 was about patterns and components: no order without a declared edge. It never ruled out
component → component. The rule asks for exactly what is missing here, a declared edge. The
format just gave a component no place to declare one, and "A component declares none" records
that omission as if it were the rule.

### What happens today

- `component.template.md` has no `**Components:**` line, and nothing in `inspire-screens` says
  how a component names the components it is built from.
- The Factory's deriver (`orchestrator/src/contracts/derive-catalog.ts`) reads
  `**Components:**` for a screen and a pattern only. A component that carries the line today is
  derived as if the line were not there, so a project cannot work around the gap by hand.

### What this ticket asks for

- **A component can depend on other components.** It declares them on a `**Components:**`
  line, the same line and the same link form as a screen and a pattern, and the derived
  contract records each one in `requires` as an ordering edge.
- `component.template.md`, `screen-catalog.md` and `inspire-screens/SKILL.md` show the line and
  say when it is required: a component that renders another component with its own catalog
  entry.
- `derived-contract.md` § `requires` replaces "A component declares none" with the component's
  `**Components:**` line, and states A17 in full, in its own words, so the rule no longer rests
  on an id this repository does not define.
- A review rule reports a component named in a component's structure and missing from its
  `**Components:**` line, so the gap is found before a run.
- A component without the line derives as today, with the same contract and fingerprints, so a
  project that has not edited its components derives as before.
- **Adding the line rebuilds nothing.** A component that is already built and gains a
  `**Components:**` line keeps the fingerprints of its claims, so the Factory does not plan it
  again.
- **The change is measured.** New edges make units wait for others, so the change is checked
  on `wishlist-app`, before and after: the depth of the component graph, the total duration of
  the run, the time each unit waits for its `requires`, and the units re-emanated after
  `/inspire:update`.

### Circular dependencies

Once components can depend on each other, two of them can depend on each other in a circle:
`comment-thread` renders `comment`, and `comment` renders `comment-thread` for its replies.
No build order exists for a circle, so it is checked twice: in INSPIRE before the run, where
the operator can fix it, and in the Factory when it plans the run.

What exists today:

- INSPIRE's `acyclic-deps.sh` (severity error) checks only the action → action `requires`
  graph. It never sees a component.
- The Factory's planner refuses every cycle among the units of a run before any unit starts
  (`PR-11`, `ready: false`), so a circle never reaches an agent. But its remedy speaks only of
  entities and actions ("drop `nonnull` from the `references(...)`… or re-point the `requires:`
  chain"), and gives a component nothing to act on.

For circles, this ticket asks for:

- **Before the run, the operator is warned.** `acyclic-deps.sh`, or a sibling rule, checks the
  component → component graph and reports each circle with every entry in it, in order
  (`comment-thread → comment → comment-thread`), and the `**Components:**` line to change. The
  report runs wherever review runs today, so the operator sees it before launching a run.
- **A circle the Factory can build on its own does not stop the run.** Two cases count as
  automatic:
  - a component that lists itself (a tree node that renders its children): the edge is
    dropped, since a component never waits for itself, and the review reports it as a warning,
    not an error;
  - a circle the planner can build as one unit, its components as the members of that unit.
    The planner already builds some units together as members of one unit (updates, datastore
    cutovers), but today it never groups a unit that is in a cycle, so this is new Factory
    work. The review reports it as a warning that names the components that will be built
    together.
- **Any other circle stops the run before it starts.** The planner refuses it with `PR-11`, the
  refusal names every component in the circle, and its remedy for components says to remove one
  `**Components:**` link of the circle, or to move the shared part into a new component that
  both use. The review reports it as an error.

### Open questions

- Is the review rule a script (component names in backticks that match a catalog entry) or a
  judgment of the workspace review? A name in backticks is not always a use: in this KB
  `button` names `page-banner` as one of its users, and `wishlist-form` sizes its panel "as
  `item-form`".
- Which circles can the planner build as one unit: any size, or up to a number of components?
  The answer decides which circles the review reports as a warning and which as an error, and
  both sides must give the same answer.
- Does `/inspire:update` add the line to existing components, or does the review rule report
  them and the operator fixes them?

## Acceptance criteria

- [ ] A fixture component with a `**Components:**` line derives with each listed component in
      `requires`, as an ordering edge.
- [ ] A fixture component that names a catalog component in its structure without listing it is
      reported by review.
- [ ] A fixture with a circle of components is reported by review before a run, with every
      entry of the circle in order.
- [ ] A component that lists itself is reported as a warning and derives with no edge to itself.
- [ ] A fixture component without the line derives with the same contract and fingerprints as
      before.
- [ ] Adding the `**Components:**` line to a component that is already built does not change the
      fingerprints of its claims.
- [ ] The PR reports, for `wishlist-app` before and after the change, the depth of the
      component graph, the total duration of the run, the time each unit waits for its
      `requires`, and the units re-emanated after `/inspire:update`.
- [ ] `derived-contract.md` states A17 in full and no longer says a component declares none.

## Notes

- Factory note: when this ships, the Factory needs matching work: its deriver reads
  `**Components:**` on a component, the planner orders the units by it, and the claim tool
  accepts the components a component requires. The same work covers the circles above: build a
  circle it can build as one unit, with its components as members; refuse any other with
  `PR-11` and a remedy written for components; and test that a run with such a circle stops
  before its first unit and names the circle. It is filed in the Factory's tracker then, and
  the Factory's support is released before or with the INSPIRE release that writes the line,
  since the released Factory would ignore it.
