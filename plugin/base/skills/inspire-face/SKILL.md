---
name: inspire-face
description: "Manage the project's faces and bundles: add a face (greenfield, or split out of an existing face), add a bundle, retire either, or review them for coherence. Owns every {face}.face.md and {bundle}.bundle.md under inspire_kb/01_spec/. Use when the product grows a second app, an admin console, an API, an SDK or a backend for a frontend; when one is being wound down; or when checking that ids, packages, shells and exposure still agree."
---

# /inspire-face — Faces and bundles

## Scope

A **face** is an application a person uses: a web portal, a back office, a mobile
app. It holds its screens, its shell and its tokens, and declares the bundles it
uses. A **bundle** is a headless grouping of actions from one or more modules: an
API, an SDK, a library, a backend for a frontend. Modules say *what* the product
does; faces and bundles say *how* it reaches people and other systems.

A project with screens has at least one face. A project without screens has none.

The rules that govern faces and bundles — what `faces:` and `bundles:` mean on an
artifact, how a skill resolves scope, which ids are refused — are defined once in
[`.claude/skills/_references/face-scope.md`](../_references/face-scope.md). Read it
before any subcommand here; this skill applies those rules, it does not restate them.

## Ownership

This skill owns two kinds of file, found by their typed extension anywhere under
`inspire_kb/01_spec/`:

- `{face}.face.md` — one per face, at `_faces/{face}/{face}.face.md`;
- `{bundle}.bundle.md` — one per bundle, at `_bundles/{bundle}.bundle.md`.

It is the only skill that creates or retires a face or a bundle. Both files'
on-disk contract — frontmatter, body, fields, defaults — lives in
[`references/face-format.md`](references/face-format.md). **Read it before writing
either file.** New files start from
[`templates/face.template.md`](templates/face.template.md) and
[`templates/bundle.template.md`](templates/bundle.template.md).

What this skill does **not** own:

- **screens** — `inspire-screens` writes `{slug}.screen.md` under a face's
  `_screens/` and the face's `_index.md`. This skill moves screens only inside a
  split the operator has classified entry by entry.
- **processes** — `inspire-process` writes a face's `_processes/`.
- **the store** — `inspire-store` writes a face's `{face}.store.md`.
- the `faces:` and `bundles:` fields on global ADRs, features and design-system
  entries — `inspire-adr`, `inspire-feature`, `inspire-screens` and `inspire-task`
  stamp their own.
- **exposure** — an action's route, dispatch and guard bindings stay on the action
  (`inspire-domain`). A bundle lists which actions it publishes; it never redefines
  how one is reached.
- the **packages** themselves — a face or bundle records a `package` path; the INSPIRE
  Factory scaffolds it on first emanation.

## Invocation

- `/inspire-face add face` — declare a new face (greenfield · split)
- `/inspire-face add bundle` — declare a new bundle
- `/inspire-face retire {id}` — wind a face or a bundle down and unpick its scope
- `/inspire-face review` — coherence of every face and bundle (read-only)

## Subcommand: add face

Two **arrival shapes**: a greenfield face starts empty, a split face starts with
screens taken from another face. Establish which one applies first. Both share
steps 1–4 below.

`add face` ends with a `{face}.face.md` whose frontmatter is complete and with the
operator knowing what moved. It never invents an id and never moves a screen the
operator has not classified.

### Greenfield

1. **Interview the shape**: id, display name, and the optional fields (`package`,
   `profiles`, `shell`) only where they differ from the defaults in
   [`references/face-format.md`](references/face-format.md). Ask for what is
   missing rather than guessing it.
2. **Validate the id** — a slug, unique among faces, never starting with `_`. A
   rejected id stops the add and returns to the interview; it is never silently
   corrected. The shell must be unique among faces. A second face means both
   faces need a shell: if the existing one has none, adding one changes every
   route it serves, so say so and let the operator choose its prefix.
3. **Name the bundles it uses.** Ask which existing bundles expose the actions this
   face's screens will bind, and write them in `bundles:`. A bundle that does not
   exist yet is created as a draft from
   [`templates/bundle.template.md`](templates/bundle.template.md) in the same
   change (see `add bundle`): a link always has a file behind it.
4. **Write the file** at `inspire_kb/01_spec/_faces/{face}/{face}.face.md` from
   [`templates/face.template.md`](templates/face.template.md), with
   `lifecycle: draft`.
5. **Hand off the shell** to `/inspire-prototype`, which scaffolds a shell at the
   face's `shell` prefix. Screens accrue afterwards through `/inspire-screens`;
   `add face` creates no screen files.
6. **Propose an ADR** — a new face changes the shape of the product. Offer
   `/inspire-adr`; the operator may decline, and the face stands either way.

A face candidate from `/inspire-extract` enters at step 1 as a greenfield interview,
its fields pre-filled and confirmed one by one. A candidate is a proposal, not a fact.

