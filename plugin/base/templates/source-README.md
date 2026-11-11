# `/source` — the production monorepo

This is the root of the **production code** — the actual product you ship, laid
out as a monorepo. It lives at the repo root (product side, non-dot), alongside
the horizontal prototype at [`/prototype`](../prototype).

It is the last layer in the INSPIRE flow: intent and contracts are worked out in
the knowledge base and de-risked in prototypes, then **realized here**.

- Driven by the KB: the specification ([`inspire_kb/01_spec`](../inspire_kb/01_spec)),
  with its features, domain, bundles, faces, screens and processes, defines *what* to
  build and what "correct" means; the shared tech context lives in
  [`inspire_kb/00_bootstrap`](../inspire_kb/00_bootstrap).
- Informed by prototypes: what the horizontal prototype clarified (now in the
  specs) and what the external spikes de-risked ([`inspire_kb/06_spikes`](../inspire_kb/06_spikes))
  flows into the design before it's built here.
- Governed by ADRs: an ADR (`*.adr.md` under
  [`inspire_kb/01_spec`](../inspire_kb/01_spec)) reaches `implemented` maturity when
  it is realized in this
  codebase — the point at which the decision becomes immutable (supersede to
  change).

> Template note: this folder starts empty (just this README). Scaffold the
> production monorepo here — packages/apps, build tooling, and its own tech-stack
> docs — when the project moves from prototype to build. Packages map onto the
> `package:` paths each face (`{face}.face.md`) and bundle (`{bundle}.bundle.md`)
> declares, relative to this root. Faces never import each other directly, and
> sharing flows through bundles and the design system instead. See
> [`.claude/skills/_references/face-scope.md`](../.claude/skills/_references/face-scope.md)
> for the full rules.
>
> Location is configurable: this is `source_root` (default `source/`) in
> [`00_bootstrap/stack.md`](../inspire_kb/00_bootstrap/stack.md). A brownfield project
> installing in place sets `source_root: .` (the repo root is the code), and this
> folder is not created.
