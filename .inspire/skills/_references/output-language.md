# Output language — the language INSPIRE artifacts are written in

Every INSPIRE skill authors the artifacts it produces in the project's **declared
output language**, read from `output_language` in
[`00_bootstrap/project.md`](../../../.inspire_kb/00_bootstrap/project.md). Default:
`en` (English). Set it with `/inspire_bootstrap language`.

## The rule

Write **every knowledge-base artifact** in `output_language`, whatever it is:
specs (`04_domain`), features (`03_features`), ADRs (`01_adr`), screen specs
(`05_screens`), spike learnings (`06_spikes`), tracker entries
(`99_tracker`), bootstrap docs (`00_bootstrap`) and the project `README.md`.

This holds regardless of two things it is deliberately independent of:

1. **The conversation language.** The operator may talk to you in any language;
   the artifacts you write stay in `output_language`. Reply to the operator in
   their language — but author the *files* in the project's.
2. **The product's own i18n.** The source code / UI may target many languages; the
   *knowledge base* is single-language so the shared human+agent context stays
   stable and diffable across regenerations.

Applies to new artifacts and to edits of existing ones. When `output_language`
changes, existing artifacts are **not** auto-translated — translate only on the
operator's request.

## What stays as-is regardless of language

Machine-read tokens are **not** translated — they are part of the schema the
validators enforce. Translating them breaks the graph. Keep verbatim:

- frontmatter **keys** and enum **values** (`kind`, `status`, `maturity`, the
  lifecycle states `draft`/`accepted`/`stable`, ADR maturities, …);
- wikilink **target slugs** and the file / directory names they resolve to;
- code identifiers, IDs, prefixes, and status-map **keys**.

Translate the **prose** — titles, descriptions, rationale, section bodies, review
findings addressed to the operator. Never the keys.
