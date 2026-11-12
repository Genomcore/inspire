# Faces, bundles and scope (shared reference)

## What this defines

The canonical rules for **faces** and **bundles**: what each one is, where each
declares its packaging, what the `faces:` and `bundles:` fields mean, and how a skill
decides what a given write applies to. Skills that write face- or bundle-scoped
artifacts cite this file instead of restating it. It is the single home for these
rules.

## The two concepts

| Concept | What it is | Its file | Neutral examples |
|---|---|---|---|
| **Face** | An application a person uses: a web portal, a back office, a mobile app | `inspire_kb/01_spec/_faces/{face}/{face}.face.md` | `portal`, `admin`, `mobile` |
| **Bundle** | A headless grouping of actions from one or more modules, published together by one package: an API, an SDK, a library, a backend for a frontend | `inspire_kb/01_spec/_bundles/{bundle}.bundle.md` | `api`, `sdk` |

A face holds its screens, its shell, its tokens, its ADRs and its processes. It
declares the bundles it uses. A bundle names the actions it exposes (whole modules or
single actions), its package and its profiles.

**The domain never says which face or bundle uses it.** A module holds no screens, and
a face holds no domain. A face reaches the domain only through the bundles it
declares, so an entity or action never carries a face or bundle attribute. Exposure
stays on the action: its route, dispatch and guard bindings belong to the action, and
a bundle never redefines them.

A project with screens has at least one face file. A project without screens has
none. There is one shape, and nothing is implicit.

## Each face and bundle carries its own packaging

There is no roster. Each face and bundle declares its own packaging in its own
frontmatter:

| Field | Face | Bundle | Meaning |
|---|---|---|---|
| `id` | yes | yes | the slug; unique among faces, or among bundles |
| `package` | yes | yes | where its code lives, relative to the single `source_root` (see [product-roots.md](product-roots.md)) |
| `profiles` | yes | yes | stack profile ids; omitted means `stack.md`'s |
| `shell` | when two or more faces exist | no prefix | the route prefix for the face's screens, with its leading slash (`/admin`); a project with one face may omit it, so its routes stay `/{module}/{screen}` |
| `bundles` | yes | — | the bundle ids the face's screens use |

A bundle lists its members under `## Actions`: a link to the module hub, `[{module}](../_modules/{module}/{module}.module.md) (whole module)`,
or to one action, `[{module}::{entity}::{action}](../_modules/{module}/_domain/{entity}/{entity}.{action}.action.md)`.

**The set of faces is the set of `*.face.md` files; the set of bundles is the set of
`*.bundle.md` files.** Find them by extension under `inspire_kb/01_spec/`, never by
listing a directory. Nothing indexes them by hand.

The checks across the whole set run as validators, not as prose rules:

- `spec-identity.sh`: ids are unique per type, no user id starts with `_`, no two
  faces share a shell, every id in a face's `bundles:` names a bundle that exists, and
  every bundle declares its `package`.
- `face-exposure.sh`: a screen binds only actions its face's bundles expose.

## The `faces:` and `bundles:` fields — blast radius

An artifact whose placement does not already say its scope declares which faces and
bundles it affects, in frontmatter:

```yaml
---
faces: [portal, admin]   # face ids this artifact affects
bundles: [api]           # bundle ids this artifact affects
---
```

- **Absent means the whole project.** An artifact with neither field binds every face
  and every bundle. There is no `all` value: leave the fields out.
- **Carriers:** global ADRs (under `_adr/`), features, and design-system entries
  (patterns, layouts, components); tickets optionally.
- **No field where placement gives the scope.** A screen belongs to the face whose
  `_screens/` holds it. An ADR or process under a module's or face's directory is
  scoped by that directory. Neither carries `faces:` or `bundles:`.
- **Domain files never carry it.** No `*.entity.md` or `*.action.md` takes `faces:` or
  `bundles:`.
- Each value is the id of a face or bundle that exists: `spec-identity.sh` reports one
  that does not.

## Scope resolution

The rule, for any skill that writes something a face or bundle scopes, and for any
write that must pick a face or a module:

> **An explicit argument wins.** With **exactly one face**, scope resolves silently to
> it and the operator is never asked. Otherwise, if the artifact being touched or the
> conversation does not pin the face (or the module), **ask before writing**. Every
> write states its scope (the frontmatter value, or the face or module directory it
> lands in) in the skill's output.

**Never invent an id.** A face, bundle or module id comes from a file that exists, or
from the operator. When a write links to a face or bundle that does not exist yet, the
link requires its file: create it from `inspire-face`'s template
([face.template.md](../inspire-face/templates/face.template.md) or [bundle.template.md](../inspire-face/templates/bundle.template.md)) with `lifecycle: draft`, and say so in
the output. A missing face or bundle file then always means a broken link, never a
concept nobody wrote down.

## Screens live in their face

A screen is `inspire_kb/01_spec/_faces/{face}/_screens/{slug}.screen.md`. Its id is
`{face}.{slug}`, where `slug` is the file's slug, unique within the face. Each face
has one navigation file, `_faces/{face}/_index.md`.

Global catalogs sit outside every face, in `inspire_kb/01_spec/_design-system/`:
`design-system.md`, `design-system.tokens.json`, `theme.md`, `theme.tokens.json`,
`patterns/`, `layouts/`, `components/`. Face-level tokens sit in the face's directory,
`{face}.tokens.json`.

There are no shared screens. When the same screen appears in two faces, what they
share is its structure: it becomes a layout or a pattern in `_design-system/`, and
each face keeps its own screen.

**A route is derived, never positional.** It comes from the screen's declared
`module:` and `screen:` frontmatter fields, `/{module}/{screen}`, prefixed by its
face's `shell`, which carries its own leading slash: `/admin` gives
`/admin/billing/list`. The face contributes only the shell prefix. The screen's `id`
contributes nothing, so `admin.user-list` (`module: users`, `screen: list`) renders
`/admin/users/list`. `screen:` is a route segment, unique within a module; `slug` is an
identity, unique within the face. They are two things. The exact rendering belongs to
the framework profile, like every other binding convention.

## Reserved ids

A user-chosen id (module, face, bundle, entity, action, process, screen) never starts
with `_`. A leading `_` on a directory means INSPIRE structure (`_modules/`,
`_faces/`, `_screens/` …), and on a file it means navigation (`_index.md`).
`spec-identity.sh` reports a violation as an error.

## Who owns what

| Skill | Its part of this |
|---|---|
| `inspire-face` | owns every `*.face.md` and `*.bundle.md`: the only skill that adds, retires or reviews a face or a bundle |
| `inspire-screens` | owns the screens in a face's `_screens/`, the face's `_index.md`, and the design-system catalog |
| `inspire-adr`, `inspire-feature`, `inspire-task` | stamp `faces:` and `bundles:` on the artifacts they write, when placement does not give the scope |
| `inspire-process` | places a process globally, or under the module or face it belongs to; placement gives its scope |
| the coding stage | resolves a face's or bundle's package and stack from its own file; faces never import each other, sharing flows through bundles and the design system |
| `inspire-prototype` | one shell per face |
| `inspire-workspace` | runs the validators above and reports per-face health |
| `inspire-domain` | owns nothing here, deliberately: the domain never names a face or bundle |
