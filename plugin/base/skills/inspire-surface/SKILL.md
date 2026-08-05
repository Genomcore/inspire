---
name: inspire-surface
description: "Manage the suite's surface roster and its lifecycle: add a surface (greenfield / split out of an existing one / adopt a joining codebase), retire one, or review the roster for coherence. Owns inspire_kb/00_bootstrap/surfaces.md. Use when the product grows a second app, an admin console, a service or a shared package; when a surface is being wound down; or when checking that surface ids, packages, shells and the screens tree still agree."
---

# /inspire_surface — Surface roster and lifecycle

## Scope

A **surface** is a deliverable that faces someone — a UI a person looks at, a
service with no face, or a shared package other surfaces consume. Surfaces are the
second first-class axis of the KB: modules say *what* the product does,
surfaces say *where* it is delivered. Every project is a suite; most are suites of
one and never need this skill.

The rules that govern surfaces — the three kinds, which ids are reserved, what
`surfaces:` means on an artifact, how a skill resolves scope, and the two shapes
the screens tree takes — are defined once in
[`.claude/skills/_references/surface-scope.md`](../_references/surface-scope.md).
Read it before any subcommand here; this skill applies those rules, it does not
restate them.

## Ownership

This skill owns exactly one file: the roster at
`inspire_kb/00_bootstrap/surfaces.md`. It is the only skill that adds or retires a
surface, and the only diagnostic for the roster's own coherence. Owning a
`00_bootstrap` file from outside `inspire-bootstrap` follows the existing
cross-layer precedent — bootstrap owns `05_screens/design-system.md`.

The roster's on-disk contract — frontmatter, body sections, fields, defaults —
lives in [`references/roster-format.md`](references/roster-format.md). **Read it
before writing the file.**

What this skill does **not** own:

- the **shape** of `05_screens/` day to day — `inspire-screens` creates surface and
  module directories lazily as screens land. This skill touches that tree only
  inside a sweep the operator has classified entry by entry: the one-time split the
  roster's second UI surface triggers, and the moves a later split performs.
- the `surfaces:` field on individual artifacts — `inspire-adr`, `inspire-feature`
  and `inspire-task` stamp their own.
- the packages themselves — the roster records a `Package` path; `inspire-code`
  scaffolds it on first emanation.

## Invocation

- `/inspire_surface add` — declare a new surface (greenfield · split · adopt)
- `/inspire_surface retire {surface}` — wind a surface down and unpick its scope
- `/inspire_surface review` — roster coherence (read-only)

## Subcommand: add

Three **arrival shapes**, chosen by where the surface comes from. Establish which
one applies before doing anything: a greenfield surface starts empty, a split
surface starts full of someone else's screens, and an adopted one starts as an
existing codebase. They share steps 1–3 below; they differ in everything after.

Whatever the shape, `add` must end with the roster naming the new surface, the
frontmatter list mirroring it, and the operator knowing what moved. It may never
leave the roster half-written, invent an id, or move an artifact the operator has
not classified.

One further obligation is keyed to the roster rather than to the arrival shape:
**the `add` that takes the roster's `kind: ui` count from 1 to 2 performs the
screens split** (below). Which `add` came first has no bearing on it.

### Greenfield

1. **Interview the shape**: id, kind, display name, and the optional fields
   (profiles, package, shell) only where they differ from the defaults in
   [`references/roster-format.md`](references/roster-format.md). Ask for what is
   missing rather than guessing it.
2. **Validate the id** — a slug, unique in the roster, and not one of the reserved
   ids. A rejected id stops the add and returns to the interview; it is never
   silently corrected.
3. **Record it** — append the body section and add the id to the frontmatter
   `surfaces:` list in the same write. The two must never disagree, not even
   between two edits.
4. **UI surfaces get a shell** — hand off to `/inspire_prototype` to scaffold a
   shell at the recorded prefix, behind the suite landing. Screens accrue normally
   afterwards through `/inspire_screens`; `add` creates no screen files.
5. **Propose an ADR** carrying `surfaces: all` — a suite-shape change is
   system-wide by construction. Offer `/inspire_adr`; the operator may decline, and
   the roster entry stands either way.

`add` only **records** the `Package` path. It does not create the directory,
scaffold a project, or install anything: `inspire-code` materializes the package
lazily, on the first emanation into that surface.

