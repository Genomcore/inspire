# Quality gates — mechanical enforcement (shared reference)

A **quality gate** is a check a machine runs every time, which refuses to let work
through when it fails. This reference states three things: where a given rule
belongs, how a rule gets adopted in a codebase that cannot satisfy it yet, and where
its threshold must live. It is stack-agnostic — the concrete tools and commands that
realize it live in each stack skill's `## Quality gates`
([`stack-skills.md`](stack-skills.md)).

Why the runtime carries this at all: when most code is written by an agent, review by
reading stops scaling long before the code stops arriving. What a human stops
reading, a machine has to start checking. The gates are not hygiene — they are the
mechanism the coding stage is trusted *through*.

## Rule 1 — the cheapest layer that can enforce a rule, owns it

| Layer | Acts | Owns |
|---|---|---|
| Linter / type-checker | inside the agent's own loop, before anything is shown | rules that are **local and binary** — one file, pass/fail |
| Test suite | every run | behavioral contracts |
| Repo-wide metric gate | commit / PR | **aggregates** — a value over the whole codebase |
| Human | once, at setup | what no machine can reach (Rule 5) |

A rule placed one layer too high costs a round trip through the operator; the same
rule at the linter layer is fixed by the agent before the operator ever sees the
code. So a rule that *can* be a lint rule *is* a lint rule — enforced absolutely,
never as a report someone reads afterwards.

Corollary: a review dimension that a linter could have owned is a **tooling gap**,
not something to check by hand every time.

## Rule 2 — absolutes by default, ratchets only for contaminated ground

A **ratchet** is a baseline value plus a direction: the metric may improve, never
regress. It exists for exactly one reason — to adopt a rule in a codebase that
cannot satisfy it today. Choosing between the two is mechanical:

- **Few existing violations** → fix them, set the rule **absolute**. No state to
  store, nothing to maintain.
- **Many** → the rule enters **scoped** (changed files only) or **ratcheted**, and
  the cleanup becomes a ticket (`/inspire-task create`). Recorded, never silent.
- **The rule is wrong here** → drop it and write down why, in the profile.

Never reach for a ratchet where an absolute would hold. An absolute is a line in a
config file; a ratchet is state that has to be stored, trusted, and kept honest.

## Rule 3 — the threshold lives outside the author's write reach

When the code's author is an agent with write access to the repository, a threshold
stored in that repository is not a control. Failing a gate and lowering the gate are
both one edit away, and the second is cheaper. This is not misbehavior — it is what
optimizing against a movable obstacle looks like.

- **Aggregate baselines** (coverage, duplication, bundle size) live wherever their
  history lives: outside the repository, out of reach of the change being judged.
- **What stays in the repo** must be legible as a diff in a pull request — a lint
  rule set, a declared identifier, a config threshold a reviewer sees. Relaxing it
  has to *look* like relaxing it.
- **Never** let a gate's pass condition be a value the same change is allowed to
  rewrite.

