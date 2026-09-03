# Screens — update
> Part of [inspire-screens](../SKILL.md). Read together with [`format-screen.md`](format-screen.md), which owns the on-disk shape.

Patch-style modification of an existing screen — its bindings, the layout it
names, the components it instantiates, `## Purpose`, its deviations and notes —
and the flow that brings a screen of an older shape to the current one.

Two things this flow does not touch: identity, because `id` · `module` ·
`screen` are write-once ([`format-screen.md`](format-screen.md) § Identity — the
id is the referent), and `lifecycle:`, which is
[`promote`](screen-lifecycle.md)'s. A changed id or a new module is a new
referent, so it is a `create` plus a supersession, never an update; renaming the
file, or re-placing it in another surface tree, is a move and takes no command at
all.

## Which screen

The argument is the **id** — `/inspire-screens update users.list`. Resolve it to
a path through the id index (`.inspire/bin/wikilinks-resolve.sh`), never by
guessing the file name: the name is positional and may have diverged from
`screen:`.

`{module}/{screen}`, the form `create` and `validate` take, resolves too when
exactly one screen matches it. Once the suite declares two or more UI surfaces,
two trees can hold the same `{module}/{screen}` while only the newcomer's id
carries a surface segment — ask for the id rather than pick a file.

## Stable screens block

`update` refuses when the target is at `lifecycle: stable`:

```
Cannot update users.list — it is at lifecycle: stable.
A stable screen is a locked contract; editing its bindings in place would shift
them under the tests covering its claims. To modify it:
  1. /inspire-screens promote users.list accepted   # stable → accepted
  2. /inspire-screens update users.list ...         # apply the change
  3. /inspire-screens promote users.list stable
```

Screens carry no `demote` verb — `promote` walks both directions
([`screen-lifecycle.md`](screen-lifecycle.md) § How `promote` walks) — and the
regression is the point: it makes the loosening of a locked contract an explicit,
traceable act rather than a side effect of an edit.

At `superseded` the screen is kept for backward reference: repair its identity
and its shape, `superseded_by:` included, and decline binding changes. New
behaviour belongs on the screen that replaced it.

A screen with no frontmatter at all reads as `draft`
([`screen-lifecycle.md`](screen-lifecycle.md)), so nothing has to be regressed
before converting it.

## Flow

1. **Read the file and show it.** If `lifecycle: stable`, refuse with the message
   above and stop. If the frontmatter carries `endorsed:`, disclose it before
   proposing anything — presence is the whole test
   ([trust-stamps](../../_references/trust-stamps.md#endorsement)).
2. **Scope the change.** A natural-language continuation is applied as a patch
   without re-asking for the id — `/inspire-screens update users.list drop the
   archive dispatch` is parsed as "update `users.list`, change: remove the
   `archive` dispatch". Otherwise ask what should change, in one question. Where
   the invocation arrived from a derivation refusal, the refusal's class **is**
   the scope: the shape it names
   ([`_references/derived-contract.md`](../../_references/derived-contract.md))
   is what this turn resolves.
3. **Interview new content, don't draft it.** A change that introduces a
   section's worth of content — a first `### States` table, a `## Purpose` an
   older file never carried — runs the matching step of
   [`screen-create.md`](screen-create.md) rather than arriving pre-written. Key
   every new binding row screen-locally, and drop a subsection left with nothing
   in it.
4. **Convert an older shape whole, one screen at a time.** Walk
   [`format-screen.md`](format-screen.md) § Old shape → new shape and resolve
   every row it lists: mint the identity block at `lifecycle: draft` — the one
   identity write this flow performs, on a file whose id was never minted — move
   `## Instantiation` declarations into keyed `## Bindings` rows, drop a route
   authored into the H1, drop `**Pattern:** bespoke`, and ask for the
   `## Purpose` paragraph, which such a file has no sentence to convert into.
   Partial conversion leaves the screen refusing derivation on the rows still
   outstanding.
5. **Show the diff** (unified ` ```diff ` block). The operator approves or
   iterates. Sections the operator did not touch are not rewritten.
6. **Write, then reconcile the module's `_index.md`** — the one in the directory
   the screen sits in. Its row carries the id, the title and the feature
   coverage, so an edit to the H1 or the `**Features:**` line makes the row
   stale.
7. **Re-run the mechanical half.** `.inspire/bin/screen-coherence.sh` and
   `.inspire/bin/sections-present.sh` over the screen's directory, and report
   what they say. They are the same checks the entry's index routes to
   ([`screen-checks.md`](screen-checks.md)); the judgment-level ones — pattern,
   component and prototype drift — belong to `validate`, which is where a screen
   that needs them goes next.
8. **Stamp.** `.inspire/bin/trust.sh stamp <file> --skill screens` on the screen
   and on any `_index.md` this turn rewrote
   ([trust-stamps](../../_references/trust-stamps.md#stamping)). `endorsed:` is
   never written here — the machine does not author it, and this flow proposes no
   endorsement.
9. **Propagate.** A changed binding, layout or outcome is a UI change: close the
   turn with the propagation question
   ([`screen-propagation.md`](screen-propagation.md)).