### Split

A concern built inside one face is becoming its own: an admin console growing out
of the main portal. The face file is cheap; the sweep is the work.

1. **Create the new face first** (greenfield steps 1–4). The sweep classifies
   screens *against* an id, so the id must exist.
2. **Sweep** every screen of the source face, and every global ADR, feature and
   design-system entry whose `faces:` names the source face, and present the whole
   set as **one batch** — not a prompt per artifact.
3. **The operator classifies each entry**: *stays* · *moves* · *both*.
   *Both* is not a shared screen: there are none. Each face keeps its own screen,
   and what they share becomes a layout or a pattern in `_design-system/`, through
   `/inspire-screens`.
4. **Only then, perform** the classified result:
   - a screen marked *moves* goes to the new face's `_screens/`. Its id changes
     from `{source}.{slug}` to `{face}.{slug}` — the face is part of a screen's
     id, and this is the one operation that changes it. `module:` and `screen:`
     stay, so the route changes only by the shell prefix.
   - **record every changed id** before anything else reads the KB: add an
     `"{old}": "{new}"` entry to the `screens` object of
     `inspire_kb/01_spec/_migration/id-map.json`, creating the file as
     `{"screens": {}}` if it is missing. This is the same map `/inspire:migrate`
     writes. Rewrite the links to the moved screens across the KB to the new id.
   - a screen marked *both* stays, and a copy with a new id lands in the new face.
     Only the copy's id is new, so it needs no id-map entry.
   - global ADRs, features and design-system entries take their classification as
     their `faces:` value.
   - hand `/inspire-feature` the features that now need coverage in the new face.
5. **Tell the operator what built code needs.** A moved screen that the INSPIRE
   Factory has already built is cited by its old id in the code and its tests. The
   Factory's id-map rewrite updates those citations from `id-map.json` without
   rebuilding the screen. Until it runs, the built screen reads as stale.
6. **Propose the ADR**, as in greenfield.

> **Nothing is reclassified or moved silently.** The operator sees the full list and
> classifies every entry before the first move. An unclassified entry blocks the
> sweep; it never takes a default.

## Subcommand: add bundle

A bundle groups actions that are published together, by one package.

1. **Interview the shape**: id, display name, `package`, `profiles`. Validate the id
   as for a face (a slug, unique among bundles, never `_`-prefixed). No version in
   the id: `api`, never `api@v1`.
2. **Ask which actions it exposes.** This is the operator's specification decision,
   made from the use cases. INSPIRE may suggest a grouping — one bundle per module
   is a reasonable start — but never decides it. Each entry in `## Actions` is a
   whole module (`[{module}](../_modules/{module}/{module}.module.md) (whole module)`) or one action
   (`[{module}::{entity}::{action}](../_modules/{module}/_domain/{entity}/{entity}.{action}.action.md)`).
3. **Every link has a file.** Links follow [kb-links.md](../_references/kb-links.md). A module or action named here that does not exist
   yet is created as a draft from its template (`inspire-module`,
   `inspire-domain`) before the bundle is written.
4. **Ask what kind of bundle it is.** A bundle that only groups actions has exactly
   one Factory claim, `{bundle}/mount/every-action`: a test that starts the
   bundle's application and checks it exposes every action it lists. A bundle that
   produces its own artifact (an SDK, a library, a backend for a frontend) has code
   of its own, and its body describes what that code does — those descriptions are
   its further claims. Write the body accordingly
   ([`references/face-format.md`](references/face-format.md)).
5. **Write the file** at `inspire_kb/01_spec/_bundles/{bundle}.bundle.md` from
   [`templates/bundle.template.md`](templates/bundle.template.md), with
   `lifecycle: draft`.
6. **Offer to add it to faces.** A face whose screens bind these actions lists the
   bundle in its `bundles:`; offer the edit per face, never apply it unasked.

## Subcommand: retire

The reverse sweep. A retire ends with nothing in the KB scoped to a face or bundle
that is retired, and with the operator having decided the fate of every such
thing. It never deletes an artifact on the operator's behalf.

1. **Resolve the id** to its `*.face.md` or `*.bundle.md`. An id with no file is an
   error, not an invitation to guess.
2. **List what depends on it:**
   - for a face — its `_screens/`, `_adr/`, `_processes/`, `_index.md`, its
     tokens, its prototype shell, its package path, and every global artifact whose
     `faces:` names it and nothing else;
   - for a bundle — every face whose `bundles:` lists it, and every global artifact
     whose `bundles:` names it and nothing else.
   Artifacts that name it *alongside* other ids are a second, shorter list: they
   lose one id, and that edit is mechanical.
3. **Each entry in the first list takes an explicit decision** — *archive* or
   *rescope* (to another face or bundle, or to the whole project). Present them as
   one batch. An entry with no decision blocks the retire. A screen rescoped to
   another face changes id, and the change goes into `id-map.json` as in a split.
