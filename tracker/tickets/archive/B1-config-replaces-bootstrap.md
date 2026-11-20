---
id: B1-config-replaces-bootstrap
title: "B1 — /inspire:config with a shipped default replaces /inspire-bootstrap"
created: 2026-10-23
updated: 2026-11-19
reporter: "@dario.blasco"
closed_by: "@joaquim.ballester"
closed_at: 2026-11-19
epic: roadmap
size: XL
importance: High
skills: [bootstrap, screens]
status: Done
blocked_by: []
related_to: []
---

## Origin

The INSPIRE maintainers held a design review on 2026-10-23 while preparing the training of
new INSPIRE operators. This ticket records one of its decisions. The review's working notes
are not public, so this ticket states everything needed to act on the decision.

**Decision:** a new plugin skill, `/inspire:config`, replaces `/inspire-bootstrap`.
INSPIRE ships a default config, so a project works before anyone answers a technical
question. During `/inspire:init`, the operator chooses whether to run Config's
interactive wizard now or keep the default.

Background terms:

- **Functional operator:** the upstream person who specifies the product.
- **Technical operator:** the downstream person who reviews and builds it.
- **INSPIRE Factory:** a separate service, not part of this repository, that runs
  emanation (the unattended KB-to-code loop) for many projects. The Factory reads the
  config this ticket defines.

## Description

### The problem

`/inspire-bootstrap` asks both operators' questions in one interview. Product questions
(identity, README, output language, theme) are mixed with technical ones (platform,
database, Docker, stack). A functional operator gets stuck on questions only a
technical operator can answer.

### What `/inspire:config` is

**Where it lives.** It is a plugin skill at `plugin/skills/config/`, beside `init` and
`update`. Because it is a plugin skill, it runs before the runtime is materialized, and
`/inspire:init` can start it in the same session. It asks for the product roots, so
`init` stops asking for them. When code already exists at the repository root, Config
recommends `source_root: .` and `prototype_root: none`.

**What it writes.** The person commits all of it.

1. **`.inspire/config.json`, the spec config.** It is committed, governed by the spec,
   and separate from `.inspire.lock`, which stays provenance only. INSPIRE's skills and
   the Factory both read it. Until it exists, skills use the shipped defaults. Keys:
   - `source_root`: `source` by default, or `.` when the repository root is the code.
   - `prototype_root`: `prototype` by default, or `none`.
   - `toolchains`: one entry per toolchain. Each entry has:
     - `kinds`: the unit kinds whose code it builds and tests;
     - `tests`: path globs, from the repository root, naming its test files;
     - `description` (optional): one sentence on what the toolchain image provides;
     - `setup`: commands that turn a fresh checkout into a tree where the tests run.
       They run in order: environment, dependencies, generated artifacts;
     - `test`: a list of `{command, format}`. With a `format` such as `jest` or
       `pytest`, the command writes a report and the format says how to read pass and
       fail counts. Without a format, as for lint or an audit, the exit code decides.
   - `journeys` (optional): `setup`, `test` and `tests`, as a toolchain has them, but
     with no `kinds`. Used for end-to-end tests that need more than one toolchain.
   - `environment`: the path of the environment file.
2. **The environment.** A compose file at `.inspire/environment/compose.yaml`, plus one
   Dockerfile per toolchain.
   - Each toolchain is a compose service with the same name. It holds only the tools
     its kinds need to build and test.
   - Every other service is one the tests use. A toolchain's `depends_on` names the
     services its tests use.
   - A variable the environment cannot work without is written `${NAME:?}`, so it is
     required.
   - This file is not the project's development compose file. Published host ports in
     that file collide when runs are concurrent. Config reads it only to match image
     versions.
3. **`00_bootstrap/stack.md`.**
4. **A scaffold under `source_root`**, only in a repository with no code yet.

**How it fills them.**

- **Code exists.** An agent reads the code and writes the toolchains, the journeys, the
  environment and the route binding rule the code follows. It reads each test runner's
  report flags from a reference table.
- **No code yet.** The stack question offers each shipped stack seed by name, plus
  "describe your own".
  - A seed writes the profiles and the binding rule into `stack.md`, plus the scaffold,
    the spec config and the environment.
  - "Describe your own" runs the layer-by-layer stack interview. An agent then
    scaffolds a minimal app: `GET /api/is-alive`, a home screen that calls it, a 404 on
    each side, and one real integration test.

