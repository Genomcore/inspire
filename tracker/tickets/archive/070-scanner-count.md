---
id: 070-scanner-count
title: "070 — extract's scanner briefs still name a count"
created: 2026-08-18
updated: 2026-08-19
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-08-19
epic: follow-up
size: S
importance: Low
skills: [extract]
status: Cancelled
blocked_by: []
related_to: []
---

## Description

The four scanner briefs each open "You are one of four parallel scanners"
(`plugin/base/skills/inspire-extract/references/scanner-{stack,screens,logic,styles}.md:3`)
— a count statement that survived the enumerate-don't-count rule because these
preambles are blind-subagent payloads (the pair-3 strike excludes them: a subagent
reading its own brief cannot see the other three, so the count is the only way it
knows it is one of a set, and W3's prose pass never touched them for that reason).

## Acceptance criteria

- [ ] Decide whether the count stays (it is load-bearing for a blind subagent) or is
      reworded to name the seam without counting (e.g. "you are one of the parallel
      extract scanners; your seam is...").
- [ ] If reworded, all four scanner briefs change together — they must stay consistent
      with each other and with `manifest-format.md`'s scanner list.

## Notes

Candidate: reword to name the seam without the count. Recorded at the 0.7.0 close
(C5-P2/C6-T10) rather than fixed, since the blind-payload exception may make the
count the right call — not just a lapsed rule.

## Cancelled 2026-08-19 — absorbed into F08-authority

Not cancelled as "won't do" — **cancelled as "not its own ticket."** F08-authority ships
`scanner-mocks.md`, a fifth scanner brief, which falsifies the count at all six hardcoded
sites. The release that creates the problem is the release that must answer the question,
so the work now lives as an acceptance criterion on [[F08-authority]], with this ticket's
caution about blind-subagent payloads preserved verbatim there.
