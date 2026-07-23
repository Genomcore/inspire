# ADR 0001 — Runtime lifecycle: distribution, ownership, and the lessons-based update model

- **Status:** Accepted (design) — 2026-07-22. Implementation staged: docs + safe
  foundations now (pre-v1, *accelerated breathing*); the update machinery builds at v1
  (*conscientious breathing*).
- **Scope:** INSPIRE **core itself** — how the guardrail runtime is installed into a
  project, updated across releases, and how a fork's local skill customizations survive
  those updates. Not a decision about any product built on top of INSPIRE.
- **Authoring note:** This is a **core-level** decision. INSPIRE core is developed in the
  template repo and is *not* an instantiated fork (no live `.claude/`, no `inspire-adr`
  skill running here), so this ADR is hand-authored plain Markdown under `docs/adr/`.
  `install.sh` only ever copies specific subdirectories of `.inspire/`, so `docs/` never
  leaks into a fork. The fork-facing ADR skeleton (`.inspire_kb/01_adr/`) stays generic
  and is deliberately not used for this.

---

## Context

Today INSPIRE is distributed as **"fork the template repo."** A project is a clone of
this repository; `install.sh` copies the dormant runtime from `.inspire/{skills,bin,hooks}`
into `.claude/{skills,bin,hooks}` where Claude Code discovers it; the product you build
lives in non-dot dirs (`source/`, `prototype/`) alongside it.

This model has four coupled problems, all traceable to the same root: **the runtime and
the product share one git history, so updating the runtime means merging the template's
history into your product.**

1. **`install.sh` destroys non-INSPIRE content.** Step 1 does `rm -rf "$DEST/$part"` over
   the *whole* `skills`, `bin`, and `hooks` directories before copying
   ([`.inspire/install.sh` L32–38](../../.inspire/install.sh)). Any skill, hook, or bin
   the user placed in `.claude/` (personal skills, other plugins) is deleted on
   (re)install. The advertised idempotency only holds for `prototype/`, `source/`,
   `README.md`, `settings.json`, and `design-system.md` — not for the contents of
   `.claude/`.
2. **No surgical update.** "Re-run `install.sh` after pulling template updates" is the
   only update path, and pulling updates means merging template git history into the
   product — conflicts with product code, KB, and any local skill edits. There is no
   command that fetches a release, sees what changed, and reconciles it without
   destroying local work.
3. **No changelog or migration path.** `.inspire.lock` records provenance (which version
   was installed) but there is no machine- or human-readable record of *what changed
   between versions* and *what a fork must migrate* — neither for the runtime nor for the
   authored knowledge base.
4. **No install-in-place for an existing repo.** The only on-ramp is "clone the template
   as your repo." A team with an existing codebase cannot add INSPIRE without forking,
   and `install.sh` unconditionally creates `source/` and `prototype/` at the repo root
   ([L93–102](../../.inspire/install.sh)) — wrong when the product code already lives at
   `./`, `packages/`, `apps/`, etc.

A fifth, subtler issue underlies the "how do updates preserve local edits" question: the
runtime's skills are **natural-language instructions**, not code. A line-level three-way
merge — correct for `bin/` bash — is wrong for prose: a few words can flip a skill's
meaning, and a textually-clean merge can produce a semantically incoherent skill.

## Decision

Reframe INSPIRE from **"a repo you fork"** to **"a runtime you vendor/install"**, with a
declared ownership boundary, a rebuild-based update model, and a lessons layer that is the
sole durable record of local skill customization.

### D1 — Distribution: vendored dependency, two on-ramps

The runtime is an installable/updatable dependency, fetched at a **pinned release** and
materialized in place. Two on-ramps:

- **Greenfield** — clone the template (as today).
- **Brownfield / install-in-place** — a bootstrap drops the runtime + KB skeleton into an
  existing repo without touching product code. Mechanically: `git clone --depth 1
  --branch <tag>` to a scratch dir, copy the owned paths in, discard the scratch — a bash
  command that fetches from the public remote but **never entangles the product's git
  history** (no submodule, no subtree, no merge of template history). A `curl | bash`
  bootstrap may wrap this as sugar, but always version-pinned, never `main`.

### D2 — Ownership: a namespace and a manifest, never a directory

INSPIRE owns a **namespace, not a directory**. A manifest enumerates exactly the paths the
runtime places (`inspire-*` skills, the validators, the hooks). install / uninstall /
update touch **only** manifest paths; everything else in `.claude/` is the user's and is
never removed. Consequences:

- No `rm -rf` of `.claude/{skills,bin,hooks}`. Copy/remove only `inspire-*` (plus shared
  `_references`). Namespacing the validators/hooks under an owned subpath (e.g.
  `.claude/inspire/`) makes "what INSPIRE owns" trivially enumerable; this requires
  updating the `.claude/bin/…` paths the skills and `_lib.sh` currently assume flat.
