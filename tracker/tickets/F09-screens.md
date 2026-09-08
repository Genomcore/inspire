---
id: F09-screens
title: "F9 SCREENS — the UI layer catches up with the domain layer"
created: 2026-08-13
updated: 2026-08-25
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: Mid
skills: [screens, module, feature]
status: Open
blocked_by: []
related_to: [F10-flows]
---

## Description

Theme: **parity.** The screen layer carries as much judgment as the domain layer on a
tenth of the elaboration (1 file / 337 lines vs 25 files / 1,373). Ship the bounded
extensions that need no new design decision: a specified route-map format (today assumed
by two skills, defined by none); validated screen-transition targets so orphan screens
become detectable; a UX-state vocabulary (empty / loading / error / permission-denied);
an actor/visibility axis on the screen template.

## Acceptance criteria

- [ ] Route map has a format, a starter and a check.
- [ ] A transition target that resolves to no screen is a finding.
- [ ] Screen template carries UX states and actor/visibility; propagation rules updated.

## Notes

Free lane. Deliberately excludes the flow-artifact question — that is F10-flows, which
these quick wins inform. Bundles FLOW-01..03.

**Amended 2026-08-25 (emanation-loop epic, per its design doc D11):** the
bounded extensions become the **first slice of the UI substrate**, landing in
the epic's screens package (T2), aligned to keyed states — with one shape
change each: the route map is **derived, never authored** (routes derive from
screen frontmatter `module:` + `screen:` by profile convention, A12 — so AC-1's
"format + starter" dissolves into the convention and its check); transition
targets become **navigation outcomes in screen-owned bindings**, targeting
screens by id, resolvable via the id index added to `wikilinks-resolve.sh`
(A14 — AC-2's orphan check survives as that resolution); the UX-state
vocabulary lands as **keyed states** with the `When`-column join-check.
