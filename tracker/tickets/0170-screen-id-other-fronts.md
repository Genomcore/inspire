---
id: 0170-screen-id-other-fronts
title: "0170 — the Angular, iOS and Android skills do not say where a screen's route, module and face come from"
created: 2026-11-13
updated: 2026-11-13
reporter: "@irene.gonzalez"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: Mid
skills: [code]
status: Open
blocked_by: []
related_to: [B1-config-replaces-bootstrap, FB1-react-native-profile]
---

## Description

Early adopters reported F19 on the 0.17.0 upgrade: generated code took a screen's module from
`id.split('.')[0]`. Since 0.15.0 a screen id is `{face}.{slug}`, so after the Factory's remap
rewrote the id literals, that code picked the same module for every screen. Genomcore/inspire#111
fixed this in `inspire-code-react` only.

### What happens today

- `inspire-code-react` has a `## Routes` seed: a screen's route comes from its `module:` +
  `screen:` frontmatter, through one route table per face and a `routeOf('{screen id}')` helper.
  Since #111 the table also carries the module and the face (`moduleOf`, `faceOf`), and
  § Forbidden patterns forbids reading anything from a screen id's shape.
- `inspire-code-angular`, `inspire-code-ios` and `inspire-code-android` have no `## Routes`
  section and no rule about screen ids. Nothing tells an agent on these stacks where a screen's
  route, module or face comes from, so the `split('.')` from F19 is as likely there as it was in
  React. `_references/stack-skills.md` already lists `## Routes` as a seed of every UI skill.

### What this ticket asks for

- In each of the three skills, § Forbidden patterns gets the rule #111 added to React: code must
  not read anything from a screen id's shape; a screen's module, face and route come from its
  frontmatter.
- Each skill gets a `## Routes` seed in that stack's own terms: how `module:` + `screen:` becomes
  a route (Angular's router, SwiftUI navigation, Compose navigation), how the face's shell prefix
  applies, and the one place code reads a screen's route, module and face from.

### Scope

- The `ios` and `android` profiles may be removed (`B1-config-replaces-bootstrap` leaves that
  open). If they are, this ticket covers Angular only.
- A React Native profile (`FB1-react-native-profile`) should start with the React rule, not wait
  for this ticket.

## Acceptance criteria

- [ ] `inspire-code-angular` has the Forbidden patterns rule and a `## Routes` seed.
- [ ] `inspire-code-ios` and `inspire-code-android` have the same, or the ticket notes that the
      profiles were removed.
- [ ] `bash plugin/test/run.sh` passes.

## Notes

- The Factory side, for code already generated, is the Factory's `0160-remap-id-splits`.
