# Screens — routes
> Part of [inspire-screens](../SKILL.md). Read when the entry's index routes here.

`routes` renders two derived views and **writes nothing**. Neither view has a home
on disk: both are computed from the screen files every time, because a stored copy
of a derived value is a copy that drifts.

## The route map

One map per face, in face order; within a face, one row per screen, ordered by
module, then screen. `routes {face}` renders that face's map alone. The screens are
every `*.screen.md` under `inspire_kb/01_spec/`; a screen belongs to the face its id
names, whatever directory it sits in.

**Face `admin`** — shell `/admin`

| Screen id | Route | Lifecycle |
|---|---|---|
| `admin.user-detail` | `/admin/users/detail/{id}` | accepted |
| `admin.users-list` | `/admin/users/list` | accepted |

**Face `portal`** — shell `/portal`

| Screen id | Route | Lifecycle |
|---|---|---|
| `portal.users-list` | `/portal/users/list` | draft |

- The **route** is `{shell}/{module}/{screen}`: the screen's declared `module:` and
  `screen:` fields, prefixed by the `shell:` of its face's `{face}.face.md`.
- Every **`path` parameter** the screen declares under `### Parameters` appends
  one segment, in row order: `admin.user-detail` declaring `id` renders
  `/admin/users/detail/{id}`. A record inside a record is two segments, outer
  first. `query` parameters never enter the route; they are listed in the
  transition graph, where they are passed.
- The **id** never enters the route. The face appears once, as the shell, and the
  slug never appears.
- The exact rendering — trailing slashes, index routes, the parameter syntax
  (`{id}` here, `:id` or `[id]` under a profile) and how nested segments
  interleave — belongs to the framework profile. State which profile
  the rendering came from when one is declared.

**Route collisions.** Two screens in one face deriving the same route are a
collision, and the report names both files. Two faces never collide: their shells
differ, and `.inspire/bin/spec-identity.sh` refuses two faces sharing one.
`.inspire/bin/screen-coherence.sh` reports the same fact as a finding, so a
collision fails review whether or not anyone runs `routes`.

## The transition graph

One graph per face. The edges come from the bindings, never from prose:

- every `### Navigation` row — `{source-id} --{key}--> {target-id}`
- every `### Dispatches` outcome of the form `→ [[{screen-id}]]` — labelled with
  the dispatch key and the side it fires on (success or error)

Each edge carries the `param \`{key}\`` tokens written after its link, so the
graph shows what every transition passes. A passed parameter the target does not
declare is a finding `screen-coherence.sh` reports.

Report, in this order:

1. the edge list, grouped by source screen;
2. **unreachable screens** — screens no edge targets, excluding the ones a shell's
   landing route reaches by convention. An unreachable screen is a question for
   the operator, never an error: a route typed by hand is still a route.
3. **dangling targets** — edges pointing at an id no screen declares. These are
   findings, and `wikilinks-resolve` reports them independently. The fix is the
   missing screen, created from its template at `lifecycle: draft`.
4. **cross-face edges** — an edge whose target belongs to another face. A question
   for the operator: a person moving between faces leaves one shell for another,
   and the shared structure usually belongs in a layout or a pattern instead.
5. **unpassed required parameters** — an edge into a screen that declares a
   required parameter the edge does not pass. A question for the operator, never
   an error: a value a profile carries implicitly is still a value, but the spec
   should say so.

Targets are ids. A transition therefore survives every move and rename its target
goes through — which is the whole reason navigation names screens by id rather than
by route.
