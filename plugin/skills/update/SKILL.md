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

1. `.inspire.lock` exists at the project root. If not, this project was never
   initialized — direct the operator to `/inspire:init`.
2. `jq` is on `PATH`.
3. A clean-enough working tree that the operator can review a diff. If `git status
   --porcelain` is non-empty, warn and ask whether to continue.

## Step 1 — Compare versions

Read `inspire_version` from `.inspire.lock` and `version` from
`${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`.

- Equal → report "already at <version>; nothing to do" and stop.
- Plugin older than the lock → the operator has an older plugin than the project was
  built from. Report both versions and stop; do not downgrade silently. Tell them what
  to do about it: update the plugin itself (`/plugin update inspire`, or refresh the
  marketplace) until it is at least the lock's version, then re-run `/inspire:update`.
- Plugin newer → continue.

## Step 2 — Drift check

**Scope: the runtime only, never the KB.** `inspire_kb/` is product content — seeded
once at init from `base/kb`, owned by the project from that moment on. It is not in
`.inspire.lock`'s `files` map, and `materialize.sh --mode update` never replaces or
deletes anything under it — the `kb` mapping is init-only (it seeds two missing files
additively; see Rule 2). Drift-check output below only ever names paths under
`.claude/skills/`, `.inspire/bin/` and `.claude/inspire/hooks/`.

**A pre-0.3 project cannot be updated in place.** If `.inspire.lock` has no `files`
map it came from the `install.sh` era, whose layout differs (`.inspire_kb/`,
`.claude/bin/`, `.claude/hooks/`). `materialize.sh` refuses with exit 2 and prints the
one-time manual migration; relay it verbatim rather than improvising.

**If a newer release adds a KB layer file** (a new README, a new starter template),
update will not deliver it — the `kb` mapping is init-only. That is deliberate, but it
leaves the operator with no automatic route to genuinely new skeleton content. If they
want it, tell them where to copy it from by hand:
`${CLAUDE_PLUGIN_ROOT}/base/kb/<layer>/<file>`. Never copy it for them without asking —
an existing file at that path is theirs.

Hashing is deterministic, so the script does it. This skill does not compute hashes itself:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/materialize.sh" \
  --mode drift-check \
  --plugin-root "${CLAUDE_PLUGIN_ROOT}" \
  --project-root "$(git rev-parse --show-toplevel)"
```

Read-only. Returns `unchanged`, `drifted` and `missing` arrays plus both versions.

## Step 3 — Plan, and gate

Print a plan before writing anything:

```
INSPIRE update — 0.3.0 → 0.4.0

  Will re-materialize   N files (unchanged since install)
  Will SKIP (drifted)   M files
  Missing               K files (will be restored)

  Drifted files — NOT overwritten:
    .claude/skills/inspire-domain/SKILL.md
    .inspire/bin/entity-coherence.sh
```

Then explain what drift means, precisely:

- **A drifted skill** is an uncaptured local teaching. To make it survive future updates,
  record it with `/inspire_lesson note` — that is the "import" step. Until the semantic
  rebuild exists, this skill will not overwrite it.
- **A drifted validator** is not a supported customization. There is no lesson category
  for bash, so it has no capture mechanism and no update path. Rule changes belong
  upstream — open an issue or a PR against INSPIRE.

**For each drifted file, give the operator what they need to merge it themselves.** A bare
refusal is a dead end; manual merge is the documented interim path, so make it actionable:

```
  .claude/skills/inspire-domain/SKILL.md
      yours:    .claude/skills/inspire-domain/SKILL.md
      new base: ${CLAUDE_PLUGIN_ROOT}/base/skills/inspire-domain/SKILL.md
      diff:     diff -u "${CLAUDE_PLUGIN_ROOT}/base/skills/inspire-domain/SKILL.md" \
                        ".claude/skills/inspire-domain/SKILL.md"
```

Offer to show any of those diffs inline before deciding. If the operator merges a file by
hand during this session, they must re-run `/inspire:update` afterwards so the lock records
the merged result as the new baseline — otherwise the next update reports it as drifted
again.

Stop for approval via `AskUserQuestion`: proceed (skipping drifted files), or abort.

## Step 4 — Materialize

On approval, one call — passing every drifted path as `--skip`. The script handles the
copying (mirroring `plugin/base/{bin,hooks,skills}` into the project, excluding
`base/bin/test` — the validator fixtures and harness are never materialized — and
excluding `base/kb` entirely, which `--mode update` never opens), the `settings.json`
re-merge and the lock rewrite; this skill performs no file operations of its own. The
re-merge only touches hook entries carrying the `INSPIRE-MANAGED` marker, so any hooks
the operator added independently are left alone.

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/materialize.sh" \
  --mode update \
  --plugin-root "${CLAUDE_PLUGIN_ROOT}" \
  --project-root "$(git rev-parse --show-toplevel)" \
  --source-root "<from stack.md>" --prototype-root "<from stack.md>" \
  --skip "<each drifted path>"
```

