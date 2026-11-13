# Faces and bundles — on-disk format

Two file types, authored by `/inspire-face` and by nothing else:

| Type | File | Where | Id |
|---|---|---|---|
| Face | `{face}.face.md` | `inspire_kb/01_spec/_faces/{face}/` | `id:` (`{face}`) |
| Bundle | `{bundle}.bundle.md` | `inspire_kb/01_spec/_bundles/` | `id:` (`{bundle}`) |

Tools find them by extension, anywhere under `inspire_kb/01_spec/`, and never by
directory. The set of faces is the set of `*.face.md` files; the set of bundles is
the set of `*.bundle.md` files. Nothing else lists them.

This file defines their **shape** only. What `faces:` and `bundles:` mean on other
artifacts, and how a skill resolves scope, live in
[`.claude/skills/_references/face-scope.md`](../../_references/face-scope.md).

## Face

### Worked example

```markdown
---
id: portal
package: apps/portal
profiles: [react]
shell: /portal
bundles: [api]
lifecycle: accepted
---

# Face: Customer portal

Customers use the portal to place and track their orders. It shows only their
own organisation's data; the back office is a separate face.
```

### Frontmatter

| key | form | required | default |
|---|---|---|---|
| `id` | kebab slug, unique among faces, never starting with `_` | yes | — |
| `package` | path **relative to the single `source_root`** | yes | `apps/{id}` |
| `profiles` | bracketed list of stack profile ids, `[react]` | no | the global `profiles:` in `00_bootstrap/stack.md` |
| `shell` | prototype and application route prefix, leading slash | no | none: the face's routes take no prefix |
| `shell_layout` | the id of the layout entry that is this face's shell | no | `shell` |
| `bundles` | bracketed list of bundle ids this face's screens use | yes, once a screen binds an action | — |
| `lifecycle` | `draft` · `accepted` · `stable` · `superseded` | yes | `draft` |

- **id** — the same token everywhere: the face's directory, the first segment of
  every screen id in it (`{face}.{slug}`), and `faces:` values on global artifacts.
- **package** — relative to `source_root`, which stays a single scalar (see
  [`_references/product-roots.md`](../../_references/product-roots.md)). Write it
  even when it matches the default, so the emanation target is readable without
  knowing the default. The file records the path; it does not create the directory.
- **profiles** — omit it and the face inherits the project's global list. Present,
  it replaces that list for this face; it does not extend it.
- **shell** — unique among faces. A screen's route is `{shell}/{module}/{screen}`,
  from the screen's own `module:` and `screen:` fields. A project with one face may
  omit it, and that face's routes take no prefix. With two or more faces, each one
  declares a shell: two faces without one would derive the same routes.
- **shell_layout** — the layout entry that frames this face's routes. One face
  keeps the default, `shell.layout.md`. With several faces, each names its own
  entry, and that entry lists the face in `faces:`: a shell binds its face's
  store and bundles, so one entry cannot be the shell of two faces that bind data.
  `spec-identity.sh` checks that the layout exists.
- **bundles** — every id names an existing `{bundle}.bundle.md`. A screen of this
  face binds only actions these bundles expose (`face-exposure.sh`).

### Body

An `# Face: {Display name}` heading and one paragraph: who uses this face, for
what, and how it differs from the project's other faces. No route table, no screen
list: a search for `*.screen.md` under the face's directory gives the screens, and
the face's `_index.md` (owned by `inspire-screens`) carries its navigation prose.

A face has **no claims of its own**. Its screens do.

### Beside the face file

```
_faces/{face}/
  {face}.face.md
  {face}.tokens.json      # optional: tokens of this face only
  _index.md               # navigation prose (inspire-screens)
  _adr/                   # decisions that bind this face only (inspire-adr)
  _screens/               # {slug}.screen.md (inspire-screens)
  _processes/             # {process}.process.md (inspire-process)
```

## Bundle

### Worked example

```markdown
---
id: api
package: apps/api
profiles: [nestjs]
lifecycle: accepted
---

# Bundle: api

The platform API. Every face calls it; partners call it with their own keys.

## Actions

- [orders](../_modules/orders/orders.module.md) (whole module)
- [billing::invoice::close](../_modules/billing/_domain/invoice/invoice.close.action.md)
```

### Frontmatter

| key | form | required | default |
|---|---|---|---|
| `id` | kebab slug, unique among bundles, never starting with `_` | yes | — |
| `package` | path relative to `source_root` | yes (`spec-identity.sh` warns without it) | `apps/{id}` |
| `profiles` | bracketed list of stack profile ids | no | the global `profiles:` in `00_bootstrap/stack.md` |
| `lifecycle` | `draft` · `accepted` · `stable` · `superseded` | yes | `draft` |

**No version.** The id is `api`, never `api@v1`, and no field carries one. The
specification does not change when a new version of the package is published.

A bundle has no `shell`: it is not something a person navigates.

### Body

- `# Bundle: {id}` and one paragraph: what the bundle exposes, and to whom.
- `## Actions` — one entry per line, each either
  - a whole module: `[{module}](../_modules/{module}/{module}.module.md) (whole module)`, or
  - one action: `[{module}::{entity}::{action}](../_modules/{module}/_domain/{entity}/{entity}.{action}.action.md)`.

  Every link names an existing module or action file; a missing one is created as a
  draft from its template before the bundle is written. Which actions go here is a
  specification decision, made from the use cases.

**Exposure stays on the action.** An action's route, dispatch and guard come from
its own bindings. A bundle lists which actions it publishes; it never redefines a
route or adds a binding.

### Claims

- **A bundle that only groups actions has exactly one claim,
  `{bundle}/mount/every-action`**: a test that starts the bundle's application and
  checks that it exposes every action listed. Its payload is the sorted list of
  member action ids plus the `package`, so adding an action makes this one claim
  stale and nothing else. Its body is the paragraph and `## Actions`, and nothing
  more.
- **A bundle that produces its own artifact** — an SDK, a library, a backend for a
  frontend — has code of its own. Its body adds sections that describe what that
  code does, and those are its further claims.

## Defects

Write only fields that exist. An omitted optional field means "the default"; an
empty one means nothing and is a defect. A `design_system` field on a face is not
supported: the design system in `_design-system/` serves every face, and a face's
own tokens go in `{face}.tokens.json`.
