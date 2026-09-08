---
id: F01-derive
title: "F1 DERIVE — retire the KB index mirrors"
created: 2026-08-13
updated: 2026-08-19
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-08-19
epic: roadmap
size: M
importance: Very High
skills: [module, adr, feature, screens, workspace]
status: Done
blocked_by: []
related_to: [F02-contracts, F10-flows]
---

## Description

Theme: **subtraction — one source of truth on disk.** Five of the six `_index` kinds are
pure mirrors of what the files already state (module registry, ADR index, use-case indexes
with totals, pattern/component TOCs); `trust-stamps.md:49` already classifies them as
rebuilt content. Delete the mirrors, replace all ~25 "update the index" prose obligations
across 6 skills with glob/grep, migrate existing projects with derive-then-diff retirement
(a mirror matching its regeneration deletes silently; a diverging one asks the operator).
The screens `_index.md` — the one carrier of authored nav — survives until F10 rehomes it.

## Acceptance criteria

- [x] No skill instructs maintaining a mirror index; the five mirror kinds are gone from
      the KB skeleton and the manifests. — no `_index` file remains under
      `plugin/base/kb/`; `plugin/manifests/0.7.0.json` lists zero `_index` paths; no
      index-maintenance obligation survives across `plugin/base/skills/`.
- [x] Migration hop ships: derive-then-diff retirement with operator ask on divergence. —
      `plugin/scripts/hops/0.7.0.sh`; the pattern/component arms at `:259-276` settle
      pristine seeds silently and route an authored Purpose/State column to the ask.
- [x] Workspace review and trust-stamp rules no longer reference the removed kinds. — the
      only surviving mentions (`_references/trust-stamps.md:49`,
      `inspire-workspace/references/workspace-structure.md:20,49`) are the screens
      `_index.md` that F01 deliberately kept.
- [x] D9 (delete vs regenerate) recorded as decided by the audit (INDEX-01).

## Notes

Recommended opener of the release ladder: smallest spine item, no pending decision,
subtractive. Bundles INDEX-01..03 from the vectors report. Soft edge: ship before
F02-contracts so shape pinning starts from a smaller artifact inventory.

Spike kind added; prose-only kinds recorded; AC-1's manifest clause satisfied-by-
construction; skills count 5→7; module SKILL :245–246-class enumerations adjudicated
word-only; the hub-glob predicate is now the registry at every enumeration site.

## Closing note (2026-08-19)

Shipped in **0.7.0** (PR #14, merge `21f3fd8`, tag `v0.7.0`). Verified against the tree at
close, not against the release notes.

**One item deliberately carried, not dropped:** the screens `_index.md` — the single
carrier of authored nav — still exists. It was never F01's to retire; retiring it needs
nav rehomed first, which is [[F10-flows]]'s AC-2 ("The last index mirror … retires once
nav is rehomed — closing F01-derive's final item"). F10 owns it; nothing here is orphaned
by this closure.
