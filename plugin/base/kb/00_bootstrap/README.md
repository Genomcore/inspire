# 00 · Bootstrap

The **foundation** every other layer stands on: the basic building blocks of the
stack and the basic design system (theme). This is the common ground each agent
reads before working — the base context the rest of the KB assumes.

- **Skill:** `inspire-bootstrap` (configure these artifacts).
- **Contents:**
  - [`project.md`](project.md) — **project conventions** the whole KB inherits,
    chiefly the `output_language` every skill writes its artifacts in (default
    English — independent of the conversation language and of the product's own
    i18n).
  - [`stack.md`](stack.md) — the **tech stack** and its **shape**: languages,
    runtimes, frameworks, the shared component layer, data/messaging, the
    prototype's mock-data stack, plus how the product is laid out
    (frontend / backend / monorepo · web / mobile · database provisioning +
    local dev DB). What the product is built with.
  - [`glossary.md`](glossary.md) — the **term list**: one concept, one word. Each
    row carries the approved term, the synonyms it displaces and a one-line
    definition. The approved term is the operator's own language, written here by
    `/inspire-bootstrap` when an interview settles a naming question — never the
    agent's taxonomy. It ships **empty**, meaning header + separator and zero data
    rows; an empty list binds nothing, which is the honest state of a project that
    has settled no naming question yet. R4 of
    `.claude/skills/_references/writing-style.md`
    binds every layer's prose to it.
  - [`style-tokens.md`](style-tokens.md) — the project's own **R6 and R7 tokens**:
    words that narrate history and intensifiers, in the project's `output_language`.
    `prose-style.sh` flags them beside its built-in English lists, and outside
    English they are the only words R6 and R7 check. A token belongs here only if it
    almost never states present behavior. Written by `/inspire-bootstrap`; it ships
    **empty**, like the glossary.
  - [`semantic-types.md`](semantic-types.md) — the **project's own semantic types**:
    the types this project adds to the universal vocabulary defined in
    `.claude/skills/inspire-domain/references/type-mapping.md`.
    Every row carries a mandatory **universal base type**, so a type declared here
    always renders — a language profile with no explicit row for it falls back to that
    base type. Like the glossary it ships **empty**: most projects need no type of
    their own, and an empty table says exactly that.
  - The default design-system template, `theme.md` and `theme.tokens.json`, lives
    with the design system it seeds, in
    [`01_spec/_design-system/`](../01_spec/_design-system). Faces and bundles
    declare their own packaging in their own files under `01_spec/`; there is no
    roster here.

Both `stack.md` and the theme start seeded with a **sensible default** (the stack + theme of the OpenBIMS
reference implementation). Reconfigure them for your project with
`/inspire-bootstrap` — every downstream layer (specs, screen specs, the prototype,
production code) builds on what is declared here.

> Changing a load-bearing choice here (a framework, the primary color) is an
> architectural decision — record it as an ADR in [`01_spec/_adr`](../01_spec/_adr) and update
> these files together.
