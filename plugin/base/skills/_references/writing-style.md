# The writing contract — how INSPIRE prose is written

A knowledge base is read twice: once by a person deciding what to build, once by an
agent deciding what to generate. Prose written to read well serves the first reader
and fails the second. This contract makes the vault's prose regular enough that both
readers reach the same conclusion from the same sentence.

**Provenance.** The rules below adapt the principles of **ASD-STE100** (Simplified
Technical English, the controlled-language standard written for aerospace maintenance
documentation) to specification prose. STE constrains vocabulary and sentence
construction so a procedure means one thing to every reader. INSPIRE borrows the
construction discipline and drops the closed dictionary. A product's vocabulary is the
operator's own, so the term list is per-fork —
[`inspire_kb/00_bootstrap/glossary.md`](../../../inspire_kb/00_bootstrap/glossary.md) —
not a standard shipped from outside.

## Scope

This contract binds the prose an INSPIRE skill writes into
[`inspire_kb/`](../../../inspire_kb): specs, features, ADRs, screen specs, module
hubs, spike learnings, lessons, tickets and bootstrap documents. It binds
operator-facing reports — a finding is prose someone acts on — and it binds the
session's own replies. An answer in the conversation is read the same way and for
the same purpose as a report, so the rules that make a report legible apply there
too. See § Reports and replies.

It does **not** bind machine-read tokens. Frontmatter keys and enum values, wikilink
target slugs, identifiers, filenames and code fences stay exactly as
[`output-language.md`](output-language.md) requires. The schema is not prose, and
rewriting it for style breaks the graph.

**Language.** The rules bind in whatever `output_language` the project declares. Some
are stated through English grammar, because that is the language this file is written
in. A fork writing in another language applies the same rule through its own
construction. R1 in Spanish is `se + verbo` avoided rather than *be + participle*
avoided. The rule is the constraint on meaning, never the morphology used to describe
it.

## The core rules

Eight rules, and they are not equal. R1, R3, R4, R6, R7 and R8 constrain what a
sentence may say; R2 and R5 only measure how long it runs. § Enforcement says
what that difference costs a review.

### R1 — Write in the active voice

A passive sentence can omit its actor. In a specification the actor is usually the
thing being specified, so omitting it hides the very fact the reader came for.

> **Bad.** The password is hashed before the row is written.
> **Good.** `auth::password::hash` hashes the password; this action then writes the row.

The bad sentence never says who hashes. Two readers will guess two different
components, and both will implement their guess.

### R2 — One sentence, one claim

A sentence carrying two claims cannot be half-accepted. A reader who disagrees
with one clause has to reject the whole sentence, and an agent generating from it
cannot tell which half is load-bearing. One claim per sentence is also what makes
a claim reviewable and back-sourceable.

> **Bad.** When the operator submits the form the system validates the email against
> the tenant's domain allow-list and, if that passes, hashes the password and writes
> the user row, emitting an audit event afterwards. *(four claims)*
> **Good.** On submit, the system validates the email against the tenant's domain
> allow-list. It then hashes the password and writes the user row. Writing the row
> emits an audit event.

**The rule is the claim count, not the word count.** A forty-word sentence stating
one thing plainly satisfies R2. A twenty-word sentence stating three does not.
Length is where to look: past roughly thirty-five words a second claim has usually
crept in, which is where the mechanical check warns.

Two sentences are almost always available. There is nothing a hundred-word
sentence says that two shorter ones cannot say more clearly.

### R3 — No noun clusters

A run of stacked nouns compresses a relationship into adjacency and leaves the reader
to reinvent it. A preposition costs a word or two and removes the ambiguity.

> **Bad.** invoice payment capture retry policy configuration
> **Good.** the configuration of the retry policy for capturing invoice payments

Applies inside table cells as much as in prose — a column header is where noun
clusters hide best.

### R4 — One concept, one word

Two words for one concept split the graph: a reader greps one and misses the other,
and an agent generates both. The approved term is **the operator's own language**,
recorded in [`inspire_kb/00_bootstrap/glossary.md`](../../../inspire_kb/00_bootstrap/glossary.md)
when an interview settles a naming question. It is never the agent's taxonomy, and it
is never chosen for elegance over what the team already says out loud.

> **Bad.** Each tenant owns its billing settings. An organization may override the
> workspace defaults.
> **Good.** Each tenant owns its billing settings. A tenant may override the
> platform defaults.

