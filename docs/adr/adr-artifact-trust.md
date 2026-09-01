# ADR — Artifact trust: who vouched for this, and what machinery produced it

- **Status:** Accepted — 2026-08-11 (shipped in 0.6.0)
- **Builds on:** [[adr-plugin-delivery]] **D4e** (the KB is `inspire_kb/`, visible and
  the operator's) and [[adr-upgrade-path]] **D10** (the KB is additive in both init and
  update) — both stamps live in KB content the upgrade never classifies, so this design
  adds no upgrade outcome and no layout hop. Rests on [[adr-upgrade-path]] **D11** (git
  is read-only against the operator's repository), which is why authorship cannot be
  read out of git at all.
- **Scope:** How a KB artifact records the human who vouched for it and the machinery
  that produced it, how divergence between a stamp and the installed runtime is
  measured, and where that measurement surfaces. Not a gate, not a review rule, not a
  quality score, not a maturity model, not a review ledger.

---

## Context

Two questions the KB could not answer. Neither is about an artifact's content; both are
about trusting it.

1. **Who vouched?** The machine writes most of the vault. Nothing distinguished an
   artifact a human had read and put their name on from raw machine output that happened
   to read plausibly.
2. **What machinery produced it?** The machine is non-deterministic and the harness
   moves underneath it: releases change skills, lessons change how a skill behaves, and
   an operator may edit a deployed skill outright — a sanctioned workflow the upgrade's
   merge keep-rule exists to protect ([[adr-upgrade-path]] **D6**). Nothing recorded
   which skill, at which exact bytes, last wrote an artifact, so "has the machinery that
   wrote this moved since?" had no answer.

Git answers neither. Every file in the vault is committed by the operator in their own
name, because the agent never commits (**D11**) — so author and blame both say "the
operator" for a file the operator may never have read.

The reflex answer to both questions is a freshness score, and that is the trap. Age is
not a defect: an artifact written a year ago, against skills that have not moved since,
is exactly as trustworthy as one written this morning. **Staleness here is ecosystem
divergence, never age** — no check in this design reads a clock. The second trap is a
ledger: a state file recording what has been reviewed and acknowledged is a second copy
of something that can be recomputed from the vault, so it is a thing that drifts, and
INSPIRE already refused that shape for `.inspire.lock`'s file hashes
([[adr-upgrade-path]] **D2**).

This design was walked deliberately *down* two tiers from an earlier, larger proposal.
That walk is recorded in D9, because the shape of what was cut is the most useful thing
this ADR can carry forward.

## Decisions

Decision numbers are scoped to this ADR. A reference to another ADR's decision is always
qualified.

### D1 — Two additive frontmatter blocks, two owners, two questions

```yaml
---
endorsed:              # human-owned — the machine never writes, updates or removes it
  by: "@dario"         # resolved from git config user.email
  at: 2026-09-13
produced:              # machine-owned — overwritten wholesale on every write
  skill: domain        # the skill that performed the write
  skill_sha: 3f9c2a1   # composite hash of its deployed dir — THE staleness comparand
  refs_sha: 91b04e7    # composite hash of the deployed _references/ dir
  inspire: 0.5.0       # runtime version; a human label and retrieval key, never a trigger
  at: 2026-09-13
---
```

`produced` answers *what machine wrote this?* — the owning skill, the exact bytes of the
deployed skill directory, the shared references, and the runtime version. `endorsed`
answers *who is the last human that put their name on this?*

Absence is the honest default and reads truthfully: no block means "never endorsed" /
"provenance unknown". **Nothing migrates** — stamps accrue as artifacts are touched, and
this design changes no byte of an existing vault: no stamp appears until a skill next
writes to it. Neither field name collides with anything the KB already uses, so no
rename rides along.

### D2 — `endorsed` is attestation, not content-pinning

The block is a name and a date. It does **not** pin the bytes it was applied to, and the
reference states the honest reading verbatim: *a human put their name here at that point
in history; the content may have evolved since, and git history is the audit trail.* The
commit that introduced or changed the block pins the file state, and the operator commits
everything in their own name — so the byte-level record already exists, in the one place
that cannot be forged from inside the file.

An earlier iteration hashed the endorsed body. Dropping that hash is what made the block
cheap: a file cannot contain its own hash, and the body-scoping machinery invented to
escape that circularity was the single most expensive thing in the original design. Here
the circularity is not solved, it is **dissolved** — there is nothing to scope.

The cost is that endorsement drift is not detectable, and that is deliberate. It was the
most-attacked feature in review: permanent noise with no closing action, since "the text
moved since @x read it" is true of most artifacts most of the time and nothing the
operator does makes the line go away. If attestation proves too weak, adding `sha` later
is purely additive and old stamps stay valid as attestations.

### D3 — `produced` is sha-anchored, and the two hashes stay separate

A version-only stamp (`skill` + `inspire`) was walked and rejected: it cannot see
**operator-local skill edits**, which are exactly the cohort that matters — a sanctioned,
upgrade-protected workflow, and the shape lessons will take once they are materialized.
The sha anchors to what actually ran, not to what shipped.

`refs_sha` is a separate field rather than folded into `skill_sha` because the two
findings need different judgments: "this skill moved" is a per-skill decision, "the shared
rules moved" is one vault-wide decision. A combined digest cannot be decomposed after the
fact, and a stamp that ignored `_references/` would mean less than it appears to, since
the shared rules define what every skill writes.

`inspire` stays as information only. The house pattern is version+sha pairs everywhere —
`.inspire.lock` (`inspire_version` + `template_sha`), manifests (`version` + `commit`),
lessons (`inspire_version` + `template_sha`) — sha for machines, version for a human
reading frontmatter at grep-scale. The pair also diagnoses on its own: stamp says 0.5.0
and the sha matches no 0.5.0 reconstruction means "locally-deviated skill", with zero
stored state. It is never a staleness input, and neither `at` field is an input to any
check.

### D4 — Staleness is measured against the structural ownership map, not the stamp's own name

The comparand is `produced.skill_sha` against the current composite hash of the skill that
the **structural ownership map** assigns to that path — `01_adr`→adr, `02_modules`→module,
`03_features`→feature, `04_domain`→domain, `05_screens`→screens, with two positional
overrides (`05_screens/design-system.md`→bootstrap, its one artifact outside
`00_bootstrap`; `00_bootstrap/surfaces.md`→surface, per [[adr-suites-and-surfaces]] **D7**).

The map, not the stamp, because **the map is INSPIRE-owned code and a stamp is the
operator's content**. When a release renames or splits a skill, the map is fixed in the
same commit and every existing stamp keeps resolving. A skill name frozen in a stamp could
never be lawfully repaired: rewriting it means INSPIRE editing files in `inspire_kb/`,
which **D10** forbids outright — so the alternative is not "harder to fix", it is
"unfixable by construction". This is the single most load-bearing reason the design looks
the way it does.

The stamp's own `skill` name is kept as **evidence**, not as the comparand: when it
disagrees with the map owner, that disagreement is itself a reported finding — a misrouted
write — rather than an error. One codifying rule ships with it: *a skill writing outside
its owned layer is misbehaviour; route the write to the owner.*

### D5 — Determinism in the tool, judgment in the skills

`.inspire/bin/trust.sh` owns every mechanical act: hashing (`skill-sha`), writing both
blocks (`stamp`, `endorse`), scanning and rendering (`report`). Skills never author stamp
YAML and never compute a hash — **an LLM hand-writing a hash is not a trust primitive**,
and one algorithm in one place is the only way the comparand means anything.

The tool requires `yq` and deliberately not `jq`, so the pre-PR hook can call it in a
project that never installed one. It is a **tool, not a rule**: `review.sh` enumerates
validators from an explicit list and does not pick it up, it emits no findings, and
`report` exits 0 no matter what it finds.

What is left for the skills is only *when*: after which write to stamp, at which moment to
propose an endorsement, when to disclose that a rewrite touches endorsed content, and
`inspire-code`'s warning when a build anchors on a spec no human endorsed. That last one
cannot be a hook — which specs a build anchors on is chosen by reasoning mid-session — and
it warns and continues, never refuses.

### D6 — Endorsement is operator-consented, and the machinery cannot enforce it

`trust.sh endorse <file>` is the only writer of the human-owned block, and it runs only
after an explicit operator yes. A skill may *recognize* an endorsement moment — top-rung
lifecycle promotions are the native one, those flows being operator-confirmed ceremonies
already — and *propose*; the human decides.

This is **stated honestly rather than claimed as a property**: nothing checks that anyone
was asked, so consent is a discipline the prose demands and not something the system
proves. Two rules carry it. Ask per artifact — "endorse all 23?" is not a real vouch, it
is one keystroke producing 23 stamps a later reader trusts as if a human had read each
one. And disclose before rewriting the body of a file carrying `endorsed:`, presence being
the whole test, so no hash is needed for it.

Endorsement lives with the owning skills' ceremonies and **never** in
`/inspire-workspace`, whose read-only charter forbids writes.

### D7 — The report is stateless, grouped, and surfaced unconditionally once

`trust.sh report` recomputes everything on every run. No ack ledger, nothing to
rebaseline, exit 0 always. Six groups, keyed by producer transition rather than
per-artifact, because "23 artifacts under a different `inspire-feature`" is one judgment
and not 23: `UNENDORSED`, `STALE`, `REFS-CHANGED`, `PRE-PROVENANCE`, `OWNER NOT INSTALLED`
and `MISROUTED`. Every group that has a remedy names it — for a stale artifact, its
**owning skill**: invoke that skill's update or review flow. No batch re-derivation
machinery ships. `OWNER NOT INSTALLED` is its own verdict and never stale, because
deleting a skill is legitimate use.

Surfacing splits by cost. `pre-pr.sh` — reached through `dispatch.sh` at `gh pr create` —
runs `report --summary` unconditionally and prints **one counts-only line** to stdout —
whether the operator sees it is harness-dependent, since a hook's stdout on exit 0 may be
transcript-only — informational either way, never affecting the hook's exit. Counts and
never lists: a full report at every PR would be the same wall of true-but-unchanged
lines each run, the exact noise failure the reviews
flagged, whereas a count that jumped since the last PR is precisely the signal worth an
unconditional line. The full grouped report stays operator-invoked — the `## Signals`
section of `/inspire-workspace review`, which is the methodology's actual pre-PR ritual,
plus one offer line at the `/inspire:update` tail, where mass divergence actually happens.
Pre-commit is untouched: per-commit would be noise, the PR is the review moment.

The invariant is stated exactly, and never more: *nothing is stale without the report
saying so **when run***. The pre-PR line is what makes running it unconditional at the
review moment, and it is the only machinery in a governed project that fires no matter
what.

### D8 — Scope is decided by path, never by frontmatter

`endorsed` and `produced` both apply to `01_adr`–`05_screens` artifacts including
`design-system.md`. Hubs (`_index.md`) and catalog entries take `produced` only —
endorsing rebuilt content is drift by construction. `00_bootstrap/{project,stack}.md` take
`endorsed` only — an operator interview generated them, not a skill run, so a `produced`
stamp there is unactionable noise. `theme.md`, `_template.md`, `README.md` and the meta
layers (`06_spikes`, `98_lessons`, `99_tracker`) take neither; lessons keep their own
frozen version stamping, unchanged.

Exclusion is **by path and filename, never by a frontmatter predicate**. The live
`design-system.md` inherits `status: template` from the byte-copy of `theme.md` that seeded
it, so any frontmatter test silently excuses the project's real design system — both
earlier proposals walked into this. Where an artifact has no frontmatter at all (screens by
design, most ADRs and features in practice), `stamp` creates the block; screens' positional
surface scoping is untouched, a frontmatter block being nothing like a `surfaces:` field.

`materialize.sh`'s own writes during init and update are **not provenance events**: the
upgrade never stamps.

### D9 — The tier walk, recorded so it is not re-derived

| Decision | Resolution |
|---|---|
| Vouch semantics | Attestation (`by` + `at`), not content-pinning — git history is the byte-level trail; the self-hash circularity is dissolved rather than solved |
| Endorsement drift | Out of scope — the most-attacked feature in review (permanent noise, no closing action); additive later via `sha` |
| Provenance anchoring | Sha-anchored, not version-anchored — version-only cannot see operator-local skill edits, the cohort that matters |
| `refs_sha` | A separate field, not folded into `skill_sha` — a digest cannot be decomposed, and the two findings need different judgments |
| `inspire` field | Kept, informational — the house pattern is version+sha pairs (lock, lessons, manifests) |
| Write granularity | Overwrite wholesale on every write, no derivation/annotation taxonomy — the runtime is single-writer-by-routing already |
| Staleness comparand | The structural ownership map (INSPIRE-owned, repairable per release); the stamp's name kept as evidence; owner-not-installed is its own verdict |
| Determinism | All hashing, stamping and scanning in `trust.sh`; unconditional surfacing in `pre-pr.sh`; skills decide only *when* |
| Endorse home | The owning skills' promote ceremonies and on request — never workspace |
| Renames | Zero. Both blocks are additive; nothing collides, nothing is freed, no migration |
| Consumer | `inspire-code`'s presence warning — a detector ships with a reader, and it warns rather than refuses |
| Bug fix aboard | The twelve-site `accepted`-ADR retirement (D10) |

Two of these are **operator reversals of an earlier design**, and both are worth reading
as reversals rather than as choices: the endorsement sha was dropped after full
consideration (attestation is what a reader needs, and git owns the bytes), and the
`produced` hashes were kept after a version-only tier was walked and found blind to the one
divergence a governed project actually produces.

### D10 — Riding along: the phantom ADR `accepted` state is retired

Twelve call-sites across five skills gated on an ADR `accepted` state that has never
existed. The ADR ladder is `design → prototyped → implemented` with `superseded` and
`rejected` terminal, so **an ADR present and not superseded or rejected is the current
decision at its maturity**. The gates now test that, and the prose says "current ADR",
glossed once per skill.

It rides along because it is the same kind of defect this design exists to reduce — an
artifact whose trustworthiness was being read off a field that does not exist — it adds no
files, and every file it touches was already open. Domain-lifecycle `accepted`
(`draft → accepted → stable`, enforced by the validators) is a different vocabulary on a
different layer and is untouched throughout.

---

## Alternatives considered and rejected

**An external endorsement index or ledger.** Rejected in both prior proposals and again
here. A second artifact listing what is endorsed drifts from the artifacts themselves, and
the stamp's whole value is that it travels with the file, through moves, forks and
`git log`.

**A dirty bit on maturity, or any "needs re-review" flag.** Rejected: it is state that must
be cleared, so it either gets cleared reflexively or accumulates, and it says nothing about
*what* changed. The recomputed comparand needs no clearing and names the transition.

**Anything time-based** — a review-by date, an age threshold, a decay score. Rejected per
the context: age is not a defect, and a signal that fires on the calendar trains the
operator to ignore signals. No check reads a clock.

**Section-scoped stamping** (stamping the parts of an artifact separately). Rejected for
now, not on principle: it presupposes frozen artifact layouts, and INSPIRE has no shape
contracts yet, so the scoping would be pinned to whatever headings happen to exist today.

**A derivation-vs-annotation write taxonomy.** Rejected: the runtime is
single-writer-by-routing already — the prototype keeps no file of its own and routes
insights through owning skills, extract feeds the authoring skills, ADR promotion
propagates by invoking module review and writes nothing — so the taxonomy solves a problem
this vault does not have.

**A model-version field.** Rejected on actionability: nothing an operator can do differs
because an artifact was written by a different model, and the field would only ever grow.

**A new validator for stamps.** Rejected. The validators are a `04_domain`-scoped,
non-extensible library enumerated by an explicit list, and trust is a signal that never
gates. `trust.sh` is a tool beside them, with its own wired test script.

---

## Consequences

**Good.**

- "Has a human vouched for this?" and "what wrote this?" are answerable from the artifact
  itself, offline, with `grep`.
- Zero migration and zero renames. Every existing vault is already correct; stamps accrue
  as artifacts are touched, and the pre-provenance cohort only shrinks.
- Divergence is measured, not guessed, and it survives skill renames because the map is
  INSPIRE's to repair.
- The measurement cannot rot: nothing is stored, so there is no baseline to rebaseline and
  no ledger to reconcile.
- The one unconditional surface is a single line of counts, which is what makes an
  unconditional surface tolerable at all.

**Accepted costs.**

- **Consent is unenforceable.** Nothing verifies that a human was asked before `endorse`
  ran. The design says so out loud rather than implying a guarantee, but an operator who
  automates endorsement has defeated it entirely.
- **Endorsement says nothing about the current bytes.** `endorsed` on a file rewritten
  since is not a lie — it is an attestation about a point in history — but it *reads* like
  a claim about now, and only git settles it.
- **Stamping depends on prose compliance.** A skill that forgets to call `stamp` leaves an
  artifact silently pre-provenance. The mechanical fix is D11's deferred hook; until then,
  the failure is invisible except as a group that stops shrinking.
- **The report is only as good as its last run.** The invariant is scoped to *when run*,
  and the pre-PR counts line is the only thing that makes running it unconditional.
- **`STALE` will be large in an active vault**, especially right after an upgrade, and
  most of it will be benign — a skill's prose changed in a way that would not change what
  it wrote. The grouping keeps it to one line per transition, and it remains a judgment
  the operator has to make.
- **A misrouted artifact appears in two groups.** Its `STALE` line compares against a map
  owner that never wrote it, so the two groups must be read together; the reference says
  so.
- **`.inspire/bin/` now holds two kinds of thing.** Every other script there is a review
  rule; `trust.sh` is a tool. Nothing in the directory listing says which is which, and
  `review.sh`'s explicit rule list is the only authority — which is also why the tool
  needed a hand-wired test script rather than a golden fixture, `run-tests.sh` discovering
  fixtures only.

## Staging

Built here: `trust.sh` and its tests; the `_references/trust-stamps.md` shared reference
that is the one home for the model; stamp-on-write and propose-at-promote pointer lines in
the writing skills; `inspire-code`'s unendorsed-anchor warning; the `## Signals` section in
`/inspire-workspace review` (with the design-system variance line moved under it, and the
hardcoded report skeleton in `review.workflow.mjs` updated in the same commit); the pre-PR
counts line; the `/inspire:update` tail offer; and D10's sweep.

Not built, and deliberately out of scope. Each is additive later, and nothing shipped now
blocks or prejudges any of them:

- **`endorsed.sha` and endorsement-drift detection** — attestation was chosen; add the
  field if it proves too weak.
- **The stamp-hook** (operator-decided 2026-08-11, deferred to the next release): a
  `PostToolUse` hook on `Write`/`Edit` running `trust.sh stamp` mechanically on every KB
  write, replacing prose compliance. The analysis to preserve: there is **no
  infinite-loop risk**, because hooks fire on tool events and `trust.sh` mutates via the
  shell, so its own write re-triggers nothing. The costs are real, though —
  `produced.skill` degrades to the path-derived owner, which kills the `MISROUTED` group
  structurally *and* makes a genuinely misrouted write stamp the owner's name, a stamp
  that lies; every KB write is followed by an external mutation that forces the agent to
  re-read the file; and it touches `materialize.sh`'s marker-managed `settings.json`
  merge. It layers cleanly on top of the shipped prose lines — hook is enforcement, prose
  is intent, and double-stamping is idempotent.
- **Section-scoped stamping** — needs frozen artifact layouts / shape contracts first.
- **The derivation-vs-annotation write taxonomy** — no problem to solve while the runtime
  is single-writer-by-routing.
- **Domain rung renames** (`draft→proposed`, `accepted→locked`), the disjoint-vocabulary
  program, and the ~88-file fixture sweep they require.
- **The `maturity:` enum** and the "maturity ladder" prose sweep.
- **Shape contracts / the three-zone model**, the re-derivation menu, mechanical rename
  offers.
- **Manifest vintage enrichment and a harness-deviation report row** — needs per-manifest
  hash reconstruction against deployed `.claude/skills/…` keys, with zero blocking value
  today.
- **The `reliability` / `realization` four-axis model** and its ladder grammar.
- **The `status:` five-meaning collision**, the feature state field (consumed by three
  files, defined by none), and the remaining bug pile:
  `sdd_progressive_severity`'s error-vs-warning behaviour at `superseded`,
  `entity-coherence`'s unimplemented `superseded` exemption, the missing
  `01_adr/_index.md`, the rule-count disagreements (9/10/13), `write-on-external` missing
  from findings-format's closed set, the breathing-mode spelling, and `inspire-adr`'s
  scope-bar/filename contradiction.
- **Lesson materialization** — the prerequisite before "lessons change skill bytes" is
  literally true; today lessons are consulted, not applied ([[adr-runtime-lifecycle-and-lessons]]
  **D5** is the target, unbuilt).
- **Model-version tracking, any clock-based signal, and an external endorsement index** —
  rejected above, and recorded here so they are not re-proposed as new ideas.
