# ADR — Plugin-based delivery: marketplace distribution and project materialization

- **Status:** Accepted — 2026-07-29
- **Supersedes:** [[adr-runtime-lifecycle-and-lessons]] **D1** only. Implements its D2,
  confirms D3, upholds D5. Leaves D4–D7 (the lessons model) intact and still the target.
- **Scope:** How the INSPIRE runtime is distributed and installed. Not a decision about
  the lessons/update machinery, which stays as its predecessor specified.

---

## Context

INSPIRE is distributed today as "fork the template repo." `install.sh` does `rm -rf` over
`.claude/{skills,bin,hooks}` before copying the runtime back in, destroying any non-INSPIRE
content a user placed there. There is no surgical update path — "re-run `install.sh` after
pulling template updates" means merging the template's git history into the product,
conflicting with product code, KB, and local skill edits. There is no changelog or migration
record of what changed between versions. And there is no install-in-place on-ramp: the only
way to adopt INSPIRE is to clone the template as your repo, which is wrong the moment a team
already has a codebase.

`adr-runtime-lifecycle-and-lessons` **D1** already named the fix in outline — a version-pinned
fetch (`git clone --depth 1 --branch <tag>` to a scratch dir, copy the owned paths in, discard
the scratch, never entangling the product's git history) as the brownfield on-ramp — but left
the mechanism to be built. This ADR builds it.

## Decisions

Decision numbers below are scoped to this ADR. A bare `D2` means this ADR's D2; a reference to
another ADR's decision is always qualified, e.g. `adr-runtime-lifecycle-and-lessons` D5.

### D1 — The plugin is the delivery vehicle, not the runtime

INSPIRE ships as a **Claude Code plugin published from a marketplace in this repo**. The
plugin is a *maintainer tool* — a per-user install that carries `/inspire:init` and
`/inspire:update` plus an inert payload. It is **never referenced at runtime**.

This implements, rather than replaces, `adr-runtime-lifecycle-and-lessons` D1's brownfield
fetch. The plugin *is* that pinned fetch, delivered by Claude Code with a real update UI.

### D2 — The runtime is materialized into the project and lives in git

`/inspire:init` materializes the payload into the repo. From then on the framework is shared
through git like any other project file. Consequences, all load-bearing:

- A teammate needs **nothing installed** — skills, validators, hooks and KB arrive with the
  checkout. Guardrails that depend on a per-user install are not guarantees.
- **CI works.** No Claude Code, no plugins; validators are in the repo.
- Skill changes appear in product PR diffs; `git checkout .claude/skills/` is the undo.
- Only whoever runs an init or update needs the plugin present.

### D3 — Per-project skill divergence requires local materialization

A plugin install is per-user, so a plugin-resident skill is necessarily identical across all
of that user's projects. `98_lessons/` is per-project by design ("relevance is local") and
`adr-runtime-lifecycle-and-lessons` D5 materializes lessons *into* the skill. Those cannot
both hold.

Confirmed mechanically: a project skill does **not** shadow a same-named plugin skill — per
the Claude Code docs, *"the original `/skill-name` and the plugin copy both remain available
rather than one overriding the other."* So the hybrid "plugin ships defaults, project
overrides" is unavailable. It is a clean either/or, and per-project teaching requires the
materialized copy.

### D4 — Placement follows execution coupling

**Placement is derived from one criterion: who can execute it.** The agent-portability note
under Consequences, below, measures the coupling of each layer; that measurement decides the
path, leaving no residual judgment.

```
inspire_kb/00_bootstrap … 99_tracker/     the KB        — visible: non-derivable, reviewed (D4e)
.inspire/bin/                             validators    — scaffolding, agent-agnostic, CI calls these
.inspire.lock                             provenance
.claude/inspire/hooks/                    hooks         — scaffolding, Claude-specific
.claude/skills/inspire-*/                 skills        — Claude-discovered, forced path
.claude/settings.json                     marker block  — Claude-specific
```

**Agent-agnostic → `.inspire/`.** The KB is markdown. The validators are bash + `yq`/`jq`,
runnable with no agent present. Agent-agnostic code must not sit in an agent-specific config
directory, because **CI must not depend on a path inside `.claude/`** — if a team drops Claude
Code, a teammate uses another agent, or layout conventions shift, `.claude/` may go
unmaintained while CI still has to pass.

**Claude-specific → `.claude/`.** Hooks are coupled *totally*: stdin JSON, the 0/2 exit
contract, registration in `.claude/settings.json`, meaningless without the harness. Skills are
discovered by Claude Code at a fixed path, so their location is forced regardless.
`.claude/inspire/` rather than `.claude/hooks/` so INSPIRE does not squat a generic name a
project may want.

**The KB is the exception to this criterion** — it is agent-agnostic *and* visible, for
reasons execution coupling cannot express. See D4e.

**Why the `.inspire/` name is free for the validators.** In the template it exists *solely* as
a dormancy workaround (see this repo's `CLAUDE.md`: *"If the runtime lived in `.claude/` inside
this template repo, those skills would fire while the template itself is edited — so it is
staged dormant under `.inspire/`."*). `plugin/base/` now provides dormancy (D1), so the name
carries no conflicting meaning.

**Why `.inspire.lock` stays at root** rather than moving to `.inspire/lock`:

- Lock files at repo root is near-universal — `Cargo.lock`, `flake.lock`,
  `package-lock.json`, `.terraform.lock.hcl`.
- It is read by the session-start hook, `inspire-lesson` and `/inspire:update`; root makes it
  resolvable from any working directory.
- It is the observer's discovery marker — with participating projects no longer being GitHub
  forks, an org-wide code search for `.inspire.lock` is the candidate mechanism, and a root
  dotfile is far more greppable than a nested one.

`settings.json` is reconciled by **marker-based JSON merge**, never a wholesale rewrite and
never a manual merge prompt.

The 65 hardcoded `.claude/…` references across `skills/`, `hooks/` and `bin/` are rewritten
alongside the other path substitutions, so the skill-decomposition release never touches a
path.

### D4b — Two skill tiers: lifecycle vs methodology

The rule for deciding where a skill lives — **does it operate on the *installation*, or on the
*project*?**

| Tier | Home | Skills |
|---|---|---|
| **Lifecycle** | plugin (`skills/`), per-user | `init`, `update` |
| **Methodology** | project (`.claude/skills/inspire-*`), materialized | all 13 `inspire-*` |

Two independent reasons the methodology tier cannot live in the plugin:

1. **Lessons target them.** The `skill:` enum in `lessons-format.md` explicitly includes
   `workspace` and `lesson` alongside the product-facing skills — those were deliberately
   declared teachable. By D3, a lesson target must be materialized. "Meta vs. product" is
   therefore the wrong axis: `lesson` writes `98_lessons/`, `workspace` reviews the KB,
   `bootstrap` writes `00_bootstrap/` — all project-side, all lesson-targetable.
2. **Plugin content costs context everywhere.** Plugin skill descriptions are resident in
   *every* project the user opens, INSPIRE or not — Claude Code surfaces this as a per-plugin
   *"Context cost estimate … tokens the plugin will add to your context window every turn."*
   The same hazard as hooks firing in unrelated repos. So the plugin surface is held to the
   minimum that must exist *before* a project does.

This rule is the deciding test for any skill added later.

### D4c — The `init` / `bootstrap init` boundary

`/inspire_bootstrap init` already claims *"first-time setup: establish `project.md`
(language), `stack.md` + `theme.md`, and create the project's root `README.md`."* That
overlaps `/inspire:init`. The boundary:

- **`/inspire:init` (plugin)** — mechanical, once-only: materialize the payload, create dirs,
  marker-merge `settings.json`, declare the marketplace, write `.inspire.lock`.
- **`/inspire_bootstrap init` (project)** — interview-driven, re-runnable: language, stack,
  theme, design system, README.

They stay separate because one is idempotent scaffolding and the other is a lesson-susceptible
interview — different natures, different tiers.

The handoff is a hint, not a direct call, and that is forced by skill-discovery mechanics:
Claude Code watches skill directories for file changes, and creating a top-level skills
directory that did not exist when the session started requires restarting Claude Code so the
new directory can be watched. In a greenfield repo, `/inspire:init` *creates*
`.claude/skills/`, so it is not watched and the newly materialized skills are unavailable to
the running session — a direct invocation of `/inspire_bootstrap init` would fail precisely in
the most common case. So init behaves conditionally: if `.claude/skills/` did not pre-exist, it
prints the restart instruction plus the next command; if it pre-existed (a re-init, or the
user's own skills already present), the materialized files load live and it offers the chain.

### D4d — The `bin`/`hooks` separation is free; nothing from `test/` materializes

`bin/` and `hooks/` end up in different trees as a consequence of D4's execution-coupling
criterion, not as a separate decision — the calling contracts differ, which is why the
coupling differs (`bin/` scripts take arguments and any caller, including CI, invokes them;
`hooks/` scripts read hook JSON off stdin and are meaningless outside Claude Code).

**Nothing from `bin/test/` materializes** — neither the fixtures nor the test runner. The
reason is not size, it is that **validators are not an extension point.** There is no lesson
category for bash: lessons target skills, and `adr-runtime-lifecycle-and-lessons` D5
materializes prose. So a project's edit to a validator has no capture mechanism — it is drift
the next `/inspire:update` re-copy overwrites, correctly. Shipping a test harness would imply
local rule authoring is supported when it is not. The drift check already communicates this
correctly — it hashes every materialized file, so an edited validator is surfaced and refused
rather than silently clobbered. Meanwhile the artifact that does legitimately diverge per
project, the skills, has its own travelling check.

### D4e — The KB is visible: `inspire_kb/`, fixed

D4 placed things by *who executes them*. That criterion misses a second axis: scaffolding vs.
non-derivable artifact. A dot prefix means "tooling you need not look at" — but the KB is
**not** hidden-worthy. It is largely agent-written, but it is **not derivable**: build output
is hidden because it can be regenerated from source, whereas here the KB *is* the source and
`source/` is derived from it (the ADR maturity ladder makes this explicit — a decision reaches
`implemented` when it lands in code, so the KB leads). A ledger of emergent intent is precisely
what gets audited, and what is audited must be visible.

**The path is `inspire_kb/`, fixed — not configurable.** A configurable `kb_root` was
considered and rejected on an asymmetry: `source_root` and `prototype_root` are configurable to
accommodate pre-existing reality — you cannot relocate someone's `src/`. The KB has no such
constraint, because INSPIRE creates it. Nothing pre-exists to fit around, so `kb_root` would be
configurability for taste, not for reality. The line for future roots: configurable when
something already exists that we must fit around; fixed when we are the ones creating it.

`SDD_SPEC_ROOT` is unchanged and unaffected — it points validators at an arbitrary subtree for
test fixtures, which is a test affordance, not a relocation mechanism.

### D5 — Marketplace declared in the project, trust-gated

`/inspire:init` offers (via `AskUserQuestion`) to write into the project's
`.claude/settings.json` an `extraKnownMarketplaces` entry for this repo plus
`enabledPlugins: ["inspire@inspire"]`. Teammates who trust the repo folder are **prompted** to
install — never silently. Declining breaks nothing, since the runtime is already in the repo.
Third-party marketplaces have auto-update **off** by default, so the base cannot shift under
anyone unasked.

## Alternatives considered and rejected

- **The plugin ships the 13 methodology skills live**, rather than as an inert `base/`
  payload. Rejected — this reverses `adr-runtime-lifecycle-and-lessons` D5 (materializing
  lessons into the skill): a per-user plugin install is necessarily identical across all of a
  user's projects, so it cannot give per-project lessons; and per D3, a project skill does not
  shadow a same-named plugin skill, so the hybrid "plugin default, project override" is
  mechanically unavailable.
- **A pinned curl bootstrap instead of a plugin.** Rejected — it would require maintaining all
  the fetch, update-detection and reconciliation plumbing by hand, with none of the update UI,
  trust gating, or marketplace mechanics Claude Code's plugin system already provides.
- **`{bin,hooks}` both under `.claude/inspire/`.** Rejected — puts the agent-agnostic
  validators beyond CI's reach, contradicting the coupling criterion in D4 (CI must not depend
  on a path inside `.claude/`).
- **`{bin,hooks}` both under `.inspire/`.** Rejected — puts the totally-coupled hooks outside
  `.claude/`, where Claude Code cannot discover or register them.
- **`bin/` nested under `hooks/`.** Rejected — skills invoke the validators directly at four
  call sites versus hooks' two; nesting asserts a dependency direction that is backwards for
  the majority of callers and reduces the recyclability it was meant to serve.
- **A configurable `kb_root`.** Rejected (D4e) — configurability for taste rather than reality;
  it would also introduce a chicken-and-egg (the root would have to live outside the KB it
  configures), expand `.inspire.lock` from provenance to provenance-plus-layout, and thread
  resolution indirection through every KB reference.
- **`.inspire/kb/`**, keeping the dot rather than dropping it. Rejected (D4e) — dropping the dot
  instead is a one-character substitution with **no change in path depth**, so every relative
  link inside the KB (`[[../../02_modules/…]]`) stays valid; `.inspire/kb/` would have shifted
  depth for every link crossing the KB boundary.
- **`_inspire_kb/`**, an underscore prefix for sort-first ordering. Rejected (D4e) — it overloads
  an existing convention: the KB already uses `_index.md` and `_template.md` to mean
  "structural, not a content node." Marking the whole vault that way would assert the KB is
  structure rather than content — backwards. The sort-first benefit does not outweigh it.
- **`spec/` and `kb/`.** Rejected (D4e) — bare generic names, higher collision risk in a
  brownfield repo, and `spec/` is inaccurate for a tree that also holds `99_tracker` and
  `98_lessons`.
- **Shipping `bin/test/`.** Rejected (D4d) — shipping a test harness would imply local rule
  authoring is a supported extension point; it is not, since validator edits have no lesson
  capture mechanism and are correctly treated as drift.
- **A `bootstrap.sh` agent-agnostic on-ramp**, to avoid regressing portability for non-Claude
  agents. Rejected for now — the payload is plain files in a public repo, so the escape hatch
  (clone it, ask any agent to materialize it) is already free and costs nothing to maintain;
  building a dedicated on-ramp is not justified before another agent's support is actually
  needed.

## Consequences

**Positive:** install/update become non-destructive — a plugin update cannot reach `.claude/`
or `.inspire/`, so materialized skills change only when the operator explicitly runs
`/inspire:update`, behind a plan gate, as a reviewable git diff; brownfield install-in-place
becomes possible without forking; CI and teammates need no plugin installed, since the runtime
lives in git once materialized; and a teammate gets skills, validators, hooks and KB with the
checkout alone.

**Negative:** the on-ramp now requires Claude Code's plugin system — `bash install.sh` worked
with any agent or none, `/inspire:init` and `/inspire:update` do not (see agent-portability
note, below); `/inspire:init` owns `settings.json` reconciliation as new, non-trivial
machinery; and a greenfield init requires a session restart, because materializing
`.claude/skills/` for the first time creates a directory Claude Code was not watching at
session start.

**Agent-portability note.** How coupled is INSPIRE to Claude Code? Measured, three tiers: the
KB, the validators, and the methodology (layer graph, lifecycle ladder, descriptor format)
carry **no** coupling — markdown, plain bash + `yq`/`jq`, and convention respectively, all
runnable or readable with no agent present. `SKILL.md` files are coupled only **by standard**
(the Agent Skills open standard works across multiple AI tools), with light coupling from
in-prose references to `AskUserQuestion`, `Workflow`, `TaskCreate`, the Skill tool and the
Agent tool. Delivery (plugin/marketplace) and hooks (event names like `PreToolUse`,
`SessionStart`) are **totally** coupled to Claude Code, as is invocation (`/inspire_x` slash
commands, the `CLAUDE.md` file name). The bulk of INSPIRE's value — knowledge, enforcement,
methodology — is agent-agnostic, and this design cuts both ways: D2 *improves* portability at
rest (the runtime lives in the repo, so any agent that reads markdown from a directory can
consume the skills) but *regresses the on-ramp* (init and update now require Claude Code's
plugin system, where `bash install.sh` worked with any agent or none). Not addressed now,
deliberately — no `bootstrap.sh` or curl fallback ships (see Alternatives); the enforcement
story stays agent-independent regardless, since CI makes validation real and hooks are only
fast feedback. If INSPIRE ever wants to support other agents directly, the work is: abstract
the in-prose tool references behind a capability vocabulary ("ask the operator one question"
rather than "use `AskUserQuestion`"); add a per-agent hooks story, or accept CI-only
enforcement; ship `AGENTS.md` alongside `CLAUDE.md`; and re-add a non-plugin on-ramp. Recorded
here so the coupling surface is already mapped when that day comes.

## Staging

Release A (v0.3.0) — this ADR, the repackaging, the path substitutions, install docs.
Release B (v0.4.0) — skill decomposition + the shape gate.
