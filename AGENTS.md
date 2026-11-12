# INSPIRE — workspace guide for Claude

This repository is the **home of the INSPIRE methodology** (a software
engineering methodology for the agentic era) and a **template** for bootstrapping
new specification-driven projects. See [README.md](README.md) for the full
overview, or the manual at [inspire.openbims.dev](https://inspire.openbims.dev).

## Structure

The convention: **dotfolders = INSPIRE scaffolding**, non-dot dirs = the product
you build on top of it. INSPIRE is delivered as a **Claude Code plugin**; this
repo is both its source and its own marketplace.

- `plugin/` — the distributable plugin:
  - `plugin/.claude-plugin/plugin.json` — the runtime **release identity**
    (`version` + `released`).
  - `plugin/skills/{init,update,migrate}/` — the only **live** skills, installed
    with the plugin itself: `/inspire:init` (materialize the runtime into a project,
    once), `/inspire:update` (**upgrade from any released version**, in one command —
    it detects the installed version, replays the layout hops between there and
    here, and merges content per file, never overwriting a locally-edited one; a
    pre-0.3 project is the longest chain, and the run ends by offering the trust
    report: an upgrade diverges skills en masse) and `/inspire:migrate` (moves a KB
    written in the layered layout — `01_adr` … `05_screens` and the surface roster —
    to the concept layout under `inspire_kb/01_spec/`, then, in a second run after
    the moves are committed, converts every `[[wikilink]]` to a relative Markdown
    link, once and on purpose; the engines are `plugin/scripts/migrate-kb.sh` and
    `plugin/scripts/migrate-links.sh`, and they alone read wikilinks). An update
    never moves the KB and changes no link: a layered KB gets a warning pointing at
    `/inspire:migrate`, and no `01_spec/`; a KB that holds wikilinks gets their count
    and the same pointer.
  - `plugin/manifests/<version>.json` — one **hash manifest per released version**
    (`{version, released, commit, layout, files}`), generated from its tag and the
    *only* record of what INSPIRE shipped at that version. This is what lets an
    upgrade tell an operator's edit apart from a file that is stale — a
    distinction `.inspire.lock` cannot make, since it lives on the operator's
    machine and pre-0.3 installs often wrote no lock at all.
  - `plugin/scripts/hops/` — `layouts.tsv` (each layout's structural markers and
    where it materializes `base/`) plus one executable bash script per version that
    moved something. A version that moved nothing has no file: a hop's **absence**
    is the no-op. A payload class that is only *added* moves nothing either, so it
    extends the existing row's `dest_map` instead of opening a new layout — the
    rule, and why a new layout id would break detection, is in the file's header.
  - `plugin/scripts/materialize.sh` — the mechanics the skills call. Modes:
    `--mode plan` (read-only: detect, verify the layout, enumerate the chain,
    classify content, print the grouped report to stderr and a JSON summary to
    stdout — it writes nothing at all), `--mode update`, `--mode init`.
    It handles copying, `chmod`, excluding `base/bin/test/`, **seeding**
    `inspire_kb/` (strictly additive in *both* init and update — a path already on
    disk is never replaced, only missing skeleton files are added, because the KB is
    product content INSPIRE never owns), seeding the design system, seeding a
    provisional root `CLAUDE.md` + a `.gitignore` block, creating the product roots,
    warning when `.gitignore` excludes the runtime, the marker-based
    `settings.json` merge (which also retires the unmarked pre-0.3 hook entries),
    and writing `.inspire.lock`. The lock is **provenance only** —
    `inspire_version`/`released`/`template_sha`/`installed_at`, no `files` map:
    per-file hashes live in the shipped manifests, where they cannot be edited, so
    one place answers "what did we ship?".
    `template_sha` carries the release commit, which `inspire-lesson` stamps onto
    every lesson. In act mode it also saves the grouped report to
    `.inspire/last-upgrade.log` — overwritten each run, so what the last upgrade did
    stays auditable; `--mode plan` writes nothing, that file included.
  - `plugin/scripts/gen-manifest.sh` — maintainer tool: emit a version's manifest.
    Past releases are read from their tag, since that is the only place they exist;
    the release being *prepared* is read from the commit carrying its version bump,
    because the manifest ships in the same PR and the tag is only cut once it
    merges.
  - `plugin/base/` — the **inert payload**: materialized into a project by
    `/inspire:init`, never auto-loaded here because Claude Code only discovers a
    plugin's `skills/`, `hooks/`, `agents/` and `bin/` at its top level, not inside
    a nested `base/`. Materializes as:
    - `base/skills/` → `.claude/skills/inspire-*` — the 21 agent skills: the
      judgment half of the runtime, in three families:
      - **Specification** (8) — capture what the product is and why: `module` ·
        `feature` · `domain` · `process` (work that runs on a trigger, with nobody
        behind it) · `screens` · `prototype` (horizontal mock) · `spike` (external
        verticals) · `adr`.
      - **Codification** (6) — coding itself runs in INSPIRE Factory; what ships
        here is what it reads. Six **stack skills** — `inspire-code-react` ·
        `inspire-code-nestjs` · `inspire-code-angular` · `inspire-code-ios` ·
        `inspire-code-android` · `inspire-code-typescript` — each an ordinary
        skill carrying one stack's conventions, with its deep material in its own
        `references/`. One optional frontmatter field, `stack: <id>`, scopes a
        skill: it is served only to the units whose `stack.md` `profiles:` names
        that id, and a skill without it is served to every unit. The id can be a
        framework, a language, a database or a library, and the skill's own name
        never matters — a project adds its own (`stack: postgres`) beside these.
        `layer:` and `language:` compose them along **two axes**: a **framework**
        skill carries architecture plus the project-owned binding / route /
        persistence **seeds** and names the **language** skill (`typescript`) that
        carries semantic-type rendering and the declaration-only-tree recipe —
        only `react`, `nestjs` and `angular` declare a `language:`. The contract is
        `_references/stack-skills.md`. The validators resolve an id the same way
        (`sdd_stack_skills` in `_lib.sh`, over `SDD_SKILLS_ROOT`).
      - **Housekeeping** (7) — set up and keep the workspace coherent: `bootstrap`
        (greenfield foundation: language, stack, theme + the live design system),
        `config` (writes and validates `.inspire/emanate.yml`, the one file
        INSPIRE Factory reads to run a project — image, services, env, setup and
        phases of checks — derived from `stack.md` and the stack skills and checked
        with the Factory's own reader; `init` · `review`),
        `face` (faces and bundles — `add` · `retire` · `review`; the only skill
        that writes `{face}.face.md` and `{bundle}.bundle.md`), `extract` (brownfield onboarding — fan out
        scanners over an existing codebase into KB candidates), `task` (the ticket
        tracker), `workspace` (the pre-PR global review + vault structure; its
        report's `## Signals` section carries the trust report — measurements,
        never findings), `lesson` (the lessons
        catalog — write-once, timestamp-named, version-stamped one-line
        instructions that teach the skills how to behave in this project;
        relevant locally, distilled upstream by the observer). `base/skills/`
        also ships `_references/` — a shared reference directory alongside the
        `inspire-*` skill dirs (`face-scope.md`, `trust-stamps.md`,
        `write-checks.md`, `keyed-heads.md`, `stack-skills.md`, `kb-links.md`); it is
        **not** matched by an `inspire-*` glob.
    - `base/agents/` → `.claude/agents/` — the **agents payload class**: agent
      definitions, materialized where Claude Code discovers them and merged with
      the skills' never-clobber rules (an edited shipped agent is kept or asked
      about; an operator's own agent file is kept by construction). It is **not**
      a new layout: `layouts.tsv`'s 0.3 row gained `agents:.claude/agents`,
      because an additive class moves nothing, and a second layout id could only
      reuse 0.3's own markers — leaving `verify_layout` unable to tell them apart
      and `detect_version` refusing any project that ties across them. That file's
      header carries the full argument, and no `0.9.0` hop exists because nothing
      moved. Claude Code parses **every** `*.md` under this root as an agent
      definition, so nothing without valid agent frontmatter may ship here — the
      class's own README is a `.txt` for exactly that reason. It ships only that README: the five role shells of the
      in-session emanation loop were removed with `/inspire-emanate`, because code
      emanation runs in INSPIRE Factory. The class stays, so an upgrade deletes a
      shipped shell an operator never touched and keeps an edited one.
    - `base/bin/` → `.inspire/bin/` — the validators + a README: the mechanical
      half, promoted to a real top-level directory in a materialized project so
      CI never depends on a path inside `.claude/`. Every finder is one recursive
      search for a typed extension under `SDD_SPEC_ROOT` (defaults to
      `inspire_kb/01_spec`); no rule reads the directory a file sits in.
      `screen-coherence.sh` checks screen identity (`{face}.{slug}`), keyed bindings
      and the screen↔layout join; `spec-identity.sh`, `face-exposure.sh` and
      `process-shape.sh` check ids, the actions a face's bundles expose, and processes.
      `links-resolve.sh` checks that every link in a Markdown file under the KB names
      a file or directory that exists, and reports each wikilink with
      `/inspire:migrate`; every validator reads links through `sdd_links` in `_lib.sh`,
      the reader [the link-syntax corpus](plugin/test/fixtures/link-syntax/README.md)
      holds the spec and the Factory to. `trust.sh` is here as a
      **tool, not a review rule** — all of artifact trust's mechanics (hashing, both
      stamp blocks, the report), outside `review.sh`'s rule list, never a gate; see
      [docs/adr/adr-artifact-trust.md](docs/adr/adr-artifact-trust.md).
      The derived contract INSPIRE Factory builds every unit from is specified in
      [base/skills/_references/derived-contract.md](plugin/base/skills/_references/derived-contract.md);
      the Factory implements it, and nothing under `base/bin/` derives one.
      `base/bin/test/` (the golden fixtures + test runner) **never** materializes
      — validators are not an extension point, so a project has no local rule
      authoring to preserve. Template test suite: `bash plugin/base/bin/test/run-tests.sh`,
      correct on its own and in three forms — every rule, one rule
      (`run-tests.sh <rule>`), or named scenarios of one
      (`run-tests.sh <rule> <scenario>…`). `plugin/test/run.sh` drives it one
      rule at a time plus its six hand-wired siblings, and uses the third form
      to shard the rules with many fixtures across several jobs.
    - `base/hooks/` → `.claude/inspire/hooks/` — enforcement hooks. Only two
      scripts are registered in a materialized project's `.claude/settings.json`,
      each tagged `# INSPIRE-MANAGED`: `session-start.sh` on SessionStart, and
      `dispatch.sh` on both PreToolUse and PostToolUse for Bash. `pre-commit.sh`,
      `pre-pr.sh` and `post-commit.sh` ship as files and are invoked *by*
      `dispatch.sh`, which routes on the event and the command: the two `pre-`
      checks can block, and `post-commit.sh` reviews the KB files a commit
      contains and reports to the agent without blocking. **No INSPIRE hook runs
      on each file edit**, and none should be added: it slows every write, and
      fixing a finding is itself an edit, so the hook fires again and can loop.
      The authoring skills check each file they write instead
      (`_references/write-checks.md`). `session-start` injects the
      project's `output_language`, the runtime version from `.inspire.lock` and
      the decision digest `base/bin/decisions.sh` prints — every live ADR's
      `## Decision`, held to a budget — into every session.
    - `base/kb/` → `inspire_kb/` — the **knowledge-base skeleton**: the navigable
      graph a project fills in. `00_bootstrap` (stack, project, glossary, semantic
      types, style tokens), **`01_spec`** — the specification, one directory per
      concept: `_adr/` (global ADRs), `_design-system/` (design system, tokens, theme,
      components, layouts, patterns), `_modules/{m}/` (hub, `_adr/`, `_features/`,
      `_domain/`, `_processes/`), `_bundles/`, `_faces/{f}/` (face file, tokens, `_adr/`,
      `_screens/`, `_processes/`) and `_processes/` — then `06_spikes`, `98_lessons`
      and `99_tracker`. Every specification file carries a typed extension
      (`.module.md`, `.feature.md`, `.entity.md`, `.action.md`, `.adr.md`,
      `.adr.rationale.md`, `.bundle.md`, `.face.md`, `.screen.md`, `.process.md`,
      `.component.md` · `.layout.md` · `.pattern.md`, `{type}.template.md`), is found by
      it, and is linked to by a relative Markdown link to the file
      (`[adr-audit](../../_adr/audit.adr.md)`); the extension is never part of an id. Four concepts: a
      **module** is a slice of the domain, a **bundle** is the unit of exposure (which
      actions a package publishes), a **face** is what a person uses (screens, shell,
      package, tokens, the bundles it uses), a **process** runs on a trigger. A
      screen's id is `{face}.{slug}`; its route still derives from `module` +
      `screen`. Global artifacts declare a blast radius in `faces:` / `bundles:`
      (absent = the whole project). See
      [docs/adr/adr-kb-structure.md](docs/adr/adr-kb-structure.md) (it supersedes
      adr-suites-and-surfaces) and
      [docs/adr/adr-markdown-links.md](docs/adr/adr-markdown-links.md) (the link
      form); the runtime rules live in `base/skills/_references/face-scope.md`,
      `base/skills/_references/kb-links.md` and `base/kb/01_spec/README.md`.
    - `base/templates/` → the provisional root `CLAUDE.md` (placeholders filled
      in afterwards by `/inspire-bootstrap init`, never clobbered if one already
      exists) and the `source/` + `prototype/` README stubs.
- `.claude-plugin/marketplace.json` — makes this repo its own plugin marketplace,
  so `/plugin marketplace add Genomcore/inspire` resolves.
- `.claude/hooks/template-*.sh` — template-maintenance only (e.g. guarding the
  release-identity bump); never shipped to a project.
- The INSPIRE **microsite / manual** (canonical explanation, published at
  inspire.openbims.dev) does **not** live here: its source is its own repo,
  [Genomcore/inspire-docs](https://github.com/Genomcore/inspire-docs), split out
  with its history. A change to the methodology that the manual describes needs
  a matching PR there.
- `docs/adr/` — hand-authored, core-level ADRs about INSPIRE itself. It does not
  materialize, so **nothing under `plugin/base/` ever links into it** — not by
  relative path, which resolves to nothing in a project, and not by absolute URL,
  which sends a project's operator out of their project to read the methodology's
  internals. Shipped payload explains itself where it ships: the relevant skill's
  `references/`, or the KB layer's README.

The above is the runtime surface — what `/inspire:init` copies from `plugin/base/`
into `.claude/`, `.inspire/` and `.inspire.lock`. Separately, and every time it
runs, `/inspire:init` also creates two **product-side** roots that are not part of
that runtime surface and **do not exist in this template repo** — they are the
product you build, not INSPIRE:

- `prototype/` — the **horizontal prototype** (product-side, non-dot): the wide,
  shallow, mocked working model of the whole product. It keeps **no KB file** — its
  insights co-evolve the vault directly (features, screens, ADRs, design system).
  Vertical spikes live in their own external repos, their knowledge brought home
  under `inspire_kb/06_spikes/` (skill `inspire-spike`).
- `source/` — the **production monorepo** (product-side, non-dot): the root of the
  actual product code, realized from the KB. An ADR reaches `implemented` maturity
  when it lands here.

Both roots are configurable at init time (`--source-root`/`--prototype-root`,
answered once via `/inspire:init`'s questions and read back from `stack.md` by
`/inspire:update` — never re-asked).

### Template vs deployed layout — why the runtime payload is inert in `plugin/base/`

Claude Code auto-loads a plugin's `skills/`, `hooks/`, `agents/` and `bin/` at its
top level, and runs hooks registered in `.claude/settings.json`. The skills also
reference each other and the validators via the **deployed** paths
(`.claude/skills/…`, `.inspire/bin/…`). If the payload lived at the plugin's top
level, those skills and hooks would fire in *this* repo while the template itself
is edited — so it is nested one level down, under `plugin/base/`, where Claude
Code never looks.

Instantiating a project is one command, run from a Claude Code session with the
plugin installed:

```
/inspire:init
```

It materializes `plugin/base/{skills,agents,bin,hooks,kb,templates}` into the
project (`.claude/skills/`, `.claude/agents/`, `.inspire/bin/`,
`.claude/inspire/hooks/`, `inspire_kb/`, plus
the seeded `CLAUDE.md`/`.gitignore`/product roots), makes the scripts executable,
marker-merges the hooks into `.claude/settings.json`, seeds
`01_spec/_design-system/design-system.md` from `theme.md` beside it (and
`design-system.tokens.json` from `theme.tokens.json`), and writes
`.inspire.lock`. It never deletes or rewrites unrelated content, and it is safe to
run only once per project — `.inspire.lock`'s presence is the guard; from then on,
`/inspire:update` upgrades the project to the installed plugin's version, from
whatever version it is on.

An upgrade runs in four stages, split by how much judgement each needs. **detect**
fingerprints the project against the shipped manifests and refuses rather than guess.
**verify** asserts that version's layout signature — structure only, never content,
because an operator who edited a skill, deleted a validator or removed a whole skill
directory is using INSPIRE correctly and none of that may block an upgrade. **hops**
replay the layout moves. **reconcile** merges content per file, seeds any missing KB
skeleton files, writes `settings.json` once and rewrites the lock.

Three invariants hold throughout. Nothing of the operator's is destroyed: a file
INSPIRE never shipped is *kept* by construction, not by a special case. Nothing is
left silently stale while the version claims otherwise. And the report claims only
what happened. Only a genuine conflict — a file both sides changed, differently —
asks the operator anything.

## Working in this repo

- This is the **template**, not a live project. There is no installer to run
  here — `/inspire:init` itself hard-stops with an error if it detects
  `plugin/.claude-plugin/plugin.json` at the project root, precisely to prevent
  activating the runtime against this repo.
- Keep the runtime **generic**: the skills, the validators and the `inspire_kb/`
  skeleton must stay stack-agnostic and free of any specific product's domain
  vocabulary. Concrete project content belongs in a governed project's
  `inspire_kb/`, not here.
- The KB ships as a **skeleton** — each layer has a README (and, where useful,
  starter files); a real project fills the rest in via the skills.
- **One command runs the whole estate, by hand — there is no CI:**
  `bash plugin/test/run.sh`. It discovers every test file, builds each released
  fixture the estate needs once into a run-scoped cache, and runs the lot
  concurrently (`-j N`, default `min(ncpu, 8)`; `-j 1` is serial). One line per
  file as it finishes, a failing file's output dumped under it, and **a file that
  produced zero assertions fails the run** — a test that silently did nothing is
  not coverage. `--inventory FILE` writes every `PASS`/`FAIL`/`SKIP` line of the
  run, sorted; that file is how a refactor of the tests proves it lost no
  assertion. A bare word narrows the run to the jobs whose name contains it
  (`run.sh upgrade`, `run.sh 06-hop-ops`, `run.sh golden`).

  Test-suite internals — golden-job sharding, running one file alone, why a run
  is spawn-bound, parallel safety and the fixture cache, and how to build
  period-correct fixtures without writing vacuous assertions — live in
  `plugin/test/AGENTS.md`. Do not record wall-clock figures in either file.
- **Symlinks are not supported** anywhere in a managed path. Nothing INSPIRE ships is
  one; this is a declared limitation, not a gap to close.
- **Releasing** — the version bumps, the hash manifest, `CHANGELOG.md`, the
  release-branch workflow and the post-merge tag + GitHub release (**merging is not
  releasing**) — follows the `/template-release` skill in `.claude/skills/`. Load it
  whenever you cut, tag or publish a version.
