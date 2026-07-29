# Stack / theme elaboration comparison

The bootstrap layer (`00_bootstrap/stack.md`, `00_bootstrap/theme.md`) is **not**
seeded blindly from a scanned codebase. A scanned repo is often a **prototype, a
spike, or a throwaway** — its stack may be less concrete than the one the project
already defined, and its theme may be rougher than the live design system. Copying
*down* would be a regression.

So extract **compares elaboration** between the source and the current KB, then
**recommends** migrate-or-keep. It never applies a bootstrap change automatically,
and it always asks.

## The rule

> Recommend migrating a bootstrap artifact **only** when the source is *both* more
> **elaborated** (more complete, more specific) **and** more **production-real**
> (an actual product decision, not a scaffold or experiment) than what
> `00_bootstrap` currently declares. Otherwise, keep the local and say why.

## Elaboration signals

Score the source and the KB current on the same axes, then compare.

**Stack (`stack.md`):**

| More elaborated / real | Less elaborated / throwaway |
|------------------------|------------------------------|
| Pinned, coherent versions; lockfile committed | `latest`/unpinned; no lockfile |
| Production infra (Dockerfile, CI, migrations, env config) | none, or `create-*-app` defaults untouched |
| Load-bearing choices made deliberately (DB, framework, runtime) | placeholder/in-memory store, "TODO pick a DB" |
| Consistent across the repo | mixed experiments, dead alternatives side by side |

**Theme (`theme.md` / live `design-system.md`):**

| More elaborated / real | Less elaborated / throwaway |
|------------------------|------------------------------|
| A real token system (roles: primary/accent/status, scale, density) | a handful of ad-hoc hex values |
| Consistent, named tokens reused across the UI | inline styles, one-off colors per component |
| Considered typography + layout scale | framework defaults, no design intent |

Remember: the **live** design system is `05_screens/design-system.md` (seeded from
`theme.md` at install and owned there). Compare against **that**, not the template
`theme.md`, when judging theme.

## Recommendation matrix

| Source vs KB | Recommendation |
|--------------|----------------|
| Source clearly more elaborated **and** production-real | **Recommend migrate.** Present the diff; on approval, route through `/inspire_bootstrap stack` / `theme` (or `/inspire_screens design-system` for the live one). |
| Comparable | **Keep local.** Note any *specific* concrete detail worth lifting (a pinned version, one status color) as an à-la-carte suggestion — not a wholesale swap. |
| Source less elaborated (prototype/spike) | **Keep local, don't migrate.** Say so plainly: the source is a scaffold, not a decision. |
| KB is still the seeded default, source is real | **Recommend migrate** — the default was a placeholder; the source reflects an actual product. |

## Load-bearing changes are ADRs

Per `/inspire_bootstrap`'s rules, **replacing a load-bearing choice** — a framework,
the runtime, the primary database, or the primary color — is an architectural
decision. If a recommended migration touches one, surface it and offer to chain
`/inspire_workspace adr create` to record the decision, rather than editing
`stack.md` / `theme.md` silently. Adding an incidental tool is a plain edit.

## Output

`fingerprint` (and the bootstrap-verdicts step of `scan`'s consolidation) ends the
bootstrap section with a short, explicit verdict per artifact — never a silent seed:

```markdown
## Bootstrap comparison

### stack.md — recommend: keep local
Source is a Vite scaffold with an in-memory store and unpinned deps; the KB
already declares NestJS + PostgreSQL with pinned versions. The source is less
elaborated — no migration.

### design-system.md — recommend: migrate (needs ADR)
Source carries a full token system (primary/accent/status roles, type scale,
density) vs the KB's seeded default. More elaborated and production-real. The
primary color change is load-bearing → chain `/inspire_workspace adr create`
before applying via `/inspire_screens design-system`.
```
