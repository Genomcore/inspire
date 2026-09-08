---
id: F13-viz
title: "F13 VIZ — deliverables in the project's own identity"
created: 2026-08-13
updated: 2026-08-19
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: Mid
skills: [bootstrap, workspace]
status: Open
blocked_by: []
related_to: [F12-guide]
---

## Description

Theme: **identity.** The deliverables workflow — markdown source + designed HTML render
sharing one slug — generalized into the runtime. A re-derivation of the operator's
personal `gc-deliverables` skill, not a port: the generic runtime ships no house style, so
the visual identity derives from the governed project's own `design-system.md` token
roles, which are contractually stable for exactly this kind of downstream consumer.
Output root lives outside the vault (non-md is banned from `inspire_kb/`); the standing
reports — workspace review, trust signals — become one-command renders. First ticket is
D8: generic skill in `plugin/base/` vs a documented org-skill pattern outside the
template.

## Acceptance criteria

- [ ] D8 decided; if in-base, the skill contains zero house-specific style.
- [ ] Renders derive palette/type from design-system token roles, with a neutral
      fallback before bootstrap has run.
- [ ] Workspace review and trust report render on demand; outputs land outside
      `inspire_kb/`.

## Notes

Free lane, rider-sized. New skill: touches the manifest and the hardcoded-count test —
the same fixed cost [[F12-guide]] pays; see that ticket for why the two are scheduled
together but not merged. Bundles VIZ-01..04.
