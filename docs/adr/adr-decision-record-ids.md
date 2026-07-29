# ADR — Decision-record ids are slug-only

- **Status:** Accepted — 2026-07-29
- **Scope:** How INSPIRE **core** names its own ADRs under `docs/adr/`. The same rule
  already governs a project's `inspire_kb/01_adr/` via the `inspire-adr` skill; this record
  closes the gap between what core ships and what core practises.

---

## Context

Core's ADRs used sequential numeric prefixes (`0001-runtime-lifecycle-and-lessons.md`)
while the `inspire-adr` skill mandated the opposite for every fork:

> **Filename:** `adr-{module-prefix}-{slug}.md` for module-specific, or `adr-{slug}.md` for
> cross-cutting. Slug-only — no numeric prefix.
>
> **Rationale.** Numeric prefixes collide under parallel work (two branches grab the same
> next number). Slug-only filenames are collision-free by construction.

`adr-runtime-lifecycle-and-lessons` explains why core's records are hand-authored — the
template is not an instantiated fork, so no `inspire-adr` skill runs here. But that
justified skipping the *skill*, not the *convention*.

## Decision

**Core ADRs are named `adr-{slug}.md`** (or `adr-{module-prefix}-{slug}.md` where a
decision is scoped to one area). No numeric prefix. **The canonical id is the filename
without `.md`**, and the H1 is the human-readable title.

Chronology moves to `docs/adr/_index.md`, a dated catalog ordered newest-first — the one
thing a numeric prefix genuinely provided.

**Corollary:** core holds itself to the conventions it ships. Where core's practice and the
runtime's rules diverge, the divergence is a defect in core, not an exemption.

## Alternatives considered and rejected

- **Keep sequential numbering.** Rejected — it is the collision the shipped rule exists to
  prevent, and it puts core in contradiction with its own skill.
- **Opaque random ids** (`adr-7f3k`). Collision-proof, but unreadable in the wikilinks the
  skills traverse constantly: `[[adr-plugin-delivery]]` carries meaning, `[[adr-7f3k]]`
  carries none. Slug collisions also fail *loudly and immediately* at creation (the file
  exists, pick another name), whereas numeric collisions fail *silently* on parallel
  branches and surface only at merge. Slugs address the actual failure mode.
- **Date-prefixed slugs** (`adr-20260729-plugin-delivery`). Sortable and collision-resistant,
  and it matches `98_lessons`' `YYYYMMDD_<slug>` convention — but it diverges from what
  `inspire-adr` mandates for forks, reintroducing exactly the core-vs-runtime split this
  record closes. The catalog supplies chronology without the divergence.

## Consequences

- `0001-runtime-lifecycle-and-lessons.md` is renamed; inbound references are rewritten.
- Directory listings lose chronological order; `_index.md` carries it, and each record
  carries its own date.
- Two ADRs on parallel branches can no longer collide by construction.
- Future core ADRs need no coordination on numbering.
