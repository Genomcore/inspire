# 00 · Bootstrap

The **foundation** every other layer stands on: the basic building blocks of the
stack and the basic design system (theme). This is the common ground each agent
reads before working — the base context the rest of the KB assumes.

- **Skill:** `inspire-bootstrap` (configure these artifacts).
- **Contents:**
  - [`stack.md`](stack.md) — the **tech stack**: languages, runtimes, frameworks,
    the shared component layer, data/messaging, and the prototype's mock-data
    stack. What the product is built with.
  - [`theme.md`](theme.md) — the **design system / theme**: fonts, the color
    palette + status map, density and layout tokens. What the product looks like.

Both start seeded with a **sensible default** (the stack + theme of the OpenBIMS
reference implementation). Reconfigure them for your project with
`/inspire_bootstrap` — every downstream layer (specs, UISpecs, the prototype,
production code) builds on what is declared here.

> Changing a load-bearing choice here (a framework, the primary color) is an
> architectural decision — record it as an ADR in [`01_adr`](../01_adr) and update
> these files together.
