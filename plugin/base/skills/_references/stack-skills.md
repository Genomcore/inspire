# Stack skills — the contract

A **stack skill** is an ordinary skill that carries one framework's — or one
language's, database's or library's — concrete coding conventions. It lives where
every skill lives, `.claude/skills/<name>/SKILL.md`, and is told apart by one
optional frontmatter field:

```yaml
stack: <id>     # one string, matching an id in stack.md `profiles:`
```

A skill **without** `stack` is served to every unit. A skill **with** `stack` is
served only to the units whose stack includes that id. The id can name anything a
project declares in `00_bootstrap/stack.md`'s `profiles:` — a framework (`nestjs`,
`react`), a language (`typescript`), a database (`postgres`) or a single library —
and the skill's own name does not matter. Stack skills are **data the coding agent
reads** — they never change the fact that the KB (`00_bootstrap` → `04_domain`) is
the source of truth.

`profiles:` is the only source of a project's stack: nothing is inferred from
`stack.md`'s headings, so a project with no `profiles:` gets no stack skill. A
framework skill's `language:` brings its language skill along (`profiles: [react,
nestjs]` also gets `typescript`), and a skill's `layer:` decides which units it
reaches: `frontend` or `backend` units only, every unit when it has no `layer:` or
any other value.

INSPIRE ships `inspire-code-react`, `inspire-code-nestjs`, `inspire-code-angular`,
`inspire-code-ios`, `inspire-code-android` (framework skills) and
`inspire-code-typescript` (a language skill). A project adds its own beside them.

## The composition axis

Stack skills that carry code conventions come in two kinds, told apart by the optional
`layer:` field:

| `layer:` | kind | carries |
|---|---|---|
| `frontend` · `backend` · `data` · `tooling` | **framework skill** | architecture: layering, tests, forbidden patterns, review focus, build commands — and the framework's own bindings, routes and persistence conventions |
| `language` | **language skill** | rendering: how a semantic type becomes a type / schema / column, how mapping tokens expand, how the language yields a declaration-only tree |

A framework skill names its language in a `language:` frontmatter field
(`inspire-code-react` and `inspire-code-nestjs` both declare `language: typescript`),
and **a unit built under a framework skill also gets the language skill it names**.
A language id may also be declared directly in `stack.md`'s `profiles:` — a library
surface with no framework has nothing else to name. A skill with no `layer:` (a
database, a library) is served to every unit whose stack names its id.

The axis exists because rendering is a property of the language, not of the
framework: a React surface and a NestJS service on the same TypeScript stack must
render `timestamp` identically or their wire contract is a lie. It is one third of a
three-way split, the other two of which live outside the stack skills entirely:

| part | home |
|---|---|
| universal semantic vocabulary + predicates | [`inspire-domain/references/type-mapping.md`](../inspire-domain/references/type-mapping.md) (runtime, stack-agnostic) |
| a project's own semantic types | [`00_bootstrap/semantic-types.md`](../../../inspire_kb/00_bootstrap/semantic-types.md) (project content) |
| per-target rendering | **the language skill** ([`inspire-code-typescript`](../inspire-code-typescript/SKILL.md) ships; a project adds its own) |

A project semantic type the language skill has no row for renders as its declared
**universal base type**. That is what makes the base type mandatory: it is the
guarantee that no declared type is ever a rendering hole.

## File format

### A framework skill

```markdown
---
name: <skill name>
description: "<Framework> stack conventions. Use when writing or testing code in a <Framework> package."
stack: <id>                # matches the id used in stack.md `profiles:`
layer: frontend | backend | data | tooling
language: <language id>    # the language skill this one composes with
---

