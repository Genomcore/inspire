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

## Step 1 — Detect the shape

Record, before writing anything:

- `PRESET_SKILLS` — whether `.claude/skills/` already exists. This decides the handoff in
  Step 7, because Claude Code cannot watch a top-level skills directory created after the
  session started.
- `BROWNFIELD` — whether the repo has code already. Heuristic: any of `package.json`,
  `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `Gemfile` at root, or a `src/`
  directory. Used only to recommend roots in Step 6.

## Step 2 — Ask the operator

One `AskUserQuestion` with these questions:

1. **Product roots.** Greenfield (`source_root: source`, `prototype_root: prototype`) or
   brownfield-in-place (`source_root: .`, `prototype_root: none`)? Recommend by
   `BROWNFIELD`.
2. **Declare the marketplace for teammates?** If yes, Step 6 writes
   `extraKnownMarketplaces` + `enabledPlugins` into `.claude/settings.json` so a teammate
   who trusts the repo folder is prompted to install the plugin. Recommend yes. Declining
   breaks nothing — the runtime is in the repo either way; only running a future
   `/inspire:update` needs the plugin.

## Step 3 — Show the plan, then materialize

Everything mechanical is handled by `materialize.sh` — copying, `chmod`, the `test/`
exclusion, design-system seeding, product roots, the `settings.json` merge and
`.inspire.lock`. This skill does not reimplement any of it, and must not perform file
operations of its own.

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
will be left alone. Then run the same command **without** `--dry-run`.

If it exits non-zero, report its stderr verbatim and stop. Do not attempt a partial
recovery by hand — exit 2 means nothing was committed.

Parse the JSON summary from stdout and use it for Step 4's report. Report what the script
says it did, never what you assume it did.

## Step 4 — Report, and hand off

Print what was created, then the next step — which depends on `PRESET_SKILLS` from Step 1:

**If `.claude/skills/` did not pre-exist** (the common greenfield case), the newly
materialized skills are **not available in this session**: Claude Code watches skill
directories for changes, but *"creating a top-level skills directory that did not exist
when the session started requires restarting Claude Code."* So print:

```
INSPIRE 0.3.0 installed.

  Restart Claude Code, then run:  /inspire_bootstrap init

  (The skills directory was just created, so this session cannot see it yet.)
```

Do **not** attempt to invoke `/inspire_bootstrap init` via the Skill tool here — it will
fail, because the skill does not exist as far as this session is concerned.

**If `.claude/skills/` did pre-exist**, the materialized files load live. Offer the chain
with `AskUserQuestion`: run `/inspire_bootstrap init` now, or later. On "now", invoke it
with the Skill tool.

Either way, remind the operator to **commit** the result — that is what makes the runtime
available to teammates and CI.

## Rules

1. **All file operations go through `materialize.sh`.** This skill never copies, `chmod`s,
   or edits `settings.json` itself. Mechanics live in the script so they are testable and
   shared with `/inspire:update`; judgment lives here. If something mechanical is missing,
   fix the script — do not work around it in prose.
2. **Report the script's JSON, not your assumptions.** The summary on stdout is the record
   of what happened.
3. **Stop rather than guess.** A missing `yq`/`jq`, a non-git directory, an existing
   `.inspire.lock`, or the template repo itself are all hard stops with a clear message. A
   non-zero exit from the script is a stop, not something to patch up by hand.
4. **This skill does not author content.** Language, stack, theme and the project README
   belong to `/inspire_bootstrap init`.
5. **Never invoke `/inspire_bootstrap init` via the Skill tool after a greenfield init** —
   the skill is not loadable until the session restarts. Print the instruction instead.
