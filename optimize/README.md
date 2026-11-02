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

A complaint has **≥3 tasks**: the first goes to `val` (SkillOpt's acceptance gate),
the second to `test`, the rest to `train`. A task is a prompt file; the runner
prefixes it with `/<skill> `. A directory beside it with the same stem is copied over
the workspace first, for tasks that need existing KB content.

Flip a complaint to `optimized: true` once the optimized skill has been **reviewed,
copied into `plugin/base/skills/` and released** — not when SkillOpt accepts it.

## Checks — `.ts` only

Each check is one file whose default export is `defineCheck(...)` from
[`lib/check.ts`](lib/check.ts). It declares its own kind:

| kind | what it holds | cost |
|---|---|---|
| `deterministic` | `run(ctx)` → a score, or `{score, reason}` | free |
| `judge` | a `rubric`; graded by `claude -p` with no tools | one call |
| `agent` | a `prompt`; a reviewer with read tools inside the workspace | one agent run |

`ctx` is `{task, workdir, output, files}`: the prompt the agent got, the run's workspace, the agent's final message
and every file it created or changed. Checks run **deterministic → judge → agent**,
each tier in parallel. A check passes at `pass` (default 1 for deterministic, 0.7
otherwise); the first tier with a failure zeroes every later tier without running
it. A task's score is the mean over all checks; it is a pass only if all passed.

Node ≥ 22.18 runs the `.ts` files directly — no build step and no dependency.

## A run

Per skill, in `runs/<skill>/<timestamp>/` (gitignored):

1. the splits are written to `data/`;
2. a real INSPIRE project is materialized into `workspace/` with `materialize.sh`;
3. SkillOpt trains the body of `SKILL.md` (the frontmatter is held out and
   re-attached). Each rollout copies the workspace, installs the candidate skill,
   runs `claude -p` headless in it and scores the result with the checks;
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
