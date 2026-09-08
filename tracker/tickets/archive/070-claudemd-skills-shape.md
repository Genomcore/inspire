---
id: 070-claudemd-skills-shape
title: "070 — seeded root CLAUDE.md could describe the entry+references shape"
created: 2026-08-18
updated: 2026-08-19
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-08-19
epic: follow-up
size: S
importance: Very Low
skills: [bootstrap]
status: Cancelled
blocked_by: []
related_to: []
---

## Description

Optional enrichment: the seeded root `CLAUDE.md`'s skill descriptions were verified
still-true post-split (F05-restruct did not falsify anything there). They could
additionally describe the entry+references shape — a compact `SKILL.md` entry
routing to on-demand `references/` files — so operators know where behavior lives
before they go looking for it.

## Acceptance criteria

- [ ] `base/templates/`'s seeded root `CLAUDE.md` gains one sentence (or similar)
      describing the entry+references shape, in the same register as the rest of
      the file.

## Notes

Optional; zero urgency. Recorded at the 0.7.0 close rather than done inline, since
nothing about it is broken today.

## Cancelled 2026-08-19 — nice-to-have, and those do not get delivered

The ticket said it of itself: *"Optional; zero urgency… nothing about it is broken
today."* A Very Low ticket with no defect behind it is a note, not work — it will lose
every scheduling contest it ever enters, and its only real effect is to make the open
queue longer and less trustworthy to read.

**The idea is not lost, and it is not hard to redo:** if the seeded root `CLAUDE.md`
should describe the entry+references shape, the natural moment is the next time anything
edits `plugin/base/templates/` — the file is one paragraph and the change is one
sentence. Recording that here costs nothing; keeping an open ticket for it costs
attention on every future scan of the queue.