**`config-check`.** A check, shipped with the skill, that proves the output works.

- It builds the environment. For each toolchain it starts the toolchain's service and
  the services it depends on, with the checkout mounted. It runs `setup`, then each
  `test` entry, and runs `journeys` the same way.
- It passes when every toolchain's suite and the journeys pass.
- It refuses in three cases:
  - a test file matched by two toolchains' `tests`, or by a toolchain and the journeys;
  - a unit kind that maps to no toolchain, or to two;
  - a required variable in a service's `build` section.
- Config repairs its output until the check passes or the person stops it. Config needs
  Docker.

### Spec-side changes this implies

- `inspire-bootstrap/references/bootstrap-stack-interview.md` moves into
  `plugin/skills/config/`. Its `## Test infrastructure` and `## Worktree recipe` steps
  write the environment and the spec config instead of `stack.md` sections.
- Attended `tdd` (`inspire-code/references/tdd.md`) and `inspire-code`'s rule on test
  infrastructure read the environment file instead of `stack.md`'s
  `## Test infrastructure` section.
- The spec-config schema states what a test entry's report means, with fixtures that
  pin it.

### What the Factory does with it (not tracked here)

Today the Factory scans a target repository for its test roots and worktree setup, and
keeps its own settings in the `factory` section of `.inspire/emanate.yml`. The spec config
replaces that scan. The Factory reads the config from the repository and requires it,
with a toolchain for every unit kind in a plan, before it lets a run start. That work
belongs to the Factory codebase.

### The other half of bootstrap

Bootstrap also sets project identity, output language, theme and the live design system.
Each needs a home:

- in Config, or
- in a separate product-side skill the functional operator owns, or
- in the shipped defaults alone.

## Acceptance criteria

- [x] `/inspire-bootstrap` is retired. Each of its current subcommands and steps has a
      named successor, recorded in this ticket's close note or in an ADR.
- [x] A default config ships and is materialized on init. A project that declines the
      wizard can still author specs.
- [x] Init offers the wizard, and declining it is a supported path, not an error.
- [x] The functional/technical split is explicit:
  - Every question Config asks is marked as technical or product.
  - A technical question offers "I don't know — keep the default".
- [x] No shipped default names OpenBIMS. Today `00_bootstrap/stack.md`, `theme.md`,
      `00_bootstrap/README.md` and `inspire-bootstrap/SKILL.md` describe their defaults
      as seeded from the OpenBIMS reference. That breaks this repository's rule that the
      runtime is free of any one product's vocabulary.
- [ ] `config-check` exists and enforces the pass and refusal rules above, with tests.
      **Withdrawn**, with the compose environment it checks (2026-10-26 amendment, and
      the close note). Not built.
- [x] `/inspire:update` moves an existing project from bootstrap's outputs to Config's,
      and does not re-ask anything `stack.md` already answers.
- [x] `output_language` is a key of `.inspire/config.json`, read at install and update.
      Changing it on a project with artifacts warns about the refactor.
- [x] The wizard asks for the target before the stack, and offers the recommended stack
      or "other".
- [x] Each shipped seed names its image. With a seed, `/inspire-config` asks no image
      question. The question stays for "describe your own".

## Notes

- Several data sources (more than one database or broker) need no separate design. Each
  is a service in the environment that a toolchain's `depends_on` names. Confirm this
  during implementation.

**Amended 2026-10-26 (`/inspire-config`):** the Factory no longer
reads a spec config or scans the repository. Since its project-conventions release
it reads one committed file, `.inspire/emanate.yml` — `image`, `services`, `env`,
`setup` and `phases` of checks — and refuses a run without it. The new skill
`/inspire-config` derives that file from `stack.md` and the profiles,
validates it with the Factory's own reader, and never starts a service. That
narrows this ticket. `.inspire/config.json` keeps `source_root` and
`prototype_root` but drops `toolchains`, `journeys` and `environment`; the compose
environment, the Dockerfiles and `config-check` are withdrawn; the "What the
Factory does with it" section above no longer holds. A wizard that answers the
technical questions hands over to `/inspire-config` instead of writing a
second description of the same environment.

