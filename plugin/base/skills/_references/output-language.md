# Output language — the language INSPIRE artifacts are written in

Every INSPIRE skill authors the artifacts it produces in the project's **declared
output language**, read from `output_language` in
[`00_bootstrap/project.md`](../../../inspire_kb/00_bootstrap/project.md). Default:
`en` (English). Set it with `/inspire-bootstrap language`.

## The rule

Write **every knowledge-base artifact** in `output_language`, whatever it is:
everything under `01_spec` (modules, features, entities and actions, ADRs, bundles,
faces, screens, processes and the design system), spike learnings (`06_spikes`),
tracker entries (`99_tracker`), bootstrap docs (`00_bootstrap`) and the project
`README.md`.

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
- the **section ids** that open headings (`ENT4`) — see below;
- the **bold header-line markers** a validator reads (`**Status:**`,
  `**State:**`, `**Features:**`, `**Pattern:**`, `**Rationale:**`,
  `**Decision:**`, `**Effect:**`, …) and their enum values;
- the **line markers and sentinels** of the keyed formats: a field's
  `Constraints:` line, the declared-none body `None.`, entry keys (`I1`, `P1`,
  `B1`, `Q1`, `AC-1`, `AF-1`) and the heads after them (`unique(email)`);
- the **vocabulary cells** of a table: a touch (`read`, `written`, `write`), a
  `Required` answer (`yes`, `no`), a region's `Fill` and `Accepts`, a render row's
  `Align` and `Narrow`, a binding's outcome (`→ [[…]]`, ``state `key` ``,
  ``refresh `key` ``, ``param `key` ``).

A table's **column headers** are prose: translate them (`| Campo | Tipo | Notas |`).
The validators read a table's columns by position, so its columns keep the order
the template gives them.

Translate the **prose** — titles, descriptions, rationale, section bodies, review
findings addressed to the operator. Never the keys.

## Headings: a section id, then a label

Every H2 and H3 a template ships is written `{ID}: {label}`. The **section id** —
capital letters then digits, `ENT4`, `ADR3`, `SCR7` — is what a validator looks the
section up by, and it never changes. The **label** after the first `: ` is free text
in `output_language`. The templates ship the English label:

```markdown
## ENT4: Fields                ← the template, and an English project
## ENT4: Campos                ← a Spanish project
### ADR4: Cambios incompatibles
```

- Copy the id from the template verbatim and write the label in `output_language`,
  whatever the language. Each format has its own ids (`ENT` entity, `ACT` action,
  `UC` use case, `ADR` decision and rationale, `SCR` screen, `PAT` pattern, `CMP`
  component, `LAY` layout, `MOD` module hub, `SPK` spike), numbered in template
  order. An id from another format's template is not this format's section.
- A heading without its id (`## Campos`) is not the section: the validators report
  the section as missing.
- The validators also read the legacy English name (`## Fields`, `## Fields: Campos`)
  as its section, so a KB written before ids existed keeps validating. Write the id
  in every new heading and in every heading you edit.
- A heading that is itself an identifier — a field's `### {field}`, an entity's
  `### [[module.entity|module::entity]]`, a keyed flow's `### AF-1: {label}`, a
  screen's Render region — keeps the shape its format already gives it.

An artifact's **identity** never lives in a heading or a title. It lives in a token
that is never translated: the frontmatter `id` of entities, actions, screens and
processes, and the file name, without its typed extension, of everything else —
features (`ANL-02.feature.md`, whose H1 repeats it as `ANL-02: {label}`), modules,
faces, bundles and ADRs (`{slug}.adr.md`, id `adr-{slug}`). That id is what every
wikilink resolves.

## Exception: lessons (`98_lessons`)

One layer is **always authored in English**, regardless of `output_language`: the
lessons catalog (`inspire_kb/98_lessons/`, skill `inspire-lesson`). Its reader is not
the product team but the observer / the **cross-org INSPIRE core team**, which works in
English. Everything else here still applies — machine-read tokens stay verbatim. This
is the only knowledge-base layer exempt from the rule above.
