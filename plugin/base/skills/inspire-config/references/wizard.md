# Config — the wizard
> Part of [inspire-config](../SKILL.md). Read when the entry's index routes here.

`/inspire-config init` walks the whole configuration once. `/inspire:init` offers
it right after installing; declining it there leaves every default in place, and the
wizard runs later, in full or one subcommand at a time.

The four rules of [`../SKILL.md`](../SKILL.md) § Asking bind every step: mark the
question, show the current value, let a technical question keep the default, and
never ask what a file already answers.

## Before the first question

1. Read `.inspire/config.json`, `00_bootstrap/stack.md` and `project.md`, the root
   `CLAUDE.md` and `README.md`, and whether code exists (`package.json`,
   `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `Gemfile` or `src/` at the
   root, or anything under `source_root`).
2. Show the current configuration in one table: each value, and whether it is the
   shipped default or the project's own.
3. Ask who is answering: **the product questions**, **the technical questions**, or
   **both**. One person may take both; a functional operator takes the first and
   leaves the second.

## The product questions

| # | Question | Default | Flow |
|---|---|---|---|
| P1 | `[product]` Which language is the knowledge base written in? | `en`, or the value in the config | [`spec-config.md`](spec-config.md) § Changing the language |
| P2 | `[product]` What is the project called, and what does it do, in one or two sentences? | the repository name, humanized; no description | [`identity.md`](identity.md) |
| P3 | `[product]` What do you want to build? | the target `stack.md` records | [`seeds.md`](seeds.md) § Targets |
| P4 | `[product]` Keep the default look (fonts, colors, density), or change it? A mockup's CSS can provide it. | keep | [`theme-interview.md`](theme-interview.md) |

P1 comes first: it governs everything written after it. P3 comes before any
technology is named, and its answer selects the seed the technical questions start
from.

## The technical questions

Skipped whole when the person answers only the product questions. Each one offers
"I don't know — keep the default".

| # | Question | Default | Flow |
|---|---|---|---|
| T1 | `[technical]` The recommended stack for this target, or another? | the target's seed | [`seeds.md`](seeds.md) § Choosing the stack |
| T2 | `[technical]` Where does the production code live, and the prototype? | with code at the repository root: `source_root: .`, `prototype_root: none`. Otherwise the values in the config | [`stack-interview.md`](stack-interview.md) § Product roots |
| T3 | `[technical]` The rest of the stack: faces and bundles, the database, wire conventions, test infrastructure, the worktree recipe, quality gates | what the seed and `stack.md` declare | [`stack-interview.md`](stack-interview.md) |
| T4 | `[technical]` Write the factory's file now? | no, while no code exists; yes otherwise | the `emanate` flow, [`derive.md`](derive.md) |
| T5 | `[technical]` Which remote does the project push to? | the current `origin`, or none | below |

T2 is asked only when the recommendation differs from the config, or the operator
asks to change a root. On a seed, T3 asks only what the seed leaves open.

**T5, the git remote.** Run `git remote -v` and show the current `origin`. If the
operator names one, wire it on an explicit yes (`git remote add origin <url>`, or
`git remote set-url origin <url>` when one exists). Never change git configuration
silently, and write the remote into no artifact.

## Closing

1. **Refine `CLAUDE.md`** from the answers ([`identity.md`](identity.md) §
   `CLAUDE.md`): the name and purpose from P2, the stack summary from `stack.md`.
2. **Report** in three lists:
   - *written* — each file, and the answers it now holds;
   - *kept at the default by choice* — a default the person looked at and kept;
   - *left at the default, for a technical operator* — every technical question
     answered "I don't know", or skipped with the technical part. Name the
     subcommand that answers each one later.
3. **Tell the operator to commit** `.inspire/config.json` and the files under
   `inspire_kb/`.
4. **Point at the next layer**: usually `/inspire-module create` for the first
   module. A project can author specs with every technical question still open.
