---
name: inspire-prototype
description: "Build and evolve the horizontal prototype at /prototype — the interactive, mock-data, whole-system visual model — from the specs, so the user can SEE the product and steer functional + UI/UX criteria. Its insights co-evolve the vault live (features, screens, component specs, ADRs). Use to scaffold or iterate the visual prototype. Vertical spikes (external repos) live in /inspire_spike."
---

# /inspire_prototype — The horizontal prototype (discovery)

The horizontal prototype is a **wide, shallow, mock-data model of the whole
product** — "Figma with data", not the production app. Its job is to make the
system **legible end to end so the user can see it and steer** the functional and
UI/UX criteria, fast and interactively. It answers *"is this the right thing to
build?"* — the code is throwaway; the **clarity is the deliverable**, and that
clarity lands in the vault.

> **Agile on purpose.** No tests, no auth, no persistence, minimal controls — only
> what's needed to *learn*. Rigor (tests, error handling, robustness) is reserved
> for real implementation in [`/inspire_code`](../inspire-code/SKILL.md). Building
> the mock, borrow the UI conventions of the codification stage — the
> **design system** ([`/inspire_bootstrap design-system`](../inspire-bootstrap/SKILL.md))
> and the UI **stack profile** (`/inspire_code`'s `react` etc.) — but in sketch mode.
>
> **Vertical spikes are a different skill.** Deep, functional, throwaway builds in
> their own external repos answering *"can we build it as we think?"* →
> [`/inspire_spike`](../inspire-spike/SKILL.md).

## Building the prototype

Build it **pattern-driven from the KB**. Before writing code, read the layers that
describe the screen:

1. **Screen spec** — `.inspire_kb/05_screens/{module}/{screen}.md` — the source of
   truth for what to build (features covered, pattern, data, slots, components).
2. **Pattern** — `.inspire_kb/05_screens/patterns/{pattern}.md` — layout, slots, behavior.
3. **Components** — `.inspire_kb/05_screens/components/{component}.md` — the shared
   catalog. Adopt these; don't reinvent.
4. **Design system** — `.inspire_kb/05_screens/design-system.md` — tokens, type,
   density. Never redefine these per screen.
5. **Intent & contract** — the feature in `.inspire_kb/03_features/{module}/…`
   and, where relevant, the specs in `.inspire_kb/04_domain/…`.

> **Stack-agnostic.** This skill assumes no framework. The project's own stack,
> component catalog, conventions and known pitfalls live in its KB
> (`.inspire_kb/00_bootstrap` and `.inspire_kb/05_screens`), not here — read those
> first on a real project.

## The learnings loop — insights co-evolve the vault, live

This is the heart of the skill. As you build and the **user reacts** ("that's not
the flow", "this needs a filter", "these two screens should merge"), the insight is
**applied to the vault in the same session**, through the owning skill — the
prototype is a discovery surface for the spec, not a place learnings pile up:

- New/changed behavior or use case → [`/inspire_feature create|update`](../inspire-feature/SKILL.md).
- New/changed screen, or a UI block worth sharing → [`/inspire_screens`](../inspire-screens/SKILL.md)
  (screen spec, pattern, or component spec).
- A behavioral contract the flow implies → [`/inspire_domain define|update`](../inspire-domain/SKILL.md).
- An architectural decision the exploration forces → [`/inspire_adr create`](../inspire-adr/SKILL.md).

The horizontal prototype keeps **no learnings file of its own** — everything it
teaches lands in the vault through the owning skill (above). Insight that is
cross-cutting rather than one feature/screen has a higher-level home: a **decision**
→ an ADR (`/inspire_adr`, module-scoped or cross-cutting by slug); a **system-wide
design pattern** → the design system (`/inspire_bootstrap design-system`); a **stack
pitfall** → `00_bootstrap`; **future work** → a task (`/inspire_task`); a question the
horizontal **can't resolve** → a spike (`/inspire_spike`). Nothing accumulates in a
`03_*` file for the horizontal — a running learnings log would fight INSPIRE's
"present state, not history" rule anyway.

**Surface, don't silently edit.** Propose each vault change to the user before
writing shared artifacts (components, ADRs, design tokens); let the interactive
loop stay the user's.

## Rules

> **Output language.** Write every artifact you produce — vault edits, prototype
> learnings — in the project's declared `output_language` (default English), per
> [`_references/output-language.md`](../_references/output-language.md). Machine-read
> tokens (frontmatter keys/values, wikilink slugs, filenames) stay verbatim.

1. **Specs are the source of truth.** Build what the screen spec says — no extra
   screens, tabs, or features "for completeness". If something's missing, evolve the
   spec (via the owning skill), don't invent scope in the prototype.
2. **Adopt, don't reinvent.** Before writing new UI, check the component catalog
   (`05_screens/components`) and existing prototype code for something canonical.
3. **Mocked, not real.** The prototype *visualizes* decisions; it does not implement
   backends, auth, persistence, or tests. That's `/inspire_code`.
4. **Verify by running, not just building.** A green build is not a working screen —
   runtime issues (bad data coercion, render loops, null derefs) often render a
   blank page a build won't catch. Launch the prototype and drive the affected flow
   before calling it done (use the `run` / `verify` skills).
5. **Learnings land live in the vault, in no file of their own.** The deliverable is
   co-evolved artifacts (feature/screen/domain/ADR/design-system/task); the
   horizontal prototype keeps no learnings log — see the learnings loop above.
6. **Propagation is bilateral.** A prototype change that alters behavior/structure
   the screen spec describes must reach the spec (`/inspire_screens`), and vice
   versa. Ask before ending the turn.
7. **Consult the task tracker** ([`/inspire_task list`](../inspire-task/SKILL.md))
   for tracked prototype drift; don't re-surface it as new.

## Verify checklist

- Every horizontal screen traces to a screen spec (or declares "not implemented yet").
- No reinvented UI that duplicates the shared component catalog.
- The affected route **runs**, not just builds.
- Every insight the session surfaced landed in a real vault artifact
  (feature/screen/component/ADR/design-system/task).

## Related skills

- `/inspire_screens` · `/inspire_domain` · `/inspire_feature` · `/inspire_adr` — the
  spec skills the learnings loop co-evolves.
- `/inspire_spike` — vertical spikes (external functional prototypes).
- `/inspire_code` — the real implementation, once the prototype has clarified the thing.
- `run` / `verify` — launch and exercise the prototype end to end.
