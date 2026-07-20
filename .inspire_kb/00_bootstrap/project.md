---
kind: bootstrap-project
status: default          # default (seeded) → set per project via /inspire_bootstrap
output_language: en      # ISO 639-1 code (or plain name) — the language ALL KB artifacts are written in
---

# Project conventions

Project-wide conventions the whole knowledge base inherits. The foundation layer
every skill reads before authoring. Configure with `/inspire_bootstrap`.

## Output language

`output_language` (frontmatter above) is the **single language every INSPIRE skill
writes its artifacts in** — specs, features, ADRs, screen specs, prototype
learnings, the tracker, bootstrap docs and the project `README.md`. Default: `en`
(English). Change it with `/inspire_bootstrap language`.

It is **deliberately independent** of two other things:

- **The conversation language.** You can talk to Claude in any language; the KB
  artifacts are still authored in `output_language`. (Claude replies to you in your
  language, but writes the files in the project's.)
- **The product's own i18n.** The source code / UI may ship many languages; the
  *knowledge base* is single-language so the shared human+agent context stays
  stable and diffable across regenerations of the code.

Machine-read tokens are never translated — frontmatter keys and enum values
(`kind`, `status`, `maturity`, lifecycle states), wikilink target slugs, file and
directory names, code identifiers, status-map keys. Only prose is written in
`output_language`. See
[`.claude/skills/_references/output-language.md`](../../.claude/skills/_references/output-language.md)
for the full rule the skills follow.
