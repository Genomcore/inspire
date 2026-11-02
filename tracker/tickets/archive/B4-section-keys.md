---
id: B4-section-keys
title: "B4 — translating a KB artifact's headings breaks its validation"
created: 2026-10-28
updated: 2026-11-02
reporter: "@dario.blasco"
closed_by: "@djessy.czaplicki"
closed_at: 2026-11-02
epic: roadmap
size: M
importance: High
skills: [domain, feature, adr, screens]
status: Done
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

- [x] Every format's mandatory headings carry a key, and the templates ship with them.
- [x] Validators, the deriver and the skills find sections by key. A golden fixture with
      translated labels passes `sections-present.sh`.
- [x] `output-language.md` names heading keys as machine-read tokens and labels as
      translatable.
- [x] The design states where each artifact type's identity lives, and adds a frontmatter
      `id` where one is missing and needed.
- [x] Existing projects keep validating, through a dual-shape reader or an explicit
      migration that respects the KB-additive upgrade rule.
- [x] The open questions have written answers in this ticket's close note.

## Resolution

A heading is `## {key}: {label}`. The key is the English section name, and the label
after the first `: ` is free text in the project's language: `## Fields: Campos`. The
templates and the seeded pattern entries ship every heading in that form with an
English label (`## Fields: Fields`), and the authoring skills write it in every
language, English included, so a KB has one heading shape. `sdd_heading_key` in `_lib.sh` reads a heading
that way, and every section reader there (`sdd_body_section`, `sdd_body_prose`,
`sdd_has_section`, `sdd_has_subsection`, `sdd_body_subsection`) looks a section up by
key. The validators that read headings themselves use the same function or the same
shape: `sections-present.sh` (its order check), `prose-style.sh`, `_keyed-heads.sh`,
`screen-coherence.sh` (the `## Bindings` subsections) and `adr-split.sh`.

The open questions have these answers:

- **Key form: the English name.** An opaque code reads worst for an operator. The
  English name is what every existing heading already is, so the reader accepts both
  shapes with no migration: an existing `## Fields` is a key with no label. The risk
  that the name looks translatable is answered in `output-language.md`, which lists
  heading keys as machine-read tokens. A heading translated without its key is
  reported loudly, as a missing section, never read as an empty one.
- **Per format or global: neither question arises.** A key is a section name, so it
  means the same role wherever it appears (`Purpose` in an entity, an action and a
  screen). No code table exists to scope.
- **Identity.** No artifact needs a new frontmatter `id`. Entities, actions and screens
  carry one. A feature's identity is its filename stem (`ANL-02`), which
  `criteria-have-tests.sh` already qualifies claims by and the H1 repeats as a key. An
  ADR's identity is its filename `adr-{slug}`, which every wikilink resolves. Neither
  is ever translated. `output-language.md` states this.
- **The deriver.** `emanate-derive.sh` left this repository with in-session emanation;
  the Factory's deriver is the remaining reader, and its port is the Factory note below.

Pinned by `sections-present/translated-labels` (every format, Spanish labels, clean),
`sections-present/translated-label-without-key` (a label with no key is a missing
section), `screen-coherence/translated-labels` (a defect inside translated bindings
is still found, which the old reader missed), the heading-key cases in
`lib-tests.sh`, and a translated `## Decision` in `test-adr-split.sh`.

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
