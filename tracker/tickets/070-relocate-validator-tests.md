---
id: 070-relocate-validator-tests
title: "070 — three test-harness defects"
created: 2026-08-18
updated: 2026-08-19
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: Low
skills: []
status: Open
blocked_by: []
related_to: []
---

## Description

Three concrete defects in the template's own test harness. Each cost real time once,
each is a small fix, and none of them is a design question.

## Acceptance criteria

- [ ] **`plugin/test/test-materialize.sh:119` needs a SKIP path.** The check "every
on-disk `base/kb` directory ships at least one tracked file" asks git a question, so
it is unrunnable outside a git checkout — a copy-based harness reads one false
failure. Skip when `git rev-parse` fails rather than fail. - [ ] **`test-
materialize.sh:755,758` are mislabelled.** Both say "guard: real v0.3       lock…" while
exercising a **v0.6.0** fixture. A label naming the wrong version is       worse than no
label. - [ ] **Mutation harnesses must restore file modes** (`chmod` before `mv`). Cost
an hour       to diagnose once; also a lesson candidate for the project's own catalog.

## Notes

**The relocation was dropped 2026-08-19.** This ticket used to lead with moving
`plugin/base/bin/test/` to `plugin/test/validators/`, so that `plugin/base/` would mean
exactly "what materializes" with no `! -path '*/test/*'` carve-out in `materialize.sh`.
That move is cosmetic by its own admission, costs a manifest regen plus all six suites
plus a re-rehearse, and would lose every scheduling contest it entered. It is a nice-to-
have, and nice-to-haves do not get delivered — so it is recorded here rather than
tracked.

If a future release regenerates the manifest anyway and someone wants the tidier
invariant, the move is: relocate runner + fixtures, update the runner's relative paths,
delete the `! -path` clause at `materialize.sh:317`, re-point the fixtures-suite "no
bin/test" assertions, and update CLAUDE.md's suite table and its `base/bin/test/ never
materializes` prose.

The three defects above arrived via `070-carryforwards` (cancelled 2026-08-19) and are
independent of all that.
