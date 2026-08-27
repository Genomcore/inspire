---
name: update
description: "Update this project's INSPIRE runtime to the installed plugin's version: report drift, re-materialize unchanged files, and refuse to clobber local edits. Use after /plugin update inspire reports a newer base."
---

# /inspire:update — re-materialize the runtime

Brings a project's materialized runtime up to the plugin's current base. This is the
**materialize-only** stage: it does not reconcile lessons. Lesson classification and
skill rebuilding are specified in
[`adr-runtime-lifecycle-and-lessons`](https://github.com/Genomcore/inspire/blob/main/docs/adr/adr-runtime-lifecycle-and-lessons.md)
D6, and building them is future work — nothing here approximates them in the meantime.

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
  `ask`/`create`/`restore`/`delete` — tallied over the *merged* hop-journal + classify
  stream, the same union the stderr footer counts, never a classify-only tally), and `ask`
  (the array of paths that actually need a decision, the same union). `--mode update`'s own
  stdout carries the identical `ask` field: whatever a hop asked and no `--take-base`/
  `--take-mine` answered is still listed there once the run is done (Step 3).
- **stderr** — the grouped human report (RUNTIME / KNOWLEDGE BASE / HARNESS / PRODUCT /
  LEFT ALONE). In `--mode update` (never in `--mode plan`, which writes nothing at all)
  the same report is also saved to `.inspire/last-upgrade.log`, overwritten on each run —
  so what an upgrade did stays auditable after the session ends.

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
a path already on disk is left alone, only a path the project lacks is added. That
direction stays fully automatic. As of 0.7.0 a versioned hop can also go the other way and
*retire* a KB seed file the project no longer needs — a proven-derivable one is deleted
silently, a diverged one lands in `ask` like any other conflict (Step 2). So "nothing
manual" no longer covers the whole picture: seeding is still silent, retirement sometimes
is not.

## Step 2 — Decide

Only the paths in `ask` need a decision — everything else `--mode plan` already resolved
(`noop`/`replace`/`keep`/`create`/`restore`/`delete` all apply without asking). If `ask`
is empty, skip straight to Step 3.

