---
produced:
  skill: feature
  skill_sha: 7aff836
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---
# LND-01: Read the value proposition

> Source: [[../../02_modules/landing]]

The visitor lands on the page and reads, above the fold, what OpenBIMS is and why it
matters: one headline, one subtitle, three calls to action, a copy-ready install
snippet and a trust strip. The hero is the only section every visitor sees, so it
carries the three governing ideas in order: data stays on the visitor's
infrastructure, the licence is AGPL-3.0, the assistant operates the platform.

**State:** 🟡 Planned
**Priority:** Core

## Actor
A developer or IT lead at a hospital, regional health service or research centre,
arriving from search or from the GitHub repository.

## Preconditions
None.

## Main flow
1. `B1` — The visitor opens the landing root and sees the headline, the subtitle and
   the three calls to action without scrolling on a 1280 px wide viewport.
2. `B2` — The visitor reads the trust strip beneath the calls to action: BIMS v1
   lineage, production in six Spanish regions, AGPL-3.0, the open-source stack list.
3. `B3` — The visitor reads the install snippet (clone, compose up, console URL) and
   copies it with one click.
4. `B4` — The visitor follows the primary call to action and reaches the Getting
   Started documentation.

## Alternative flows
### AF-1: Secondary call to action
The visitor follows "See live demo" and reaches the demo console of this repository.

### AF-2: Tertiary call to action
The visitor follows "Talk to Genomcore" and reaches the sales contact for Cloud and
Enterprise.

## Error flows
### EF-1: Clipboard unavailable
The browser rejects the clipboard request. The snippet stays selectable as plain
text. The copy control shows a "select and copy" hint instead of a success state.

## Postconditions
- `Q1` — The visitor has seen the three governing ideas and can reach the docs, the
  demo and sales in one click each.

## Acceptance criteria
- [ ] AC-1: On a 1280×800 viewport with no scroll, the page shows one headline, the subtitle and three calls to action labelled "Deploy in 5 minutes", "See live demo" and "Talk to Genomcore".
- [ ] AC-2: The trust strip contains exactly these four items: "Evolution of BIMS v1", "In production in 6 Spanish regions", "AGPL-3.0", and a stack list naming PostgreSQL, NATS, Meilisearch and MinIO.
- [ ] AC-3: The install snippet contains the three lines `git clone https://github.com/genomcore/openbims`, `cd openbims && docker compose up` and a comment naming `http://localhost:3000`, and the copy control places those three lines verbatim on the clipboard.
- [ ] AC-4: When the clipboard API rejects, the copy control shows a "select and copy" hint and the visitor can still select the text of the snippet.
- [ ] AC-5: Each call to action resolves to a non-empty URL: docs Getting Started, the demo console route, and the Genomcore contact page; no link points at `#`.
- [ ] AC-6: In both languages, the copy of the hero excludes the marketing words the brief bans: "revolutionary", "transform" and their translations.