**Amended 2026-10-26 (design review, second session): output language.** This settles
the output-language part of "The other half of bootstrap".

- *Decision:* there is no organisation-wide "English only" rule. A project picks its KB
  language at the start, and INSPIRE applies it deterministically at install and update.
  Changing it mid-project counts as a refactor.
- *Today:* the language is not stored in a skill. It is `output_language` in
  `00_bootstrap/project.md`. The session-start hook reads it and injects it into every
  session, and `_references/output-language.md` tells every skill to follow it. An update
  never replaces a KB file, so an update cannot reset it. What is still prose-only is
  applying it: the agent is told the language and is trusted to use it.
- *Change:* `output_language` becomes a key of the spec config, `.inspire/config.json`,
  which Config writes and install and update read. It replaces
  `/inspire-bootstrap language`. The default stays `en`. Changing it on a project that
  already has artifacts warns that existing artifacts stay in the old language and that
  translating them is a refactor.
- *Open:* the review mentioned both a config key and an environment variable. This
  ticket already defines a config file, so a key fits better. And does "deterministic"
  mean more than injecting the language each session, for example writing it into the
  skills at install? That would turn every update into a local edit to merge.

**Amended 2026-10-26 (design review, second session): the wizard asks for targets.**
Agreed at low priority: needed eventually, not urgent.

- *Today:* bootstrap asks platform questions directly. For a mobile app it suggests
  React Native with Expo, a stack INSPIRE has no profile for. The surfaces question also
  asks about deliverables indirectly, in terms a newcomer won't know.
- *Change:* the wizard's first question is the target: desktop-only web · responsive
  web · progressive web app · native mobile · executable binary · other. It then offers
  the recommended stack (React + NestJS today) or "other", as free text. Choosing "other"
  means the operator knows what they want and can add their own profiles. The wording is
  written for someone who doesn't know the technical options.
- *Open:* how this relates to the surfaces question depends on part 3 of
  `B1-kb-structure`, which asks what separates a surface from a module.
- *Not decided:* the review proposed removing the `ios` and `android` profiles under a
  company policy that still has to be confirmed. They stay while native mobile is a
  target: the profiles and the target change together or not at all. Neither profile
  declares a language profile today, so emanation refuses both (`PR-06`). Keeping native
  mobile as a real target eventually means fixing that.

**Amended 2026-10-27 (design review, third session): one config skill, not two.**
Direction stated, design still pending.

- *Today:* `/inspire-config` (0.12.0) writes and validates `.inspire/emanate.yml`. This
  ticket plans a plugin skill, `/inspire:config`, that writes `.inspire/config.json`. The
  two names differ by one character.
- *Direction:* one config skill. `/inspire-config` was named to grow into the project's
  whole configuration, with emanation as one part. It grows to cover the spec config, so
  no second skill named `/inspire:config` is built.
- *Candidate keys:* the default semantic types (`B3-overridable-types`) and the product's
  supported languages (`B3-ui-text-keys`) are candidate keys of that config.
- *Open:* one file or two? `emanate.yml` could stay as the Factory's input, generated
  from `config.json`, or the two could merge. And this ticket has config as a *plugin*
  skill, so it can run before init, while `/inspire-config` is a materialized project
  skill. Which one wins?

**Amended 2026-10-28 (tracker pass): the shape of the spec config is open, and the
ticket waits on it.**

- *The conflict.* The Description above (toolchains per unit kind, a compose
  environment, `config-check`, a plugin skill) and what shipped (the Factory's
  `.inspire/emanate.yml` with one project `image`, and `/inspire-config` as a project
  skill that writes it) describe two different configs. The 2026-10-26 and 2026-10-27
  amendments narrow the ticket toward the shipped one. The original description is not
  withdrawn by a decision, only by those amendments. Which one the spec config is gets
  decided before this ticket is scheduled, and the decision is recorded here.
- *Two themes.* The ticket holds Config (the stack, the spec config, the environment)
  and Init (the interview: language, identity, theme, and the retirement of
  `/inspire-bootstrap` and `theme.md`). Once the config shape is decided, it splits into
  one ticket for each.
