# ADR — Suites and surfaces: one domain, many deliverables

- **Status:** Accepted — 2026-08-05 (shipped in 0.5.0)
- **Builds on:** [[adr-plugin-delivery]] **D4e** (the KB is `inspire_kb/`, visible and
  the operator's). Upholds [[adr-upgrade-path]] **D10** (the KB is additive in both
  init and update) — this ADR adds no delete outcome to it and no layout hop.
- **Scope:** How a product delivered through several UIs and/or several services is
  represented in one knowledge base. The second scoping axis of the KB, what carries
  it in each layer, and what happens to a project that never uses it. Not deployment
  topology, not multi-tenancy, not a second knowledge base.

---

## Context

INSPIRE's shape assumed one "app": one API, optionally one UI. Real products are often
**suites** — one product delivered through several UIs and/or several services: a
use-case console beside a control-plane admin console, a web app with a companion
mobile one, a platform service beside an admin service.

The KB had exactly one scoping axis, the module, and five hard singletons that each
encoded the assumption from a different direction:

1. one `design-system.md`;
2. scalar `source_root` / `prototype_root`;
3. one flat `profiles:` list in `stack.md`, disambiguated by layer — which stops working
   the moment there are two frontends;
4. one module-keyed screen namespace, with a global `/{module}/...` route rule;
5. one flat module registry.

The consequence was not that suites were hard to express. It was that they could not be
**declared**: an operator had no way to say — and no way to see — whether a decision, a
feature or a pattern applied to one piece of the system or to all of it. Every artifact
was implicitly system-wide, which is correct exactly while the system is one app.

The trap in fixing this is to make "suite" a mode. A mode splits every skill in two,
doubles what has to be verified, and asks a project to migrate at the moment it grows —
which is the worst possible moment.

## Decisions

Decision numbers are scoped to this ADR. A reference to another ADR's decision is
always qualified.

### D1 — One domain, many surfaces

A suite shares **one domain truth**: one module registry, one `04_domain` tree. What
multiplies is the **surface** — a deliverable that faces someone. Three kinds:

| kind | what it is |
|---|---|
| `ui` | something a person looks at |
| `headless` | any service without a face: HTTP API, worker, event consumer |
| `lib` | any shared package: ui-kit, shared types/contracts, SDK |

A suite may declare several of each, and a module may be surfaced in several surfaces.

The domain layer is **never touched** by surface scoping. It is a pure capability
descriptor; *where* a capability is realized is emanation, resolved downstream by
`inspire-code` from the roster, not authored spec. No exposure maps, no `surfaces:` on
domain files, no validator changes. This is the load-bearing half of the decision: it
is what keeps a suite from costing a second knowledge base.

The kinds are `ui` · `headless` · `lib`, and deliberately **not** `api`. A worker and
an event consumer are the same thing as an HTTP API for every purpose this axis serves
— they own capabilities and have no face — and naming the kind after one transport
invites a fourth kind per transport.

### D2 — Single-app is the degenerate suite, and its KB is byte-identical

Every project is a suite. A project that declares no surfaces is a **suite-of-one**: a
single implicit surface, a KB indistinguishable from one written before surfaces
existed, and sessions identical to today's.

There is one mental model, not two. No modes, no branching in the skills beyond "is
there a roster", no migration triggered by an upgrade. This is what makes the axis free
for the projects that never need it, and it is why the roster is **authored, never
seeded** — a file that ships in the skeleton would make every project a multi-surface
project on paper.

### D3 — Two scoping tools, chosen by the artifact's relationship to surfaces

Artifacts that *span* surfaces declare a **blast radius** in frontmatter: `surfaces:`,
a list of roster ids or `all`. Spanning kinds are ADRs, features, pattern and component
entries, and — optionally — tickets. **Absent means suite-wide**, so every artifact in
every existing project is correct by default, forever; once 2+ surfaces exist, new
spanning artifacts must spell the value out, because being declared is the entire point
of the field.

Screens do not span. A screen belongs to a UI surface constitutively — a "blast radius"
whose value is always exactly one is an **identity, not a scope**. Identities in this KB
are positional (the module already is), so screens split by directory:
`05_screens/{surface}/{module}/{screen}.md`, once 2+ UI surfaces exist. Surface-first
ordering preserves path↔route symmetry (`admin/billing/list.md` ↔
`/admin/billing/list`) and makes walking one surface's tree the same act as walking that
app. A reserved `shared/` pseudo-surface holds screens more than one UI surface uses;
the suite-wide catalogs (`design-system.md`, `patterns/`, `components/`) sit beside the
surface trees, never inside one.