Otherwise, one `AskUserQuestion` covering the whole batch: **keep mine** (every `ask`
path keeps the operator's file), **keep base** (every `ask` path takes the new version),
or **go one by one**. **Retirement asks are excluded from both batch shortcuts.** Every
`ask` path under `inspire_kb/` is one — content classification never runs against
`inspire_kb/` at all (Rule 2; no shipped manifest lists a KB path), so a KB-rooted `ask`
has no source but a hop proposing to retire a seed file it could not prove derivable. A
batch "keep base" must never delete a KB index as a side effect of accepting ordinary
skill/hook updates, and a batch "keep mine" must not wave a retirement through unseen
either — the operator sees what they are declining, not just the safe outcome by accident.
Itemize every retirement ask instead, one by one, below.

**Two more kinds of `ask` are excluded from both shortcuts, for that same reason.** A
**collision** ask — a path the target version newly ships where the operator already has
a file — carries the file Rule 2 protects, so a batch "keep base" must not replace it as a
side effect of accepting ordinary skill updates. A **split-case** ask — a `SKILL.md` with
`create` rows beside it under the same skill's `references/` — needs the two-copies and
new-home disclosure below, which neither batch answer can give. Itemize both one by one
too; the batch shortcuts are for asks whose two outcomes an operator can weigh from the
path alone.

For a content `ask` (anywhere outside `inspire_kb/`), ask per file: **mine** / **base** /
**merge**.
- `mine` / `base` resolve exactly like the batch choice, scoped to that file.
- **`merge` is the one case where your judgement is legitimate.** Read both the
  operator's file and the matching file under `${CLAUDE_PLUGIN_ROOT}/base/...`, write a
  combined file that preserves the operator's intent, save it at the operator's path, then
  resolve that path as `mine` in Step 3 (the file now on disk — the merged one — is the
  one to keep). Nowhere else in this flow should you edit file content: everywhere else
  the resolution is "pick one side," and the script performs it.

**The split case — an `ask` on a `SKILL.md` with `create` rows under the same skill's
`references/`.** Read that pairing off the grouped **stderr** report, which lists both
kinds of row: the plan JSON's `verdicts` is a tally, not a path list, and update-mode
stdout carries only `ask`, so neither one tells you which paths are the `create` side.
The pairing means the monolith's content has a new home: the operator's divergent edit
may belong in one of the new reference files rather than in `SKILL.md`. Say so when you
ask, and name the shape of keeping mine — a **kept monolith
with the new references beside it**, two live copies of the same guidance — so the choice
is made with that in view.

Taking the split is a `merge` whose combined content lands at a *different* path than the
conflicted one, and **the sequencing is load-bearing: place content only after
`--mode update` has finished.** That run reclassifies from disk before it writes, so a
file you create at a `create` path stops being a creation — it becomes an `ask` ("new in
this release, and you already have a different file here"), the unresolved default keeps
*your* file, and the reference INSPIRE ships never lands at all. So: resolve the
`SKILL.md` itself as `--take-base`, let the run install the new references, then write the
operator's content into the appropriate one and tell them where it went. Never pass
`--take-base` / `--take-mine` for a `create` path: it matches no `ask` row, and the script
warns that the resolution "matched nothing" while changing nothing.

For a retirement `ask` (any path under `inspire_kb/` — see the batch note above for the
discriminator), the choice is **keep** / **retire** only. There is no `merge`: there is no
base-side file to merge against either way — the index seeds left `base/kb/` in this same
release, and the ADR index (`01_adr/_index.md`) never shipped one to begin with. **keep**
leaves the file on disk untouched (the default if left unresolved); **retire** deletes it.
Hand both back the same way, as `--take-mine` / `--take-base` in Step 3.

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

The two flags mean different things depending on which kind of `ask` they resolve. For a
content `ask`, `--take-base <path>` replaces the file with the new base version and
`--take-mine <path>` keeps the operator's. For a retirement `ask`, there is no base file to
take, so `--take-base <path>` retires it instead — it deletes the file — and
`--take-mine <path>` keeps it (`hops/0.7.0.sh`'s `_h7_settle`: an explicit `--take-mine`
outranks everything, an explicit `--take-base` outranks the verdict and calls the hop's own
`rm`, and anything left unmatched falls through to `hop_ask`). Either kind left unresolved
defaults to keeping the operator's file — `_apply_resolutions` for a content `ask`, the
same fallthrough for a retirement one — doing nothing is always the safe choice.

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
entirely). Skill edits need no session restart: `.claude/skills/` already existed at
session start, so edits to files inside it load live. **The agents class is the
caveat.** When this run created `.claude/agents/` for the first time — every project
coming from 0.7 or earlier — say plainly that a directory which appears mid-session may
not be discovered until the next one, so the role shells can need a fresh session before
`/agents` lists them. Then remind the operator to review the git diff and commit.

## Step 5 — Nudge

For each kept **skill** edit (an `ask` resolved to `mine`, or a plain `keep` verdict —
never a kept `inspire_kb/` retirement ask: that is the operator declining to retire a seed
file, not a skill edit, and it earns no lesson-capture suggestion): tell the operator the
customization belongs in `/inspire_lesson note`. Say plainly that
nothing is remembered by this flow — the same file will be classified as `ask` (or
`keep`) again on the next upgrade, and that recurrence is deliberate: it is what stands in
for the lesson-reconciliation half (D6) that does not exist yet.

For each kept **validator** edit: there is no capture mechanism for it — a lesson has no
category for bash. Say it belongs upstream: open an issue or a PR against INSPIRE.

## Step 6 — Trust report

If `.inspire/bin/trust.sh` exists, offer — never run unprompted — `.inspire/bin/trust.sh
report`. What its groups mean is explained at
`.claude/skills/_references/trust-stamps.md`; point there rather than restating it.

## What this skill is, and what is missing from it

Update has two halves, and only one of them can be a script:

| Half | Nature | Where it lives | Status |
|---|---|---|---|
| Version compare, manifest-driven content classification, the hop chain, copying, settings merge, lock rewrite | **deterministic** | `materialize.sh` | **complete** |
| Re-deriving each skill as `new base + surviving lessons` | **semantic** — a judgement about meaning, not a file operation | this skill | **not built** |

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

**Refining that second half is future work**, specified by D6 of the ADR linked at the
top of this file and tracked by the operator rather than promised here. Nothing in this
skill waits on it: everything above is what the current release actually does.

## Rules

1. **All file operations go through `materialize.sh`.** No copying, hashing or settings
   editing in prose. Content classification is `--mode plan` (`--mode drift-check` is
   accepted as a deprecated alias).
2. **Never silently overwrite an operator's file.** An `ask` row left unresolved defaults
   to keeping the operator's version — doing nothing is how work survives. Only
   `--take-base` moves a conflicted path to the new base version; only a `merge` you write
   yourself combines the two.

   **The guarantee's exact scope: a path the target version does not ship.**
   Classification compares disk against the SOURCE version's manifest
   (`plugin/manifests/<version>.json`) and the current `base/` — not against any lock;
   the lock's old `files` map is gone. A file the *project* authored at a path no
   manifest lists and the new base does not carry — e.g.
   `.claude/skills/inspire-code/profiles/mystack.md` — always classifies as `keep`
   ("yours — INSPIRE never shipped this") and is never touched or deleted, even though it
   sits inside a skill directory INSPIRE owns. This is the fix for the pre-0.3 behaviour
   (`install.sh` used to `rm -rf` a whole owned entry, destroying exactly these files) —
   already shipped, not a roadmap item.

   **Where the target version does ship that path, the guarantee is narrower — and a
   skill's `references/` is exactly such a place.** INSPIRE ships reference files under
   `inspire-*/references/`, and 0.7.0 ships a batch of new ones, so a file the project
   authored there can **collide** with a newly shipped one. It then classifies `ask` —
   "new in this release, and you already have a different file here" — and an unresolved
   `ask` keeps the operator's file, exactly as everywhere else. It is still never silently
   touched or deleted; what changes is that the operator gets a question where before there was
   nothing to ask. Project content still belongs in the KB, in a `98_lessons` node, or in
   the project's `CLAUDE.md` — not inside an `inspire-*` directory — but a file left there
   by mistake survives rather than being silently destroyed.

   `inspire_kb/` is out of scope for *classification* — content classification never runs
   against it at all, because no shipped manifest lists a KB path in the first place. KB
   seeding is a separate, purely additive path that runs in both `init` and `update` (see
   Step 1): a path already on disk is never replaced, only a missing one is added.
   `--mode update` is **not**, though, flatly non-destructive under `inspire_kb/` as of
   0.7.0: a versioned hop may retire a KB seed file the project no longer needs to keep —
   a proven-derivable one is deleted silently, and any divergence from the derivation lands
   in `ask` rather than a silent delete (Step 2's retirement branch). Two further exceptions
   are purely additive and never clobber: `seed_design_system` creates
   `05_screens/design-system.md`, and `seed_claude_md` creates `CLAUDE.md`, **only if
   absent**.
3. **No writes happen before Step 2's decisions are gathered.** `--mode plan` itself
   writes nothing, whatever the operator decides — that is asserted by the test suite, not
   just documented here.
4. **Never downgrade.** A plugin older than the project's detected version is an error, not
   an update — enforced by `version_cmp` in the script, in both `--mode plan` and
   `--mode update`.
5. **No lesson reconciliation here.** Classification, archiving and skill rebuilding are
   D6, and unbuilt. This skill does not read `98_lessons/`. Do not approximate it — telling
   the operator an edit was kept is truthful; silently merging it is not.
6. **Do not re-ask the product roots.** Read them from `stack.md`; changing them is a Shape
   change owned by `/inspire_bootstrap stack`.
