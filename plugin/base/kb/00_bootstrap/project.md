---
kind: bootstrap-project
status: default          # default (seeded) → set per project via /inspire-config
---

# Project conventions

Project-wide conventions the whole knowledge base inherits. The foundation layer
every skill reads before authoring. Configure with `/inspire-config`.

## Output language

`output_language` is the **single language every INSPIRE skill writes its artifacts
in** — specs, features, ADRs, screen specs, prototype learnings, the tracker,
bootstrap docs and the project `README.md`. It is a key of the spec config,
`.inspire/config.json`, beside the product roots. Default: `en` (English). Change it
with `/inspire-config language`.

It is **deliberately independent** of two other things:

- **The conversation language.** You can talk to Claude in any language; the KB
  artifacts are still authored in `output_language`. (Claude replies to you in your
  language, but writes the files in the project's.)
- **The product's own i18n.** The source code / UI may ship many languages; the
  *knowledge base* is single-language so the shared human+agent context stays
  stable and diffable across regenerations of the code.

Changing it translates nothing: the artifacts already written stay in the language
they were written in, and translating them is a refactor of the knowledge base.

Machine-read tokens are never translated — frontmatter keys and enum values
(`kind`, `status`, `maturity`, lifecycle states), link paths, file and
directory names, code identifiers, status-map keys. Only prose is written in
`output_language`. See
`.claude/skills/_references/output-language.md`
for the full rule the skills follow.