Read `source_root` and `prototype_root` from `inspire_kb/00_bootstrap/stack.md` — update
never re-asks; those were settled at init and changing them is a Shape change owned by
`/inspire_bootstrap stack`.

Run with `--dry-run` first if the operator wants to see the exact file list before writing.

**On failure:** if the script exits non-zero, report its stderr verbatim and stop; do not
hand-patch. On exit 2, the copy may already have landed on disk while `.inspire.lock` still
records the previous version's hashes, because copying runs first and the lock is written
last. Consequently a re-run's drift-check may report those freshly-copied, unskipped files
as drifted — that is expected after a failed update, and it is **not** the local-teaching
kind of drift described in Step 3. If unsure which it is, apply Step 3's `diff` guidance
against the new base to check; either way, proceeding is correct, because a skipped path is
rebaselined at its current hash when the lock is rewritten. Re-running `/inspire:update` is
the correct recovery — the copy is idempotent.

## Step 5 — Report

Summarize what changed, list what was skipped, and print every entry in the JSON's
`warnings` array verbatim — these are conditions the run could not fix on the operator's
behalf (a `.gitignore` excluding the runtime being the common one, which silently keeps the
update out of the commit entirely). Note that no session restart is needed:
`.claude/skills/` already existed at session start, so edits to files inside it load live.
Remind the operator to review the git diff and commit.

## What this skill is, and what is missing from it

Update has two halves, and only one of them can be a script:

| Half | Nature | Where it lives | Status |
|---|---|---|---|
| Version compare, drift hashing, copying, settings merge, lock rewrite | **deterministic** | `materialize.sh` | **complete** |
| Re-deriving each skill as `new base + surviving lessons` | **semantic** — a judgement about meaning, not a file operation | this skill | **not built (v1)** |

The second half is `adr-runtime-lifecycle-and-lessons` D6: classify every lesson against the
new base (absorbed / untouched / partial / contradicted), then rebuild each affected skill
from `theirs + apply(surviving lessons)`. It cannot be scripted — it is a semantic merge over
prose, which is exactly why that ADR rejected textual three-way merge for skills.

Until it exists, this skill's honest behaviour is to **refuse and assist** rather than
approximate: a drifted skill is left exactly as the operator wrote it, and Step 3 hands over
the paths and the `diff` command so they can merge it themselves. The deterministic half is
genuinely useful on its own — it brings validators, hooks and untouched skills forward safely
— and it is the substrate the semantic half will call.

**Refining that second half is a dedicated spike**, scheduled after Release B. See
*Follow-up: the update-process spike* at the end of this plan.

## Rules

1. **All file operations go through `materialize.sh`.** No copying, hashing or settings
   editing in prose. Drift detection is `--mode drift-check`.
2. **Never overwrite a drifted file, and never delete from the KB.** Pass every drifted
   path as `--skip`. Skipping and reporting is always correct; silent clobbering never is.

   **The guarantee's exact scope: files INSPIRE shipped.** Drift detection compares
   against `.inspire.lock`'s `files` map, so it protects files that came from a
   previous materialize. A file the *project* authored **inside** a skill directory
   INSPIRE owns — e.g. `.claude/skills/inspire-code/profiles/mystack.md`, or
   `inspire-*/references/*.md` — was never in the lock, so it is never reported as
   drift and **is deleted** when the entry is replaced. This is pre-0.3 behaviour
   (`install.sh` replaced owned entries the same way) and is on the v0.4 roadmap, not
   a regression. Report it as a known limitation if an operator asks. Project content
   belongs in the KB, in a `98_lessons` node, or in the project's `CLAUDE.md` — not
   inside an `inspire-*` directory.

   `inspire_kb/` is out of scope for replacement — `--mode update` never *replaces or
   deletes* anything under it and it carries no lock entries to drift. Two exceptions
   are additive and never clobber: `seed_design_system` creates
   `05_screens/design-system.md`, and `seed_claude_md` creates `CLAUDE.md`, **only if
   absent**. The KB is seeded once at init and belongs to the project from then on.
3. **The plan gate is mandatory.** No writes before approval.
4. **Never downgrade.** A plugin older than the lock is an error, not an update.
5. **No lesson reconciliation here.** Classification, archiving and skill rebuilding are v1
   (D6). This skill does not read `98_lessons/`. Do not approximate it — telling the operator
   a drifted skill was skipped is truthful; silently merging it is not.
6. **Do not re-ask the product roots.** Read them from `stack.md`; changing them is a Shape
   change owned by `/inspire_bootstrap stack`.
