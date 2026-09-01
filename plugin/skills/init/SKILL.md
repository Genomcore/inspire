---
name: init
description: "Install the INSPIRE runtime into this repository: materialize the skills, validators, hooks and knowledge-base skeleton, register the hooks, and freeze the runtime version. Run once per project. Use when setting up INSPIRE in a new or existing repo."
---

# /inspire:init — install INSPIRE into this project

Materializes the plugin's inert payload into the repository and registers it. Once
committed, the runtime travels with the repo: teammates and CI need no plugin.

## Preconditions

1. **A git repository.** Run `git rev-parse --show-toplevel`. If it fails, stop and tell
   the operator to `git init` first.
2. **Tools.** `yq` (Mike Farah v4) and `jq` 1.6+ must be on `PATH`. Check with
   `command -v yq jq`. If either is missing, stop and report which.
3. **Not already installed.** If `.inspire.lock` exists, stop — this project is already
   initialized. Direct the operator to `/inspire:update` instead.
4. **Not the template repo.** If `plugin/.claude-plugin/plugin.json` exists at the
   project root, stop: this is the INSPIRE template itself, and installing here would
   activate the runtime against it.
5. **Not an unmigrated pre-0.3 project.** If `.inspire_kb/` exists and `inspire_kb/` does
   not, stop: this is a v0.2 layout that has not been migrated, and `/inspire:init` never
   migrates — it only installs fresh. `materialize.sh` refuses this too (exit 1), but say
   it here rather than surfacing it as an error — initializing over it would strand the
   entire knowledge base at `.inspire_kb/`, where no v0.3 skill looks. The remedy is to
   run `/inspire:update`, which migrates a pre-0.3 project: it detects the old layout and
   runs the hop chain to bring it forward, then applies the current base around whatever
   survives.

## Step 1 — Detect the shape

Record, before writing anything:

- `BROWNFIELD` — whether the repo has code already. Heuristic: any of `package.json`,
  `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `Gemfile` at root, or a `src/`
  directory. Used only to recommend roots in Step 2.
- `EXISTING_KB` — whether `inspire_kb/` is already present. With no `.inspire.lock`
  (precondition 3), that means this is an **adoption**, not a fresh install: a completed
  v0.2 migration, a restored backup, a KB vendored in before init, or a lock deleted by
  hand. `materialize.sh` seeds the KB additively — it replaces nothing under
  `inspire_kb/` — but the operator must be told, not have it inferred.

## Step 2 — Ask the operator

One `AskUserQuestion` with these questions:

1. **Product roots.** Greenfield (`source_root: source`, `prototype_root: prototype`) or
   brownfield-in-place (`source_root: .`, `prototype_root: none`)? Recommend by
   `BROWNFIELD`.
2. **Declare the marketplace for teammates?** If yes, Step 3 passes `--declare-marketplace`
   to `materialize.sh`, which writes `extraKnownMarketplaces` + `enabledPlugins` into
   `.claude/settings.json` so a teammate who trusts the repo folder is prompted to install
   the plugin. Recommend yes. Declining breaks nothing — the runtime is in the repo either
   way; only running a future `/inspire:update` needs the plugin.

## Step 3 — Show the plan, then materialize

Everything mechanical is handled by `materialize.sh` — copying (including the
`inspire_kb/` skeleton, seeded once here and never again), `chmod`, the `test/`
exclusion, design-system seeding, a provisional root `CLAUDE.md`, the `.gitignore`
block, product roots, the `settings.json` merge and `.inspire.lock`. This skill does
not reimplement any of it, and must not perform file operations of its own.

First a dry run, and show the operator what it will do:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/materialize.sh" \
  --mode init \
  --plugin-root "${CLAUDE_PLUGIN_ROOT}" \
  --project-root "$(git rev-parse --show-toplevel)" \
  --source-root "<answer>" --prototype-root "<answer>" \
  [--declare-marketplace] \
  --dry-run
```

Summarize the returned JSON for the operator: what will be created, what already exists and
will be left alone. Two fields need more than a summary line:

- **`existing_kb: true`** — the run is adopting a KB that is already there. Say so
  explicitly and confirm before proceeding: *"`inspire_kb/` already exists (N files). Init
  will keep everything in it and only add skeleton files it lacks. Proceed?"* If the
  operator did not expect a KB to be there, stop — a KB present without a lock usually
  means an interrupted migration or a restored backup, and it is worth understanding
  which before writing.
- **`warnings: [...]`** — print each one verbatim. These are conditions the run cannot fix
  on the operator's behalf. A `.gitignore` that excludes the runtime is the common one,
  and it silently defeats the point of committing the runtime at all.

Then run the same command **without** `--dry-run`.

If it exits non-zero, report its stderr verbatim and stop. Do not hand-patch a partial
install: on exit 2 the payload may already be on disk, but the settings block and
`.inspire.lock` were not written. Because the lock is written last, its absence means the
install did not complete — re-running `/inspire:init` is the correct recovery.

Parse the JSON summary from stdout and use it for Step 4's report. Report what the script
says it did, never what you assume it did.

## Step 4 — Report, and hand off

Print what was created — and re-print any `warnings` from the final run, above the handoff
rather than buried under it. A warning the operator scrolls past is a warning that did not
happen. Then:

```
INSPIRE <version> installed.

  Run:  /reload-skills
  Then: /inspire-bootstrap init

  (/reload-skills picks up the newly materialized skills; /inspire-bootstrap init
  fills in CLAUDE.md's placeholders and starts the KB.)
```

Do not invoke `/reload-skills` or `/inspire-bootstrap init` on the operator's behalf —
`/reload-skills` is the operator's action, and chaining `/inspire-bootstrap init` across it
would run against whatever skill state existed before the reload. Instruct, don't chain.

Remind the operator to **commit** the result — that is what makes the runtime available to
teammates and CI.

## Rules

1. **All file operations go through `materialize.sh`.** This skill never copies, `chmod`s,
   or edits `settings.json` itself. Mechanics live in the script so they are testable and
   shared with `/inspire:update`; judgment lives here. If something mechanical is missing,
   fix the script — do not work around it in prose.
2. **Report the script's JSON, not your assumptions.** The summary on stdout is the record
   of what happened.
3. **Stop rather than guess.** Every *Precondition* above is a hard stop with a clear
   message, never a thing to work around — and a non-zero exit from the script is a stop
   too, not something to patch up by hand.
4. **This skill does not author content.** Language, stack, theme and the project README
   belong to `/inspire-bootstrap init`.
5. **Instruct, don't chain.** Report the handoff and stop; `/reload-skills` and
   `/inspire-bootstrap init` are the operator's next actions, not this skill's.
