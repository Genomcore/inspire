---
name: inspire-prototype
description: "Build and maintain the horizontal prototype at /prototype from the specs, and capture prototype knowledge into the KB: horizontal learnings plus links to external vertical-spike repos with their learnings imported. Use when scaffolding or evolving the horizontal prototype, recording what a prototype taught you, or registering a vertical spike."
---

# /inspire_prototype — Prototypes as knowledge

Prototypes exist to **create clarity**, not production code. The code is often
throwaway; the **learnings are the deliverable**. This skill builds the
horizontal prototype and makes sure every prototype's knowledge lands durably in
[`.inspire_kb/03_prototypes/`](../../.inspire_kb/03_prototypes) — decoupled from
the code that produced it.

## The model — two shapes, two locations

| Shape | Question | Code lives in | Knowledge captured in |
|-------|----------|---------------|-----------------------|
| **Horizontal** — wide, shallow, mocked model of the *whole* product | "Is this the right thing to build?" | [`/prototype`](../../prototype) (repo root, one per project) | `03_prototypes/horizontal.md` |
| **Verticals** — narrow, deep, functional spikes | "Can we build it the way we think?" | their **own external repos** (one per spike) | `03_prototypes/verticals/{name}.md` (repo link + imported learnings) |

The KB stores **knowledge, not code**: the horizontal's learnings are mirrored
in; the verticals are linked and their learnings brought home so they survive
even after the spike repo goes stale.

## When to use

- Scaffold or extend the **horizontal prototype** at `/prototype` from the specs.
- Capture learnings from the horizontal prototype into `horizontal.md`.
- Register a new **vertical spike** (external repo) and import its learnings.
- Refresh a vertical's learnings, or mark it archived.
- Resolve screen spec drift the prototype surfaced.

## Building the horizontal prototype

The horizontal prototype is an **interactive mockup, not the production app** —
mocked data, no real backend, closer to "Figma with data". Its job is to make the
whole product legible end to end so you can judge whether it's the right thing.

Build it **pattern-driven from the KB**. Before writing code, read the layers
that describe the screen:

1. **screen spec screen** — `.inspire_kb/05_screens/{module}/{screen}.md` — the source of
   truth for what to build (features covered, pattern, data, slots, components).
2. **Pattern** — `.inspire_kb/05_screens/patterns/{pattern}.md` — layout, slots, behavior.
3. **Components** — `.inspire_kb/05_screens/components/{component}.md` — the shared
   catalog. Adopt these; don't reinvent.
4. **Design system** — `.inspire_kb/05_screens/design-system.md` — tokens, type,
   density. Never redefine these per screen.
5. **Intent & contract** — the feature in `.inspire_kb/02_features/{module}/…`
   and, where relevant, the specs in `.inspire_kb/04_domain/…`.

> **Stack-agnostic.** This skill does not assume a framework. The project's own
> stack, component catalog, conventions and known pitfalls live in its KB
> (`.inspire_kb/00_bootstrap` and `.inspire_kb/05_screens`), not here. Read those
> first on a real project.

## Rules

1. **Specs are the source of truth.** Build what the screen spec says — no extra
   screens, tabs, or features "for completeness". If something's missing, fix the
   spec first (via `/inspire_screens`), don't invent scope in the prototype.
2. **Adopt, don't reinvent.** Before writing new UI, check the component catalog
   (`05_screens/components`) and existing prototype code for something canonical.
3. **Mocked, not real.** The horizontal prototype *visualizes* decisions; it does
   not implement backends, auth, or persistence beyond what's needed to learn.
4. **Verify by running, not just building.** A green build is not a working
   screen — runtime issues (bad data coercion, render loops, null derefs) show up
   only when you exercise the route, and often render a blank page a build won't
   catch. Launch the prototype and drive the affected flow before calling it done
   (use the `run` / `verify` skills).
5. **Capture the learning.** Learnings are the deliverable — see below.
6. **Propagation check.** If a prototype change alters behavior or structure the
   screen spec describes, ask the user whether to propagate it back via `/inspire_screens`.
   This is bilateral: a change to one layer must reach the layer it affects.

## Capturing learnings (the deliverable)

The point of a prototype is what it teaches. After a meaningful build or fix:

- **Horizontal** → add an entry to `.inspire_kb/03_prototypes/horizontal.md`:
  one insight per line, and **link the artifacts it affects**
  (`02_features/…`, `04_domain/…`, `05_screens/…`).
- **Vertical** → in that spike's `verticals/{name}.md`, write the learning so it
  **stands on its own** — useful even if the external repo later disappears.
- **Recurring class of problem.** If a fix reveals something that will recur (a
  stack quirk, a reusable helper, a canonical component), record it where it
  belongs — project stack pitfalls in `00_bootstrap`, reusable UI in
  `05_screens/components` via `/inspire_screens`. **Surface the proposal to the user; don't
  silently edit shared artifacts**, and don't let the insight evaporate.

## Registering a vertical spike

1. Copy `.inspire_kb/03_prototypes/verticals/_template.md` → `{name}.md`
   (kebab-case).
2. Fill in the **repo link**, the question, the scope, and the features it covers.
3. **Import the learnings** — write them to stand on their own.
4. Add a one-line entry to the `verticals/README.md` index.
5. Record the **outcome**: promote to a spec, feed the horizontal prototype, park
   it, or mark it archived (keep the learnings either way).

## Verify checklist

- Every horizontal screen traces to a screen spec (or declares "not implemented yet").
- No reinvented UI that duplicates the shared component catalog.
- The affected route **runs**, not just builds.
- Learnings are captured for anything the prototype clarified.
- Every vertical entry has a live repo link (or an archived note) **and** its
  imported learnings.

## Related skills

- `/inspire_screens` — the screen specs, patterns and components the horizontal builds from.
- `/inspire_object` — the specs (`04_domain`) behind the screens.
- `/inspire_feature` / `/inspire_module review` — feature coverage and module
  consistency before a PR.
- `run` / `verify` — launch and exercise the prototype end to end.
