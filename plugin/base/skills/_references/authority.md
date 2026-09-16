# Authority and specificity (shared reference)

## What this defines

Which layer wins when two of them answer the same question differently. Every
skill that reads more than one layer cites this file instead of restating it —
it is the single home for these rules.

The short form: **the narrowest artifact that speaks to the question is the
authority, and an override is declared rather than inferred.**

## The ladder

Five rungs, widest reach first. A rung outranks every **wider** rung on the
questions it actually answers.

| rung | what sits there | reaches |
|---|---|---|
| **runtime** | the `inspire-*` skills, their `references/`, this `_references/` directory, the stack profiles, the wire conventions | every project on this release |
| **project** | the root `CLAUDE.md`, `00_bootstrap/` (`stack.md`, `theme.md`, `surfaces.md`, `glossary.md`), `05_screens/design-system.md`, `98_lessons/` | this project |
| **decision** | an ADR in `01_adr/` | its declared blast radius — suite-wide, or the surfaces its `surfaces:` field names |
| **module** | a module hub in `02_modules/{module}.md` | one module |
| **artifact** | a use case in `03_features/`, an entity or action descriptor in `04_domain/`, a screen in `05_screens/` | the one thing it names |

The runtime is the outermost rung, so **every project artifact outranks it** on a
question the project has decided. That is the intended direction: the runtime
ships defaults for projects that have not decided, not rulings over projects that
have.

### Two axes, one comparison

Scope narrows on two axes, and a comparison resolves only where one artifact's
scope is **contained** in the other's. Rung depth is the first axis. **Blast
radius** is the second: a `surfaces:`-scoped ADR is narrower than a suite-wide one,
and a screen under `05_screens/{surface}/` is narrower than the suite-wide fact it
specializes ([`surface-scope.md`](surface-scope.md)).

Where two artifacts narrow on different axes and neither scope contains the other,
neither wins. That is a question nobody has decided, and the honest move is to say
so and offer the skill that would decide it — not to pick the one that happens to
be read first.

## The four rules

### A1 — The narrowest artifact that speaks to the question is the authority

Specificity is measured on the **question**, never on the file. A screen outranks
an ADR on what the screen declares and on nothing else; the same ADR still holds
over everything that screen leaves unsaid.

So "which layer wins" is never asked of two documents. It is asked of one
question, and answered by whichever of them actually decides it.

### A2 — An override is declared, never inferred

The narrower artifact names what it departs from, in the place its own format
provides — the descriptor's `**Wire deviation:**` note, the `CLAUDE.md` section
that restates a git convention, an ADR's `## Consequences`. Silence means the
wider rule holds.

A narrower artifact that contradicts a wider one **without saying so is drift**.
Drift is handed back to the owning skill, never obeyed: it is indistinguishable
from a stale artifact, from a copy-paste, and from an author who never read the
wider rule. This is what makes a wider layer restrictive rather than decorative.

**Where a format offers no place to declare the departure, the departure is not
that artifact's to make.** It goes up a rung, to the layer whose format does —
usually an ADR.

### A3 — An override reaches exactly as far as the artifact declaring it

A screen's deviation binds that screen. It changes nothing for the screen beside
it, and it is not evidence about any other artifact.

The corollary is the sharp half: **a question wider than the artifact is not the
artifact's to answer.** A screen may decide what that screen does; it may not
decide a design token, because a token is a suite-wide fact and a local exception
to one is still a suite-wide change. Where the question outruns the artifact, the
decision moves up a rung — which is why `/inspire-screens` enforces the design
system against a screen and accepts the screen's own behavior.

### A4 — A repeated override is a decision at the wrong rung

The third artifact to declare the same departure is evidence that the wider rule
is wrong, not that three artifacts are exceptions. Move the decision to the rung
whose reach matches the pattern: an ADR where the product decided differently, a
lesson (`/inspire-lesson note`) where the runtime should behave differently here.

A skill that notices the third one offers the move. It never performs it.

## What specificity does not reach

One carve-out, and it is not a special case of A1 — it is a different kind of
thing being compared.

**The grammar the KB is written in is never out-specified.** Frontmatter schemas,
the keyed-entry grammar and its closed head vocabularies
([`keyed-heads.md`](keyed-heads.md)), the four-state lifecycle
([`lifecycle-rules.md`](lifecycle-rules.md)), claim ids, trust stamps
([`trust-stamps.md`](trust-stamps.md)), the finding format
([`findings-format.md`](findings-format.md)) and the validators that check them
carry no default for an artifact to specialize. They are the notation the rungs
are written in, so an artifact that departed from them would not be readable by
the skills that have to act on it — the override would not lose an argument, it
would fail to be stated.

A project changes them by changing the runtime: capture a lesson, which is the
declared channel from a fork back to the base
([`lesson-capture.md`](lesson-capture.md)).

## Where this already holds

The rules above are the generalization of decisions the runtime already ships.
Each row is the authority for its own question; this file is the authority for the
shape they share.

| question | wider rule | narrower authority | how the departure is declared |
|---|---|---|---|
| what a caller observes when an action raises a logical error | the resolved wire convention ([`conventions/README.md`](conventions/README.md)) | the action descriptor | a `**Wire deviation:**` note under `## Errors` |
| branch, commit and PR shape | [`git-conventions.md`](git-conventions.md) | the project's `CLAUDE.md` | the `CLAUDE.md` section that states it |
| how a skill behaves in this project | the shipped skill | a file in `98_lessons/` | the lesson itself ([`inspire-lesson/SKILL.md`](../inspire-lesson/SKILL.md)) |
| whether the tests or the criteria are right | — | the use-case file's acceptance criteria | none needed; a wrong criterion is an `/inspire-feature` hand-back |
| what a screen does, where spec and prototype disagree | the screen spec | the prototype, on functional drift only | `/inspire-screens validate` writes the spec back |
| visual and structural convention | the design system, patterns, components and current UX ADRs | nothing narrower — A3 | a screen never declares one; the token moves instead |

## Who reads this

| Consumer | Uses it for |
|---|---|
| `/inspire-code` | which of the descriptor, the convention, the profile and the criterion decides a test |
| `/inspire-screens` | the triangulation matrix's `Authority` column |
| `/inspire-adr` | whether a decision belongs at the ADR rung at all |
| `/inspire-workspace review` | an undeclared contradiction is drift, and drift is a finding |
| `/inspire-lesson` | whether the project wants the runtime changed, or one artifact excepted |
