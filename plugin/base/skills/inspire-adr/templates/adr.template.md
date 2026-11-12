---
# faces: [face-a]       # global ADRs only: the face ids this decision affects
# bundles: [bundle-a]   # global ADRs only: the bundle ids it affects
# omit both = the whole project; a module or face ADR carries neither (its _adr/ gives the scope)
# see `.claude/skills/_references/face-scope.md`
---

# {Title}

**Status:** design
**Modules affected:** [module-a]({path-to-module-a}.module.md), [module-b]({path-to-module-b}.module.md)
**Rationale:** [adr-{slug}.rationale]({slug}.adr.rationale.md)
<!-- Supersedes: [adr-{old-slug}]({old-slug}.adr.md) — optional; add only when this ADR supersedes a prior one.
     Links are relative Markdown links, per .claude/skills/_references/kb-links.md. -->
<!-- Status maturity ladder: design | prototyped | implemented | superseded by [adr-{new-slug}]({new-slug}.adr.md) | rejected.
     design = the design workspace (features + screen spec + horizontal prototype + specs).
     prototyped = validated in an EXTERNAL functional prototype (a vertical spike repo,
       NOT the horizontal prototype) — add: **Prototype:** `repo-or-env` — what it validated. -->

## ADR2: Decision
What we decided, as one or a few imperative statements. The reasons go in the rationale.
