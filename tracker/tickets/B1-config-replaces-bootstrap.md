---
id: B1-config-replaces-bootstrap
title: "B1 — /inspire:config with a shipped default replaces /inspire-bootstrap"
created: 2026-10-23
updated: 2026-10-26
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: XL
importance: High
skills: [bootstrap]
status: Open
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
writes the result to its own `.inspire/emanate.json`. The spec config replaces that
scan and that file. The Factory reads the config from the repository and requires it,
with a toolchain for every unit kind in a plan, before it lets a run start. That work
belongs to the Factory codebase.

### The other half of bootstrap

Bootstrap also sets project identity, output language, theme and the live design system.
Each needs a home:

- in Config, or
- in a separate product-side skill the functional operator owns, or
- in the shipped defaults alone.

## Acceptance criteria

- [ ] `/inspire-bootstrap` is retired. Each of its current subcommands and steps has a
      named successor, recorded in this ticket's close note or in an ADR.
- [ ] A default config ships and is materialized on init. A project that declines the
      wizard can still author specs.
- [ ] Init offers the wizard, and declining it is a supported path, not an error.
- [ ] The functional/technical split is explicit:
  - Every question Config asks is marked as technical or product.
  - A technical question offers "I don't know — keep the default".
- [ ] No shipped default names OpenBIMS. Today `00_bootstrap/stack.md`, `theme.md`,
      `00_bootstrap/README.md` and `inspire-bootstrap/SKILL.md` describe their defaults
      as seeded from the OpenBIMS reference. That breaks this repository's rule that the
      runtime is free of any one product's vocabulary.
- [ ] `config-check` exists and enforces the pass and refusal rules above, with tests.
- [ ] `/inspire:update` moves an existing project from bootstrap's outputs to Config's,
      and does not re-ask anything `stack.md` already answers.
- [ ] `output_language` is a key of `.inspire/config.json`, read at install and update.
      Changing it on a project with artifacts warns about the refactor.
- [ ] The wizard asks for the target before the stack, and offers the recommended stack
      or "other".

## Notes

- Several data sources (more than one database or broker) need no separate design. Each
  is a service in the environment that a toolchain's `depends_on` names. Confirm this
  during implementation.

**Amended 2026-10-26 (emanate-3, `/inspire-config`):** the Factory no longer
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
