# The emanation plan

What `.inspire/bin/emanate-plan.sh` prints on stdout: the **frontier snapshot**
for one scope, its dependency **waves**, the **floor** those waves imply, and
every **readiness** answer the orchestrator needs before the first worktree
exists. This file owns its JSON shape, its exit codes, the `PR-*` catalogue, the
frontier rule, the edge rule and the wave algorithm.

Plan **composes on derive**: one [`emanate-derive.sh`](derived-contract.md) run
per frontier unit, read from stdout and nothing else. Derive's own refusal
classes are never re-detected here — they arrive as `PR-01` findings carrying
derive's `class`, `target`, `message` and `remedy` verbatim.

It **writes nothing**: no file, no log, no KB edit, no git state, and not
`.inspire/last-emanation.log` either. Stdout is the JSON, stderr is the grouped
human report, and a scratch directory removed by an `EXIT` trap is the only
thing that ever touches a disk.

## CLI

```
emanate-plan.sh [--scope PATH]... [--ceiling N]
                [--profiles-root DIR] [--agents-root DIR]
```

| flag | meaning |
|---|---|
| `--scope PATH` | repeatable. A KB path — a directory or a single file — intersected with each layer through the scope contract every rule obeys. Omitted: the whole knowledge base |
| `--ceiling N` | the maximum number of waves this run may execute. Unset by default; budgets are invocation arguments, never a KB artifact. A ceiling below the floor is a warning, never a blocker |
| `--profiles-root DIR` | where the stack profiles live. Default `.claude/skills/inspire-code/profiles`, env override `INSPIRE_PROFILES_ROOT` |
| `--agents-root DIR` | where the agent shells live. Default `.claude/agents`, env override `INSPIRE_AGENTS_ROOT` |

There is no `--mode`: plan is read-only unconditionally, which is why it has no
act half to guard. The current working directory is the repo root; `SDD_SPEC_ROOT`
(default `inspire_kb/04_domain`) and `SDD_KB_ROOT` (default `inspire_kb`) name
the two layers, as everywhere in `.inspire/bin/`.

| exit | meaning | stdout |
|---|---|---|
| `0` | **ready** — a plan, and no error-severity finding | the plan, `"ready": true` |
| `1` | **not ready** — a plan was computed and at least one finding is an error | the plan, `"ready": false` |
| `2` | usage — unknown flag, a bad `--ceiling`, a `--scope` path that is not there, `-h`/`--help` | empty |
| `4` | **refused** — a precondition of planning failed; nothing is planned | the refusal object |
| `5` | roots missing: `$SDD_KB_ROOT` or `$SDD_SPEC_ROOT` is not a directory | empty |
| `6` | internal — a `derive` run exited outside `{0,4}`, or produced no readable contract. Defensive; every input it could refuse over is checked first | empty |
| `127` | a required tool is missing (`jq`, `yq`, `tsort`, or a sha256 digest) | empty |

`1` means not-ready rather than internal failure, matching `review.sh`'s verdict
vocabulary; `4` means refused because derive already means refused by 4, and a
generic catch-all would collapse two different answers into one.

## The plan

```json
{ "schema": "inspire.emanation-plan/1",
  "scope": ["inspire_kb"],
  "ready": true,
  "floor": 3,
  "ceiling": null,
  "deliverable_waves": 3,
  "units": [
    { "kind": "entity", "id": "auth.user",
      "path": "inspire_kb/04_domain/auth/user/auth.user.md",
      "lifecycle": "accepted", "module": "auth", "surface": null,
      "profiles": ["nestjs", "typescript"],
      "requires": [ { "kind": "action", "id": "auth.password.hash" } ],
      "wave": 1, "claims": 12 } ],
  "waves": [ ["auth.org", "auth.user"], ["auth.user.create"], ["users.list"] ],
  "findings": [
    { "code": "PR-03", "severity": "error", "unit": "auth.user.create",
      "target": "inspire_kb/04_domain/auth/password/auth.password.hash.md",
      "owner": "inspire-domain", "message": "…", "remedy": "…",
      "derive_class": null } ] }
```

- **`scope`** is the `--scope` paths, `LC_ALL=C` sorted and deduplicated — the
  order they were typed in never reaches stdout. With none given it names the
  roots the default sweep walks: `$SDD_KB_ROOT`, and `$SDD_SPEC_ROOT` as well
  when that is not inside it.
- **`waves`** is an array of arrays of unit ids, each inner array `LC_ALL=C`
  sorted, and `floor == (waves | length)`.
