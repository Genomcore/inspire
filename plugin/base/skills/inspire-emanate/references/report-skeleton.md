# The run report — the shape

[`run.md`](run.md) § The run report says what `.inspire/last-emanation.log`
carries, and § Liveness says when the chat hears about it. This file is the
**form**: the three block kinds in order, each with a slot for the lines those
sections name. An orchestrator fills a shape here. It never composes one.

**The shape is here; the meaning is there.** That division decides which file to
edit. A new line in § The run report's list gets a slot below carrying its label
and nothing else — a slot that explained itself would be a second answer to what
the line means, and the two would drift.

**A slot with no answer is filled with the reason, never dropped.** *drill
skipped — no language profile*, *nothing dropped*, *no survivors* are all
answers. An absent slot reads as an oversight, and the operator cannot tell one
from a measurement that came back empty.

## The identity block, at t=0

Written once, immediately after the turn branch exists, before wave 1 spawns
anything. It is the whole of what the file holds until the first wave closes.

```
# Emanation run <run-id>

- **base branch** — <the branch the run was launched from>
- **turn branch** — <emanate/<run-id>>
- **scope** — <as typed>
- **goal** — <as typed, or *none*>
- **selectors** — <as typed, or *none*>
- **budget** — floor <n> · effective floor <n> · declared ceiling <n> ·
  waves permitted <n>
- **preflight** — <the declared components and their probe verdicts, or
  *none declared*; plan's `PR-22` where it fired>
- **status** — RUNNING
```

**`status` is the one line this file rewrites in place**, and it is the worked
example of the rule below: at the exit it becomes the exit that was reached.

## One block per wave close

Appended as a wave closes, and at no other moment. A turn between two wave
closes writes nothing here (§ Liveness), so this block is the only place a
unit's own measurements land — the closing block never repeats them.

```
## Wave <n> — closed

<one row per unit that reached a terminal state in this wave>

### <unit id> — delivered | stalled | blocked
- **integration branch** — <emanate/<run-id>-<unit-slug>, where one was left in place>
- **gate verdict** — <the digest>
- **rework cycles** — <n> · **infrastructural retries** — <n>
- **harvest dropped** — <paths, or *nothing dropped*>
- **drill** — <survivors as `file:line — mutation applied → the missing test`,
  or *no survivors*, or *drill incomplete* / *drill skipped* with the reason>
- **verify, did not halt** — <each finding, attributed to its target path,
  carrying the rule's own severity, or *none*>
- **promote trailers** — <run id · template_sha · profile hashes · gate digest>
- **stalled or blocked only** — <the class, and the remedy verbatim>

### Findings
<Free prose, and the one slot that is free. What this wave taught: a defect in
the doctrine, a profile that refused, an oracle the loop could not reach. It is
bounded to the wave it belongs to.>

- **frontier after this wave** — <n> units
```

## The closing block, at the exit

Written once, at the run's end, when one of the three exits is reached — the goal
is reached, the ceiling or a budget is exhausted, a stall cascades. Writing it
**is** the act of ending the run (§ Liveness).

```
## Report — <the exit that was reached>

- **budget answer** — waves actually executed <n>, against ceiling <n> and
  floor <n>
- **delivered** — <unit, with its integration branch> …
- **stalled** — <unit, its stall class, its remedy> …
- **blocked** — <unit, and what blocks it> …
- **pre-PR** — the rules verify did not run (`profile-gates-installed.sh`,
  `adr-maturity-matches-features.sh`) and `criteria-have-tests.sh`'s 🟡
  limitation
- **next act** — <the PR to open or already opened, and every remedy named above>
```

Per-unit detail is **not** restated here. It is in the wave block where the unit
reached terminal, and this block's rosters name the unit and its branch so the
operator can find it.

## What binds every slot above

Both rules are [`run.md`](run.md) § The run report's, and they apply to the
`### Findings` prose exactly as they apply to a labelled slot:

- **the last position wins** — a slot whose answer this run revises is corrected
  where it stands, never left with a correction appended beside it. The identity
  block's `status` is the standing example;
- **the file is tracked** — it is committed with the run, so what it claims is
  read again in review.
