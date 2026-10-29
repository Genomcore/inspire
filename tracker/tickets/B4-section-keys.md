---
id: B4-section-keys
title: "B4 — translating a KB artifact's headings breaks its validation"
created: 2026-10-28
updated: 2026-10-28
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: High
skills: [domain, feature, adr, screens]
status: Open
blocked_by: []
related_to: [B1-kb-structure]
---

## Origin

The INSPIRE maintainers held the fourth session of a design review on 2026-10-28 while
preparing the training of new INSPIRE operators. This ticket records one of its
decisions. The review's working notes are not public, so this ticket states everything
needed to act on the decision.

**Decision:** the KB stays multilingual. Mandatory sections carry a stable key in front
of their heading, for example `F2: Campos`, and validators match the key, never the
label. The label can then be translated into the project's language without breaking a
check.

The review also confirmed, as an earlier session had decided, that the KB may be written
in any language: an operator has to be able to read the KB to check what an agent says
it contains. English performs best today. If measurement shows the INSPIRE Factory does
much worse on other languages, a project-wide or company-wide "the KB is written in
English" stays a legitimate choice. That needs no change here: `output_language`
already supports it.

## Description

### What happens today

`_references/output-language.md` says to translate "titles, descriptions, rationale,
section bodies" and to keep machine-read tokens verbatim. It does not say whether a
heading is either. The validators read headings as literals: `sections-present.sh`
requires an H2 "with the exact name", such as `## Purpose` or `## Fields`. A KB written
in Spanish or Catalan fails every mandatory-section check. This was hit in a test
project.

Part of the idea already exists. Entries inside a section are keyed (`I1`, `B3`, `P2`,
`AC-1`; see `_references/keyed-heads.md`), and a feature's H1 already reads
`ANL-02: Name`, a stable key followed by a translatable label. Headings are the one
level with no key.

### What this ticket asks for

- A stable key on every heading a validator or the deriver looks for, in every format:
  entity, action, use case, ADR, screen.
- Validators, `emanate-derive.sh` and the authoring skills find sections by key. The
  label after it is free text in the project's language.
- `output-language.md` lists heading keys as machine-read tokens, and says plainly that
  the label is translated.
- Every artifact's identity lives in a token that is never translated: its filename or a
  frontmatter `id`. Features and ADRs have no frontmatter `id` today. The design states
  whether they need one.
- Templates ship with the keys. Existing projects keep working, either through a reader
  that accepts both shapes or through an explicit migration. Either path respects the
  upgrade rule in `docs/adr/adr-upgrade-path.md`, section "The KB is additive in both
  init and update".

### Open questions

- Key form: an opaque code (`F2: Campos`), the English name as key (`fields: Campos`), or
  a template marker. Opaque codes read worst for an operator. English names read best but
  look translatable.
- Is the key per format (`F2` means Fields only in an entity) or global across formats?

### Alternative not chosen

Headings could be treated like a programming language's keywords: always English, never
translated. That needs no format change. The review chose keys so that an operator reads
the whole KB, headings included, in their own language.

## Acceptance criteria

- [ ] Every format's mandatory headings carry a key, and the templates ship with them.
- [ ] Validators, the deriver and the skills find sections by key. A golden fixture with
      translated labels passes `sections-present.sh`.
- [ ] `output-language.md` names heading keys as machine-read tokens and labels as
      translatable.
- [ ] The design states where each artifact type's identity lives, and adds a frontmatter
      `id` where one is missing and needed.
- [ ] Existing projects keep validating, through a dual-shape reader or an explicit
      migration that respects the KB-additive upgrade rule.
- [ ] The open questions have written answers in this ticket's close note.

## Notes

- `B1-kb-structure` also changes every template and every `sdd_find_*` reader. If both
  land in the same window, ship them as one migration. They stay separate tickets:
  `B1-kb-structure` is a layout decision, and this ticket fixes a defect that bites
  today.
- **Factory port.** The INSPIRE Factory's deriver looks sections up by their English
  names (`orchestrator/src/contracts/derive-domain.ts` reads `Fields`, `Purpose`,
  `Invariants`, `Behavior` and `Outputs`; `markdown-document.ts` and
  `validate-domain.ts` do the same). The matching change is filed in the Factory's
  tracker when this ticket lands.