- `settings.json` is reconciled by a **marker-based JSON merge** (a tagged INSPIRE hook
  block), never a wholesale rewrite and never a manual "merge this yourself" prompt.
- `.inspire.lock` carries version + provenance + a **content hash per owned file**, so
  update can detect "did the user modify this file since install?" without keeping a full
  pristine copy on disk.

### D3 — `source` / `prototype` are configuration, not fixed folders

Introduce `source_root` and `prototype_root` (declared in `00_bootstrap`, mirrored to the
validators as `SDD_SOURCE_ROOT` / `SDD_PROTOTYPE_ROOT`, following the existing
`SDD_SPEC_ROOT` pattern). Defaults stay `source/` + `prototype/` for greenfield (no
regression). Brownfield sets `source_root: .` ("the repo root *is* the production
monorepo, governed in place") and may set `prototype_root: none`. Every skill that
hardcodes `/source` or `/prototype` reads the configured path instead. `inspire-extract`
gains the ability to scan the configured `source_root` (today it forbids scanning
`/source`), completing the brownfield onboarding loop: install → `bootstrap init` with
`source_root: .` → `extract scan .`.

### D4 — Lessons: declarative, one-line, atomic; relevance is local

Rename the `learnings` concept to **lessons**. A lesson is the transmissible unit: it can
be *learned* or *taught*, and the folder is a **catalog of lessons** a fork holds. Two
reframes from the current `inspire-learn` design:

- **Relevance is local; generalization is the observer's job.** Capture stops asking the
  operator "is this generalizable / worth sending upstream?" — the wrong person to judge
  it from a single context. A lesson means "this is relevant to me here and I don't want
  to lose it." Whether it generalizes is decided downstream by the **observer** (the
  central pull-from-above agent) across the distribution of many forks' lessons.
- **One-line and atomic.** A lesson's body is a **single imperative line** ("do X this
  way"); at most two (positive + negative: "do X" / "don't do Y"); an optional **example
  is *support only***, never the instruction. The one-line limit *mechanically enforces*
  atomicity — you cannot pack two intents into one imperative without it obviously being
  two lessons — which makes the update-time split (D6) rare and clean, and keeps the
  catalog and the materialization prompt small. `apply` (D5) consumes only the
  instruction line(s); the example exists for the `plan` review, the classifier, and the
  observer, and is never materialized.

Frontmatter (machine-read metadata: target skill, version stamp, `supersedes`, date) is
retained; only the body shrinks.

### D5 — Materialization: internalize into the skill (Terraform desired-state)

Lessons are **materialized into the skill file** — the taught behavior *becomes* the
skill's behavior — rather than layered as a runtime overlay. The goal is internalization:
the agent should behave as taught, not "consult the book and apply the note if it happens
to weight it." The relationship is Terraform's desired-state model:

- **Lessons = the declaration** (source of truth). **The skill file = materialized state**
  (a derived artifact). `apply` reconciles the skill to `base + lessons`.
- A **hand edit to a skill that is not captured as a lesson is drift** — it is overwritten
  on the next `apply`, exactly like an out-of-band change to cloud infrastructure. Nothing
  forbids hand-editing; but to persist a change you must write the lesson (the "import"
  step). `plan` (D6) surfaces detected drift before it is overwritten.

Materialization runs **once per update** (a gated build step), not per session — which
*contains* the LLM nondeterminism to a single reviewable moment rather than spreading it
across every session (the failure mode a runtime overlay would have had).

### D6 — Update is a rebuild, not a merge

On update to a new base version, the skill is **rebuilt** as `theirs + apply(surviving
lessons)`. The old materialized skill (`mine`) is used as **evidence** for classification,
not as a merge input — the previous materialization is discarded and regenerated, so drift
never compounds across versions.

Each lesson is classified (embarrassingly parallel — one agent per lesson, given `mine`,
`theirs`, and the changelog) into **four outcomes**:

| Outcome | Meaning | Action |
|---|---|---|
| **Absorbed** | the new base now does this natively | move the lesson to `archive/` — no longer taught |
| **Untouched** | the base is unchanged w.r.t. this lesson | keep and re-materialize |
| **Partial** | the base absorbed part of it | `supersede` the old lesson; write a new atomic lesson carrying only the **residual** uncovered part |
| **Contradicted** | the base deliberately reversed this behavior | **human gate** — by default respect the local lesson; the operator decides whether to accept the upstream reversal |