- *Factory coupling.* The Factory plans to remove the scaffold step from every run. It
  can land only once a project gets its scaffold elsewhere, which this
  ticket gives to Config.

**Amended 2026-10-30 (fifth design-review session): the project's base is specified in
config.**

- *Direction stated:* the project's base is specified in config: its folder structure
  (including a monorepo whose packages are of different kinds), the environment, the
  test commands and the technology versions. The person keeps it current by talking to
  the config skill, which also creates the folder tree. A default config can ship a
  starter, such as an OpenAPI skeleton or a well-built reference project, so the first
  build has something to follow. A framework upgrade then starts as a config change.
- *The case:* a monorepo had to be laid out by hand before the Factory could run,
  because the Factory builds product units, not project structure. From then on the base
  was managed outside INSPIRE. `stack.md` names technologies but not their versions, and
  `/inspire-config` adds one check per package already on disk but creates none.
- *The config shape.* The INSPIRE Factory's control-plane design (ready for approval)
  answers the open question of the 2026-10-28 note: it takes this ticket's original
  description, `.inspire/config.json` with toolchains, a compose environment,
  `config-check` and `/inspire:config` as a plugin skill, over the shipped
  `.inspire/emanate.yml`. Once that design is approved, this ticket records it and
  splits into Config and Init as planned.
- *Already covered by that design:* the scaffold and the Factory's templates moving into
  Config as seeds; a stack change being a new Config run that updates the scaffold, the
  config and the environment together; a setup step per toolchain.
- *Still open, so this ticket keeps them:* a monorepo seed (the design lists it as not
  built); technology versions as config keys; an OpenAPI starter in the default seed.
- *Not this ticket:* whether a very large suite needs several spec repositories is a
  question for `B1-kb-structure`.

**Amended 2026-11-05 (Factory review, block 1): a functional operator never chooses an
image.** Direction stated.

- *Direction:* each kind of product (web, mobile, an API service) has a default, as a
  predefined project seed: the empty source tree, the profiles, the image and the skills,
  chosen as the recommended practice for that kind. The operator answers "what do you want
  to build". Choosing your own stack stays possible, and the generated `emanate.yml` stays
  editable.
- *Today:* the ticket already has seeds: "the stack question offers each shipped stack seed
  by name, plus 'describe your own'". Its 2026-10-26 note puts the target first (web,
  progressive web app, native mobile, …). No seed names an image. In the shipped skill,
  `/inspire-config` asks every operator "Which image runs the agents…" (Q1), lists the image
  as "never deduced", because "no profile names an image", and has no default for each kind
  of product.
- *Change:* a new acceptance criterion. Each shipped seed names its image, and with a seed,
  `/inspire-config` asks no image question. The question stays for "describe your own".

## Close note (2026-11-19, ships in 0.21.0)

**The decisions this ticket waited on**, taken by `@joaquim.ballester` on 2026-11-19:

- *The shape of the spec config* (open since the 2026-10-28 note): the shipped one.
  `.inspire/emanate.yml` stays the one file INSPIRE Factory reads.
  `.inspire/config.json` holds `source_root`, `prototype_root` and `output_language`
  and nothing else. The original description's `toolchains`, `journeys`,
  `environment`, the compose file, the Dockerfiles and `config-check` are withdrawn.
  The control-plane design named in the 2026-10-30 note was not adopted here; if it
  is approved later, it is a new ticket.
- *One skill, and which one* (2026-10-27 note): the project skill `/inspire-config`
  grows. No plugin skill `/inspire:config` exists. So `/inspire:init` cannot start
  the wizard in its own session: it asks whether to run it, and hands over to
  `/reload-skills` and `/inspire-config init`.
- *The other half of bootstrap*: in Config, as product questions. The live design
  system goes to `/inspire-screens`, which already owns the catalog beside it.
- *One ticket, not two*: the planned split into Config and Init was not made, since
  one change retires the skill and both halves land together.

**Successors of `/inspire-bootstrap`** (first acceptance criterion):

