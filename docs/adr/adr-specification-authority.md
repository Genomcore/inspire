# ADR — Specification authority: the narrower artifact decides

- **Status:** Accepted — 2026-09-15
- **Builds on:** [[adr-plugin-delivery]] **D4e** (the KB is `inspire_kb/`, visible and
  the operator's) — this ADR says what that ownership means when the operator's
  artifact and the shipped runtime disagree. Uses [[adr-suites-and-surfaces]]'s blast
  radius as the second scoping axis.
- **Scope:** Which layer wins when two of them answer the same question differently,
  and what a narrower artifact has to do to win. Not a new file format, not a new
  frontmatter field, not a validator.

---

## Context

INSPIRE ships judgment. A skill carries defaults, a stack profile carries a
rendering, a wire convention carries an error mapping, `git-conventions.md` carries a
branch shape. A project then writes its own artifacts, and those artifacts routinely
say something more specific about the same question.

The runtime already resolved several of those collisions, each in the place it came
up and each on its own terms:

- a descriptor's `**Wire deviation:**` note wins over the resolved convention, and
  silence means the convention holds (`conventions/README.md`, `tdd.md`);
- the project's `CLAUDE.md` wins over the shipped git defaults, "when the two
  disagree, the project wins" (`git-conventions.md`);
- the prototype wins over a screen spec on functional drift, and the design system
  wins over both on visual convention (`inspire-screens/SKILL.md`);
- a lesson changes how a skill behaves in this fork (`inspire-lesson`).

Four correct answers, no stated rule. The cost is not that the four disagree — they
do not. It is that the **fifth** collision has no answer, and every skill that meets
one invents its own. Two failure modes follow from that, in opposite directions: a
skill that treats its shipped default as a ruling overwrites what the project
decided, and a skill that treats every local contradiction as an intentional override
obeys stale artifacts and copy-paste.

The second is the expensive one. A contradiction and a deliberate exception look
identical on disk unless the artifact says which it is.

## Decisions

Decision numbers are scoped to this ADR.

### D1 — Authority is ordered by reach, and the narrowest reach wins

Five rungs, widest first: **runtime** (skills, references, profiles, conventions) →
**project** (`CLAUDE.md`, `00_bootstrap/`, the design system, `98_lessons/`) →
**decision** (`01_adr/`) → **module** (`02_modules/`) → **artifact** (a use case, a
descriptor, a screen). Blast radius narrows on a second axis alongside rung depth,
so a `surfaces:`-scoped artifact is narrower than a suite-wide one at the same rung.

The runtime is the outermost rung by construction. A project artifact therefore
outranks the shipped judgment on every question the project has actually decided,
which is the whole point: the runtime ships defaults for projects that have not
decided, not rulings over projects that have.

Where two artifacts narrow on different axes and neither contains the other, neither
wins. That is not a tie to break — it is a question nobody decided, and inventing an
answer there is the same defect as guessing a status code.

### D2 — Specificity is measured on the question, not on the document

A screen outranks an ADR on what the screen declares, and on nothing else. The same
ADR still holds over everything that screen leaves unsaid.

This is what keeps D1 from reading as "a screen beats an ADR". Nothing beats
anything in general; one question has one authority, and the comparison is only ever
run per question.

### D3 — An override is declared, never inferred

The narrower artifact names what it departs from, in the place its own format
already provides. Silence means the wider rule holds. A narrower artifact that
contradicts a wider one without saying so is **drift**, and drift is handed back to
the owning skill rather than obeyed.

This is the decision the four shipped cases were already making, generalized. It is
also the only one that pays for itself: an undeclared contradiction carries no
evidence that its author knew the wider rule existed, so reading it as an override
is a guess that the wider rule was considered and rejected.

**Where a format offers no place to declare the departure, the departure is not that
artifact's to make** — it goes up a rung, to the layer whose format does. This is
deliberately a constraint on the author rather than a gap to close with a new
marker: see *Alternatives considered*.

### D4 — An override reaches exactly as far as the artifact declaring it

A screen's deviation binds that screen and is evidence about no other artifact. The
corollary is what makes the design-system case fall out rather than be special-cased:
a question **wider** than the artifact is not the artifact's to answer. A design
token is a suite-wide fact, a local exception to one is still a suite-wide change, so
a screen cannot declare it and `/inspire-screens` is right to enforce the token
instead.

### D5 — A repeated override is a decision at the wrong rung, and the skill offers the move

The third artifact declaring the same departure is evidence that the wider rule is
wrong, not that three artifacts are exceptions. The remedy is to move the decision to
the rung whose reach matches: an ADR where the product decided differently, a lesson
where the runtime should behave differently in this fork.

The skill that notices **offers** the move and never performs it, on the standing
rule that nothing machine-authors the knowledge base.

### D6 — The KB's grammar is outside the ladder entirely

Frontmatter schemas, the keyed-entry grammar and its closed vocabularies, the
four-state lifecycle, claim ids, trust stamps, the finding format and the validators
that check them carry **no default for an artifact to specialize**. An artifact that
departed from them would not be readable by the skills that act on it, so the
override would not lose the argument — it would fail to be stated.

A project changes them by changing the runtime: capture a lesson, distilled upstream
by the observer ([[adr-runtime-lifecycle-and-lessons]]). Without D6, an ADR reading
"this project writes prose invariants rather than keyed ones" would outrank the
grammar under D1 and defeat every mechanical check the methodology has.

### D7 — This ships as doctrine, cited once and restated nowhere

The rules live in `plugin/base/skills/_references/authority.md`. The skills that
already state a case of them keep their own wording for their own question and cite
the shared file for the shape — the same arrangement `surface-scope.md` and
`keyed-heads.md` have. No skill restates the ladder.

## Alternatives considered and rejected

**A general `overrides:` frontmatter field, or a shipped `**Overrides:**` marker.**
It would make every override greppable and let a validator check that the cited
target resolves. Rejected for now: it adds a field to every artifact kind to serve
the rare case, and the mechanical half can only ever check the marker's shape — never
whether the prose beside it actually contradicts anything — so the judgment call
stays with the skill either way. D3's "no place to declare it means it is not yours
to declare" gets the discipline without the field. Reconsider if the shipped
per-format places (the wire-deviation note and its siblings) prove too few.

**Enforcing D3 in `review.sh`.** A validator cannot read two artifacts' prose and
decide they disagree. It would catch only declared markers, which is the case that is
already fine. Left to `/inspire-workspace review`, where the comparison is judgment
and already happens.

**Letting the runtime win on anything outside D6.** It reads as safer and is not: a
skill that overrules `00_bootstrap/stack.md` because its own default disagrees is
overwriting the project's decision with a stranger's, and the operator has no place
to put the decision that would stop it.

**Saying nothing and leaving the four cases as they are.** The cases are correct;
the fifth one is the problem, and it arrives with every new skill.

## Consequences

- A skill meeting a collision the runtime never anticipated has an answer, and it is
  the same answer in every skill.
- An undeclared contradiction is now **named**: it is drift, it is a finding, and the
  remedy is a hand-back to the owning skill rather than a silent choice.
- `/inspire-workspace review` gains a lens it can apply without a new rule — the
  comparison was already judgment.
- Nothing on disk changes. No frontmatter field, no migration, no validator, no
  golden fixture. A vault written before this ADR is already compliant, because the
  ADR describes how its artifacts were already being read.
- The obligation lands on authors: a deliberate exception has to say so. An author
  who writes the exception silently gets it reported rather than honored, which is
  the intended trade.