The glossary carries the approved term, the synonyms it displaces, and a one-line
definition. A glossary with no data rows binds nothing. An empty term list is the
honest state of a fork that has settled no naming question yet. It is not a gap to
fill with invented entries.

### R5 — One paragraph, one idea

A paragraph is one idea. Past that it is two ideas sharing a block, and the second
one is the one nobody remembers.

> **Bad.** One block carrying what the invoice is, how its lifecycle runs, which
> entities it touches, and why it carries a tax field.
> **Good.** One paragraph for the purpose, one for the lifecycle, one for the
> relationships. The tax field's reason belongs in `## Rationale`, where a reader
> looks for it.

A list is not a paragraph. Each item is measured on its own, and a bullet list is
never collapsed into one block for this rule.

The sentence count is where to look, exactly as R2's word count is: the check
warns past eight sentences, where a second idea has usually arrived.

### R6 — State what is

Every file states what is true now. Three kinds of sentence state something else,
and they fail the same way: the subject becomes the document rather than the
system, and the reader has to work out which description is current.

**The past.** Git carries what was true before, and it carries it better: with
dates, authors and diffs. Prose that narrates its own past ages into a second,
wrong description of the system sitting beside the right one.

> **Bad.** The total was previously computed client-side; it is now computed on the
> server.
> **Good.** The server computes the total.

**The future.** A plan is a ticket, and a ticket has a home in
[`99_tracker/`](../../../inspire_kb/99_tracker). A description that promises
tomorrow's behavior is wrong on the day the work lands and wrong until someone
notices.

> **Bad.** The endpoint returns one page for now; pagination arrives in a later
> release.
> **Good.** The endpoint returns one page. `#412` tracks pagination.

**The negative space.** What an artifact is not, or will never be, describes
every other thing in the world equally well. The reader came for the one
description that fits, and a denial narrows nothing.

> **Bad.** This is not a cache, and it will never persist across restarts. It holds
> the resolved session for the duration of the request.
> **Good.** It holds the resolved session for the duration of the request.

**A prohibition is not negative space.** "Write to this table only through
`billing::invoice::settle`" is a present-tense rule the reader has to obey, and it
stays. The test is the sentence's subject: a rule constrains the reader, while
negative space describes the artifact by exclusion.

The mechanical subset of this rule reaches the past alone, and the sections exempt
from it are below.

### R7 — Name the thing, not a figure of speech

A metaphor asks the reader to carry meaning across from something else, and two
readers carry different amounts across. In a specification that is a defect: the
figure reads as understanding while the fact stays unstated.

> **Bad.** The gate is the load-bearing wall of the loop, and nothing reaches the
> branch without earning its way past it.
> **Good.** `emanate-gate.sh` returns a pass or fail verdict. A unit merges only on
> a pass.

Verbs of mechanism are not metaphor. A parser *refuses* a shape, a check *emits* a
finding, a script *returns* a verdict — each names something that happens. Verbs
of mind are the line: nothing INSPIRE ships *knows*, *wants*, *remembers* or
*decides to*, and writing that it does hides where the behavior actually comes
from.

Flourish also arrives as intensifiers — *simply*, *merely*, *of course*,
*seamless*, *elegant*, *powerful*. Each ranks a fact rather than stating one, and
"simply" in particular ranks the reader. Cut them: the sentence keeps its meaning
and loses a judgment nobody asked for.

### R8 — Say it once

A fact restated is not a fact reinforced. The second copy ages on its own, and a
reader who finds two copies disagreeing has to work out which one is current.

The shapes it takes, in the order they tend to show up:

- the paragraph after a table that says what the table already said;
- the same numbers in a table and again in a chart;
- one conclusion in a table row, in a note beneath it, and again as a finding;
- a known gap stated once in the method and repeated as a caveat per finding;
- a whole list formatted the way its hardest item needed.

That last shape is worth naming plainly: the hardest item sets the ceiling, not
the floor. Nothing simpler than it needs more than it does, and most items need
far less.

Every one of these reads as thoroughness while it is being written, and none of
them adds a fact. R8 is judgment only — no check can tell a restatement from a
second, genuinely different claim.

## What binds where

Rules bind by **section kind**, not by file. The same artifact holds sections of
several kinds, and a rule that is right for a `## Purpose` paragraph is wrong for an
`## Inputs` table.

