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

- `BROWNFIELD` — whether the repo has code already. Heuristic: any of `package.json`,
  `pyproject.toml`, `go.mod`, `Cargo.toml`, `pom.xml`, `Gemfile` at root, or a `src/`
  directory. Used only to recommend roots in Step 2.

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

If it exits non-zero, report its stderr verbatim and stop. Do not hand-patch a partial
install: on exit 2 the payload may already be on disk, but the settings block and
`.inspire.lock` were not written. Because the lock is written last, its absence means the
install did not complete — re-running `/inspire:init` is the correct recovery.

Parse the JSON summary from stdout and use it for Step 4's report. Report what the script
says it did, never what you assume it did.

## Step 4 — Report, and hand off

Print what was created, then:

```
INSPIRE 0.3.0 installed.

  Run:  /reload-skills
  Then: /inspire_bootstrap init

  (/reload-skills picks up the newly materialized skills; /inspire_bootstrap init
  fills in CLAUDE.md's placeholders and starts the KB.)
```

Do not invoke `/reload-skills` or `/inspire_bootstrap init` on the operator's behalf —
`/reload-skills` is the operator's action, and chaining `/inspire_bootstrap init` across it
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
3. **Stop rather than guess.** A missing `yq`/`jq`, a non-git directory, an existing
   `.inspire.lock`, or the template repo itself are all hard stops with a clear message. A
   non-zero exit from the script is a stop, not something to patch up by hand.
4. **This skill does not author content.** Language, stack, theme and the project README
   belong to `/inspire_bootstrap init`.
5. **Instruct, don't chain.** Report the handoff and stop; `/reload-skills` and
   `/inspire_bootstrap init` are the operator's next actions, not this skill's.
