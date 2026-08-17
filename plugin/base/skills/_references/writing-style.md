# The writing contract — how INSPIRE prose is written

A knowledge base is read twice: once by a person deciding what to build, once by an
agent deciding what to generate. Prose that is merely *nice* serves the first reader
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
hubs, spike learnings, lessons, tickets and bootstrap documents. It binds the prose
of operator-facing review reports too — a finding is prose someone acts on.

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

### R1 — Write in the active voice

A passive sentence can omit its actor. In a specification the actor is usually the
thing being specified, so omitting it hides the very fact the reader came for.

> **Bad.** The password is hashed before the row is written.
> **Good.** `auth::password::hash` hashes the password; this action then writes the row.

The bad sentence never says who hashes. Two readers will guess two different
components, and both will implement their guess.

### R2 — One sentence, at most 25 words

Long sentences carry more than one claim, and a reader who disagrees with one clause
has no way to accept the rest. The cap forces one claim per sentence, which is also
what makes a claim reviewable and back-sourceable.

> **Bad.** When the operator submits the form the system validates the email against
> the tenant's domain allow-list and, if that passes, hashes the password and writes
> the user row, emitting an audit event afterwards. *(33 words)*
> **Good.** On submit, the system validates the email against the tenant's domain
> allow-list. It then hashes the password and writes the user row. Writing the row
> emits an audit event.

Twenty-five words is a ceiling, not a target. Most good specification sentences run
well under half of it.

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

### R5 — One paragraph, at most 6 sentences

A paragraph is one idea. Past the cap it is two ideas sharing a block, and the second
one is the one nobody remembers.

> **Bad.** One block carrying what the invoice is, how its lifecycle runs, which
> entities it touches, and why it carries a tax field.
> **Good.** One paragraph for the purpose, one for the lifecycle, one for the
> relationships. The tax field's reason belongs in `## Rationale`, where a reader
> looks for it.

A list is not a paragraph. Each item is measured on its own, and a bullet list is
never collapsed into one block for this rule.

### R6 — State the present, never the history

Every file states what is true now. Git carries what was true before, and it carries
it better: with dates, authors and diffs. Prose that narrates its own past ages into a
second, wrong description of the system sitting beside the right one.

> **Bad.** The total was previously computed client-side; it is now computed on the
> server.
> **Good.** The server computes the total.

The mechanical subset of this rule, and the sections exempt from it, are below.

## What binds where

Rules bind by **section kind**, not by file. The same artifact holds sections of
several kinds, and a rule that is right for a `## Purpose` paragraph is wrong for an
`## Inputs` table.

| Section kind | Where it occurs | Binds |
|---|---|---|
| **Normative prose** | `## Purpose`, `## Rationale`, `## Behavior`, `## Context`, `## Decision`, `## Consequences`, feature descriptions, screen prose | R1 · R2 · R3 · R4 · R5 · R6 |
| **Acceptance criteria** | feature `## Acceptance criteria` | R1 · R2 · R3 · R4 · R6, and each criterion states an observable outcome — see below |
| **Tabular / structured** | `## Inputs`, `## Outputs`, `## Entities` field tables, `## Fields`, roster and coverage tables | R3 · R4 · R6 (cells are fragments, so R1, R2 and R5 do not apply) |
| **Machine-read tokens** | frontmatter keys and enum values, wikilink targets, identifiers, filenames, code fences | nothing — [`output-language.md`](output-language.md) governs these |

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
behaves today, that clause was history.

**The mechanical subset is closed.** These tokens are greppable, and a check may act
on them:

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

**Section-scoped exemptions.** R6 does not bind:

- an ADR's `### Breaking changes` content — naming what breaks *is* the section's job;
- an ADR's `## Related ADRs` section;
- the `**Status:**` line, including `superseded by [[…]]`;
- a `Supersedes: [[…]]` header line.

These exemptions make R6 **narrower than an unconditional ban** inside an ADR, and the
narrowing is intended. An unconditional ban is unwritable against the sections
[`inspire-adr`](../inspire-adr/SKILL.md) itself mandates. An ADR must record what it
supersedes, so a rule forbidding that would forbid a required section.

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

**The mechanical checks are a subset, and an English-only one in 0.7.** They run from
`.inspire/bin/` at review time. Their scope is narrow, and stated rather than implied:
*prose-style mechanical checks are en-only in 0.7; the writing contract still binds as
authoring judgment.* When `00_bootstrap/project.md` declares an `output_language` other
than `en`, `prose-style.sh` emits exactly that note at info level and exits without
findings.

The reason is structural, not effort. R1, R3 and the historical-token list are English
morphology. More decisively, the binding table above is keyed on H2 **names**, and a
compliant non-`en` fork translates its headers. Headers are prose, not machine-read
tokens, so even the language-independent rules would have no section kind to bind to.
A non-`en` checking strategy is **deferred and recorded**, not solved: until one
exists, the validator stays an `en`-only subset of a contract that binds everywhere.

Mechanical findings are advisory where the vault is still forming, and firmer where a
`lifecycle` field says the artifact is settled. The per-rule severities live with the
validators. Nothing here gates a commit on style alone.
