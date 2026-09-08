---
id: 080-comment-density-cleanup
title: "080 — comment-heavy runtime and test files: a comments-only trim pass"
created: 2026-08-26
updated: 2026-08-26
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: Low
skills: []
status: Open
blocked_by: [T0.75]
related_to: []
---

## Description

The plugin's runtime and test files carry far more comment than code: `plugin/scripts/lib/merge.sh`
at `394eaa9` is 199 comment lines of 427; `materialize.sh`, the hops, `lib/manifest.sh` and the
block essays of `test-upgrade.sh` are in the same register. Much of it restates what the next lines
do, retells how the code got there, or copies design rationale that already lives in the design
ledgers and commit messages. The operator's standing rule (2026-08-26): a comment carries only a
*why* the code cannot express — a non-derivable invariant, a trap that was actually hit, a
deliberate deviation — at ≤ 5 lines per function; a function that needs a 20-line comment is
renamed or split instead.

New code follows the rule from now on (every brief and reviewer contract carries it). The existing
files are not trimmed piecemeal — this ticket is the deliberate, separate pass.

## Acceptance criteria

- [ ] One comments-only commit per file (or per directory for `plugin/base/bin/`), no code change:
      `git diff --ignore-blank-lines` restricted to non-comment lines is empty for every touched file.
- [ ] Every surviving comment states a *why*: an invariant, a hit trap (one line + where it is
      recorded), or a deviation. No restatement of the following code, no change history, no design
      narrative — those point to `docs/adr/`, the manual or the commit that introduced them.
- [ ] Behaviour proven untouched: all suites green with an unchanged assertion inventory;
      `materialize.sh --mode plan|update|init` byte-identical before/after on fixtures of every
      released version; every shipped manifest reproduces byte-identically.
- [ ] Comment-to-code ratio per touched file reported before/after in the PR body.

## Notes

Not part of the T0.75 test-infrastructure detour nor of wave 2 of the emanation-loop epic;
scheduled after the epic's release (0.8.0) unless the operator pulls it forward. The boy-scout
rule still applies meanwhile: any package that touches a function trims that function's
comments to the rule in the same change.

## Carried in from the T0.75a' lean review (2026-08-26)

- `plugin/scripts/lib/common.sh:25` — the count-check caveat was compressed so that its leading
  clause ("does not catch a newline in a path") is wrong for the `sha256sum` path and only the
  parenthetical rescues it; restate both halves in one line each.
- `plugin/scripts/lib/merge.sh:146` and `plugin/test/upgrade/10-three-way-classifier.sh:31` — the
  tab-in-a-name trap keeps its one line but lost its "where it is recorded" pointer (the B1 commit /
  the T0.75a fable verdict); the rule wants both.
