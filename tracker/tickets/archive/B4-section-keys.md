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

A heading is `## {ID}: {label}`. The section id is capital letters then digits
(`ENT4`) and never changes. The label after the first `: ` is free text in the
project's language: `## ENT4: Campos`. The templates and the seeded pattern entries
ship every heading with its id and an English label (`## ENT4: Fields`), and the
authoring skills write that shape in every language, English included, so a KB has
one heading shape.

The ids live in one table, `SDD_SECTION_IDS` in `_lib.sh`: format, id, section name
and, for an H3, its parent. `sdd_heading_name` resolves a heading to its section name
through it, and every section reader in `_lib.sh` (`sdd_body_section`,
`sdd_body_prose`, `sdd_has_section`, `sdd_has_subsection`, `sdd_body_subsection`)
looks a section up that way, so the rules keep asking for `Fields` and never see an
id. The validators that read headings themselves resolve them the same way:
`sections-present.sh` (its order check), `prose-style.sh`, `_keyed-heads.sh`,
`screen-coherence.sh` (the `## Bindings` subsections), `screen-presentation.sh` and
`adr-split.sh`. `sections-present.sh` warns about a heading that carries another
format's id.

The open questions have these answers:

- **Key form: an id, `[A-Z]+[0-9]+`.** A name reads as translatable, and an agent
  writing in Spanish translates it. An id does not invite that. Each format has a
  prefix of its own (`ENT`, `ACT`, `UC`, `ADR`, `SCR`, `PAT`, `CMP`, `LAY`, `MOD`,
  `SPK`), long enough to say which format it belongs to, and the number follows
  template order. The label keeps the heading readable.
- **Per format.** `Purpose` is `ENT1` in an entity, `ACT1` in an action and `SCR1` in
  a screen. A per-format series numbers in template order, and a section added to one
  format takes the next number in its own series without touching another. A shared
  series would need a global registry for every new section.
- **Identity.** No artifact needs a new frontmatter `id`. Entities, actions and screens
  carry one. A feature's identity is its filename stem (`ANL-02`), which
  `criteria-have-tests.sh` already qualifies claims by and the H1 repeats. An ADR's
  identity is its filename `adr-{slug}`, which every wikilink resolves. Neither is
  ever translated. `output-language.md` states this.
- **Existing projects.** The readers also take the legacy English name (`## Fields`,
  or `## Fields: Campos`) as its section, so nothing breaks. `/inspire:update`
  recommends the rewrite to the one shape and runs it on the operator's yes:
  `heading-keys.sh` replaces each English name with its id, keeping a label or
  taking the name as one, and the skill translates the labels when `output_language`
  is not English. Asking first follows `adr-upgrade-path` D10, as the single-file ADR
  migration does.
- **The deriver.** `emanate-derive.sh` left this repository with in-session emanation;
  the Factory's deriver is the remaining reader, and its port is the Factory note
  below. It reads the same table.

Pinned by `sections-present/translated-labels` (every format, ids and Spanish labels,
clean), `sections-present/translated-label-without-key` (a label with no id is a
missing section), `sections-present/foreign-section-id` (another format's id is a
warning and the section reads as missing), `screen-coherence/translated-labels` (a
defect inside translated bindings is still found, which the old reader missed), the
section-id cases in `lib-tests.sh`, an id-keyed `## Decision` in `test-adr-split.sh`,
and `test-heading-keys.sh`, which also holds the id table equal to the templates'
headings.

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
