---
name: update
description: "Update this project's INSPIRE runtime to the installed plugin's version: report drift, re-materialize unchanged files, and refuse to clobber local edits. Use after /plugin update inspire reports a newer base."
---

# /inspire:update — re-materialize the runtime

Brings a project's materialized runtime up to the plugin's current base. This is the
**materialize-only** stage: it does not yet reconcile lessons. Lesson classification and
skill rebuilding are specified in
[`adr-runtime-lifecycle-and-lessons`](https://github.com/Genomcore/inspire/blob/main/docs/adr/adr-runtime-lifecycle-and-lessons.md)
D6 and land at v1.

## Preconditions

1. **`.inspire.lock` is not required, and a missing one is not evidence of anything.**
   `--mode plan` identifies the project's version from what is actually on disk,
   scoring it against every shipped manifest; the lock is only a tie-break hint. A
   pre-0.3 install may legitimately have no lock at all — the `install.sh`-era
   installer wrote one only when both a manifest and `jq` were present — and those
   are exactly the projects this skill exists to migrate. So never read a missing lock
   as evidence that INSPIRE was never installed here, and never redirect the operator
   to `/inspire:init` over it: init refuses a pre-0.3 tree and points back here, so that
   advice is a closed loop with no exit. If the tree genuinely holds no INSPIRE
   runtime, `--mode plan` says so itself by exiting 1 — let it.
2. `jq` and `yq` (Mike Farah v4) are on `PATH` — `materialize.sh` hard-requires both.
3. A clean-enough working tree that the operator can review a diff. If `git status
   --porcelain` is non-empty, warn and ask whether to continue.

## Step 1 — Plan

Run `--mode plan` (`--mode drift-check` is accepted as a deprecated alias). It is
**read-only** — it writes nothing to the project, and that is asserted by the test
suite, not just claimed here:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/materialize.sh" \
  --mode plan \
  --plugin-root "${CLAUDE_PLUGIN_ROOT}" \
  --project-root "$(git rev-parse --show-toplevel)"
```

It detects the project's version (scored against every shipped manifest — never read
blindly from the lock, which is only a tie-break hint), verifies the layout, enumerates
the hop chain the upgrade would run, classifies every file the project has against what
the target version ships, and emits:

- **stdout** — JSON: `source_version`, `target_version`, `score`, `layout`, `chain` (the
  hop versions that would run), `verdicts` (a count per verdict — `noop`/`replace`/`keep`/
  `ask`/`create`/`restore`/`delete`), and `ask` (the array of paths that actually need a
  decision).
- **stderr** — the grouped human report (RUNTIME / KNOWLEDGE BASE / HARNESS / PRODUCT /
  LEFT ALONE).

**Relay the stderr report verbatim.** If it exits 1, relay the refusal and stop — do not
attempt a workaround. Exit 1 means a precondition failed (an unidentifiable project, a
downgrade, a layout the tool cannot verify), and every one of those is a decision only the
operator or a plugin update can resolve — this includes the pre-0.3, `install.sh`-era
layout, which is no longer a special case: it is simply the longest hop chain there is,
and `--mode plan`/`--mode update` migrate it like any other upgrade.

Version comparison and the never-downgrade guard are enforced in the script itself
(`version_cmp`), in both `--mode plan` and `--mode update` — do not compare
`inspire_version` to the plugin's `version` yourself, and do not second-guess the exit
code.

A newer release's brand-new KB layer file (a new README, a new starter template) is
delivered automatically too: KB seeding runs additively in **both** `init` and `update` —
a path already on disk is left alone, only a path the project lacks is added. There is
nothing manual to tell the operator about that any more.

## Step 2 — Decide

Only the paths in `ask` need a decision — everything else `--mode plan` already resolved
(`noop`/`replace`/`keep`/`create`/`restore`/`delete` all apply without asking). If `ask`
is empty, skip straight to Step 3.

Otherwise, one `AskUserQuestion` covering the whole batch: **keep mine** (every `ask`
path keeps the operator's file), **keep base** (every `ask` path takes the new version),
or **go one by one**.

For one-by-one, ask per file: **mine** / **base** / **merge**.
- `mine` / `base` resolve exactly like the batch choice, scoped to that file.
- **`merge` is the one case where your judgement is legitimate.** Read both the
  operator's file and the matching file under `${CLAUDE_PLUGIN_ROOT}/base/...`, write a
  combined file that preserves the operator's intent, save it at the operator's path, then
  resolve that path as `mine` in Step 3 (the file now on disk — the merged one — is the
  one to keep). Nowhere else in this flow should you edit file content: everywhere else
  the resolution is "pick one side," and the script performs it.

Leaving a path unresolved is a valid choice, not an error: an unresolved `ask` defaults to
**keeping the operator's file** — `materialize.sh` does this itself if you pass nothing
(see Rule 2).

## Step 3 — Apply

Re-run with `--mode update`, plus one `--take-base <path>` or `--take-mine <path>` per
resolved `ask` path — paths come straight back from the plan's `ask` array
(project-relative, no leading `/`, no `..`; `--skip` is accepted as a deprecated alias for
`--take-mine`):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/materialize.sh" \
  --mode update \
  --plugin-root "${CLAUDE_PLUGIN_ROOT}" \
  --project-root "$(git rev-parse --show-toplevel)" \
  --source-root "<from stack.md>" --prototype-root "<from stack.md>" \
  [--take-base <path>]... [--take-mine <path>]...
```

Read `source_root` and `prototype_root` from `inspire_kb/00_bootstrap/stack.md` — update
never re-asks; those were settled at init and changing them is a Shape change owned by
`/inspire_bootstrap stack`.

Run with `--dry-run` first if the operator wants to see the exact file list before
writing — the decision logic is identical in both, only the write is skipped, so the
preview cannot diverge from what happens next.

**On exit 2, relay the failure and tell the operator to re-run — that is now the correct
recovery, not a hopeful guess:**
- a hop that already moved a path is a silent no-op the next time (a missing source is
  treated as "already done," never an error);
- a failed layout hop stops the run *before* `.inspire.lock` is rewritten, so the
  version still reads the old one. That is deliberate and it is what makes the re-run
  work: a lock claiming a migration that did not happen would make the next run score
  the project as already migrated and never retry the hop. Tell the operator the
  version was left as it was — it is not a second failure to explain away;
- the content merge converges: a file already replaced with the new base version hashes
  identical to that base version, so a second run reads it as already matching and leaves
  it alone rather than reapplying or re-flagging it.

There is nothing to hand-patch and no different flags to pass. Re-running
`/inspire:update` with the same command is the whole recovery.

## Step 4 — Report

Relay the final report and every entry in the JSON's `warnings` array verbatim — these
are conditions the run could not fix on the operator's behalf (a `.gitignore` excluding
the runtime is the common one, which silently keeps the update out of the commit
entirely). Note that no session restart is needed: `.claude/skills/` already existed at
session start, so edits to files inside it load live. Remind the operator to review the
git diff and commit.