### Split

A concern already built inside one surface is becoming its own — an admin console
growing out of the main UI. The roster entry is cheap; the sweep is the work.

1. **Create the roster entry first** (greenfield steps 1–3). The sweep classifies
   artifacts *against* an id, so the id must exist.
2. **Sweep** every screen spec, feature and ADR whose content or blast radius
   touches the moving concern, and present the whole set as **one batch** — the
   same pattern as `/inspire_module scan`, not a prompt per artifact.
3. **The operator classifies each entry**: *stays* · *moves* · *both*.
4. **Only then, perform** the classified result:
   - screens marked *moves* go to `05_screens/{surface}/{module}/`; *both* goes to
     `05_screens/shared/{module}/`. Move with `git mv` so history follows the file.
   - screens marked *stays* move too when this `add` is the one crossing to a
     second UI surface — the whole tree is reshaping, so they land in the
     incumbent's tree rather than staying flat. Otherwise they are untouched.
   - re-prefix the `**Target:**` routes in every moved screen spec, and the
     corresponding routes in the prototype shells, to the new shell prefix.
   - hand `/inspire_feature` the list of features that now need per-surface
     coverage rows.
   - ADRs take their classification as their `surfaces:` value.
5. **Propose the ADR** (`surfaces: all`), as in greenfield.

> **Nothing is reclassified or moved silently.** The operator sees the full list and
> classifies every entry before the first move. An unclassified entry blocks the
> sweep; it never takes a default.

### Adopt

An existing codebase joins the suite as a surface.

1. **Delegate the reading to `/inspire_extract`**, scoped to that codebase's path.
   Extract owns brownfield analysis; this skill does not re-implement scanners.
2. **Consume its surface candidates back into `add`** — each candidate is a
   proposal, not a fact. It becomes a greenfield interview (steps 1–3) with the
   fields pre-filled and confirmed one by one.
3. Everything else the scan produced — modules, screens, stack findings — lands
   through extract's own consolidation into the **one** domain. A joining codebase
   brings a surface, never a second module registry.
4. **Propose the ADR** (`surfaces: all`).

### The promote ceremony — the first `add`

The first `add` in a project with no roster is the moment the existing product
stops being implicit. It does everything a normal `add` does, plus two things that
happen exactly once:

1. **Name the incumbent.** Interview what the existing product is called *as a
   surface*, and write both entries. The roster file is created here — not seeded
   earlier, not created by an upgrade.
2. **Offer a backfill** stamping `surfaces:` onto existing ADRs and features —
   offer it, never force it, and never make it a precondition for the promote.
   Declining leaves every existing artifact correct, by the absent-field rule in
   [`_references/surface-scope.md`](../_references/surface-scope.md).

### The screens split

The split of `05_screens/` belongs to whichever `add` takes the roster's `kind: ui`
count from 1 to 2 — the sweep from *split* above, run over the existing flat tree
with the incumbent UI surface as the default classification, every entry confirmed
by the operator. The shape the tree must end in is derived from the roster's UI
count, in [`_references/surface-scope.md`](../_references/surface-scope.md), never
from what the tree used to be or from which `add` came first.

Usually that is the promote ceremony, but the two are separate obligations and
conflating them breaks in both directions:

- A promote that declares a `headless` or `lib` surface leaves the UI count at 1.
  The tree stays flat — reshaping it there would put it in a shape the roster does
  not imply.
- The later `add` that introduces a second UI surface is ordinary in every other
  respect — no roster to create, no incumbent to name — and still owes the split.

## Subcommand: retire

The reverse sweep. A retire must end with nothing in the KB scoped to a surface
that no longer exists, and with the operator having decided the fate of every such
thing. It may never delete an artifact on the operator's behalf.

1. **Resolve the surface** against the roster. An id that is not there is an error,
   not an invitation to guess.
2. **List what is scoped solely to it** — its screens tree, its prototype shell, its
   package path, and every artifact whose `surfaces:` names it and nothing else.
   Artifacts that name it *alongside* other surfaces are a second, shorter list:
   they only lose one id, and that edit is mechanical.
3. **Each entry in the first list takes an explicit decision** — *archive* or
   *rescope* (to another surface, or to the suite). Present them as one batch. An
   entry with no decision blocks the retire.
