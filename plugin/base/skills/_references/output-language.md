# Output language — the language INSPIRE artifacts are written in

Every INSPIRE skill authors the artifacts it produces in the project's **declared
output language**, read from `output_language` in
[`00_bootstrap/project.md`](../../../inspire_kb/00_bootstrap/project.md). Default:
`en` (English). Set it with `/inspire-bootstrap language`.

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
- code identifiers, IDs, prefixes, and status-map **keys**;
- **heading keys** — see below;
- the **bold header-line markers** a validator reads (`**Status:**`,
  `**State:**`, `**Features:**`, `**Pattern:**`, `**Rationale:**`,
  `**Decision:**`, …) and their enum values.

Translate the **prose** — titles, descriptions, rationale, section bodies, review
findings addressed to the operator. Never the keys.

## Headings: a key, then a label

Every H2 and H3 a template ships is written `{key}: {label}`. The **key** is the
stable, English name a validator looks the section up by, and the **label** after
the first `: ` is free text in `output_language`. The templates ship the English
label:

```markdown
## Fields: Fields              ← the template, and an English project
## Fields: Campos              ← a Spanish project
### Breaking changes: Cambios incompatibles
```

- Write every templated heading as `{key}: {label}`, whatever the language: copy
  the key from the template verbatim, case and spacing included, and write the
  label in `output_language`.
- A heading translated *without* its key (`## Campos`) is not the section: the
  validators report the section as missing.
- The validators also read a bare `## Fields` as the key `Fields`, so a KB written
  before keys existed keeps validating. Write the full form in every new heading
  and in every heading you edit.
- A heading that is itself an identifier — a field's `### {field}`, an entity's
  `### [[module.entity|module::entity]]`, a keyed flow's `### AF-1: {label}` —
  keeps the shape its format already gives it.

An artifact's **identity** never lives in a heading or a title. It lives in a token
that is never translated: the frontmatter `id` of entities, actions and screens, and
the filename of features (`ANL-02.md`, whose H1 repeats it as `ANL-02: {label}`) and
ADRs (`adr-{slug}.md`), which is what every wikilink resolves.

## Exception: lessons (`98_lessons`)

One layer is **always authored in English**, regardless of `output_language`: the
lessons catalog (`inspire_kb/98_lessons/`, skill `inspire-lesson`). Its reader is not
the product team but the observer / the **cross-org INSPIRE core team**, which works in
English. Everything else here still applies — machine-read tokens stay verbatim. This
is the only knowledge-base layer exempt from the rule above.
