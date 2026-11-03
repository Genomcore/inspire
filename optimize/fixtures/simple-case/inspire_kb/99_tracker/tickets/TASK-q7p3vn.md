---
id: TASK-q7p3vn
title: Install quality gates once source/ exists; protect main; pick the coverage service
created: 2026-09-18
updated: 2026-09-18
reporter: "@joaquim.ballester"
closed_by: null
closed_at: null
epic: tooling
size: M
importance: High
skills: [bootstrap, code]
status: Open
blocked_by: []
related_to: []
---

## Description

`/inspire-bootstrap init` confirmed the stack on an empty tree, so nothing that lives
in `source/` could be installed yet. This ticket holds the remaining gate work.

## Acceptance criteria

- [x] `source/eslint.config.mjs` and `source/package.json` satisfy every `gates:` row of
  `.claude/skills/inspire-code/profiles/nestjs.md` (`.inspire/bin/profile-gates-installed.sh` green).
- [x] `.escape-hatches.json` seeded at ceiling zero, `escape-hatch-ratchet.sh` green.
- [x] `.github/workflows/inspire.yml` invokes `.claude/inspire/hooks/pre-pr.sh` and the `source/` suites on push and pull request.
- [x] `## Worktree recipe` rows executed once in a throwaway worktree, with the suites green.
- [ ] Human acts, owner `@joaquim.ballester`: protect `main` on GitHub so a red check blocks merge;
  choose the external coverage service and make its pass condition strict; record both in
  `stack.md` § Quality gates.