Corollary — **scoping a check to the change dissolves the problem**. A check that only
judges the diff has nothing to compare against and therefore no baseline to store,
trust, or keep honest. That is often the cheaper design, not a weaker one: the
per-diff mutation drill (mutate each changed line's behavior and confirm a test fails)
replaces a repo-wide mutation score for exactly this reason, and pays for it
in the one currency to be explicit about — it says nothing about code the diff does not
touch. Name that limit when choosing the design (Rule 2's third branch); a scoped check
sold as a global one is the failure mode.

## Rule 4 — an escape hatch is the linter's to allow or refuse

Every rule set needs a way out: a mis-typed dependency, a framework bug, a boundary
where the shape genuinely cannot be known yet. Forbidding that outright is what gets
the whole rule switched off, which is strictly worse. So whether a hatch is allowed,
and in which form, is decided once, in the linter's config — never counted afterwards.
Each condition below is local and binary, so by Rule 1 the linter owns it:

- **Allowed or refused, per rule** — the config says, for each hatch, whether code may
  use it at all. `@typescript-eslint/no-explicit-any` at `error` refuses `as any`
  everywhere; `@typescript-eslint/ban-ts-comment` refuses `@ts-ignore` and allows
  `@ts-expect-error` only with a description. A refused hatch fails at the line, in the
  agent's own loop, before anyone sees the code. A rule the project never allows is also
  closed to inline disables (`eslint-comments/no-restricted-disable`): otherwise one
  described `eslint-disable-next-line` turns a refused hatch into an allowed one.
- **Named** — one greppable syntax, never a wholesale one. `@ts-expect-error`, not
  `@ts-ignore`: expect-error *fails once the underlying error is fixed*, so it expires
  by itself. `eslint-disable-next-line <rule>`, never a bare file-wide `eslint-disable`
  (`eslint-comments/no-unlimited-disable`), and a directive that no longer suppresses
  anything is an error (`--report-unused-disable-directives`).
- **Justified in place** — a suppression without a written reason is a lint error, not
  a review comment (`eslint-comments/require-description`). Where the reason is "later",
  it carries the tracker id that owns the cleanup.

There is no count and no ceiling. A hatch the config allows is allowed wherever its
rule permits it; one it refuses is refused everywhere. Using fewer is a change to the
config — turning a rule to `error`, narrowing where an override applies — and that
change is a diff a reviewer sees (Rule 3). A codebase with too many existing hatches
to refuse one today adopts the refusal the way Rule 2 says, with the cleanup as a
`/inspire-task` ticket. The linter keeps that baseline itself: ESLint's bulk
suppressions (`eslint --suppress-all`) record each existing violation in
`eslint-suppressions.json`, a new one fails, and `--prune-suppressions` drops the
entries a fix removed.

## Rule 5 — a gate the runtime cannot install is declared, never pretended

Some gates live where no skill can reach: a metrics service's own pass condition, the
branch protection that makes a failing check actually block a merge. The runtime gets
three moves, and no more:

1. **Declare** which service the project uses, in
   [`00_bootstrap/stack.md`](../../../inspire_kb/00_bootstrap/stack.md) — the stack
   registry already records environment choices the runtime does not provision.
2. **Install and validate the in-repo bridge** — the CI workflow, the reporter
   config. That part *is* a versioned file and is owned like any other.
3. **Hand the far side to a human, as a ticket** — `/inspire-task create`, with the
   human owner and the concrete acts named (protect the branch so a red check blocks
   the merge; make the service's own pass condition strict). Not a validator, not an
   agent's job, and never reported as done.

Step 3 is load-bearing, not paperwork: a flawless CI workflow protects nothing if the
default branch accepts a red check. And it is a **ticket, not a printed checklist** —
a checklist that exists only in a session's output dies with the session, which is the
same pretending this rule forbids, committed by the rule itself. A half-installed gate
has to stay visible until a human closes it.

## Rule 6 — every gate also runs where the author cannot skip it

The hooks are a **fast local echo, not the enforcement layer**. A `PreToolUse` hook fires
only inside one machine's tooling: a commit from a plain terminal, a merge button on the
forge, a collaborator without the runtime — none of them pass through it. The failure is
concrete: with every gate green locally, a pull request merges with zero checks run,
because nothing on the server has ever heard of the gates.

So every mechanical gate runs twice, by design:

- **locally**, via the hooks — for the fast feedback loop, and
- **in CI on every push and pull request** — the run that counts, because it does not
  depend on who is committing or from where.

Two disciplines keep the pair honest. **CI invokes the hook's own script** (the pre-PR
entry point), never a restated list of steps — two definitions of "passing" will drift,
and the drifted one will be the one that matters. And **the suite must pass on CI's
operating system**, which is rarely the laptop's: a first Linux run readily surfaces a
check that matched only macOS tool output and had been passing silently — a gate that
looks enforced on the machine that wrote it is this rule's characteristic failure.

The far side — branch protection, so a red run *blocks* rather than warns — is Rule 5's
step 3: a human act, handed over as a ticket.

## Who reads this

| Consumer | Uses it for |
|---|---|
| `/inspire-bootstrap stack` | installing a new project's gates from its profiles; declaring the external one |
| code review | a missing mechanical check is a finding, with the gate that should own it |
| code authoring | which violations the toolchain already refuses, so they are never written |
| stack skills (`## Quality gates`) | the per-framework translation of Rules 1–2 |
