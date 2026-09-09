---
id: 090-compile-stub-lint
title: "090 — profiles: the canonical compile stub fails the profile's own lint gate"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: Mid
skills: [code]
status: Open
blocked_by: []
related_to: [F14-semantic-types]
---

## Description

`contracter.md` § Emission: every declared method carries a **compile stub** — "the
smallest thing its language needs to type-check, a raised *not implemented* and never a
partial implementation." The `react` and `nestjs` profiles' quality gates install
`tseslint.configs.strictTypeChecked`, which enables `@typescript-eslint/no-unused-vars`
with no `argsIgnorePattern`, and the escape-hatch ratchet holds every suppression ceiling
at zero. The canonical stub is therefore **unlintable** in a project that follows the
profiles:

| stub shape | `eslint` |
|---|---|
| `function find(input: FindInput) { throw new Error('not implemented') }` | error — `'input' is defined but never used` |
| same with `_input` | error — the underscore buys nothing without `argsIgnorePattern` |
| class method, body throws | error — no component-type escape exists |
| body throws **naming the parameter**: `` throw new Error(`not implemented: find(${input.id})`) `` | clean, and `tsc --noEmit` clean |

The `form` contracter in the first field run hit this and reported it at error severity,
correctly — it would have bitten every remaining unit, and the two NestJS contracters
stub class methods, which have no escape at all. The orchestrator probed the four shapes
and found the last row, a project-legal idiom: it suppresses nothing, implements nothing,
and reads the parameter only to name it. The run proceeded on that idiom, undeclared
anywhere.

## Acceptance criteria

- [ ] The idiom has **one home**. Either `profiles/typescript.md` (the language profile,
      where the declaration-only-tree recipe already lives) states the stub form — a
      thrown message that names its parameters — or the framework profiles' § Quality
      gates declare `argsIgnorePattern: '^_'` and the stub uses the underscore. One of the
      two, stated once, and `contracter.md` points at it instead of describing the stub in
      the abstract.
- [ ] The escape-hatch ceilings stay at zero either way. Whatever the idiom is, it is not
      a suppression.
- [ ] A sentence in the chosen home names the trap — `strictTypeChecked` turns on
      `no-unused-vars` for parameters — so the next profile author does not rediscover it.

## Notes

Recorded in the run's log as a "gate defect worth an operator's edit". It is a template
defect: the template ships both the stub rule and the lint gate, and they disagree.