| Subcommand or step | Successor |
|---|---|
| `init` | `/inspire-config init`, the wizard |
| `init` step 1, `language` | `/inspire-config language`; the value is `output_language` in `.inspire/config.json` |
| `init` step 2, `stack` | `/inspire-config stack`: the target, then a seed or the layer interview |
| the product roots, asked by `/inspire:init` and by `stack` | `/inspire:init` writes them without asking (`.` and `none` with code at the root, the defaults otherwise); `/inspire-config stack` changes them; the values are in `.inspire/config.json` |
| `init` step 3, `theme` | `/inspire-config theme` |
| `init` step 4, the `CLAUDE.md` placeholders | `/inspire-config identity` |
| `init` step 5, `readme` | `/inspire-config identity` |
| `init` step 6, the git remote | the wizard's question T5 |
| `review` | `/inspire-config review`, which also validates `emanate.yml` |
| `design-system` | `/inspire-screens design-system` |
| `design-system backfill` | `/inspire-screens design-system backfill` |
| `/inspire-config init` as it was (write `emanate.yml`) | `/inspire-config emanate` |

**How the criteria are met.**

- *Default config.* `materialize.sh` writes `.inspire/config.json` at init, beside the
  default `stack.md` (the `web` seed) and theme.
- *Update.* It builds the file from `stack.md`'s and `project.md`'s frontmatter when a
  project has none, and replaces no value. It edits no KB file: the frontmatter keys
  stay, unread, and a warning names them. Every reader takes the config first and the
  frontmatter second, so a project is read correctly before and after.
- *Output language.* Install and update write and keep the key, and the session-start
  hook injects it into every session. The 2026-10-26 open question is answered: no,
  "deterministic" does not mean writing the language into the skills, because every
  update would then be a local edit to merge. Applying it stays the agent's job.
- *Targets and seeds.* `inspire-config/references/seeds.md` holds six targets and one
  seed, `web`. `native-mobile`, `binary` and `other` have no seed: the wizard says so
  and a technical operator describes the stack.
- *The scaffold.* An agent writes it, every time: `/inspire-config stack` ends by
  building the starter project in a repository with no code, for a seed and for a
  described stack alike (`GET /api/is-alive`, a home screen that calls it, a 404 on
  each side, one real integration test, and the configuration the stack skills
  prescribe). INSPIRE ships no copy of one. A shipped copy was built first and
  withdrawn on `@joaquim.ballester`'s decision of 2026-11-20: a copy lags behind the
  stack skills, as the Factory's own template did, which lacked the lint rules the
  `nestjs` skill gates. Before writing, the skill tells the operator that the Factory
  builds everything on this code, to use the most capable model, and to review it.
  `/inspire:init` lays no code, so a project that keeps the defaults has no starter
  until someone runs `/inspire-config stack`.
- *Several data sources* (the first note): confirmed. Each is a row of `stack.md`'s
  `## Test infrastructure`, and so a service in `emanate.yml`; `datastores:` says which
  entity lives in which.

**Not built, and not tracked by any ticket.** Each needs a decision before it is
scheduled, so none was filed (tracker rule 2):

- a monorepo seed, technology versions as config keys, an OpenAPI starter
  (2026-10-30 note);
- a seed for a native mobile target, which waits on `FB1-react-native-profile`;
- the candidate keys of the 2026-10-27 note, which stay with `B3-overridable-types`
  and `B3-ui-text-keys`.

**Factory work.** Two changes there follow this one, each described here and filed
in the Factory's tracker when this lands.

*The scaffold can leave the run.* A project now gets its starter project from
`/inspire-config stack`, so the Factory's own scaffold step has nothing left to do.
Its removal should refuse a run whose source root is empty and name
`/inspire-config stack`: a project that kept every default has no starter, and
without that refusal its first units would build the project unreviewed.

*The roots moved.* The product roots moved from `stack.md`'s frontmatter to
`.inspire/config.json`. The Factory's deriver resolves a face's and a bundle's
`package` against `source_root`, so it must read the key from the config first, then
from the frontmatter, then default to `source`, as `derived-contract.md` now states.
Until it does, a project installed on 0.21.0 with `source_root: .` is read by the
Factory as `source`. `emanate.yml`'s commands and claim roots carry the root
literally and are not affected.

**The manual.** The pages that describe `/inspire-bootstrap` and `/inspire:init`'s
questions need the matching change in Genomcore/inspire-docs.
