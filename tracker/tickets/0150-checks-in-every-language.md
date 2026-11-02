---
id: 0150-checks-in-every-language
title: "0150 — some checks only run, or only fire, on an English KB"
created: 2026-11-02
updated: 2026-11-02
reporter: "@djessy.czaplicki"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: Mid
skills: [workspace, screens, bootstrap]
status: Open
blocked_by: []
related_to: [B4-section-keys, F04-mech]
---

## Description

`B4-section-keys` made a KB in any `output_language` pass the structural checks: a
section is found by its id (`## ENT4: Campos`), a table's columns by position, and
`test-translated-kb.sh` holds an English KB and its Spanish twin to the same findings.
Its review found four places where a non-English KB is still checked less than an
English one. None produces a false error; each one is a check that silently does not
run.

1. **`prose-style.sh` skips everything.** When `output_language` is not English it
   emits one `info` finding and exits 0, before any rule runs. Its header gives the
   reason: the binding table is keyed on English H2 names, so "even the
   language-independent rules would have no section kind to bind to". Since
   `B4-section-keys` that is no longer true — `h2_list` resolves a heading through its
   section id — so the comment is stale and the gate is wider than it needs to be.
   Three rules do not depend on the language at all:
   - **R2** sentence length (over 35 words);
   - **R4** glossary synonyms, read from `00_bootstrap/glossary.md`, which is itself
     written in `output_language`;
   - **R5** paragraph length (over 8 sentences).
2. **R1, R3, R6 and R7 are English by construction.**
   - R1 (passive voice) looks for an English be-verb plus a past participle.
   - R3 (noun clusters) counts consecutive nouns against an English stopword list; the
     construction is rare in Romance languages, which require a preposition.
   - R6 (historical language) is a closed English token list (`previously`, `used to`,
     `migrated from`) plus `~~strikethrough~~`, which is language-independent.
   - R7 (figurative language) is the closed English intensifier list `PS_FLOURISH`.
3. **`screen-presentation.sh` `check_touch`** greps the screen for `hover` and then for
   `touch|tap|long-press`. A Spanish screen that says "al pasar el cursor" is never
   asked for a touch path, and one that keeps the loanword `hover` but writes
   "pulsación larga" is warned although it has one.
4. **`screen-presentation.sh` NONARROW** — the warning for a render table of columns
   with no Narrow column — fires only when the region's H3 matches `/table|column/`.
   A region written `### Tabla` never gets it.

## Acceptance criteria

- [ ] R2, R4 and R5 run on a KB in any `output_language`. The `info` finding names the
      rules that were skipped instead of saying every check was.
- [ ] `prose-style.sh`'s header states the gate as it now is.
- [ ] R1, R3, R6 and R7 each have one stated answer: a per-language token list or
      heuristic for the languages INSPIRE projects use, or "English only" written in
      `writing-style.md` so a non-English team knows that half of the contract is
      judgment only. Ratifying English-only for all four closes this item with no
      code changed. R6's strikethrough half runs in every language either way.
- [ ] `check_touch` either reads the hover and touch vocabulary of `output_language`,
      or keys on something language-independent, or its English-only scope is stated
      in `format-screen.md`.
- [ ] NONARROW decides "this region lists a table's columns" without reading the
      region's name, or states the restriction.
- [ ] Golden fixtures cover each rule that now runs on a non-English KB, and
      `test-translated-kb.sh`'s Spanish twin stops excluding them from the comparison.

## Notes

`F04-mech` already opens `prose-style.sh` to split it under ~500 LOC and to clear five
items. If that work lands first, items 1 and 2 belong in the split files; this ticket
does not depend on it.
