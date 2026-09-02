# inspire-code stack profiles — the contract

`inspire-code` is stack-agnostic. A **stack profile** is a thin, declarative file
that layers one framework's — or one language's — concrete conventions onto the
skill's generic dimensions. Profiles are **data the skill reads** — they never
change the fact that the KB (`00_bootstrap` → `04_domain`) is the source of truth,
and they load **on demand**: only what a project declares, only when a subcommand
runs.

## The composition axis

Profiles come in two kinds, told apart by `layer:`:

| `layer:` | kind | carries |
|---|---|---|
| `frontend` · `backend` · `data` · `tooling` | **framework profile** | architecture: layering, tests, forbidden patterns, review focus, build commands — and the framework's own bindings, routes and persistence conventions |
| `language` | **language profile** | rendering: how a semantic type becomes a type / schema / column, how mapping tokens expand, how the language yields a declaration-only tree |

A framework profile names its language in a `language:` frontmatter field
(`react.md` and `nestjs.md` both declare `language: typescript`), and **resolving a
framework profile pulls its language profile in**. A language profile may also be
declared directly in `stack.md`'s `profiles:` — a library surface with no framework
has nothing else to name — and resolving the same id twice loads it once.

The axis exists because rendering is a property of the language, not of the
framework: a React surface and a NestJS service on the same TypeScript stack must
render `timestamp` identically or their wire contract is a lie. It is one third of a
three-way split, the other two of which live outside the profiles entirely:

| part | home |
|---|---|
| universal semantic vocabulary + predicates | [`inspire-domain/references/type-mapping.md`](../../inspire-domain/references/type-mapping.md) (runtime, stack-agnostic) |
| a project's own semantic types | [`00_bootstrap/semantic-types.md`](../../../../inspire_kb/00_bootstrap/semantic-types.md) (project content) |
| per-target rendering | **the language profile** ([`typescript.md`](typescript.md) ships; a project adds its own) |

A project semantic type the language profile has no row for renders as its declared
**universal base type**. That is what makes the base type mandatory: it is the
guarantee that no declared type is ever a rendering hole.

## Resolution

At the start of any subcommand, `inspire-code` resolves the active profile set from
[`00_bootstrap/stack.md`](../../../../inspire_kb/00_bootstrap/stack.md):

1. **Deterministic** — if `stack.md`'s frontmatter declares `profiles: [<id>, …]`,
   use that set. `/inspire-bootstrap stack` maintains this line.
2. **Inference fallback** — otherwise infer from the stack sections
   (`## Frontend: React` → `react`; `## Backend: NestJS` → `nestjs`; …).

Then read **only** `profiles/{id}.md` for each resolved id, **plus the language
profile each resolved framework profile names** in its `language:` field. A
framework the project does not use never loads. If a declared framework has no
profile file, the subcommand runs **purely generic** and says so — offering
`/inspire-bootstrap` to scaffold one. Missing profiles never block.

Profiles are **composable**: a React + NestJS monorepo loads both, and each
subcommand applies whichever profile owns the layer it is working in — or, when a
surface roster exists, whichever profile the target surface declares in its
`Profiles` field (`inspire-code` SKILL.md, *Surfaces and the monorepo*).

### The one exception: emanation refuses a missing language profile

"Missing profiles never block" holds for every **attended** subcommand — `tdd`,
`review`, `debug`, `fix-build`, `fix-vulns` — where an operator is present to judge a
generic answer. Emanation has no operator in the loop, so it draws the line
differently: **`emanate plan` refuses a unit whose stack declares no language
profile**, and reports it as a readiness error naming the missing file.

The reason is that the two failures are not the same size. A missing *framework*
profile costs generic-but-correct architecture. A missing *language* profile means
nothing knows what `timestamp` renders as, and an unattended run would emit a guess
that compiles — a silent wrong contract, discovered downstream. A spec gap is a
defect of the readiness check, not something to paper over at emission time. The
refusal is enforced by `emanate plan`; this section is where the rule is declared.

The same refusal covers a project semantic type with neither a base type nor a row
in the language profile: declared, unrenderable, and therefore not ready.

## File format

### A framework profile

```markdown
---
kind: inspire-code-profile
id: <slug>                 # matches the id used in stack.md `profiles:`
layer: frontend | backend | data | tooling
language: <language id>    # the language profile this one composes with
---

## Layering
Where each kind of code lives; the architectural shape. Must also answer the
module-boundary questions: what a module exposes to its siblings, and where code
shared across modules (an external system's client and its generic helpers) lives —
decided at first use, never deferred to the second consumer. Feeds review Phase 1
(architecture) and the implementation shape in `tdd`.

## Test conventions
Test tools, what each test level means here, and how to run them. Feeds `tdd` and
review Phase 4.

## Test infrastructure       # optional — the probe recipe
How to check that the components `stack.md` declares are up and **healthy** before
the first red test, in both modes: attended asks the operator to start them,
unattended refuses and names the command. Never starts one. `emanate plan` tests
for this section's presence (`PR-22`); `emanate run` executes it at t=0.

## Forbidden patterns
Stack-specific anti-patterns beyond the universal authoring rules. Feeds `review`
and the authoring rules in `tdd`.

## Review focus
Extra dimensions `review` adds to its fan-out for this stack (e.g. api-contract,
styling, a11y, security). Each is a lens name + one line of what it hunts for.

## Quality gates
The concrete tools and rules that mechanically enforce this stack's share of
[`_references/quality-gates.md`](../../_references/quality-gates.md): which lint
rules, which coverage tooling, which of them are absolute vs ratcheted, and which
suppression syntax counts as this stack's escape hatch. A rule that does not hold for
this stack is listed as **dropped with its reason**, never left out silently. Names
tools and rules only — never an org's server or pipeline.

## Build & verify
The concrete lint / type-check / build / test commands. `fix-build`, `review`, and
`debug` use these instead of guessing.

## Bindings                # seed — how an action id becomes an invocable surface
The convention that turns `{module}::{entity}::{verb}` into a route / command / tool
name, and the actor constraint into a guard. Derived, never authored per action.
A profile whose surface exposes nothing says so.

## Routes                  # seed — UI profiles only
How a screen's `module:` + `screen:` frontmatter becomes a route, and what a surface
shell contributes. Never derived from a file path or from the screen's id string.

## Persistence             # seed — how state is stored, or "not applicable"
ORM, entity→table and field→column naming, keys, and the append-shaped migration
rule. A surface that stores nothing states that instead.

## Declaration-only tree
How this stack yields a bodies-stripped tree for the test phase's worktree.
**Required on a language profile** (it owns the recipe); on a framework profile it is
an optional addendum for what the stripping loses here.

## References              # optional — progressive disclosure
Pointers to deeper files under `profiles/{id}/references/`, read only when needed.
```