4. **Apply the decisions, then retire the file last**: set its `lifecycle:` to
   `superseded`, or remove it if the operator asks. The id must still resolve while
   the sweep runs.
5. **Propose an ADR.**

Retiring a bundle never touches the actions it listed: exposure lives on the action,
and the actions stay in their modules.

## Subcommand: review

Read-only diagnostic for every face and bundle and everything that points at them.
It reports, recommends and offers; it never edits.

1. **Run the validators:**

   ```bash
   .inspire/bin/spec-identity.sh
   .inspire/bin/face-exposure.sh
   ```

   `spec-identity` checks that ids are unique and never `_`-prefixed, that no two
   faces share a shell, that every bundle a face lists exists, and that every bundle
   declares its `package`. `face-exposure` checks that a screen binds only actions
   its face's bundles expose. Report their findings as they are.
2. **Add the judgment the validators cannot make:**
   - **Packages resolve under `source_root`** — resolve the root via
     [`_references/product-roots.md`](../_references/product-roots.md), never the
     literal `source/`. A recorded path with no directory yet is a warning: the
     package is scaffolded on first emanation.
   - **Bundle boundaries match the use cases.** A bundle whose actions serve no
     common audience, or two bundles that every face always lists together, is a
     grouping worth questioning. Suggest; never regroup.
   - **A bundle's kind is clear.** A grouping bundle carries no prose that promises
     code of its own; a bundle with its own artifact says what that artifact does.
   - **Every `faces:` and `bundles:` value KB-wide names an existing file.** An
     unknown id is an error; an absent field is not a finding.
   - **A screen used by another face** — one face's screens linking another face's
     screen — is shared structure that belongs in a layout or a pattern.
   - **An `id-map.json` entry whose new id has no screen** is a split or retire
     that did not finish.

Render findings in the shared operator-facing format from
[`_references/findings-format.md`](../_references/findings-format.md) — heading,
**Issue.**, **Suggested follow-up.** Validator findings name their rule; the
judgment checks above name the check in the rule slot.

## Rules

> **Output language.** Write every artifact you produce in the project's declared
> `output_language` (default English) — see
> [`_references/output-language.md`](../_references/output-language.md). Applies
> whatever language the conversation is in, and independently of the product's own
> i18n; machine-read tokens (frontmatter keys/values, link paths, filenames,
> face and bundle ids) stay verbatim.

> **Writing contract.** Face and bundle prose and every review report follow
> [`_references/writing-style.md`](../_references/writing-style.md).

> **Lesson capture.** At a natural pause, when the operator's feedback should
> change how this skill behaves, offer `/inspire-lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

1. **This skill writes face and bundle ids; every other skill only reads them.** A
   new id comes from the operator, never from inference about the codebase.
2. **The domain never says which face or bundle uses it.** Adding or retiring a
   face or bundle never touches a module's `_domain/`, and never splits the design
   system.
3. **Exposure stays on the action.** A bundle lists actions; it never moves or
   restates an action's route, dispatch or guard.
4. **A face has no claims of its own.** Its screens do. A grouping bundle has
   exactly one, `{bundle}/mount/every-action`; only a bundle with its own artifact
   has more.
5. **Every changed screen id is recorded** in `01_spec/_migration/id-map.json`
   before the change is committed. An unrecorded id change forces a rebuild of
   built code.
6. **`review` is read-only.** It reports, suggests fixes and recommends other
   skills; it never edits files.
7. **Nothing moves, is reclassified, or is deleted silently.** Every sweep presents
   its full list first and takes an explicit decision per entry.
8. **`add` and `retire` close by proposing an ADR.** Proposing is required;
   accepting is the operator's call.
9. **Check and stamp every write.** After `add` or `retire` writes a face or bundle
   file, run `.inspire/bin/review.sh <file>` and fix what it reports on that file
   ([write-checks](../_references/write-checks.md)). Then run
   `.inspire/bin/trust.sh stamp <file> --skill face`
   ([trust-stamps](../_references/trust-stamps.md#stamping)); rewriting one that
   carries `endorsed:` is disclosed to the operator first
   ([trust-stamps](../_references/trust-stamps.md#endorsement)).

## Related skills

- `/inspire-screens` — owns a face's screens and `_index.md`; receives the layouts
  and patterns a split brings up.
- `/inspire-process` — owns a face's processes.
- `/inspire-prototype` — one shell per face.
- `/inspire-extract` — reads an existing codebase and emits face and bundle
  candidates.
- `/inspire-bootstrap` — the shape interview delegates each face and bundle here.
- `/inspire-config` — reads each face's and bundle's `package` and `profiles`.
- `/inspire-workspace` — the global pre-PR review runs both validators over the KB.
