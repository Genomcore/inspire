# Roles — the five positions the loop dispatches

Every other file under `references/` describes a **subcommand**. These describe a
**role**: what one agent may do at one handoff, and the judgment it applies while it
does it. The role set is closed. A project extends the stack axis and the overseer
roster instead, and both extension points are named below.

Three axes stay apart, each in the artifact that already owns it:

| axis | set | home |
|---|---|---|
| **role** — what you may do | closed | the shell in `.claude/agents/`, plus one doc here |
| **stack** — how this unit is built | open | [`../../profiles/`](../../profiles/), resolved per unit |
| **doctrine** — judgment | one | this skill, in the docs beside this one |

INSPIRE therefore ships one coder agent rather than one per stack. An implementer may
not write tests in any stack, so the envelope is role-shaped; the stack composes in at
spawn time, and the combinations multiply without the artifacts multiplying.

## The five

| role | shell | doctrine | writes |
|---|---|---|---|
| contracter | `inspire-contracter.md` | [`contracter.md`](contracter.md) | interfaces · validators · bindings · schemas |
| tester | `inspire-tester.md` | [`tester.md`](tester.md) | tests |
| implementer | `inspire-implementer.md` | [`implementer.md`](implementer.md) | bodies |
| security overseer | `inspire-security-overseer.md` | [`security-overseer.md`](security-overseer.md) | nothing |
| quality overseer | `inspire-quality-overseer.md` | [`quality-overseer.md`](quality-overseer.md) | nothing |

Every shell sits at `.claude/agents/{file}`, where Claude Code discovers it. Per unit
the three personas run in that order, and both overseers read at each handoff between
them.

**The attended subcommands play the same roles in sequence.** Under `tdd` one session
contracts, tests and implements; under `review` it holds both overseer lenses and
reports to the operator rather than to an orchestrator. One doctrine, two dispatch
shapes — which is why these docs never say "the agent" where they can say the role.

## The envelope has two halves

- **Tools** — the shell's `tools:` list, which is an **allowlist**: a tool absent from
  it does not exist for that agent. This half is what makes an overseer read-only.
- **Paths** — what the orchestrator materializes into the phase's worktree, and what
  it accepts back out. This half is the freeze, and it is structural rather than
  permissive: the whole worktree is writable, and only the phase's own paths leave.

Neither half lives in a hook, and an agent cannot widen either from the inside. A
persona that writes outside its owned paths loses that work at harvest and is told so
afterwards; nothing warns it earlier, which is why each persona doc states what it
owns.

**A persona's tool list is a working set, and it is yours to extend.** A project whose
stack needs another tool adds it to that shell's list; the edit survives
`/inspire:update` like any other edit to a shipped file. Dropping `Agent` from a
persona narrows it to a single agent, which is a legitimate cost choice.

**Every shell declares `model: inherit`.** The tier belongs to the run the operator
started, never to a file INSPIRE ships.

## Non-escalation

- **A persona spawns only copies of itself.** Its clones work inside its worktree and
  leave through its harvest filter, so delegation can never widen the envelope. The
  sentence is doctrine; the envelope is the guarantee.
- **An overseer never addresses a persona.** Findings go to the orchestrator, which
  decides what to hand back. An oracle that argued with the agent it judges would be a
  fourth persona.

## The overseer contract

Both shipped overseers are **read-only oracles**, and these rules bind any overseer a
project adds:

- they see everything at their boundary, bodies included, and **write nothing**;
- they return approve or reject, plus findings, **to the orchestrator only**;
- **a rejection routes like a failed test.** The orchestrator hands the findings back
  for rework inside the unit's budget; an exhausted budget stalls the unit with the
  findings recorded. Never an interrupt, never a question — the run is unattended;
- **approvals are necessary, never sufficient.** An overseer cannot pass a unit over a
  deterministic gate. A judgment oracle may only make the loop more conservative,
  which is what keeps it safe to add one.

**What an overseer receives:** the boundary it is judging, the diff, the worktree path
to read it in, the unit's derived contract, the suite result, and the unit's resolved
profile set. **What it returns:**

```markdown
## {role} — {unit id} @ {boundary}

### Verdict: APPROVE | REJECT ({n} blocking)

{one sub-section per finding}
```

Findings use the shared shape in
[`_references/findings-format.md`](../../../_references/findings-format.md) — heading,
issue, suggested follow-up. Blocking findings are what a REJECT is made of; a
non-blocking finding is recorded and never rejects on its own.

## The roster is additive-only

**An overseer is any agent file under `.claude/agents/` whose name ends in
`-overseer.md`.** That is the whole mechanism — no frontmatter key, no roster file, no
knowledge-base artifact.

- A project **adds** an overseer — compliance, accessibility, a domain lens — by
  dropping one more `*-overseer.md` shell there and a doctrine doc beside these.
- The two INSPIRE ships are **non-removable**. `emanate` refuses to run when either is
  missing, or when either carries a shape that is no longer an overseer: a `tools:`
  list that can write is the case to watch.

The ceiling only rises. A gate its author can lower is not a gate, while an extension
point that only adds keeps each overseer a position the people who own that concern
can refine.
