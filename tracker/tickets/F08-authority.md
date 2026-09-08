---
id: F08-authority
title: "F8 AUTHORITY — extract knows what it is reading"
created: 2026-08-13
updated: 2026-08-19
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: Mid
skills: [extract, prototype, domain]
status: Open
blocked_by: []
related_to: [070-scanner-count]
---

## Description

Theme: **provenance — source trust as a first-class axis, orthogonal to evidence
confidence.** Today extract is trust-blind outside bootstrap comparison: a production
schema with 200 migrations gets the credit of a mock array. Ship mode resolution in Phase
0 (prototype root vs source root vs external, derived from `product-roots` — discharging
the unimplemented ADR runtime-lifecycle D3); a `scanner-mocks.md` brief for prototype
sources (where the logic scanner's DDL-first ranking finds nothing); an
`authority: authoritative | hinted` candidate stamp doing real work in provenance notes,
the domain grounding digest and gap semantics; and a shared `source-authority.md`
reference lifting spike-capture's posture: separate signal from roughness, never import
shortcuts as decisions.

## Acceptance criteria

- [ ] First ticket is the D3 stress test: proto extraction as scan (mode parameter) vs
      gap analysis (`/inspire_prototype harvest`) — decided against one real prototype.
- [ ] The authority stamp changes at least three behaviors (provenance note wording,
      grounding-digest claims, gap classification) — never entry lifecycle.
- [ ] `surfaces_inferred` suppressed in proto mode.
- [ ] **The scanner count is resolved before `scanner-mocks.md` ships.** Adding a fifth
      brief falsifies "You are one of four parallel scanners" at
      `scanner-{logic,styles,screens,stack}.md:3` and the scanner list at
      `manifest-format.md:3,15,45` — six hardcoded sites. Either the count is reworded to
      name the seam without counting ("you are one of the parallel extract scanners; your
      seam is…") or it is kept and every site updated to five. All four existing briefs
      change together; they must stay consistent with each other and with
      `manifest-format.md`.

## Notes

Free lane — no incoming dependencies; a good breather release between spine pushes.
Bundles XTRACT-00..04.

**Absorbed `070-scanner-count` (2026-08-19).** It was filed at the 0.7.0 close as a
standalone question — should the count stay, given it is load-bearing for a blind
subagent that cannot see the other briefs? It is not standalone: F08 is the release that
adds the fifth scanner, so F08 is what forces the answer. The original ticket's own
caution is preserved above — the count exists because a subagent reading its own brief
has no other way to know it is one of a set, so "reword to name the seam" is a candidate,
not a foregone conclusion. The pair-3 enumerate-don't-count strike deliberately excluded
these preambles for that reason; W3's prose pass never touched them.
