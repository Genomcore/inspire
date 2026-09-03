# Subcommand: plan

Answer what a scope would deliver, and answer it **read-only**. `plan` is the
cheap goal check: it is what an operator runs before committing an afternoon to a
run, and it is what `run` executes internally at t=0 before it builds anything.

```
/inspire-emanate plan [until <goal>] [--scope PATH]... [--ceiling N] [--reemanate SEL]...
```

## The one call

Everything below is a reading of one invocation of the substrate tool:

```
.inspire/bin/emanate-plan.sh [--scope PATH]... [--ceiling N] [--tests-root DIR]...
                             [--reemanate SEL]... [--goal SEL]
                             [--profiles-root DIR] [--agents-root DIR]
```

Its JSON shape, its `PR-*` catalogue, the frontier rule, the edge rule and the
wave algorithm are
[`_references/emanation-plan.md`](../../_references/emanation-plan.md). **Read the
JSON from stdout; the grouped human report is on stderr.** The tool writes
nothing at all — no file, no log, no git state, and not
`.inspire/last-emanation.log` either — so `plan` leaves the checkout exactly as it
found it.

**Resolve `--tests-root` before calling.** The flag has no default, and given
none no tests tree is read and **no unit is realized** — a plan that silently
re-emanates the whole vault. Resolve it from the framework profile's
`## Test conventions` the same way the gate's is resolved, and pass every root the
suite actually lives in. Say in the report which roots were read.

**Forward the operator's arguments; invent none.** Selector prose is resolved to a
canonical id here ([`SKILL.md`](../SKILL.md) § Invocation); everything else is
passed through.

## Acting on the exit code

Every code has an answer, and none of them is "try again".

| exit | what it means | what to do |
|---|---|---|
| `0` | **ready** — a plan, no error-severity finding | report it (§ Reporting a ready plan). Under `run`, proceed to the t=0 preflight |
| `1` | **not ready** — a plan was computed and at least one finding is an error (the common case: `PR-01`…`PR-07`) | report every finding with its `owner` and its `remedy`, verbatim. **Refuse the run.** Nothing is built |
| `2` | **usage** — an unknown flag, a bad `--ceiling`, a `--scope`/`--tests-root` path that is not there, or a selector that selects nothing | this skill built the command line, so a usage error is an **internal error**: report the exact argv and the tool's stderr, and **stall the run**. Never retry with different arguments — a selector that selects nothing is the operator's typo, and guessing at what they meant is exactly what the exit code exists to prevent |
| `4` | **refused** — `PR-10` (overseer roster) · `PR-11` (cycle) · `PR-12` (empty frontier) · `PR-13` (no stack) | refuse, naming the class and its remedy from the refusal object. There is no `waves`, `floor` or `units` key to read on this path, and no `preflight`, `wire_conventions`, `realized`, `realized_all`, `reemanate` or `goal` either |
| `5` | **roots missing** — `$SDD_KB_ROOT` or `$SDD_SPEC_ROOT` is not a directory | refuse, naming the tool and the two roots. Run from the repo root |
| `6` | **internal** — a `derive` run exited outside `{0,4}`, or produced no readable contract | refuse, naming the tool. Defensive: every input it could refuse over is checked first, so this is a bug report, not an operator remedy |
| `127` | a required tool is missing (`jq`, `yq`, `tsort`, or a sha256 digest) | refuse, naming the tool the message names. Nothing here installs anything |

**A refusal is a finished answer, not a failure to plan.** Report it and stop;
under `run`, stop before the first worktree exists.

## Reporting a ready plan

On exit 0, the plan carries the answers a run is budgeted from. Report, in this
order:

1. **The waves** — `waves[]`, in order, each with its units. This is the schedule
   a run would execute.
2. **The floor against the ceiling.** `floor` is the number of waves; with a goal,
   `goal.floor` is the effective one and `deliverable_waves` is what the declared
   ceiling actually permits. Say both numbers, and say which floor you compared
   against.
3. **`realized` and `realized_all`.** Realized units are absent from `units[]` and
   `waves[]` for the same reason a `stable` artifact is — they are not in the
   frontier. **`realized_all: true` with `floor: 0` is the success answer**, not
   an empty result: the goal is already met, and the honest report is "there is
   nothing left to build", never "nothing was planned".
4. **`preflight`** — the components `stack.md` declares and which resolved
   framework profiles can probe them. Under `run` this is what the operator sees
   first, because it is the one thing they may have to act on before a run can
   start at all.
5. **Every warning, with its owner.** A warning never blocks: `PR-20` (ceiling
   below the effective floor) is surfaced together with `deliverable_waves`, so
   the report says how far the run would actually get rather than merely that the
   budget is short. `PR-22` (components declared, no profile probe) and `PR-23`
   (a goal slice with no navigable way in) are reported the same way.
6. **`reemanate`**, when a selection was given: the selectors as typed and the
   units they resolved to. An operator asking "what would this rebuild?" deserves
   the answer before the run rather than after it.

**Report a finding's `message` and `remedy` as the tool wrote them.** They are
already scoped to the artifact and already name the owning skill; rewording them
would put two vocabularies in front of the operator and make a `PR-01` finding
disagree with `derive`'s own words about the same defect.

## Two answers that look alike and are not

- **An empty frontier is `PR-12`, a refusal**: nothing in scope is at
  `lifecycle: accepted`, so there is nothing to build. Remedy: promote something,
  or widen `--scope`.
- **An empty frontier *because everything is realized* is exit 0**, `floor: 0`,
  `realized_all: true`: there is nothing **left** to build.

The two are opposite on purpose, and the tool decides which is which. Never
translate one into the other in the report.

## Under `run`

`run` calls `plan` first, always, and this is where its questions die. What it
carries forward from the JSON, and reads from nowhere else:

- `waves[]` — the schedule;
- `units[].profiles` — the resolved framework and language profiles per unit,
  which the spawn brief carries;
- `units[].claims` — the sizing signal budgets are set against; `0` for a unit
  derive refused;
- `wire_conventions` — the ids **and** the decision rows, both of which go into
  every persona brief;
- `preflight` — the components the t=0 probe checks;
- `goal.units` and `goal.floor` — the subset a goal-directed run executes, and
  the floor the ceiling is measured against.

`stack.md` is never read by this skill: the plan JSON emits these fields
precisely so there is one reader of the bootstrap layer, and it is the tool.