## Layering
Where each kind of code lives; the architectural shape. Must also answer the
module-boundary questions: what a module exposes to its siblings, and where code
shared across modules (an external system's client and its generic helpers) lives —
decided at first use, never deferred to the second consumer.

## Test conventions
Test tools, what each test level means here, and how to run them.

## Test infrastructure       # optional — the probe recipe
How to check that the components `stack.md` declares are up and **healthy** before
the first red test, in both modes: attended asks the operator to start them,
unattended refuses and names the command. Never starts one.

## Forbidden patterns
Stack-specific anti-patterns beyond the universal authoring rules.

## Review focus
Extra review dimensions for this stack (e.g. api-contract, styling, a11y,
security). Each is a lens name + one line of what it hunts for.

## Quality gates
The concrete tools and rules that mechanically enforce this stack's share of
[`quality-gates.md`](quality-gates.md): which lint
rules, which coverage tooling, which of them are absolute vs ratcheted, and which
suppression syntax counts as this stack's escape hatch. A rule that does not hold for
this stack is listed as **dropped with its reason**, never left out silently. Names
tools and rules only — never an org's server or pipeline.

## Build & verify
The concrete lint / type-check / build / test commands, so nobody has to guess them.

## Bindings                # seed — how an action id becomes an invocable surface
The convention that turns `{module}::{entity}::{verb}` into a route / command / tool
name, and the actor constraint into a guard. Derived, never authored per action.
A skill whose surface exposes nothing says so.

## Routes                  # seed — UI skills only
How a screen's `module:` + `screen:` frontmatter becomes a route, and what a surface
shell contributes. Never derived from a file path or from the screen's id string.

## Persistence             # seed — how state is stored, or "not applicable"
ORM, entity→table and field→column naming, keys, and the append-shaped migration
rule. A surface that stores nothing states that instead.

## Declaration-only tree
How this stack yields a bodies-stripped tree for the test phase's worktree.
**Required on a language skill** (it owns the recipe); on a framework skill it is
an optional addendum for what the stripping loses here.

## References              # optional — progressive disclosure
Pointers to deeper files under the skill's `references/`, read only when needed.
```

### A language skill

```markdown
---
name: <skill name>
description: "<Language> conventions. Use when writing or testing <Language> code."
stack: <language id>       # e.g. typescript
layer: language
---

## Rendering
One row per universal semantic type → this language's type, schema fragment and
column type.

## Mapping tokens
How each `Mapping`-column token expands here. The token meanings are universal and
live in `type-mapping.md`; only expansions belong here.

## Project semantic types
The base-type fallback rule, and how a project adds an explicit row.

## Engine notes
Where the rendering assumes a database engine or runtime, and how to move it.

## Declaration-only tree
The recipe: how this language emits signatures without bodies.
```

A language skill carries **no** `## Layering`, `## Test conventions`,
`## Forbidden patterns`, `## Review focus` or `## Build & verify` — those are
architecture, and architecture is the framework skill's.

## Seeds

`## Bindings`, `## Routes` and `## Persistence` are **project-owned conventions**,
not rules INSPIRE enforces. The shipped `react` and `nestjs` skills carry
defaults — a REST shape, a route shape, an ORM — purely as **seeds**: a starting
convention so a fresh project is not asked to invent one. Every consumer reads
whatever the skill declares, so editing a seed changes the emitted code and
nothing else. An undeclared convention is a readiness refusal for that surface,
never a fallback to something INSPIRE picked.

**Your edit to a seed survives `/inspire:update`.** These files *are* shipped, so
the guarantee is the merge classifier's, not the never-shipped case below: an
update hashes each file against the manifest of the version it is upgrading *from*.
Bytes that differ from that hash are your edit — if INSPIRE did not also change the
file in the new release, it is **kept** untouched; if both sides changed it, the
update **asks**. It never silently replaces an edited stack skill.

## Authoring rules for stack skills

- **Keep them lean and declarative** — a stack skill states conventions; it is not a
  tutorial. Deep material goes in its `references/` and loads on demand, linked from
  its `## References` section.
- **Framework conventions only, never domain or org policy.** "Business logic goes
  in services" is a stack rule; "our Jira branch names" or "our private registry
  login" is org policy and belongs in the project's `CLAUDE.md`, not here.
- **No product vocabulary.** A skill that a different React project could not reuse
  verbatim has leaked something that isn't a framework convention.
- **One `stack` id per skill.** A skill that should reach two stacks is two skills,
  or no `stack` at all.
- **A language skill stays language-wide.** If a rule only holds for one framework
  on that language, it belongs in the framework skill: two frameworks sharing a
  language must both be able to read every line of it.

> **A stack skill you author survives `/inspire:update`.** An update classifies
> content against the manifest of the version it is upgrading *from*, and a skill
> INSPIRE never shipped appears in no manifest, so it classifies as yours and is
> neither replaced nor deleted. Keep yours in version control anyway, as you would
> any other source file.

See [`stack-skill-example.md`](stack-skill-example.md) for an annotated skeleton.
