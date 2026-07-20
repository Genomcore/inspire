# `/source` — the production monorepo

This is the root of the **production code** — the actual product you ship, laid
out as a monorepo. It lives at the repo root (product side, non-dot), alongside
the horizontal prototype at [`/prototype`](../prototype).

It is the last layer in the INSPIRE flow: intent and contracts are worked out in
the knowledge base and de-risked in prototypes, then **realized here**.

- Driven by the KB: features ([`.inspire_kb/02_features`](../.inspire_kb/02_features)),
  specs ([`.inspire_kb/04_domain`](../.inspire_kb/04_domain)) and screen specs
  ([`.inspire_kb/05_screens`](../.inspire_kb/05_screens)) define *what* to build and what
  "correct" means; the shared tech context lives in
  [`.inspire_kb/00_bootstrap`](../.inspire_kb/00_bootstrap).
- Informed by prototypes: what the horizontal prototype and the external vertical
  spikes clarified ([`.inspire_kb/03_prototypes`](../.inspire_kb/03_prototypes))
  flows into the design before it's built here.
- Governed by ADRs: an ADR reaches `implemented` maturity
  ([`.inspire_kb/01_adr`](../.inspire_kb/01_adr)) when it is realized in this
  codebase — the point at which the decision becomes immutable (supersede to
  change).

> Template note: this folder starts empty (just this README). Scaffold the
> production monorepo here — packages/apps, build tooling, and its own tech-stack
> docs — when the project moves from prototype to build.