## Step 5 — Nudge

For each kept **skill** edit (an `ask` resolved to `mine`, or a plain `keep` verdict):
tell the operator the customization belongs in `/inspire_lesson note`. Say plainly that
nothing is remembered by this flow — the same file will be classified as `ask` (or
`keep`) again on the next upgrade, and that recurrence is deliberate: it is what stands in
for the lesson-reconciliation half (D6) that does not exist yet.

For each kept **validator** edit: there is no capture mechanism for it — a lesson has no
category for bash. Say it belongs upstream: open an issue or a PR against INSPIRE.

## What this skill is, and what is missing from it

Update has two halves, and only one of them can be a script:

| Half | Nature | Where it lives | Status |
|---|---|---|---|
| Version compare, manifest-driven content classification, the hop chain, copying, settings merge, lock rewrite | **deterministic** | `materialize.sh` | **complete** |
| Re-deriving each skill as `new base + surviving lessons` | **semantic** — a judgement about meaning, not a file operation | this skill | **not built (v1)** |

The second half is `adr-runtime-lifecycle-and-lessons` D6: classify every lesson against the
new base (absorbed / untouched / partial / contradicted), then rebuild each affected skill
from `theirs + apply(surviving lessons)`. It cannot be scripted — it is a semantic merge over
prose, which is exactly why that ADR rejected textual three-way merge for skills.

Until it exists, this skill's honest behaviour is to **ask rather than approximate**: a
conflicted file (an `ask` path) is never silently reconciled. Step 2 puts every one of them
to the operator — mine / base / merge — and `merge` is the only point in this whole flow
where the agent's own judgement about file content is legitimate; everywhere else the
resolution is "pick one side," and the script performs it. The deterministic half is
genuinely useful on its own — it brings validators, hooks and untouched skills forward
safely, migrating even a pre-0.3 project in the process — and it is the substrate the
semantic half will call.

**Refining that second half is a dedicated spike**, scheduled after Release B. See
*Follow-up: the update-process spike* at the end of this plan.

## Rules

1. **All file operations go through `materialize.sh`.** No copying, hashing or settings
   editing in prose. Content classification is `--mode plan` (`--mode drift-check` is
   accepted as a deprecated alias).
2. **Never silently overwrite an operator's file.** An `ask` row left unresolved defaults
   to keeping the operator's version — doing nothing is how work survives. Only
   `--take-base` moves a conflicted path to the new base version; only a `merge` you write
   yourself combines the two.

   **The guarantee's exact scope: files INSPIRE shipped.** Classification compares disk
   against the SOURCE version's manifest (`plugin/manifests/<version>.json`) and the
   current `base/` — not against any lock; the lock's old `files` map is gone. A file the
   *project* authored **inside** a skill directory INSPIRE owns — e.g.
   `.claude/skills/inspire-code/profiles/mystack.md`, or `inspire-*/references/*.md` — was
   never in any manifest, so it always classifies as `keep` ("yours — INSPIRE never
   shipped this") and is never touched or deleted. This is the fix for the pre-0.3
   behaviour (`install.sh` used to `rm -rf` a whole owned entry, destroying exactly these
   files) — already shipped, not a roadmap item. Project content still belongs in the KB,
   in a `98_lessons` node, or in the project's `CLAUDE.md` — not inside an `inspire-*`
   directory — but a file left there by mistake now survives rather than being silently
   destroyed.

   `inspire_kb/` is out of scope for replacement — `--mode update` never *replaces or
   deletes* anything under it, and content classification never runs against it at all; KB
   seeding is a separate, purely additive path that runs in both `init` and `update` (see
   Step 1). Two exceptions are additive and never clobber: `seed_design_system` creates
   `05_screens/design-system.md`, and `seed_claude_md` creates `CLAUDE.md`, **only if
   absent**.
3. **No writes happen before Step 2's decisions are gathered.** `--mode plan` itself
   writes nothing, whatever the operator decides — that is asserted by the test suite, not
   just documented here.
4. **Never downgrade.** A plugin older than the project's detected version is an error, not
   an update — enforced by `version_cmp` in the script, in both `--mode plan` and
   `--mode update`.
5. **No lesson reconciliation here.** Classification, archiving and skill rebuilding are v1
   (D6). This skill does not read `98_lessons/`. Do not approximate it — telling the operator
   an edit was kept is truthful; silently merging it is not.
6. **Do not re-ask the product roots.** Read them from `stack.md`; changing them is a Shape
   change owned by `/inspire_bootstrap stack`.