4. **Apply the decisions, then remove the roster entry last.** The id must still
   resolve while the sweep runs.
5. **Surface the consequences.** If the retire drops the suite to a single UI
   surface, the screens tree shape the roster now implies has changed — say so and
   hand the reshaping to `/inspire_screens`. Never collapse the tree as a side
   effect. Retiring back to one surface does not delete the roster.
6. **Propose an ADR** carrying `surfaces: all`.

## Subcommand: review

Read-only diagnostic for the roster and everything that points at it. It reports,
recommends and offers; it never edits.

Checks, in order:

1. **Frontmatter mirrors the headings.** The `surfaces:` list and the `##` sections
   name exactly the same ids. Machine readers see only the frontmatter, so drift
   here is wrong in a way nothing else notices — this check runs first.
2. **Ids are unique slugs and none is reserved** (`_references/surface-scope.md`).
3. **Packages resolve under `source_root`** — resolve the root via
   [`_references/product-roots.md`](../_references/product-roots.md), never the
   literal `source/`. A recorded path with no directory yet is a warning, not an
   error: the package is scaffolded on first emanation.
4. **Shell prefixes are unique among UI surfaces**, and absent on every non-UI one.
5. **The screens tree is in the shape the roster's UI count implies** — derive it
   from [`_references/surface-scope.md`](../_references/surface-scope.md), never
   from what the tree used to be. Two instances to name: a flat
   `05_screens/{module}/` directory under 2+ UI surfaces, whether it sits beside
   surface trees or the whole tree is still flat (a split that never happened, or
   never finished); and a surface-first tree standing under a single UI surface,
   typically left by a retire. Either way, offer the corrective sweep — the
   operator classifying each entry — and do nothing until they accept.
6. **Every `surfaces:` value KB-wide resolves** to a roster id or to `all`. An
   unknown id is an error; an absent field is not a finding.

Render findings in the shared operator-facing format from
[`_references/findings-format.md`](../_references/findings-format.md) — heading,
**Issue.**, **Suggested follow-up.** These are skill-level checks rather than
`.inspire/bin` rules; name the check above in the rule slot.

## Rules

> **Output language.** Write every artifact you produce in the project's declared
> `output_language` (default English) — see
> [`_references/output-language.md`](../_references/output-language.md). Applies
> whatever language the conversation is in, and independently of the product's own
> i18n; machine-read tokens (frontmatter keys/values, wikilink slugs, filenames,
> surface ids) stay verbatim.

1. **This skill writes surface ids; every other skill only reads them.** The
   never-invent rule in
   [`_references/surface-scope.md`](../_references/surface-scope.md) binds here too
   — a new id comes from the operator, never from inference about the codebase.
2. **Frontmatter and headings are written together.** A roster whose `surfaces:`
   list disagrees with its `##` sections is broken, however briefly.
3. **`review` is read-only.** It reports, suggests fixes and recommends other
   skills; it never edits files. The leftover-tree offer is a handoff, not an edit.
4. **Nothing moves, is reclassified, or is deleted silently.** Every sweep presents
   its full list first and takes an explicit decision per entry. An entry with no
   decision blocks the operation rather than defaulting.
5. **`add` and `retire` close by proposing an ADR** with `surfaces: all` —
   suite-shape changes are system-wide. Proposing is required; accepting is the
   operator's call.
6. **Adding or retiring a surface never touches `04_domain/`**, never creates a
   second module registry, and never splits the design system — the one-domain rule
   in [`_references/surface-scope.md`](../_references/surface-scope.md) is why.
7. **Never create the roster for a single surface.** The file comes into existence
   at the promote ceremony and nowhere else; creating it earlier would make the
   reading of its absence wrong for every skill that depends on it.

## Related skills

- `/inspire_screens` — owns the screens tree day to day; receives the reshaping
  work this skill's sweeps surface.
- `/inspire_prototype` — one shell per UI surface, behind the suite landing.
- `/inspire_extract` — reads a joining codebase and emits the surface candidates
  the *adopt* arrival consumes.
- `/inspire_code` — resolves a surface's package and profiles from the roster and
  scaffolds the package on first emanation.
- `/inspire_bootstrap` — the shape interview ("one surface or several?") delegates
  each declaration here.
- `/inspire_workspace` — the global pre-PR review; checks that every `surfaces:`
  value resolves and reports per-surface health.
