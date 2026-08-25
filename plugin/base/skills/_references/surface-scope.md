# Surfaces and scope (shared reference)

## What this defines

The canonical rules for **surfaces**: what one is, where a project declares them, and
how a skill decides what a given write applies to. Surface-aware skills cite this file
instead of restating it — it is the single home for these rules.

## The surface concept

A **surface** is a deliverable that faces someone. Three kinds:

| kind | what it is | neutral examples |
|---|---|---|
| `ui` | something a person looks at | `portal`, `admin`, `mobile` |
| `headless` | any service without a face: HTTP API, worker, event consumer | `api` |
| `lib` | any shared package: ui-kit, shared types/contracts, SDK | `ui-kit`, `contracts` |

A suite may declare several of each. What a suite never has is several domains:
**one domain truth spans all surfaces** — one module registry, one `04_domain` tree.
*Where* a capability is realized is emanation, resolved downstream from the roster,
not authored spec.

A project that declares no surfaces is a **suite-of-one**: a single implicit surface,
and a KB identical to one written before surfaces existed. Every project is a suite;
most are suites of one.

## The layer↔kind pairing

Each SDD layer already carries the exposure story for its own kind of surface, which
is why no layer needs a second scoping axis bolted onto it. `05_screens` projects the
product onto **UI** surfaces — UIs re-present the same capabilities as genuinely
different content, so screens split positionally (below). `04_domain` projects onto
**service** surfaces: the domain *is* the API's spec, and UIs consume it through
services rather than directly, so the domain needs no UI tags. Where several services
own capabilities, the partition between them is an ADR decision, module-granular
("the admin service serves `tenancy` and `quotas`; the platform service serves the
rest") — never action-granular. The catalogs (`patterns/`,
`components/`, contracts) project onto **`lib`** surfaces.

## The roster

Surfaces are declared in exactly one place: `inspire_kb/00_bootstrap/surfaces.md`,
owned by `inspire-surface`. It is authored, never seeded — it comes into existence
when a second surface is declared, at which point the previously implicit surface is
named too. No roster means suite-of-one.

Surface ids come from the roster or they do not exist. **Never invent a surface id.**
When the id a write needs is not in the roster, stop and ask.

## The `surfaces:` field — blast radius

Artifacts that *span* surfaces declare which ones they affect, in frontmatter:

```yaml
---
surfaces: [portal, admin]   # list of roster ids — this artifact's blast radius
# or
surfaces: all               # explicitly suite-wide
---
```

- **Absent means suite-wide.** Every artifact written before the suite existed stays
  correct, forever. Review may nudge a backfill; it never blocks on one.
- Once 2+ surfaces are declared, **new** spanning artifacts must carry the field
  explicitly — `all` spelled out, never silently omitted. Being declared is the whole
  point of the field.
- **Spanning kinds:** ADRs, features, pattern and component entries; tickets
  optionally.
- **Domain files never carry it.** Nothing under `04_domain/` takes `surfaces:`.
- **Screens never carry it either** — a screen's surface is positional. Their
  frontmatter carries identity and lifecycle (`id` · `module` · `screen` ·
  `lifecycle`) and no `surfaces:` field. The one exception is the optional
  narrowing list on a `05_screens/shared/` screen.

## Scope resolution

The rule, for any skill that writes something a surface owns:

> An explicit surface argument wins. In a suite-of-one, scope resolves silently to the
> implicit surface — the operator is never asked. With 2+ surfaces and no argument, if
> the artifact being touched or the conversation does not pin the surface, **ask
> before writing**. Every write states its scope (frontmatter value or target surface
> tree) in the skill's output.

## Screens are positional

The shape of `05_screens/` is deterministic from the roster — specifically from the
count of `kind: ui` entries, never from history:

| `kind: ui` entries | shape |
|---|---|
| roster absent, or 1 | `05_screens/{module}/{screen}.md` — the flat layout, unchanged |
| 2 or more | `05_screens/{surface}/{module}/{screen}.md` — surface-first |

`shared/` is a reserved pseudo-surface holding screens used by more than one UI
surface: `05_screens/shared/{module}/{screen}.md`, meaning all UI surfaces unless a
`surfaces:` list narrows it. Suite-wide catalogs — `design-system.md`, `patterns/`,
`components/` — sit beside the surface trees at top level, never inside one.

**A route is derived, never positional.** It comes from the screen's declared
`module:` and `screen:` frontmatter fields — `/{module}/{screen}` — prefixed by
that surface's `Shell` value from the roster, which carries its own leading slash:
`/admin` gives `/admin/billing/list`. The **surface contributes only the shell
prefix**; the screen's `id` contributes nothing at all, so a collision-minted
`admin.users.list` (`module: users`, `screen: list`) still renders `/users/list`
under the admin shell, with no doubled surface segment. The exact rendering belongs
to the framework profile, like every other binding convention.

For a screen minted the default way the derived route still mirrors its location,
which is why the two read as symmetric — but the derivation runs from the declared
fields, and only from them. Nothing in a screen file authors a route, so a route
and a location cannot disagree, and moving a screen between surface trees changes
its shell prefix and nothing else: same id, same claims, same file.

Walking one surface's tree is still walking that surface end to end. A flat
`{module}/` directory sitting beside surface trees is a pre-split leftover, not a
second convention.

## Reserved ids

`shared`, `all`, `patterns` and `components` are **forbidden as roster ids**. Each
already means something else on the very axis a roster id is read against: `shared` is
the screens pseudo-surface, `all` is the suite-wide `surfaces:` value, and `patterns`
/ `components` are catalog directories beside the surface trees — so a roster entry
using one would make a path or a field value ambiguous.

## Who owns what

| Skill | Its part of this |
|---|---|
| `inspire-surface` | owns `surfaces.md` — the only skill that adds or retires a surface, and the diagnostic for roster coherence |
| `inspire-screens` | owns the shape of the screens tree: the right surface directory, created lazily |
| `inspire-adr`, `inspire-feature`, `inspire-task` | stamp `surfaces:` on the artifacts they write |
| `inspire-code` | resolves the target surface's package and profiles from the roster; surfaces never import each other, sharing flows through `lib` packages |
| `inspire-prototype` | one shell per UI surface, behind the suite landing |
| `inspire-workspace` | checks every `surfaces:` value resolves to a roster id, and reports per-surface health |
| `inspire-domain` | owns nothing here, deliberately — the domain is the layer surface scoping never touches |