Bias is **conservative toward keep**: a false "absorbed" silently regresses taught
behavior (dangerous), whereas a false "untouched" merely re-applies something redundantly
(usually harmless). Two human gates bracket the run: a **`plan`** phase (Terraform-style)
that shows what will be applied — highlighting archives and contradictions, and flagging
any pre-update **drift** (uncaptured hand edits about to be lost) — and a post-run review
of the archive set. Classification runs in parallel; per-skill materialization is
serialized and respects the `supersedes` chain (mirrors `inspire-extract`'s "scan parallel,
author ordered").

The effect is a **monotonic reduction of teaching debt**: every update archives the
lessons the base has learned, leaving only what is still applicable.

### D7 — Changelog as a release artifact; graceful degradation; purge on archive

The changelog is a **release artifact produced by core**, versioned and structured
**per-skill**, shipped alongside each release, and annotated by the observer with which
lesson *themes* a release absorbed. It is the index that makes D6's classification cheap
and accurate.

Crucially, **the update degrades gracefully without it**: classification can run against
`theirs` alone (the agent reads the new skill fully instead of a targeted delta) — costlier
but functional. The changelog is an **accelerant for cost and precision, not a hard
dependency**. This lets the update mechanism ship before the changelog system exists.

`purge` operates **only on `archive/`** and is fully optional; the live catalog is never
purged. The archive is durable provenance by default (recoverable from git regardless, and
useful to the observer as confirmation that a generalization landed).

### The closed loop (target picture, v1)

`fork lessons → observer → core lessons (= the changelog) → fork update classification →
fork archives the now-native lesson`. Each turn reduces what a fork must re-teach. Core
recording its own changes as lessons is INSPIRE applying its regeneration thesis to itself
one level up — deferred to v1 (see *Staging*).

## Alternatives considered and rejected

- **Keep "fork the template".** Rejected — it is the root cause of all four problems;
  updating the runtime means merging template history into the product.
- **Textual three-way merge for skills.** Rejected for prose — line-diffs cannot capture
  semantic intent; a clean textual merge can be a semantically broken skill. (Retained as
  appropriate for `bin/`/`hooks/` bash, which are code.)
- **Runtime overlay — don't materialize; load lessons as always-in-context notes.**
  Rejected — it is "consult the book every time," leaves the base as the authority, and
  spreads reconciliation nondeterminism across *every session* rather than one gated build
  step. Internalization (D5) is the explicit goal.
- **Vendor a pristine `.inspire/` inside every product as the merge base.** Rejected in
  favor of the manifest + per-file hashes (D2) — avoids duplicating the whole runtime in
  every product repo; the pristine base is re-fetched only for the rare genuine conflict.
  (`.inspire/` remains only in the *template*, where dormancy genuinely requires it.)
- **git submodule / subtree for the runtime.** Rejected — entangles the product's history,
  complicates the namespace-ownership model, and buys little since Claude Code loads from
  `.claude/` regardless.
- **Learnings as a curated upstream-feedback journal (status quo).** Rejected in favor of
  lessons as a durable *local* catalog whose generalization is the observer's concern
  (D4).

## Consequences

**Positive**
- Install/uninstall/update become surgical and non-destructive; user content in `.claude/`
  is safe.
- Brownfield install-in-place becomes a first-class on-ramp; `source_root: .` governs an
  existing repo without restructuring it.
- Updates preserve local skill customization in a way appropriate to prose, and shrink the
  teaching debt on every release.
- A clean, symmetric fork↔core loop, with lessons as the single unit of divergence in both
  directions.

**Negative / costs**
- Materialization is LLM-fuzzy. Mitigated by: one-per-update (not per-session), the `plan`
  + archive-review human gates, and atomic one-line lessons.
- Renaming `learnings`→`lessons` ripples across the skill, the KB layer, the format
  reference, the session-start hook copy, the manual, and cross-references.
- The changelog needs generating; the full update machinery is significant build effort.
- De-hardcoding `source`/`prototype` and namespacing `bin`/`hooks` touch many files.

**Load-bearing fact for timing:** no fork is pinned to a *released* version today, so the
"from" of any update does not yet exist. The update machinery is therefore
design-now-build-at-v1 **by necessity**, not merely by prudence.

## Staging

**Now (pre-v1, accelerated breathing)** — docs + safe foundations:
- This ADR.
- *(optional)* a `.manual/` "Updates & Lessons" page, authored *after* this ADR and marked
  **roadmap** for the not-yet-built update flow.
- *(optional, safe)* fix `install.sh`'s `rm -rf` → namespace-scoped copy + owned-paths
  manifest.
- *(optional)* lessons **capture** redesign (authoring side only: rename, one-line format,
  README rewrite); the **consumption** side (apply/update) is deferred.
- *(optional)* `source_root` / `prototype_root` config + de-hardcoding.

**v1 (conscientious breathing)** — the machinery:
- `inspire-update` / `install.sh --update`: fetch → parallel classification → plan/drift →
  rebuild-materialize → archive.
- Changelog-as-release-artifact + graceful-degradation path.
- Brownfield in-place installer (`--into`, pinned fetch to scratch).
- Core dogfooding its own lessons/changelog.

## Open items

- **Naming:** `lesson` (the artifact noun) is fixed; the skill rename (`inspire-learn` →
  `inspire-lesson`) and folder rename (`98_skill_learnings` → `98_lessons`) are proposals,
  not decided.
- **ADR granularity:** captured here as one cohesive ADR; may later split into separate
  records (distribution / ownership / lessons) so each can be superseded independently.
