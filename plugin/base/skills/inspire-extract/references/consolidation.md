# Consolidation & cross-linking (the synthesis)

Phase 2. The four scanners return independent slices; consolidation does the work
**no single scanner can** — correlate across seams, derive features, cluster
modules, faces and bundles, and reconcile duplicates into one coherent candidate manifest. This step is
**judgment-heavy** and runs in the orchestrator (or a dedicated synthesizer agent
under the Workflow option). Its output is what the operator reviews in Phase 3.

## 1. Cross-link B ↔ C — the traceability graph

The core correlation. For each **screen** (scanner B), resolve its `data_refs`
(endpoint/query hints) against the **endpoints** scanner C recorded for each action,
and build the graph:

```
screen  →  action(s)  →  entity(ies)  →  field(s)
```

This is the operator's "*this screen uses this API and these fields*". Record it per
screen so the review shows, at a glance, what each view actually touches. Matching
is heuristic — an unresolved `data_ref` is a **gap** to surface (a screen calling an
endpoint no action explains, or an action no screen consumes), not something to hide.

## 2. Derive features (`*.feature.md`)

Features are **not** scanned; they emerge here. A **coherent flow** across a screen,
the action(s) it triggers, and the entity/fields involved *is* a candidate use case.

- **UI-driven feature.** One screen's primary flow (e.g. "issue an invoice" = the
  invoice form → `billing::invoice::create` → `invoice` written) → one feature. Its
  candidate `## Actor` comes from the auth/permission gate scanner C saw on the
  endpoint; its flow from the screen + action sequence.
- **Backend-only feature.** A significant action path with no screen that someone
  still starts (a webhook a partner calls, an internal API) is still a feature —
  mark it "No UI expected".
- **Not a feature: a process.** A path nobody starts — a scheduled job, a start-up
  task, a reaction to an event — is a **process candidate** (`processes_inferred`):
  its trigger, the actions it calls, the entities they touch. It hands off to
  `/inspire-process create`.
- **Not a feature.** Infra plumbing (health checks, migrations, internal wiring).
- **Group, don't fragment.** Several endpoints serving one user goal are one feature,
  not one-per-endpoint.

Each derived feature records the screen(s) + action(s) that realize it — that
linkage is exactly what the authoring order needs (feature first, then screen refs
it, then action back-sources to it).

## 3. Infer modules

Cluster the cross-linked artifacts into **modules** — the organizing unit for every
layer. Signals, in rough priority:

- Source folder / package boundaries (`src/billing`, `apps/*`, a monorepo package).
- API path prefixes (`/api/billing/*`).
- Bounded contexts / DDD context maps if present.
- Cohesion in the traceability graph — screens+actions+entities that only reference
  each other belong together.

Propose each module: `{slug, prefix, members[]}`. Modules are scaffolded via
`/inspire-module create` at authoring time, not here.

### Faces and bundles

The deployable boundaries answer a separate question — how the product reaches
people and other systems — and never re-cut the modules.

- **Each UI app scanner B found is a face candidate** (`faces_inferred`): id from
  its directory name, `package` (its path relative to the source root), `profiles`
  (from scanner A), `shell` (its shared route prefix). Its screens become that
  face's screen candidates, each with id `{face}.{slug}`. Two apps whose screens
  have the same slug keep both: a slug is unique within one face only.
- **Each service scanner C found is a bundle candidate** (`bundles_inferred`): id,
  `package`, `profiles`, and its actions — the actions whose `service` it is. When
  it serves every action of a module, list the module (`(whole module)`) instead of
  each action. A library with its own build is a bundle with its own artifact; a UI
  kit is a design-system candidate instead.
- **A face's `bundles:`** are the bundle candidates that serve the endpoints its
  screens' `data_refs` resolve to.
- **No service at all** (a monolith that renders its own views) still yields one
  bundle candidate, with the modules its views reach, so every face has a bundle to
  name.

Which actions belong to which bundle is the operator's decision in Phase 3. The
deployable layout is evidence for a grouping, never the decision.

## 4. Bootstrap verdicts (fold in A & D)

Run the stack (A) and styles (D) elaboration signals through
[`bootstrap-comparison.md`](bootstrap-comparison.md) and attach a
**migrate / keep** verdict per artifact (`stack.md`, `design-system.md`), with the
ADR flag for any load-bearing change. Never seed downward from a throwaway source.

## 5. Global reconciliation

Collapse artifacts seen by more than one scanner or slice into a single candidate:

- An entity in both DB schema and a validator → one entity, merged fields, conflicts
  flagged.
- A screen and its server template → one screen.
- A pattern/component proposed by B that maps to a real data shape from C → note the
  data binding on the pattern.
- Merge each scanner's intra-seam `consolidations` into the manifest so the review
  can act on them (extract a shared pattern/component, pick a canonical action set,
  adopt a token role).

Deduplicate by `(kind, proposed_id)`; when two candidates collide, keep the
higher-confidence one and record the other as an alias/evidence source.

## Output

The unified candidate manifest (schema in [`manifest-format.md`](manifest-format.md)):
per-module groupings of derived features, screens, entities, actions, and
pattern/component candidates; the face, bundle and process candidates; the
traceability graph; the bootstrap verdicts; and a
**gaps** list (unresolved cross-links, orphan actions, screens with no feature,
conflicts). Nothing here is authored — Phase 3 narrows it, Phase 4 delegates it.
