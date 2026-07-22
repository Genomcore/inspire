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
  - [`theme.md`](theme.md) — the **default design-system template**: fonts, the
    color palette + status map, density and layout tokens. At install it is copied
    to [`05_screens/design-system.md`](../05_screens) (the project's live design
    system, edited via `/inspire_bootstrap design-system`); `theme.md` stays as the
    reusable default.

Both start seeded with a **sensible default** (the stack + theme of the OpenBIMS
reference implementation). Reconfigure them for your project with
`/inspire_bootstrap` — every downstream layer (specs, screen specs, the prototype,
production code) builds on what is declared here.

> Changing a load-bearing choice here (a framework, the primary color) is an
> architectural decision — record it as an ADR in [`01_adr`](../01_adr) and update
> these files together.
