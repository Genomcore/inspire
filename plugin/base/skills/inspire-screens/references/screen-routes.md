# Screens — routes
> Part of [inspire-screens](../SKILL.md). Read when the entry's index routes here.

`routes` renders two derived views and **writes nothing**. Neither view has a home
on disk: both are computed from the screen files every time, because a stored copy
of a derived value is a copy that drifts.

## The route map

One row per screen, ordered by surface, then module, then screen:

| Screen id | Surface | Route | Lifecycle |
|---|---|---|---|
| `users.list` | portal | `/portal/users/list` | accepted |
| `admin.users.list` | admin | `/admin/users/list` | draft |

- The **route** is `/{module}/{screen}` from the screen's declared `module:` and
  `screen:` fields, prefixed by that surface's roster `Shell` value when the suite
  declares two or more UI surfaces. In a suite-of-one there is no prefix.
- The **id** never enters the route. A collision-minted `admin.users.list` still
  renders `/users/list` under the admin shell — the surface segment appears once,
  as the shell, or not at all.
- A `shared/` screen renders **one row per shell that serves it**: the same spec,
  reachable at each shell's prefix.
- The exact rendering — trailing slashes, index routes, parameter syntax for a
  detail screen's record — belongs to the framework profile. State which profile
  the rendering came from when one is declared.

**Route collisions.** Two screens deriving the same route in the same shell are a
collision, and the report names both files. Two screens in different surface trees
deriving the same path are not a collision: their shells differ.
`.inspire/bin/screen-coherence.sh` reports the same fact as a finding, so a
collision fails review whether or not anyone runs `routes`.

## The transition graph

The edges come from the bindings, never from prose:

- every `### Navigation` row — `{source-id} --{key}--> {target-id}`
- every `### Dispatches` outcome of the form `→ [[{screen-id}]]` — labelled with
  the dispatch key and the side it fires on (success or error)

Report, in this order:

1. the edge list, grouped by source screen;
2. **unreachable screens** — screens no edge targets, excluding the ones a shell's
   landing route reaches by convention. An unreachable screen is a question for
   the operator, never an error: a route typed by hand is still a route.
3. **dangling targets** — edges pointing at an id no screen declares. These are
   findings, and `wikilinks-resolve` reports them independently.

Targets are ids. A transition therefore survives every move, rename and surface
split its target goes through — which is the whole reason navigation names screens
by id rather than by route.