| Section kind | Where it occurs | Binds |
|---|---|---|
| **Normative prose** | `## Purpose`, `## Rationale`, `## Behavior`, `## Context`, `## Decision`, `## Consequences`, feature descriptions, screen prose | R1 · R2 · R3 · R4 · R5 · R6 · R7 |
| **Acceptance criteria** | feature `## Acceptance criteria` | R1 · R2 · R3 · R4 · R6 · R7, and each criterion states an observable outcome — see below |
| **Tabular / structured** | `## Inputs`, `## Outputs`, `## Entities` field tables, `## Fields`, roster and coverage tables | R3 · R4 · R6 · R7 (cells are fragments, so R1, R2 and R5 do not apply) |
| **Machine-read tokens** | frontmatter keys and enum values, wikilink targets, identifiers, filenames, code fences | nothing — [`output-language.md`](output-language.md) governs these |

**R8 is absent from that table on purpose.** Every other rule reads one sentence,
one paragraph or one cell, so a section kind is enough to decide whether it binds.
A restatement is a relationship between two places in a document — a paragraph and
the table above it, a note and the finding it repeats — so R8 binds the artifact as
a whole, across every section kind in it, including the machine-read ones: the same
fact does not belong in a frontmatter field and in the prose beneath it.

**Acceptance criteria and vague language.** A criterion that cannot fail a test is not
a criterion. Some words name a feeling rather than an outcome: *fast*, *intuitive*,
*user-friendly*, *appropriate*, *robust*, *as needed*, *where relevant*. They pass
review only when the sentence also states what is measured, and against what. "Loads
fast" fails; "renders the first row within 200 ms of the response" passes. The
vague-language discipline lives here rather than as a rule of its own: it bites in one
section kind only.

### Layer-local contracts

Some layers carry a rule of their own. Those rules are **owned elsewhere**. This table
points at the owner and does not restate the rule, so there is one place to change it.

| Layer | Local rule | Owner |
|---|---|---|
| `05_screens` — screens, patterns, components | the no-ASCII-layout rule | [`inspire-screens/SKILL.md`](../inspire-screens/SKILL.md) § Rules |
| `98_lessons` | one line, atomic | [`inspire-lesson/SKILL.md`](../inspire-lesson/SKILL.md) § Rules |

## Historical language — the specifics

R6 is judgment first. The reliable signal is a sentence whose subject is the document
rather than the system. If removing a clause loses nothing about how the product
behaves today, that clause states something other than what is.

**The mechanical subset is closed, and it covers the past alone.** These tokens are
greppable, and a check may act on them:

- `previously`
- `used to`
- `migrated from`
- `~~…~~` — strikethrough markup

`replaces` and `removed` are **deliberately absent** from that list, though both often
signal history. Both have legitimate present-tense uses in this vault.
`**Effect:** replace` is a pinned enum value, and "the row is removed" describes
correctly what a delete action does. A check that flagged them would train operators
to ignore it. Judgment still catches them: "this replaces the old flow" is history;
"this action replaces the stored document" is behavior.

**The future and the negative space get no tokens, for the same reason.** Every
candidate word carries the present-tense meaning far more often than the historical
one. `will` is how a specification states behavior in many languages and in plenty of
English sentences; `not` and `never` are how a prohibition, an invariant and a
constraint are all written. A check on those would fire on most of a healthy vault,
and a check that fires on everything is read as noise. Both halves of R6 stay
judgment, and the reader's test is the sentence's subject: the system, or the
document.

**Section-scoped exemptions.** R6 does not bind:

- an ADR's `### Breaking changes` content — naming what breaks *is* the section's job;
- an ADR's `## Related ADRs` section;
- the `**Status:**` line, including `superseded by [[…]]`;
- a `Supersedes: [[…]]` header line.

These exemptions make R6 **narrower than an unconditional ban** inside an ADR, and the
narrowing is intended. An unconditional ban is unwritable against the sections
[`inspire-adr`](../inspire-adr/SKILL.md) itself mandates. An ADR must record what it
supersedes, so a rule forbidding that would forbid a required section.

## Figurative language — the specifics

R7's metaphor half is judgment: no list distinguishes a figure of speech from a
term of art, and a vault's own domain language is full of words that were metaphors
somewhere else — a *queue*, a *stack*, a *pipeline*, a *tenant*. Those are the
operator's terms and R4 protects them.

