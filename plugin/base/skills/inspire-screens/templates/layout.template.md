---
# faces: [face-a, face-b]       # blast radius — the faces this entry serves; omit = the whole project; see `.claude/skills/_references/face-scope.md`
# bundles: [bundle-a]           # the bundles it serves, when one carries it (a lib); omit = the whole project
---

<!-- A layout is a page FRAME: where a pattern's regions sit, at what size, in what
     order, at every supported width. It owns measurements and nothing else. Which
     holes exist belongs to the pattern; what fills one belongs to the component;
     which data reaches it belongs to the screen. The face shell is a layout
     too — `shell`, with `**Pattern:** —`, framing every route of the faces it
     serves. A linked pattern that does not exist yet is created from its
     template in the same turn, at **State:** to-extract. -->
# Layout: {layout-name}

**Purpose:** {one-line description of the frame — first body line, greppable}
**State:** implemented | to-extract
**Pattern:** [{pattern-name}](../patterns/{pattern-name}.pattern.md)

{One-paragraph description of the frame and what decides its shape.}

## LAY1: Frame

1. {Element 1, top to bottom}
2. {Element 2}

## LAY2: Geometry

<!-- Every row carries a Source, and the vocabulary is closed:
       `design-system.md §…`  the design system fixes the value — cite it, never
                              restate a different number
       `design-system.tokens.json`  the Value cites a token by path in braces
       `reference`            measured from the reference design-system.md
                              § Reference names; not yet a decision
       `generated`            proposed by common sense, no reference held it;
                              nobody has confirmed it
       `undecided`            two adopters disagree, or the reference breaks here
       `as {layout}`          this row's geometry is another entry's, wholesale
     A `generated` or `undecided` row is a question for the design system. A run
     never promotes one into a decision on its own: it reports the row and asks.
     Measure a value from the rendered page (its computed box), never from a
     class name. -->

| Element | Property | Value | Source |
|---|---|---|---|
| `{element}` | {width · height · padding · gap · order · overflow} | {the value, or a token path in braces} | {design-system.md §… \| design-system.tokens.json \| reference \| generated \| undecided} |

## LAY3: Breakpoints

<!-- Per width range from design-system.md § Supported viewports: which region
     changes and how — width, columns, stacking, visibility, scroll. A row that
     holds at every range reads `every supported width`. Locate each boundary by
     sweeping the viewport width and recording where the computed layout
     changes, never by reading `md:` / `lg:` off a class. Same Source vocabulary
     as § Geometry. -->

| Range | Region | Change | Source |
|---|---|---|---|
| every supported width | {region} | {what holds} | {source} |
| {range} | {region} | {what changes, and to what} | {source} |

## LAY4: Composition

<!-- The rules that hold between elements and survive a resize: what sits in which
     cluster, what aligns with what, what a state replaces. Not a restatement of the
     tables above. -->
- {rule}

## LAY5: Variants

- **{Variant name}** — {what differs, and its own geometry rows}.

## LAY6: Adopters

<!-- Every screen sitting in this frame, by id. While **State** is `to-extract`,
     these are the screens still holding their own copy. -->
- {screen id}

<!-- A face's shell only: the data it shows and the actions it fires, in the
     screen's binding format (references/format-screen.md), store forms included.
     No ### Parameters: no route opens the shell. A shell that binds data lists
     exactly one face in `faces:`. Every other layout omits this section. -->
## LAY8: Bindings

### LAY9: Data

| Key | Action | Notes |
|---|---|---|
| `{data-key}` | store `{store-key}` | {what the shell shows} |

### LAY10: Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `{dispatch-key}` | [{module}::{entity}::{action}](../../_modules/{module}/_domain/{entity}/{entity}.{action}.action.md) | {the control} | {outcome} | {outcome} |

### LAY11: Navigation

| Key | Target | Trigger | Then |
|---|---|---|---|
| `{nav-key}` | [{face}.{slug}](../../_faces/{face}/_screens/{slug}.screen.md) | {the control} | — |

### LAY12: States

| Key | When | Presentation |
|---|---|---|
| `{state-key}` | `{data-key}` fails | {what the shell shows} |

## LAY7: Notes

<!-- Commentary a run never reads. A requirement written here reaches no persona.
     Requirements go in Frame, Geometry, Breakpoints, Composition or Variants.
     Record here, as a gap, any clipping, overflow or overlap the reference shows
     at a width, naming the width and the elements. -->
- {gap at {width}: {what breaks}}
