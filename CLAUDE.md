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
  - `plugin/skills/{init,update}/` — the only **live** skills, installed with the
    plugin itself: `/inspire:init` (materialize the runtime into a project, once)
    and `/inspire:update` (**upgrade from any released version**, in one command —
    it detects the installed version, replays the layout hops between there and
    here, and merges content per file, never overwriting a locally-edited one).
    A pre-0.3 project is no longer refused; it is simply the longest chain. The
    run ends by offering the trust report: an upgrade diverges skills en masse.
  - `plugin/manifests/<version>.json` — one **hash manifest per released version**
    (`{version, released, commit, layout, files}`), generated from its tag and the
    *only* record of what INSPIRE shipped at that version. This is what lets an
    upgrade tell an operator's edit apart from a file that is merely stale — a
    distinction `.inspire.lock` cannot make, since it lives on the operator's
    machine and pre-0.3 installs often wrote no lock at all.
  - `plugin/scripts/lib/` — the sourced units `materialize.sh` is built from:
    `manifest.sh` (fingerprint-detect a version, assert a layout signature),
    `hop-ops.sh` (the five operations a hop may perform, each of which either acts
    or records), `chain.sh` (run the hops between two versions), `merge.sh` (the
    three-way classifier and its applier), `report.sh` (the operator-facing
    report), `common.sh`.
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
    per-file hashes live in the shipped manifests, where they cannot be edited, and
    two disagreeing answers to "what did we ship?" would be worse than one.
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
    - `base/skills/` → `.claude/skills/inspire-*` — the 14 agent skills: the
      judgment half of the runtime, in three families:
      - **Specification** (7) — capture what the product is and why: `module` ·
        `feature` · `domain` · `screens` · `prototype` (horizontal mock) · `spike`
        (external verticals) · `adr`.
      - **Codification** (1) — `inspire-code`: the coding stage that turns the KB
        into production code under `source/` (subcommands `tdd` · `review` ·
        `debug` · `fix-build` · `fix-vulns`), always re-anchoring to the ADRs,
        descriptors and acceptance criteria that specify it, and handing drift
        back to the specifying skills. Stack-agnostic, layering optional **stack
        profiles** (`inspire-code/profiles/`, resolved on demand from
        `00_bootstrap/stack.md`), composed along **two axes**: a **framework**
        profile (`react`, `nestjs`, `angular`, `ios`, `android`) carries
        architecture plus the project-owned binding / route / persistence
        **seeds**, keeps its deep material in `profiles/{id}/references/` loaded
        only on need, and names the **language** profile (`typescript`) that
        carries semantic-type rendering and the declaration-only-tree recipe.
        The template ships those lean defaults; a project adds its own — note
        that only `react`, `nestjs` and `angular` currently declare a
        `language:` — `ios` and `android` deliberately declare none, and so
        refuse. Attended subcommands never block on a
        missing profile; `emanate plan` refuses **per unit** on profile
        resolution — `PR-06` when a framework profile the unit is built under
        reaches no `layer: language` profile, and `PR-07` when a `layer:` the
        unit resolves carries two framework profiles, or none at all. A unit
        resolves a *set* and the applied rules are the union of its members',
        so the ordinary fullstack suite spanning two layers refuses nothing. Its **judgment is filed by role**, not by subcommand:
        `references/roles/` holds one doc per position of the loop — contracter ·
        tester · implementer · security overseer · quality overseer — beside a
        README carrying the role model, the envelope's two halves and the
        additive-only roster rule. `tdd` (attended) and `emanate` (unattended)
        read the same docs; `review` holds the two overseer lenses; `fix-vulns`
        shares the security overseer's standing rules. The subcommand references
        keep their own flow and point there for the doctrine, so a rule has one
        home.
      - **Housekeeping** (6) — set up and keep the workspace coherent: `bootstrap`
        (greenfield foundation: language, stack, theme + the live design system),
        `surface` (the suite's surface roster and its lifecycle — `add`
        greenfield/split/adopt · `retire` · `review`; owns
        `00_bootstrap/surfaces.md`), `extract` (brownfield onboarding — fan out
        scanners over an existing codebase into KB candidates), `task` (the ticket
        tracker), `workspace` (the pre-PR global review + vault structure; its
        report's `## Signals` section carries the trust report — measurements,
        never findings), `lesson` (the lessons
        catalog — write-once, timestamp-named, version-stamped one-line
        instructions that teach the skills how to behave in this project;
        relevant locally, distilled upstream by the observer). `base/skills/`
        also ships `_references/` — a shared reference directory alongside the
        `inspire-*` skill dirs (`surface-scope.md`, `trust-stamps.md`,
        `keyed-heads.md`); it is
        **not** matched by an `inspire-*` glob.
    - `base/agents/` → `.claude/agents/` — the **agents payload class**: agent
      definitions, materialized where Claude Code discovers them and merged with
      the skills' never-clobber rules (an edited shipped agent is kept or asked
      about; an operator's own agent file is kept by construction). It is **not**
      a new layout: `layouts.tsv`'s 0.3 row gained `agents:.claude/agents`,
      because an additive class moves nothing, and a second layout id could only
      reuse 0.3's own markers — leaving `verify_layout` unable to tell them apart
      and `detect_version` refusing any project that ties across them. That file's
      header carries the full argument, and no `0.8.0` hop exists because nothing
      moved. Claude Code parses **every** `*.md` under this root as an agent
      definition, so nothing without valid agent frontmatter may ship here — the
      class's own README is a `.txt` for exactly that reason. It ships the **five
      role shells** of the emanation loop — `inspire-contracter` ·
      `inspire-tester` · `inspire-implementer` · `inspire-security-overseer` ·
      `inspire-quality-overseer`. A shell is an identity, a permission envelope
      (its `tools:` allowlist — personas keep `Bash` and `Agent`; overseers carry
      only `Read, Grep, Glob`, because D3 says an overseer writes nothing and
      Bash can write) and a pointer at its doctrine in
      `inspire-code/references/roles/`. The **overseer roster is additive-only
      and needs no new key**: an overseer is any `.claude/agents/*-overseer.md`
      whose `tools:` line is present and names no writing tool; a project adds
      its own, and the two shipped ones are non-removable — `emanate` refuses to
      run when either is missing or fails that shape.
    - `base/bin/` → `.inspire/bin/` — the validators + a README: the mechanical
      half, promoted to a real top-level directory in a materialized project so
      CI never depends on a path inside `.claude/`. Spec root is configurable via
      `SDD_SPEC_ROOT` (defaults to `inspire_kb/04_domain`); the rules that check the
      other KB layers read `SDD_KB_ROOT` instead, `screen-coherence.sh` among them —
      screen identity, keyed bindings and the screen↔layout join. `trust.sh` is here as a
      **tool, not a review rule** — all of artifact trust's mechanics (hashing, both
      stamp blocks, the report), outside `review.sh`'s rule list, never a gate; see
      [docs/adr/adr-artifact-trust.md](docs/adr/adr-artifact-trust.md).
      The **`emanate-*` scripts are the same class of thing** — the emanation
      loop's mechanics (D8), tools outside `review.sh`'s rule list, sharing
      sourced units in `base/bin/lib/` → `.inspire/bin/lib/`: `emanate-harvest.sh`
      (a phase worktree's owned diff → one integration commit) and
      `emanate-derive.sh` (a unit's KB artifacts → the derived contract on stdout,
      the **strict** parser that refuses an old shape rather than read it as an
      empty section, and the one place the 0.8 grace on the presence classes is
      paid for — see
      [base/skills/_references/derived-contract.md](plugin/base/skills/_references/derived-contract.md)).
      `emanate-plan` (a scope's frontier snapshot → dependency waves → the floor
      versus the declared ceiling → every readiness check, JSON on stdout and
      nothing written anywhere — see
      [base/skills/_references/emanation-plan.md](plugin/base/skills/_references/emanation-plan.md))
      and `emanate-gate` (a unit's claims × the tests citing them × the suite
      result → one pass/fail verdict on stdout, the deterministic evidence an
      overseer's approval can never stand in for — see
      [base/skills/_references/gate-verdict.md](plugin/base/skills/_references/gate-verdict.md))
      join them and compose on derive.
      `base/bin/test/` (the golden fixtures + test runner) **never** materializes
      — validators are not an extension point, so a project has no local rule
      authoring to preserve. Template test suite: `bash plugin/base/bin/test/run-tests.sh`,
      unchanged and still correct on its own; `plugin/test/run.sh` drives it one
      rule at a time (`run-tests.sh <rule>`) plus its six hand-wired siblings,
      which turns the estate's slowest single job into twenty-five short ones.
    - `base/hooks/` → `.claude/inspire/hooks/` — enforcement hooks. Only two are
      registered in a materialized project's `.claude/settings.json`
      (`session-start.sh`, `dispatch.sh`), each tagged `# INSPIRE-MANAGED`;
      `pre-commit.sh` and `pre-pr.sh` still ship as files but are invoked *by*
      `dispatch.sh` rather than registered directly. `session-start` injects the
      project's `output_language` — and the runtime version from `.inspire.lock`
      — into every session.
    - `base/kb/` → `inspire_kb/` — the **knowledge-base skeleton**: the navigable
      graph a project fills in. One layer per skill (`00_bootstrap`, `01_adr`,
      `02_modules`, `03_features`, `04_domain`, `05_screens`, `06_spikes`,
      `98_lessons`, `99_tracker`); each folder carries a README explaining its
      purpose and layout. The KB has a **second scoping axis besides the module**:
      a product delivered through several UIs and/or services is a **suite** of
      **surfaces** (`ui` · `headless` · `lib`), declared in the authored — never
      seeded — roster `00_bootstrap/surfaces.md`. Artifacts that *span* surfaces
      (ADRs, features, pattern/component entries, tickets) declare a blast radius
      in a `surfaces:` frontmatter field, where absent means suite-wide; screens
      instead scope *positionally*, splitting to
      `05_screens/{surface}/{module}/{screen}.md` once 2+ UI surfaces exist — while
      their identity does not move with them: a screen carries a write-once
      `id`/`module`/`screen`/`lifecycle` block, declares its own keyed `## Bindings`,
      and derives its route from `module` + `screen`, so a move is free. The
      `04_domain` tree is never surface-scoped — one domain truth spans the whole
      suite — and a project that declares no surfaces is a suite-of-one whose KB is
      byte-identical to one written before surfaces existed. See
      [docs/adr/adr-suites-and-surfaces.md](docs/adr/adr-suites-and-surfaces.md);
      the runtime rules live in `base/skills/_references/surface-scope.md`.
    - `base/templates/` → the provisional root `CLAUDE.md` (placeholders filled
      in afterwards by `/inspire-bootstrap init`, never clobbered if one already
      exists) and the `source/` + `prototype/` README stubs.
- `.claude-plugin/marketplace.json` — makes this repo its own plugin marketplace,
  so `/plugin marketplace add Genomcore/inspire` resolves.
- `.claude/hooks/template-*.sh` — template-maintenance only (e.g. guarding the
  release-identity bump); never shipped to a project.
- `.manual/` — the INSPIRE **microsite / manual** (canonical explanation;
  published at inspire.openbims.dev; source here — open `.manual/index.html`).
- `docs/adr/` — hand-authored, core-level ADRs about INSPIRE itself.

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
Code never looks. The rationale is unchanged from earlier releases; only the
mechanism moved (from a dormant `.inspire/` directory to a nested, un-discovered
plugin path).

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
`05_screens/design-system.md` from `00_bootstrap/theme.md`, and writes
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

Three invariants hold throughout, and they are the point of the whole design:
nothing of the operator's is destroyed — a file INSPIRE never shipped is *kept* by
construction, not by a special case; nothing is left silently stale while the version
claims otherwise; and the report never claims something that did not happen. Only a
genuine conflict — a file both sides changed, differently — asks the operator
anything.

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

  | area | covers |
  |---|---|
  | `plugin/test/upgrade/` | detection, layout signatures, hop ops, the chain, the merge, end-to-end upgrades — one file per concern |
  | `plugin/test/materialize/` | `init` and `update` against scratch projects |
  | `plugin/test/manifest/` | `gen-manifest.sh` + every shipped manifest reproduces |
  | `plugin/test/test-fixtures.sh` | the period-correct fixture builder and its per-run cache |
  | `plugin/test/test-lib-common.sh` | `log`, `sha256_of`, `hash_paths`, `arr_to_json`, `version_cmp` |
  | `plugin/test/test-run.sh` | `run.sh` itself, against synthetic estates |
  | golden jobs | the validators, via golden fixtures — one `run-tests.sh <rule>` per rule, plus its six hand-wired siblings. `golden/emanate-derive` is the estate's longest job (62 s solo, 83 fixtures): derive runs the rules that own the `OS-*` classes rather than re-implementing them, so most fixtures spawn four validators — the ten catalog ones spawn none, because no review rule owns a component's or a pattern's shape |

  **Every file also runs on its own**, from any directory and with no
  environment: `bash plugin/test/upgrade/06-hop-ops.sh` builds what it needs and
  prints its own summary; the cache is an accelerator, never a dependency. The
  shared assertion vocabulary is `plugin/test/lib/assert.sh` — `plugin/test/lib/`
  holds no tests and the runner never runs it.

  A run takes three to four minutes, and that is fixture builds and process
  spawns, not a hang. Measured solo: **~207 s** for the whole estate at the
  default `-j`, from 160–169 s before the component and pattern unit kinds
  brought their goldens, 267 s before the batched runtime and 106 s before
  `emanate-derive`'s goldens existed at all. It is spawn-bound, not critical-path bound — every job
  inflates roughly twofold beside eight peers, so cutting a long file shortens
  that file and leaves the wall where it was. Run on its own, every file is under
  20 s but four: `upgrade/18b-e2e-resolution-flags.sh` (27 s, four pre-0.3
  fixtures and four updates), `upgrade/23-agents-class.sh` (27 s),
  `upgrade/22c-derive-equal-resolutions.sh` (20–23 s) and
  `materialize/01-init-current-tree.sh` (22 s); of the golden jobs,
  `golden/emanate-plan` runs 39 s over 35 fixtures, and the longest job of any
  kind is `golden/emanate-derive` at 62 s, which is 83 fixtures, most of them
  spawning the validators that own the refusal classes. Every job is
  **parallel-safe**: every scratch tree is a private `mktemp` one and the repo is
  only ever read, so any number of copies — several worktrees at once, the same
  file twice over, a single file beside a full run — can run concurrently without
  interfering. The one shared tree is the fixture cache each `run.sh` builds
  inside its own `mktemp -d`: read-only to the jobs, fingerprinted after the
  build and again before exit, so a job that reached into it fails the run —
  naming the cache, not the job — instead of poisoning its siblings. Keep it that
  way: a fixed path under `/tmp` is what made the upgrade suite produce phantom
  failures before.
- Fixtures are free and cost the repo nothing: every tag ships a runnable installer,
  so `git archive <tag>` plus that era's own installer yields a genuine
  period-correct project tree. `plugin/test/lib/fixtures.sh` does this — prefer it
  over hand-built trees, and note that a pre-0.3 project legitimately retains
  `.inspire/{bin,hooks,skills,templates}` as the staged source `install.sh` copied
  FROM. **Seven assertions in this repo have been vacuous because of that**: "the
  destination exists" passes whether or not the code under test ran. Assert the
  source side too, or pick a path the old installer cannot have staged. When unsure,
  stub the function to a no-op *on a copy* and confirm the assertion fails.
- **Symlinks are not supported** anywhere in a managed path. Nothing INSPIRE ships is
  one; this is a declared limitation, not a gap to close.
- A release needs both `plugin/.claude-plugin/plugin.json` and
  `.claude-plugin/marketplace.json` bumped together and a matching
  `plugin/manifests/<version>.json`. `.claude/hooks/template-runtime-version.sh`
  blocks `gh pr create` if the two versions diverge, if the runtime changed without a
  bump, or if the version is already tagged. `plugin/scripts/` is deliberately **not**
  exempt from that check: it decides how every install behaves.