**The intensifier list is closed and greppable**, because these words state nothing
in any context a specification has:

- `simply`, `simple matter of`
- `merely`
- `of course`, `needless to say`, `it goes without saying`
- `seamless`, `seamlessly`
- `elegant`, `elegantly`
- `effortless`, `effortlessly`
- `powerful`

Deleting one never changes what a sentence claims, which is the whole argument for
the list: a word whose removal costs nothing was carrying nothing.

*fast*, *intuitive*, *robust* and their kin are **not** here. Those name a property
someone could measure, so they belong to the vague-language discipline above, where
the fix is to state the measurement rather than to cut the word.

## Reports and replies

A report and a reply are read for one purpose: deciding what to do next. Both are
bound by every rule above, and both are also subject to three that only make sense
where prose is being spent on a reader's attention in real time.

**Say each fact once, then stop.** The test is whether anything could be cut without
losing a fact. Prose about a check that passed spends attention without changing a
decision, and it buries the part that needs one. Volume reads as circling rather
than as rigour.

**Room is earned by a decision or an action, never by effort.** Something nobody can
act on gets the fewest words or stays out. Something already working gets one line
and its evidence. Only what needs a decision gets the full treatment.

**The room comes out of the prose, never the evidence.** Every number, table, row
and measurement stays, and so does the note saying how it was measured — provenance
is what makes a number checkable. What gets cut is the writing wrapped around it,
and R8 lists the shapes that writing takes.

An unattended run is where this goes wrong most reliably. Nobody interrupts it, so
prose accumulates unchecked, and a hands-off report that runs half again as long as
an operator-led one on the same scope is not reporting more — it is restating.

## Prosaic back-sourcing

A claim carries its source **inside the sentence that makes it**. The wikilink is part
of the prose, using pipe-syntax display text where that reads better. It is never a
trailing `Back-source: [[x]], [[y]].` line and never a bare `[[link]]` parked at the
end of a step.

> **Bad.** Hash the password before writing the row. Back-source:
> [[adr-auth-01-identity-model]].
> **Good.** Hash the password using [[auth.password.hash|auth::password::hash]],
> following the auth-provider integration model in [[adr-auth-01-identity-model]].

Paratextual references are cheap to write and cheap to break. Nothing in the sentence
says which clause the link grounds, so editing the sentence silently orphans it.

The per-section mechanics for domain artifacts stay with the format that owns them:
[`inspire-domain/references/format-action.md`](../inspire-domain/references/format-action.md)
and its entity sibling. Those files name which sections require a link and what form
it takes. This section states the principle; those files state the shape.

## Enforcement

Enforcement is split, and the halves cover different ground.

**The authoring skills carry it as judgment.** Every skill that writes a KB artifact
references this file from its `## Rules` section. Each applies the contract while
writing, in whatever `output_language` the project declares. This is the whole
contract, and it is the half that matters: a rule the writer follows never becomes a
finding.

**The mechanical checks are a subset, and an English-only one.** They run from
`.inspire/bin/` at review time. Their scope is narrow, and stated rather than implied:
*prose-style mechanical checks are en-only; the writing contract still binds as
authoring judgment.* When `00_bootstrap/project.md` declares an `output_language` other
than `en`, `prose-style.sh` emits exactly that note at info level and exits without
findings.

The reason is structural, not effort. R1, R3, R7's intensifier list and the
historical-token list are English morphology. More decisively, the binding table above
is keyed on H2 **names**, and a compliant non-`en` fork translates its headers. Headers
are prose, not machine-read tokens, so even the language-independent rules would have no
section kind to bind to. A non-`en` checking strategy is **deferred and recorded**, not
solved: until one exists, the validator stays an `en`-only subset of a contract that
binds everywhere.

**What can reach `error`, and what cannot.** A finding ramps with the artifact's own
`lifecycle` only where the check reads a claim: R4 and R6. R1, R2, R3, R5 and R7 are
warnings at every lifecycle state, in every layer, and never escalate. For R1, R3 and
R7 that is because they guess, and a guess does not block a commit. For R2 and R5 it is
because they measure length, and length is a place to look rather than a defect — a
review that failed on a word count would be enforcing the symptom and leaving the
disease. Nothing here gates a commit on style alone.