### A language profile

```markdown
---
kind: inspire-code-profile
id: <language id>          # e.g. typescript
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

A language profile carries **no** `## Layering`, `## Test conventions`,
`## Forbidden patterns`, `## Review focus` or `## Build & verify` — those are
architecture, and architecture is the framework profile's.

## Section → consumer mapping

| Profile section | Kind | Consumed by |
|---|---|---|
| `## Layering` | framework | the quality overseer (architecture) · `tdd` implementation shape |
| `## Test conventions` | framework | the tester — **including the test paths harvest accepts** · the quality overseer |
| `## Test infrastructure` | framework | the probe recipe for the components `stack.md` declares: `tdd`'s precondition · `emanate plan`'s `preflight` (which tests for the section's **presence**, never scraping its prose) · `emanate run`'s t=0 refusal |
| `## Forbidden patterns` | framework | the implementer (authoring rules) · the quality overseer |
| `## Review focus` | framework | `review` fan-out (extra dimensions) |
| `## Quality gates` | framework | `/inspire-bootstrap stack` (installs them) · `review` (missing-gate findings) |
| `## Build & verify` | framework | `fix-build` · `review` build step · `debug` |
| `## Bindings` | framework | the contracter (emitted surface) · derived binding claims · `emanate gate` |
| `## Routes` | framework (UI) | the contracter (route table) · screen nav claims |
| `## Persistence` | framework | the contracter (model + migration skeleton) · the implementer |
| `## Rendering` · `## Mapping tokens` · `## Project semantic types` · `## Engine notes` | language | the contracter (every emitted signature, schema and column) |
| `## Declaration-only tree` | both | the test phase's worktree packing |

## Seeds

`## Bindings`, `## Routes` and `## Persistence` are **project-owned conventions**,
not rules INSPIRE enforces. The shipped `react` and `nestjs` profiles carry
defaults — a REST shape, a route shape, an ORM — purely as **seeds**: a starting
convention so a fresh project is not asked to invent one. Every consumer reads
whatever the profile declares, so editing a seed changes the emitted code and
nothing else. An undeclared convention is a readiness refusal for that surface,
never a fallback to something INSPIRE picked.

**Your edit to a seed survives `/inspire:update`.** These files *are* shipped, so
the guarantee is the merge classifier's, not the never-shipped case below: an
update hashes each file against the manifest of the version it is upgrading *from*.
Bytes that differ from that hash are your edit — if INSPIRE did not also change the
file in the new release, it is **kept** untouched; if both sides changed it, the
update **asks**. It never silently replaces an edited profile.

## Authoring rules for profiles

- **Keep them lean and declarative** — a profile states conventions; it is not a
  tutorial. Deep material goes in `profiles/{id}/references/` and loads on demand.
- **Framework conventions only, never domain or org policy.** "Business logic goes
  in services" is a profile rule; "our Jira branch names" or "our private registry
  login" is org policy and belongs in the project's `CLAUDE.md`, not here.
- **No product vocabulary.** A profile that a different React project could not
  reuse verbatim has leaked something that isn't a framework convention.
- **The template ships lean defaults** — the framework profiles `react` and `nestjs`,
  matching the seeded reference stack, plus `angular`, `ios` and `android` (the last
  two mostly deferrals with real test conventions), and the language profile
  `typescript`; a project adds or replaces profiles for its own frameworks and
  languages by dropping `profiles/{id}.md` here — inside the runtime, at
  `.claude/skills/inspire-code/profiles/`. A profile keeps its deep material in
  `profiles/{id}/references/`, linked from its `## References` section — the profile
  file itself stays lean and loads whenever its stack is active; a reference loads
  only when the task touches its topic.
- **A language profile stays language-wide.** If a rule only holds for one framework
  on that language, it belongs in the framework profile: two frameworks sharing a
  language must both be able to read every line of it.

> **A profile you author here survives `/inspire:update`.** This directory sits
> inside a skill directory INSPIRE owns, but an update classifies content against
> the manifest of the version it is upgrading *from* — and a profile INSPIRE never
> shipped appears in no manifest, so it classifies as yours and is neither replaced
> nor deleted. Pre-0.3 `install.sh` did destroy these files; that is fixed, not a
> roadmap item. Keep yours in version control anyway, as you would any other source
> file.

See [`_example.md`](_example.md) for an annotated skeleton.
