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
    and `/inspire:update` (re-materialize from a newer plugin version, reporting
    drift and never overwriting a locally-edited file).
  - `plugin/scripts/materialize.sh` — the mechanics both of the above skills call:
    copying, `chmod`, excluding `base/bin/test/`, seeding the design system, seeding
    a provisional root `CLAUDE.md` + a `.gitignore` block, creating the product
    roots, the marker-based `settings.json` merge, and writing `.inspire.lock`
    (which now carries a `files` map — path → sha256 — driving `/inspire:update`'s
    drift detection, alongside `inspire_version`/`released`/`template_sha`).
  - `plugin/base/` — the **inert payload**: materialized into a project by
    `/inspire:init`, never auto-loaded here because Claude Code only discovers a
    plugin's `skills/`, `hooks/`, `agents/` and `bin/` at its top level, not inside
    a nested `base/`. Materializes as:
    - `base/skills/` → `.claude/skills/inspire-*` — the 13 agent skills: the
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
      - **Housekeeping** (5) — set up and keep the workspace coherent: `bootstrap`
        (greenfield foundation: language, stack, theme + the live design system),
        `extract` (brownfield onboarding — fan out scanners over an existing
        codebase into KB candidates), `task` (the ticket tracker), `workspace`
        (the pre-PR global review + vault structure), `lesson` (the lessons
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
      purpose and layout.
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
`/inspire:update` re-materializes newer plugin versions, reporting drift and
refusing to overwrite anything locally edited.

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
- Run the validator suite with `bash plugin/base/bin/test/run-tests.sh` after
  touching anything under `plugin/base/bin/`.
