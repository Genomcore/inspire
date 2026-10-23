---
id: 0911-file-scope-silent-pass
title: "0911 — a file passed as scope checks nothing and reports PASS"
created: 2026-10-20
updated: 2026-10-20
reporter: "@irene.gonzalez"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: High
skills: []
status: Open
blocked_by: []
related_to: [F04-mech]
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

- A file passed as scope is either checked as a one-file scope, or refused with a
  non-zero exit and a message naming the accepted scope shape. Either is a valid close;
  silent success is not.
- A golden fixture pins the behaviour for `review.sh` with a file scope.
- If files become a valid scope, the authoring skills can run the mechanical checks on
  the file they just wrote, the way they run `trust.sh stamp` today.
