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
    A pre-0.3 project is no longer refused; it is simply the longest chain.
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
    is the no-op.
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
        `00_bootstrap/stack.md`) — the template ships lean `react` + `nestjs`
        defaults; a project adds its own.
      - **Housekeeping** (6) — set up and keep the workspace coherent: `bootstrap`
        (greenfield foundation: language, stack, theme + the live design system),
        `surface` (the suite's surface roster and its lifecycle — `add`
        greenfield/split/adopt · `retire` · `review`; owns
        `00_bootstrap/surfaces.md`), `extract` (brownfield onboarding — fan out
        scanners over an existing codebase into KB candidates), `task` (the ticket
        tracker), `workspace` (the pre-PR global review + vault structure),
        `lesson` (the lessons
        catalog — write-once, timestamp-named, version-stamped one-line
        instructions that teach the skills how to behave in this project;
        relevant locally, distilled upstream by the observer). `base/skills/`
        also ships `_references/` — a shared reference directory alongside the
        `inspire-*` skill dirs; it is **not** matched by an `inspire-*` glob.
    - `base/bin/` → `.inspire/bin/` — the validators + a README: the mechanical
      half, promoted to a real top-level directory in a materialized project so
      CI never depends on a path inside `.claude/`. Spec root is configurable via
      `SDD_SPEC_ROOT` (defaults to `inspire_kb/04_domain`).
      `base/bin/test/` (the golden fixtures + test runner) **never** materializes
      — validators are not an extension point, so a project has no local rule
      authoring to preserve. Template test suite: `bash plugin/base/bin/test/run-tests.sh`.
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
      `05_screens/{surface}/{module}/{screen}.md` once 2+ UI surfaces exist. The
      `04_domain` tree is never surface-scoped — one domain truth spans the whole
      suite — and a project that declares no surfaces is a suite-of-one whose KB is
      byte-identical to one written before surfaces existed. See
      [docs/adr/adr-suites-and-surfaces.md](docs/adr/adr-suites-and-surfaces.md);
      the runtime rules live in `base/skills/_references/surface-scope.md`.
    - `base/templates/` → the provisional root `CLAUDE.md` (placeholders filled
      in afterwards by `/inspire_bootstrap init`, never clobbered if one already
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

It materializes `plugin/base/{skills,bin,hooks,kb,templates}` into the project
(`.claude/skills/`, `.inspire/bin/`, `.claude/inspire/hooks/`, `inspire_kb/`, plus
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
- **Six test suites, all run by hand — there is no CI.** Run the ones your change
  touches; run all six before a release:

  | suite | covers |
  |---|---|
  | `bash plugin/base/bin/test/run-tests.sh` | the validators, via golden fixtures |
  | `bash plugin/test/test-lib-common.sh` | `log`, `sha256_of`, `arr_to_json`, `version_cmp` |
  | `bash plugin/test/test-fixtures.sh` | the period-correct fixture builder |
  | `bash plugin/test/test-manifest.sh` | `gen-manifest.sh` + every shipped manifest reproduces |
  | `bash plugin/test/test-upgrade.sh` | detection, layout signatures, hops, the merge, end-to-end upgrades |
  | `bash plugin/test/test-materialize.sh` | `init` and `update` against scratch projects |

  The last two take minutes — that is the fixture builds, not a hang. Neither is
  parallel-safe: `test-upgrade.sh` uses literal `/tmp` paths, so two copies at once
  produce phantom failures.
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
