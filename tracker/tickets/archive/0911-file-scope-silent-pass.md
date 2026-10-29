---
id: 0911-file-scope-silent-pass
title: "0911 — a file passed as scope checks nothing and reports PASS"
created: 2026-10-20
updated: 2026-10-29
reporter: "@irene.gonzalez"
closed_by: "@djessy.czaplicki"
closed_at: 2026-10-29
epic: follow-up
size: S
importance: High
skills: []
status: Done
blocked_by: []
related_to: [F04-mech, B4-prose-checks-before-commit]
---

## Description

`review.sh` and every rule under it take an optional scope. A directory works. A
single file is accepted, checks nothing, and reports success:

```
$ .inspire/bin/review.sh inspire_kb/04_domain/extraccions/appointment/extraccions.appointment.md
review: PASS — no errors found in scope: inspire_kb/04_domain/extraccions/appointment/extraccions.appointment.md
$ .inspire/bin/review.sh inspire_kb/04_domain/extraccions/appointment
review: FAIL — one or more rules emitted errors (see stderr findings)   # 46 errors
```

Reproduced on a copy of a 0.9.9 project with that entity broken on purpose
(`## Purpose` and `## Fields` renamed). `prose-style.sh <file>` behaves the same way:
no output, exit 0.

The cause is shared: every `sdd_find_*` helper in `_lib.sh` (`actions`, `entities`,
`features`, `adrs`, `screens`, `catalog`) intersects the scope with its layer root and
then runs `[ -d "$scope" ] || return 0`. A file is not a directory, so the enumeration
is empty and each rule reports a clean scope.

The failure is quiet, and agents hit it. An agent working in a project ran
`prose-style.sh` on each file it had written, saw no output, and reported the files
clean; `review.sh` over the domain later found nine warnings in them.
`prose-style.sh`'s own header states the principle this breaks: "a checker that quietly
checks nothing is worse than one that says out loud it cannot".

## Acceptance criteria

- A file passed as scope is checked as a one-file scope: every rule that applies to
  that file runs on it, and on nothing else. Silent success is not a valid close, and
  neither, since 2026-10-28, is refusing the file (see Notes).
- A golden fixture pins the behaviour for `review.sh` with a file scope.

## Notes

**Amended 2026-10-28 (fourth design-review session).** The review confirmed the defect
and its importance. Two changes follow:

- *Refusing is no longer a valid close.* `B4-prose-checks-before-commit` runs the
  checks on staged files and on the file a skill just wrote, so it needs a file to be a
  working scope. A loud refusal would have closed this ticket and left that one with
  nothing to build on.
- *The third criterion moved out.* "If files become a valid scope, the authoring skills
  can run the mechanical checks on the file they just wrote" is new behaviour, not the
  fix, so it is now a criterion of `B4-prose-checks-before-commit`. This ticket closes
  on the fix and its fixture alone.


## Resolution

Shipped in 0.14.2. A file passed as scope is checked as a one-file scope.

- The six KB finders in `_lib.sh` (`actions`, `entities`, `features`, `adrs`,
  `screens`, `catalog`) take any existing path, not only a directory, and
  `sdd_scope_intersect` resolves a file's physical path through its directory.
  `adr-maturity-matches-features.sh` and `criteria-have-tests.sh` accept a file the
  same way.
- **The scope bounds what a rule reports on, not what it reads.** Three rules built
  their cross-file context from the scope, so a one-file scope judged the file without
  the rest of the tree: `stable-blockers.sh` reported its `requires` target as not
  found, `field-coverage.sh` reported every field uncovered, and `acyclic-deps.sh`
  missed a cycle through another file. They now build the id index, the touch table
  and the `requires` graph from the whole domain root, and report only on what is in
  scope. The same bug hit a module scope whose files point at another module.
- A sweep over every existing golden fixture ran each rule once on the whole tree and
  once per flagged file: each file got the same findings both ways (152 of 152). The
  two pattern-catalog findings of `screen-coherence.sh` are the exception, and not a
  file-scope one: they are raised while checking the screens that use the pattern, so a
  `patterns/` directory scope does not report them either.
- Fixtures: `review/file-scope` pins `review.sh` on a file (findings for that file,
  none for a broken file beside it), and `acyclic-deps/file-scope-cycle`,
  `stable-blockers/file-scope-dep-elsewhere` and `field-coverage/file-scope-touch-elsewhere`
  pin the three cross-file rules. Each fails without the fix.