- **`deliverable_waves`** is `min(floor, ceiling)`, or `floor` when `ceiling` is
  null. The ceiling stops a run; it never chooses winners.
- **`units[].claims`** is the count from that unit's derived contract, `0` for a
  refused one. It is the sizing signal the orchestrator budgets on.
- **`units[].requires`** is derive's edge set verbatim — every declared
  dependency, ordering or not. Which of them ORDER is visible in `waves`.
- **`units[].surface`** is the surface a split screens tree puts a screen under,
  `null` for entities, actions and the flat suite-of-one shape.
- **`units[].profiles`** is the resolved set: the ids that exist on disk, with
  each framework profile's named language folded in.
- **`findings[].derive_class`** carries derive's own class id on a `PR-01` and is
  `null` on every other code. `unit`, `target` and `owner` are `null` on a
  finding that names none.
- `units` is sorted by id, `findings` by `(code, unit, target)`.

### Refused

```json
{ "schema": "inspire.emanation-plan/1", "scope": ["inspire_kb"], "ready": false,
  "refused": [ { "code": "PR-10", "target": ".claude/agents/…",
                 "message": "…", "remedy": "…" } ] }
```

There is **no `waves`, `floor` or `units` key at all** — nothing was planned, and
an empty key would read as "planned, and it is empty". Refusals carry no `owner`:
there is no unit for a skill to own. Every class found is reported, not the first.

## What a unit is, and which are in the frontier

**Unit kinds are exactly derive's three** — `entity`, `action`, `screen`.
Patterns and components are not units; their readiness is read off a component's
`**State:**` (`PR-04`) and a pattern's `## Regions` (`PR-05`).

**The frontier is every unit at `lifecycle: accepted`, within scope.** `accepted`
is design closed and the contract being implemented, which is exactly what
emanates. `draft` is still in design, `stable` is already delivered, `superseded`
is history. An empty frontier refuses (`PR-12`) rather than emitting a green
zero-wave plan, so a run cannot build worktrees for nothing.

## The ordering edge set

**Every `requires[]` edge is checked the same way, whatever its kind: it must
resolve (`PR-02`), and its target must be `stable` or in the frontier (`PR-03`).**
What the edge set below narrows is the ORDERING, and only the ordering.

The ordering edge set is derive's `requires[]`, minus two kinds of edge that are
not build-time dependencies:

- **Navigation never orders a wave.** A `screen`-kinded edge out of a screen unit
  is a route reference — a route derives from `module` + `screen` without the
  target existing as code — and list and detail screens navigate to each other in
  every real vault, so ordering on navigation would make the common case a cycle.
  The **only** thing navigation skips is the wave ordering: a navigation target
  that resolves to nothing is still `PR-02`, and one at `draft` or `superseded`
  is still `PR-03`. A screen that navigates somewhere unfinished is not ready.
- **Pattern and component edges are readiness checks, never constraints.** They
  are answered by `PR-04` and `PR-05`.

**An edge orders a wave only when its target is itself in the frontier.** An edge
to a `stable` artifact is satisfied out of band; an edge to an `accepted` unit
outside the scope is another run's business; an edge to anything else — `draft`,
`superseded`, or a lifecycle nothing states — is `PR-03`.

An edge whose target resolves to no artifact at all is `PR-02`. Resolution is
vault-wide even when ordering is scope-wide, or a narrowed run would report every
edge leaving its scope as unresolvable.

## Waves and the floor

Kahn over the ordering edges: `wave(u) = 1` when `u` has no in-frontier ordering
edge, otherwise `1 + max(wave(d))` over the ones it has. Waves are 1-based.

**The floor is the number of waves** — the critical dependency path's depth,
known at t=0. Plan reports it against the declared ceiling so an under-budgeted
scope is known before anything runs. A node the layering cannot consume is a
cycle (`PR-11`).

## Profiles

Resolution order, per unit:

1. the suite-wide `profiles:` in `00_bootstrap/stack.md`, or — when it declares
   none — the ids inferable from its `## Layer: Name` sections;
2. for a screen under a surface, that surface's own `**Profiles:**` line from
   `00_bootstrap/surfaces.md`, falling back to the suite-wide set when it
   declares none. Entities and actions always take the suite-wide set: the
   domain-versus-service partition is an ADR decision and is not machine-readable;
3. each resolved framework profile pulls in the profile its `language:` names —
   which counts as a rendering home only when that file's own `layer:` is
   `language`. A framework naming another framework, or naming itself, resolves
   to a file and still states nothing about how a semantic type renders.

