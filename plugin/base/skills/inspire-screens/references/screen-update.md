# Screens — update
> Part of [inspire-screens](../SKILL.md). Read together with [`format-screen.md`](format-screen.md), which owns the on-disk shape.

Patch-style modification of an existing screen — its bindings, the layout it
names, the components it instantiates, `## Purpose`, its deviations and notes —
and the flow that brings a screen of an older shape to the current one.

Two things this flow never rewrites: identity — `id` · `module` · `screen` are
write-once at **every** lifecycle, `superseded` included
([`format-screen.md`](format-screen.md) § Identity — the id is the referent) —
and `lifecycle:`, which is [`promote`](screen-lifecycle.md)'s. A changed id or a
new module is a new referent, so it is a `create` plus a supersession, never an
update. The one identity write this flow performs is not a rewrite: an old-shape
file carries no identity block at all, and step 4 mints that block once,
`lifecycle: draft` included.

Renaming the file takes no command at all — the name is positional, and a rename
is a move: the id, the route and every claim survive it
([`format-screen.md`](format-screen.md) § Identity, move versus change). Moving
one screen between surface trees that already exist is the same kind of move, and
the shape of the screens tree is this skill's day to day
([`_references/surface-scope.md`](../../_references/surface-scope.md) § Who owns
what). **Reshaping the tree is not.** The `05_screens/` split belongs to the
`/inspire-surface add` that takes the roster to two UI surfaces — it sweeps every
screen, has the operator classify each one, and moves with `git mv`
([`inspire-surface`](../../inspire-surface/SKILL.md) § The screens split). Route
a split there rather than hand-moving files out of this flow.

## Which screen

The argument is the **id** — `/inspire-screens update users.list`. Resolve it to
a path by searching the frontmatter of `inspire_kb/05_screens/**/*.md` for
`id: {id}`, never by deriving a path from the id: the file name is positional and
may have diverged from `screen:`, and the leading segment of a collision-minted
`{surface}.{module}.{screen}` is a mint, not a directory. No tool answers this
lookup — the screen-id index in `.inspire/bin/wikilinks-resolve.sh` is that
rule's own, built per run for its own pass — so the frontmatter search is the
mechanism.

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

## Superseded screens narrow to the pointer and the shape

At `superseded` the screen is kept for backward reference, so this flow narrows
to two things: `superseded_by:`, which is no part of the write-once triple, and
the body shape — an old-shape conversion, a stale wikilink, an absent
`## Purpose`. Bindings are declined, and the identity triple stays exactly as it
is: new behaviour belongs on the screen that replaced it, and the id is the
referent something downstream still points at
([`screen-lifecycle.md`](screen-lifecycle.md) § How `promote` walks). A
superseded screen reaches this flow through a `review` or `validate` finding, or
through an operator-directed derivation; never through `/inspire-emanate`, whose
frontier admits `accepted` only.

A screen with no frontmatter at all reads as `draft`
([`screen-lifecycle.md`](screen-lifecycle.md)), so nothing has to be regressed
before converting it.

## Flow

1. **Read the file, show it, and gate on `lifecycle:`.**
   - `stable` → refuse with the message above and stop the turn.
   - `superseded` → say it, in one line: *"`users.list` is superseded — this turn
     can set `superseded_by:` and repair the shape, but not its bindings; new
     behaviour belongs on the screen that replaced it."* The turn continues on
     that narrowed scope, and ends there if the only thing asked for was a
     binding change.
   - anything else, no frontmatter at all included → continue.

   If the frontmatter carries `endorsed:`, disclose it before proposing
   anything — presence is the whole test
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
   **every** row of that table. It is the catalogue, and this step deliberately
   does not restate it: a second copy of the list is a second thing to keep in
   step. Two things the catalogue leaves to this flow: the identity block is
   minted at `lifecycle: draft`, on a file that carries no block at all — never
   over one that does — and the `## Purpose` paragraph is *asked for*
   rather than converted — such a file carries no sentence to convert, which is
   why the catalogue gives it no row of its own. Partial conversion leaves the
   screen refusing derivation on the rows still outstanding.
5. **Show the diff** (unified ` ```diff ` block). The operator approves or
   iterates. Sections the operator did not touch are not rewritten.
6. **Write, then reconcile the module's `_index.md`** — the one in the directory
   the screen sits in. Its row carries the id, the title and the feature
   coverage, so an edit to the H1 or the `**Features:**` line makes the row
   stale.
7. **Re-run the mechanical half.** `.inspire/bin/screen-coherence.sh` and
   `.inspire/bin/sections-present.sh` over the screen's directory, and report
   what they say. Both runs are directory-scoped, so they also report on the
   target's neighbours: read each finding's `target` path and report the target's
   findings as this turn's, the neighbours' as pre-existing. Never resolve a
   neighbour's finding here — one screen at a time is the whole discipline of
   this flow. They are the same checks the entry's index routes to
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