Positional scoping also removes a class of problem rather than handling it: two surfaces
can both have `billing/list` and no collision is possible, so no filename suffix
convention is needed.

Scope resolution is one rule, defined once in `_references/surface-scope.md` and cited
rather than restated by every skill that writes: an explicit argument wins; a
suite-of-one resolves silently; with 2+ surfaces and nothing pinning the scope, the
skill **asks before writing**. Every write states the scope it used.

### D4 — Each layer already carries the exposure story for its own kind of surface

This is why no layer needs a second axis bolted onto it, and it is the reason D1 works.

`05_screens` projects the product onto **UI** surfaces. UIs *re-present* the same
capabilities as genuinely different content, so screens split positionally (D3).

`04_domain` projects onto **service** surfaces — the domain *is* the API's spec. UIs
consume the domain *through* services and never directly, so the domain needs no UI
tags, and authority always passes through a service (offline mobile execution syncs back
to one). Where several services own capabilities, the partition between them is a
decision, recorded as an **API-partition ADR**: module-granular ("the admin service
serves `tenancy` and `quotas`; the platform service serves the rest"), `surfaces:`
naming the capability-owning services, overlap allowed.

The partition is **free** — from one service serving everything, which needs no ADR at
all, up to one service per module. It is a deployment-topology choice, never a knowledge
change, which is precisely why several services cost the KB nothing. Two guard rails
keep it that way:

- **Action-granular partition pressure is a modularity smell.** One module's actions
  wanting to live in two different services means the module is wrong. Split the module;
  do not tag actions.
- **BFFs are adapters, not capability owners.** They consume the domain and never appear
  in a partition.

The catalogs (`patterns/`, `components/`, contracts) project onto **`lib`** surfaces.

### D5 — One suite design system: extensions yes, variance named and central, overrides never

`design-system.md` stays a strict singleton and the suite-wide source of truth. The
stance separates four things that "let a surface adapt the design system" normally
conflates:

- **Extension** — surface-only vocabulary, such as a data grid only the admin console
  uses. Welcome and cheap: a `patterns/` or `components/` entry scoped `surfaces: [...]`.
  Nothing shared is redefined, so there is no shadowing and no reconciliation cost.
- **Variance** — platform and context fit: mobile density, touch targets, admin data
  density. Real needs, handled as **named variant axes the suite system defines and a
  surface selects** — the way mature systems already do density and dark mode — written
  as clearly-marked per-surface sections *inside* the one file. Visible, reviewable and
  countable; workspace review reports their count and size as a drift signal.
- **Override** — a surface redefining, from its own side, what a shared token or
  component means. **No channel exists, deliberately.**
- **Divergence** — a surface that is really its own brand. The honest form is a declared
  fork (a future `design_system: suite | own` roster field), not a shadow. Noted as an
  escape hatch and out of scope now; nothing forces it yet.

The no-override position is evidence, not purity. A previous attempt at per-consumer
overrides inverted in practice: every change, and every new component, became a design
system change **plus** an override in each consumer — the opposite of the decoupling it
was adopted for. Shadowing creates N sources of truth per name, and in INSPIRE the cost
compounds, because agents consume the design system to emanate code: `inspire-code`
would have to answer "which spec wins?" per surface, and the `lib` package would need a
per-surface theming layer to match. The autonomy that justifies overrides elsewhere —
routing around a design-system committee — barely exists in a single-operator vault.
What is left of the gain is diverging without suite visibility, which is the failure
mode itself.

Materialize's design-system seeding, the workspace assertion and bootstrap's ownership
of the file are all untouched by this.

### D6 — One prototype, one shell per UI surface, a suite landing

`prototype_root` stays scalar and there stays exactly one running artifact. With 2+ UI
surfaces it hosts one shell per UI surface behind a **suite landing** — a branded entry
that presents the suite as one product and routes into each shell — so the whole suite
remains walkable in a single browse, which is the horizontal prototype's entire purpose.

By default the landing is **prototype chrome**: derived from the roster (display names,
kinds, shell links), kept in sync by `inspire-prototype`, rendered under the suite design
system. It is scaffolding, not product. If the product genuinely ships a launcher, that
launcher is specced as an ordinary screen — typically under `shared/` — and replaces the
chrome. Mobile surfaces mock as framed web shells.

### D7 — The roster is one file, owned by one skill

Surfaces are declared in `inspire_kb/00_bootstrap/surfaces.md` and nowhere else. Ids come
from the roster or they do not exist; `shared`, `all`, `patterns` and `components` are
forbidden as ids, each because it already means something on the very axis a roster id is
read against.

The file is owned by a new housekeeping skill, **`inspire-surface`** — the symmetry is
the point: modules are one first-class axis and have `inspire-module`; surfaces are the
other. (Owning a `00_bootstrap` file from outside `inspire-bootstrap` follows the
existing precedent — bootstrap owns `05_screens/design-system.md`.) Three subcommands:
`add`, `retire`, `review`.

`add` recognizes three **arrival shapes**, because a surface's origin determines all the
work: *greenfield* starts empty; *split* starts full of another surface's screens and
runs an operator-classified sweep (stays / moves / both) that performs the physical moves
and route re-prefixing; *adopt* delegates to `inspire-extract` against the joining
codebase. `retire` is the reverse sweep — everything scoped solely to the retiring
surface gets an explicit disposition, and the roster entry is removed last. `review` is
the roster's diagnostic: unique ids, no reserved ids, packages present, shells unique.

Nothing is ever reclassified, moved or deleted silently, in either direction. Every
`add` and `retire` ends by proposing an ADR with `surfaces: all`, because a change to the
suite's shape is system-wide by definition.

### D8 — `inspire-code` becomes monorepo-aware through the roster

Four behaviors, all reading the same roster:

1. **Resolution** — it determines which surface it is emanating into (from the target
   path under `source_root`, or an explicit argument) and loads that surface's
   `profiles`, falling back to the global list. This *replaces* by-layer profile
   disambiguation, which breaks outright with two frontends.
2. **Lazy scaffolding** — on first emanation into a surface whose `package` does not
   exist, it scaffolds it at the roster path, and the workspace manifest itself on first
   need. `inspire-surface add` records the path; `inspire-code` makes it real.
3. **Per-package build and verify** — profile guidance gains monorepo command scoping, so
   `tdd` and `fix-build` run the surface's commands rather than the whole workspace's.
4. **Dependency discipline** — surfaces never import each other. Cross-surface sharing
   flows through `lib` packages, and `review` checks import boundaries against the roster.

`source_root` stays scalar throughout: a suite is one repository with several packages,
not several roots.

### D9 — The upgrade posture is additive only

`materialize.sh` is untouched — no new flags, no lock change, no seeding of the roster,
no change to design-system seeding. The validators are untouched **as an explicit
decision**: they are `04_domain`-scoped, and the domain is exactly the layer suites never
touch (D1). Roster resolution and tree-shape checks are judgment-side, in workspace and
surface review, not new validator scripts. There is no layout hop, because the runtime
moves nothing.

The one KB reshaping this design contains — the flat-to-split screens move — is performed
by a skill, at promote time, with the operator's consent, entry by entry. `/inspire:update`
never learns that suites exist. This is the same principle as `adr-upgrade-path` D10 read
from the other side: the upgrade machinery does not restructure the operator's knowledge,
so a reshaping that genuinely needs judgement belongs to a skill, not to a hop.

The only mechanical change in the release is `session-start.sh` injecting a one-line
roster when `surfaces.md` exists, which follows the existing guard-if-absent pattern and
ships through the normal manifest three-way merge.

---

## Alternatives considered and rejected

**Per-surface exposure maps or binding registries in the domain layer.** Rejected per D1.
APIs are emanated content; the domain stays a pure capability descriptor. A map of which
surface exposes which action is a second copy of something the roster and the code
already answer, and it would drift.

**Two explicit operation modes, `app` and `suite`.** Rejected per D2. Two modes double
the surface area of every skill and force a migration exactly when a product is busy
growing. One model, whose degenerate case is today's, costs nothing.

**Frontmatter-scoped screens with dotted collision suffixes (`list.admin.md`).** Rejected
per D3 — a screen's surface is an identity, not a blast radius. Positional scoping matches
the KB's existing convention for identities and makes collisions impossible rather than
naming them.

**`module/surface/screen` ordering.** Rejected. It breaks path↔route symmetry and scatters
"walk the admin app" across every module directory. Module-centric navigation is already
served by the module hub, which indexes its slices across layers.

**Design-system overlay or override files per surface.** Rejected on evidence, per D5.
Each legitimate need such a channel serves is captured without shadowing — extension via
scoped catalog entries, variance via named axes inside the one file, divergence via a
declared fork. The residual is invisible divergence, which is the failure mode, so no
channel exists for it.

**Generated per-surface indexes.** Rejected as a standing drift source. The workspace
per-surface lens covers browsing without a file that can go stale.

**Session-level "working surface" state.** Rejected: the mode outlives the intent, and a
write silently attributed to yesterday's surface is worse than being asked. Explicit
arguments plus declared scope instead.

**New validator scripts for surface checks.** Rejected per D9. The validators are a
`04_domain`-scoped, non-extensible library, and surface checks are judgement.

---

## Consequences

**Good.**

- A suite is expressible without a second knowledge base: one module registry, one domain
  tree, one design system, one prototype, one tracker.
- Existing projects are unaffected in every observable way — no roster, no field, no tree
  change, no new prompts.
- Scope becomes visible. "Which parts of the system does this decision touch?" has an
  answer in the artifact, rather than in whoever remembers.
- Multiple services cost the KB nothing, because the partition between them is a topology
  decision recorded in one ADR rather than a shape imposed on the domain.
- Shared components grow honestly: the same screen appearing in two surface trees *is* the
  cross-surface evidence `inspire-screens extract` promotes on, so a component reaches
  `surfaces: all` because it was used that way, not because someone declared it shared.

**Accepted costs.**

- **The screens split is a real reshaping of the operator's KB.** It happens once, under
  consent, but it moves files and rewrites routes in specs and prototype shells. It is the
  one moment in this design where something large happens at once.
- **Two shapes of `05_screens/` exist**, and which one is correct is derived from the
  roster's `kind: ui` count rather than from history. A flat `{module}/` directory sitting
  beside surface trees is a leftover, and only review will say so.
- **Blast radius is unverifiable by machine.** Nothing checks that an artifact's
  `surfaces:` list is *true* — only that its values resolve to roster ids. A wrong list is
  a judgement error that review may catch and a validator never will.
- **Legacy artifacts read as `all` forever.** That is the correct default and it is also
  indistinguishable from "nobody has thought about it yet". Backfill is nudged, never
  forced.
- **Variance sections concentrate in one file.** Keeping per-surface variance inside
  `design-system.md` is what makes it reviewable; it also means that file grows with the
  suite. Its count and size are reported as a drift signal precisely because the failure
  mode here is a design system that has quietly become four.
- **No override channel means a genuinely divergent surface has no answer today** beyond
  the extension and variance channels. The declared fork is designed and not built.
- **A suite does not become a single app again by retiring back to one surface.** The
  roster stays, and the screens tree is not collapsed as a side effect — `retire` names
  the consequence and hands the reshaping to `inspire-screens`. Silently restructuring a
  tree is exactly what D7 forbids, so the asymmetry is deliberate: growing into a suite
  and shrinking out of one are both operator-driven, and neither is automatic.

## Staging

Built here: the surface concept and its shared reference, the roster and `inspire-surface`,
the `surfaces:` field across the spanning kinds, the positional screens tree and its split
sweep, the API-partition pattern, per-surface variance in the design system, suite shells
plus the landing, the monorepo-aware coder, the per-surface workspace lens, surface
candidates out of extract, and the roster line in `session-start`.

Not built, and deliberately out of scope:

- **The declared design-system fork** (`design_system: suite | own`) — D5's divergence
  channel. Nothing forces it yet, and building an escape hatch before anyone needs it
  fixes its shape to a guess.
- **Machine-checkable blast radius.** Whether an artifact's declared surfaces match what it
  actually affects is judgement today, in review. It may never be more than that.
- **Reporting stale route and path references after a split.** The split sweep re-prefixes
  the routes it knows about — screen specs and prototype shells — but an operator's prose,
  tickets and source may still name the pre-split path. This is the same gap
  `adr-upgrade-path` records for the KB root rename, on a different mover.
