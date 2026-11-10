---
id: FB1-react-native-profile
title: "FB1 — INSPIRE has no profile for React Native, the chosen mobile stack"
created: 2026-11-05
updated: 2026-11-05
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: Mid
skills: []
status: Open
blocked_by: []
related_to: [B1-config-replaces-bootstrap, B5-react-skill-from-the-team]
---

## Origin

The maintainers of INSPIRE and of the INSPIRE Factory held the first block of a follow-up review
of the Factory on 2026-11-05. The block covered how a project enters the Factory and how it is
configured. This ticket records one of its decisions that needs work in this repository. The
review's working notes are not public, so this ticket states the decision in full.

**Decision:** mobile apps are built with React Native. The web comes first, as a progressive web
app. The first step for mobile is a React Native profile in INSPIRE. iOS build infrastructure is
a second-order concern.

## Description

### What happens today

- No React Native profile or skill exists. The bootstrap stack interview says only that mobile
  "adds a mobile UI stack (e.g. React Native / Expo)".
- `inspire-code-ios` and `inspire-code-android` exist but declare no `language:`, so emanation
  refuses both (`PR-06`).
- `/inspire-config` stops on `ios` because the Factory sandbox is Linux.

### What this ticket asks for

- A `react-native` profile and an `inspire-code-react-native` stack skill with
  `language: typescript`, `bindings`, `gates:` and a testing reference.
- Its tests run on Linux. Native iOS and Android builds are out of scope.
- `/inspire-config` accepts the profile and derives its checks.

### Open questions

- Expo or bare React Native?
- How much does it share with `inspire-code-react`, which `B5-react-skill-from-the-team` is
  rewriting?
- The `ios` and `android` profiles: `B1-config-replaces-bootstrap` leaves their removal
  undecided.

## Acceptance criteria

- [ ] A bench project with the profile passes `/inspire-config` validation.
- [ ] A screen of that project emanates with passing tests in the INSPIRE Factory.

## Notes

- `B1-config-replaces-bootstrap`: its "native mobile" target suggests React Native with Expo, a
  stack with no profile until this ticket ships.
- `B5-react-skill-from-the-team`: the React rules it moves into the skill are ones the new skill
  can build on.
- Native iOS builds need macOS, and the INSPIRE Factory runs on Linux containers. That work is
  filed in the Factory's tracker when a native mobile build is on the roadmap.
