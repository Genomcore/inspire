# optimize — train INSPIRE skills against their complaints

Template-maintenance tooling, never shipped: nothing here is under `plugin/`, so
`/inspire:init` cannot copy it into a project. It drives
[SkillOpt](https://github.com/microsoft/skillopt) core: the skill's `SKILL.md` body
is the trainable document, and its score is what our own checks say about real
Claude Code runs of it.

```
./optimize-skills              # every skill with a complaint at optimized: false
./optimize-skills inspire-adr  # just these
./optimize-skills --dry-run    # validate the catalog and list what would run
```

## The catalog — `complaints.yaml`

One entry per skill, one list item per complaint. The first complaint of a skill
is its **original intent**, written when the skill is, so no later optimization can
trade it away. Every complaint of a skill is evaluated on every run of that skill;
`optimized: false` on any of them only decides that the skill runs at all.

Each skill has **≥3 tasks**: the first third (at least one) goes to `val`,
the next to `test`, and the rest to `train`. Each prompt is prefixed with `/<skill>`.

An optional `fixture:` names a directory relative to `optimize/` (absolute paths
also work). The runner materializes the current INSPIRE runtime, then overlays
that directory. Each skill can name a different base; skills can share one.
React and NestJS currently share `fixtures/simple-case`, a checked-in project
with infrastructure but none of their task features. Without `fixture`, the
materialized project is the base. `--dry-run` validates fixture paths too.

A directory `tasks/foo/` beside `tasks/foo.md` overlays that base for this task.
Both overlays exclude `.git`, `node_modules`, `dist`, `coverage`, `.claude`,
`.inspire` and `.inspire.lock`: a fixture supplies product code and KB context,
not an old runtime. The candidate skill is installed last, before the snapshot.
Every attempt starts from a fresh copy; no result feeds the next attempt.

Flip a complaint to `optimized: true` once the optimized skill has been **reviewed,
copied into `plugin/base/skills/` and released** — not when SkillOpt accepts it.

## Checks — `.ts` only

Each check is one file whose default export is `defineCheck(...)` from
[`lib/check.ts`](lib/check.ts). It declares its own kind:

| kind | what it holds | cost |
|---|---|---|
| `deterministic` | `run(ctx)` → a score, or `{score, reason}` | free |
| `judge` | a `rubric`; graded by `claude -p` with no tools | one call |
| `agent` | a `prompt`; a final reviewer with no tools, evaluated last | one call |

All checks receive the same agent diff. `ctx.diff` is the unified patch;
`ctx.changes[path]` holds `before`, `after`, `patch` and added lines with their
original line numbers. `null` denotes an absent file (creation/deletion).
`task` and `output` provide the request and final answer. `files` and `workdir`
remain available for compatibility, but shipped checks do not scan them.

Deterministic checks inspect added lines via `offences()`, never inherited
violations. Structural checks live in the existing LLM rubrics: these see only
the diff, task and output, with no tools or workspace access. They must not
infer missing dependencies from files absent from the patch. Deletions are
visible; deleted files are not silently dropped. Empty changes fail without an
LLM call. Binary/non-UTF-8 changes fail preparation of evidence explicitly;
large text changes are never silently omitted.

Checks run **deterministic → judge → agent**, each tier in parallel. A check
passes at `pass` (default 1 for deterministic, 0.7 otherwise); the first failing
tier zeroes later tiers without running them. The score is the mean of unique
checks, and a task passes only if all pass. Multiple complaints can reuse a
check without another model call. Consolidating structural checks changes
score weights: compare candidates within a new run, not against old scores.

Node ≥ 22.18 runs the `.ts` files directly — no build step and no dependency.

## A run

Per skill, in `runs/<skill>/<timestamp>/` (gitignored):

1. the splits are written to `data/`;
2. a real INSPIRE project is materialized into `workspace/` with `materialize.sh`;
3. SkillOpt trains the body of `SKILL.md` (the frontmatter is held out and
   re-attached). Each rollout copies the workspace, installs the candidate skill,
   takes a snapshot, runs `claude -p` headless and scores only the resulting diff;
4. the winner lands in `SKILL.md` beside a `diff -u` command against the source.

Nothing under `plugin/` is touched. SkillOpt edits only `SKILL.md`: a complaint
rooted in a skill's `references/` will not move.

## Setup

```
git clone https://github.com/microsoft/skillopt "$SKILLOPT_HOME"
python3 -m venv .venv && .venv/bin/pip install -e "$SKILLOPT_HOME"
PYTHON=.venv/bin/python ./optimize-skills --dry-run
```

`SKILLOPT_HOME` must stay set: the base config lives in the checkout, not the
wheel. Claude Code must be logged in; it runs the agent under test, the judges and
SkillOpt's optimizer.

## Local verification (no model calls)

```
python3 -m unittest discover -s optimize/test -p '*_test.py'
node --test optimize/test/checks.test.ts
cd optimize/fixtures/simple-case/source
npm ci
npm run typecheck
npm test -- --runInBand
npm run build
```
