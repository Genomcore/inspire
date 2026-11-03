---
id: 0143-prose-checks-in-any-language
title: "0143 — prose-style checks nothing when the KB is not in English"
created: 2026-11-02
updated: 2026-11-03
reporter: "@irene.gonzalez"
closed_by: "@djessy.czaplicki"
closed_at: 2026-11-03
epic: follow-up
size: S
importance: Mid
skills: []
status: Done
blocked_by: [B4-section-keys]
related_to: [F04-mech, B4-prose-checks-before-commit]
---

## Description

`prose-style.sh` reads `output_language` from `00_bootstrap/project.md` first. When it is
not English, the script emits one info finding and exits 0, so none of its seven checks
runs. F03-style set that scope: "enforcement is en-only by declared scope".

The script's header gives two reasons for the gate:

1. R1, R3, R6 and R7 are English morphology or English token lists.
2. "A compliant non-`en` fork translates its headers — headers are prose, not
   machine-read tokens — so even the language-independent rules would have no section
   kind to bind to."

`B4-section-keys` removes the second reason. A heading is `## {ID}: {label}`, the
section id is a machine-read token, and `prose-style.sh` already resolves a heading to
its section name through `sdd_heading_name`. A Spanish KB written with ids binds to the
same section kinds as an English one. The PR for `B4-section-keys` does not change the
header comment, so after it lands the comment contradicts `output-language.md`.

The first reason still holds for R1, R3, R6 and R7. For the other three it holds only in
two details, listed in the Notes:

| check | reads | depends on English |
|---|---|---|
| R2 sentence length | word count per sentence | the count, no; the splitter's abbreviation list, yes |
| R4 glossary synonyms | rejected synonyms from `00_bootstrap/glossary.md` | the list, no; the word boundary, yes |
| R5 paragraph length | sentence count per paragraph | as R2 |
| R1, R3, R6, R7 | English be-verbs, stopwords and token lists | yes |

The result is that a KB in Spanish or Catalan gets no mechanical style check at all,
while `B4-section-keys` gives it the same structural validation as an English one. R4 is
the check this costs most: it is the one that reads a declaration, the only one that
ramps to an error on accepted and stable domain artifacts, and its glossary is written
in the project's language anyway.

## Acceptance criteria

- [x] A decision on which checks run when `output_language` is not English. The two
      answers expected are: R2, R4 and R5 run in any language and R1, R3, R6 and R7 stay
      English-only, or the gate stays as it is. **Keeping the gate closes this ticket
      Done with no change to the checks**, as long as the next criterion is met.
- [x] The header comment of `prose-style.sh` gives the reason that holds after
      `B4-section-keys`. It no longer says headings are prose.
- [x] If R2, R4 and R5 run in another language: the info finding names the checks that
      were skipped rather than saying the script checks nothing, and a golden fixture
      with `output_language: es` and id-keyed headings pins both halves (a long Spanish
      sentence is a finding, a passive Spanish sentence is not).
- [x] `writing-style.md` § Enforcement says which checks run in which languages.

## Resolution

R2, R4 and R5 run in every language. R1, R3, R6 and R7 stay English-only. When
`output_language` is not English, the info note names the four skipped checks and the
run goes on. The 35-word and 8-sentence signals apply unchanged: nothing measured
Spanish or Catalan prose to set other ones.

The two English assumptions in the Notes are fixed:

- **The splitter.** Outside English, `is_abbrev` reads `PS_ABBREV_ANY`
  (`e.g i.e etc vs cf ca ej ex sr sra dr dra`), so `no.` ends a sentence. The English
  list is unchanged.
- **R4's boundary.** The attribution pass runs with `LC_ALL=C` and counts every byte
  above `0x7f` as a word character, so `compa` no longer matches inside `compañía`.
  `fold_latin` lowercases the Latin-1 capitals in the stream and in the glossary with
  one `sed`, so `ORGANIZACIÓN` matches `organización` whatever the awk and the locale.
  The `grep` pre-filter keeps its wider boundary: it only selects lines, and the
  attribution pass decides.

The header of `prose-style.sh` gives these reasons and no longer says headings are
prose. `writing-style.md` § Enforcement has a table of which check runs in which
language. `bin/README.md`, `findings-format.md`, `lifecycle-rules.md` and
`inspire-domain`'s `review.md` match it. The golden fixture `non-en-partial` replaces
`non-en-skip`: a Spanish action with id-keyed headings, where a 44-word sentence is an
R2 finding, a rejected synonym in capitals is an R4 error, and a passive sentence, a
noun cluster, `previously`, a `no.` sentence end and `compañía` are not findings.

## Notes

- **Blocked by `B4-section-keys`.** Without section ids, a translated heading has no
  section kind, so the checks cannot bind in another language. Its PR is open against
  `release/0.15.0`.
- **Not folded into `F04-mech`.** F04 opens `prose-style.sh` to split it and carries
  five findings-level items. This ticket changes what the script checks, not where its
  code lives, and it does not wait for emanation to leave.
- R2's cap (35 words) and R5's cap (8 sentences) were calibrated on an English KB.
  Whether the same caps fit Spanish or Catalan is a question for the decision above,
  not a reason to keep the gate.
- Two English assumptions sit inside R2, R4 and R5, and running them in another
  language means fixing or accepting both:
  - The sentence splitter treats a period after one of a fixed list of English
    abbreviations as no sentence end (`is_abbrev`). The list includes `no`, so a Spanish
    sentence ending in "no." runs into the next one. Spanish abbreviations such as
    `p. ej.` are not on the list.
  - R4 matches a synonym between `[^a-z0-9_]` boundaries, and the glossary is lowercased
    with awk's `tolower`. An accented letter (`á`, `ñ`) counts as a boundary, and
    whether `tolower` lowercases it depends on the awk and the locale.
