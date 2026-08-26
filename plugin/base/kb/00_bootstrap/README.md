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
    `/inspire_bootstrap` when an interview settles a naming question — never the
    agent's taxonomy. It ships **empty**, meaning header + separator and zero data
    rows; an empty list binds nothing, which is the honest state of a project that
    has settled no naming question yet. R4 of
    [`.claude/skills/_references/writing-style.md`](../../.claude/skills/_references/writing-style.md)
    binds every layer's prose to it.
  - [`semantic-types.md`](semantic-types.md) — the **project's own semantic types**:
    the types this project adds to the universal vocabulary defined in
    [`.claude/skills/inspire-domain/references/type-mapping.md`](../../.claude/skills/inspire-domain/references/type-mapping.md).
    Every row carries a mandatory **universal base type**, so a type declared here
    always renders — a language profile with no explicit row for it falls back to that
    base type. Like the glossary it ships **empty**: most projects need no type of
    their own, and an empty table says exactly that.
  - [`theme.md`](theme.md) — the **default design-system template**: fonts, the
    color palette + status map, density and layout tokens. At install it is copied
    to [`05_screens/design-system.md`](../05_screens) (the project's live design
    system, edited via `/inspire_bootstrap design-system`); `theme.md` stays as the
    reusable default.
  - [`surfaces.md`](surfaces.md) — the **surface roster**, the one optional file
    here: absent in a suite-of-one (the default a bare template ships with), it is
    authored — never seeded — by `/inspire_surface add` the moment a second surface
    is declared. Owned entirely by `inspire-surface`. See
    [`.claude/skills/_references/surface-scope.md`](../../.claude/skills/_references/surface-scope.md)
    for what a surface is and how scope resolves.

Both `stack.md` and `theme.md` start seeded with a **sensible default** (the stack + theme of the OpenBIMS
reference implementation). Reconfigure them for your project with
`/inspire_bootstrap` — every downstream layer (specs, screen specs, the prototype,
production code) builds on what is declared here.

> Changing a load-bearing choice here (a framework, the primary color) is an
> architectural decision — record it as an ADR in [`01_adr`](../01_adr) and update
> these files together.
