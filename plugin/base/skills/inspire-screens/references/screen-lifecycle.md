# Screens — lifecycle
> Part of [inspire-screens](../SKILL.md). Read when the entry's index routes here.

Screen files carry `lifecycle:` in frontmatter and take the **same 4-state enum**
as action descriptors and entity documents — one enum, one state machine, defined
once in [`_references/lifecycle-rules.md`](../../_references/lifecycle-rules.md).
This file says what each state means for a screen and how `promote` walks them. It
does not restate the enum.

## What each state means here

| State | For a screen |
|---|---|
| `draft` | In design. Bindings are still moving; the shape checks report warnings only. |
| `accepted` | Design closed. The bindings are the contract: keys, actions, outcomes and states are fixed, and the shape checks are errors from here on. The screen is in the emanation frontier. |
| `stable` | Implementation locked. The screen is realized, its claims are covered by evidence, and every pattern and component it declares is at `**State:** implemented`. |
| `superseded` | The screen exists for backward reference. It carries `superseded_by:` pointing at the screen id that replaced it, and drops out of the frontier. |

The severity of a screen's shape and coherence findings ramps with this field, the
same way a domain object's does: warning at `draft`, error at `accepted` and
`stable`, warning again at `superseded`. A screen file that carries no
frontmatter at all — every screen written before the identity block existed —
reads as `draft` and keeps emitting warnings, so no existing project's commit
starts failing.

## How `promote` walks

`/inspire_screens promote {id} {state}` confirms the target state, then re-runs
the checks that apply there. An error finding refuses the promotion.

- **`draft → accepted`** — confirm explicitly. The shape and coherence checks
  already ran at draft; promotion is the act of locking the bindings.
- **`accepted → stable`** — the two dependency gates run: every component the
  screen declares must be at `**State:** implemented` (a `to-extract` component is
  a promise, not a dependency), and every pattern it names must exist with its
  `## Regions` declared. Refuse on either.
- **`stable → accepted`** and **`accepted → draft`** — regression, confirmed
  explicitly, no gates re-run: the contract is loosening, not tightening. A screen
  regresses when a component it declares regresses, or when a feature it realizes
  reopens.
- **`{any} → superseded`** — confirm explicitly; require `superseded_by:` to
  resolve to an existing screen id. A superseded screen keeps its file: the id is
  the referent, and something downstream may still point at it.
- **Reverse from `superseded`** — refused. Mint a new screen instead.

Promotion never renames or moves anything: the id is write-once, and a lifecycle
change is not a change of referent.

## How the frontier reads it

The emanation frontier takes `accepted` screens — and, beside them, the catalog
entries at `**State:** to-extract`, which is what `accepted` is for an entry that
carries no `lifecycle:` of its own. Two orderings meet here and both are correct:

- **Birth order** — `/inspire_extract` may discover a shared component *after* the
  screens that adopt it. Discovery running behind adoption is specification-time
  work, not a defect.
- **Wave order** — a screen emanates a wave behind the patterns and components it
  declares, in the same run. It never waits for them to be hand-built: an entry at
  `to-extract` is a unit the loop emanates, and only an entry stating neither
  `to-extract` nor `implemented` leaves a screen unready.

There is no circularity: extraction happens while specifying, the ordering applies
while emanating. The sharp edge is accepted knowingly — promoting a recurring block
out of already-delivered screens changes their composition, so those screens
legitimately re-enter the frontier. A refactor *is* a spec change, and claims are
keyed per binding, so the unchanged ones stay covered and the re-emanation stays
cheap.