The resolved set must contain at least one language profile that exists on disk,
or the unit is `PR-06`. This is where D5's amendment lands: "missing profiles
never block" holds for every attended subcommand, and emanation alone draws the
line differently, because an unattended run with no rendering table emits a guess
that compiles.

## `PR-*` — the readiness catalogue

### Findings — a plan is emitted, `ready` is false, the run exits 1

| id | shape | severity | owner |
|---|---|---|---|
| `PR-01` | derive refused this unit — one finding per class in its `refused[]`, carrying derive's `class` (as `derive_class`), `target`, `message` and `remedy` verbatim, never re-worded | error | the target's layer |
| `PR-02` | a `requires[]` edge resolves to no artifact in the vault. Derive records the edge and never resolves it | error | the depending unit's layer |
| `PR-03` | a `requires[]` edge resolves, but the target is neither `stable` nor in the frontier — navigation targets included, since ordering is the only question navigation is exempt from | error | the target's layer |
| `PR-04` | a screen declares a component whose `**State:**` is not `implemented`: a screen cannot emanate until the components it declares are stable | error | `inspire-screens` |
| `PR-05` | a screen names a pattern whose entry has no `## Regions` table, so the screen-to-layout join is unverified. `screen-coherence` reports the same shape as a warning on the pattern file; at emanation an unverifiable join is a rendering the contracter would guess at | error | `inspire-screens` |
| `PR-06` | the unit's resolved profile set yields no language profile — none declared, a framework profile's `language:` naming a file that is absent or that is not itself `layer: language`, or the framework profile itself absent so nothing can name a language | error | `inspire-code` |
| `PR-20` | the declared `--ceiling` is below the floor. **A warning, never a blocker**: a lower ceiling yields partial-but-reported delivery in graph order, so it does not flip `ready` and a run whose only finding is this one exits 0 | warning | — |

### Refusals — nothing is planned, the run exits 4

| id | shape | remedy |
|---|---|---|
| `PR-10` | the overseer roster fails: either shipped overseer absent, or any `*-overseer.md` under the agents root failing the shape (a `tools:` line present, naming none of `Bash`, `Write`, `Edit`, `NotebookEdit`, `Agent`) | restore the shell, or fix its `tools:` line |
| `PR-11` | a cycle in the ordering edge set. `acyclic-deps.sh` owns the action-to-action case and is run rather than re-implemented; a cycle the wider edge set forms is reported off the layering, which already knows which nodes it could not consume. A unit `derive` refused contributes no edges at all, so a cycle running through one surfaces only once its `PR-01` is remedied — nothing proceeds meanwhile, because `PR-01` is an error and already forces `ready: false` | fix the `requires:` chain |
| `PR-12` | empty frontier: no unit in scope is at `lifecycle: accepted` | promote something, or widen `--scope` |
| `PR-13` | no stack: `00_bootstrap/stack.md` is absent, or declares no `profiles:` and no inferable stack section | `/inspire_bootstrap stack` |

**Refusals are evaluated in two tiers, and each tier reports every class it
finds.** Tier 1 — `PR-10`, `PR-12`, `PR-13` — needs no derivation. Tier 2 —
`PR-11` — needs the whole frontier derived, so it can only be asked once tier 1
has held. Deriving a vault to discover that the overseer roster is broken would be
work whose answer nothing could use.

## Owning skills

A finding's `owner` is read off the **root** the target sits under, not off a
hardcoded directory name — the roots are configurable everywhere else in
`.inspire/bin/`, and a fixture's domain tree is not called `04_domain` at all.

| target under | owner |
|---|---|
| `$SDD_SPEC_ROOT` (`04_domain/`) | `inspire-domain` |
| `$SDD_KB_ROOT/05_screens` | `inspire-screens` |
| `$SDD_KB_ROOT/00_bootstrap` | `inspire-bootstrap` |
| anything else — a profile file, the agents root | `inspire-code` |

## Determinism

Two runs over one tree produce **byte-identical stdout**. Every list is
`LC_ALL=C` sorted, no unsorted `find` output reaches the output, and no
timestamp, temp path or process id appears in it. This is a requirement rather
than a nicety: the orchestrator diffs plans between runs, and a plan that
reordered itself would read as a vault that had changed.

## Consumers

`emanate run` executes plan internally first and refuses the whole run at t=0 on
any readiness blocker — all questions die in plan mode, and run mode never asks.
An operator reads the same answer on stderr, grouped by class, then by owning
skill, then by target: the shape `derive` and `harvest` already print.
