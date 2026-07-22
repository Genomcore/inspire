# inspire-code stack profiles — the contract

`inspire-code` is stack-agnostic. A **stack profile** is a thin, declarative file
that layers one framework's concrete conventions onto the skill's generic
dimensions. Profiles are **data the skill reads** — they never change the fact that
the KB (`00_bootstrap` → `04_domain`) is the source of truth, and they load
**on demand**: only the frameworks a project declares, only when a subcommand runs.

## Resolution

At the start of any subcommand, `inspire-code` resolves the active profile set from
[`00_bootstrap/stack.md`](../../../../.inspire_kb/00_bootstrap/stack.md):

1. **Deterministic** — if `stack.md`'s frontmatter declares `profiles: [<id>, …]`,
   use that set. `/inspire_bootstrap stack` maintains this line.
2. **Inference fallback** — otherwise infer from the stack sections
   (`## Frontend: React` → `react`; `## Backend: NestJS` → `nestjs`; …).

Then read **only** `profiles/{id}.md` for each resolved id. A framework the project
does not use never loads. If a declared framework has no profile file, the
subcommand runs **purely generic** and says so — offering `/inspire_bootstrap` to
scaffold one. Missing profiles never block.

Profiles are **composable**: a React + NestJS monorepo loads both, and each
subcommand applies whichever profile owns the layer it is working in.

## File format

```markdown
---
kind: inspire-code-profile
id: <slug>                 # matches the id used in stack.md `profiles:`
layer: frontend | backend | data | tooling
---

## Layering
Where each kind of code lives; the architectural shape. Feeds review Phase 1
(architecture) and the implementation shape in `tdd`.

## Test conventions
Test tools, what each test level means here, and how to run them. Feeds `tdd` and
review Phase 4.

## Forbidden patterns
Stack-specific anti-patterns beyond the universal authoring rules. Feeds `review`
and the authoring rules in `tdd`.

## Review focus
Extra dimensions `review` adds to its fan-out for this stack (e.g. api-contract,
styling, a11y, security). Each is a lens name + one line of what it hunts for.

## Build & verify
The concrete lint / type-check / build / test commands. `fix-build`, `review`, and
`debug` use these instead of guessing.

## References              # optional — progressive disclosure
Pointers to deeper files under `profiles/{id}/references/`, read only when needed.
```

## Section → generic-dimension mapping

| Profile section | Consumed by |
|---|---|
| `## Layering` | `review` Phase 1 · `tdd` implementation shape |
| `## Test conventions` | `tdd` · `review` Phase 4 |
| `## Forbidden patterns` | `review` · `tdd` authoring rules |
| `## Review focus` | `review` fan-out (extra dimensions) |
| `## Build & verify` | `fix-build` · `review` build step · `debug` |

## Authoring rules for profiles

- **Keep them lean and declarative** — a profile states conventions; it is not a
  tutorial. Deep material goes in `profiles/{id}/references/` and loads on demand.
- **Framework conventions only, never domain or org policy.** "Business logic goes
  in services" is a profile rule; "our Jira branch names" or "our private registry
  login" is org policy and belongs in the project's `CLAUDE.md`, not here.
- **No product vocabulary.** A profile that a different React project could not
  reuse verbatim has leaked something that isn't a framework convention.
- **The template ships lean defaults** (`react`, `nestjs`) matching the seeded
  reference stack; a fork adds or replaces profiles for its own frameworks by
  dropping `profiles/{id}.md` here (versioned in `.inspire/`, like all runtime).

See [`_example.md`](_example.md) for an annotated skeleton.
