# Feature — review
> Part of [inspire-feature](../SKILL.md). Read when the entry's index routes here.

## Subcommand: review

### Single feature mode

Reviews one feature across all layers. Runs inline (no agents).

1. **Locate the feature.** Find the use-case file in
   `inspire_kb/03_features/{module}/`. Read: description, actor/personas,
   dependencies, priority, state, ADRs referenced. Identify the module from the
   folder.
2. **screen spec coverage.** Search each screen's `**Features:**` line for this
   feature ID; cross-reference the screen spec `_index.md` coverage table. Where to
   look follows the shape of the screens tree, which
   [`_references/surface-scope.md`](../../_references/surface-scope.md) keys to the
   roster: `inspire_kb/05_screens/{module}/` while the suite has at most one UI
   surface; `05_screens/{surface}/{module}/` plus `05_screens/shared/{module}/`,
   walked once per UI surface in the feature's blast radius, once it has two or
   more. Flag if no screen covers a UI-facing feature — per surface, since a
   feature can be covered in one and uncovered in another; note "No UI expected"
   for backend/infrastructure features.
3. **Prototype coverage.** For each covering screen, verify it is reflected in the
   horizontal prototype at the project's prototype root (`/prototype` by default;
   resolve `prototype_root` per
   [`_references/product-roots.md`](../../_references/product-roots.md), and report
   the layer `N/A` when it is `none`) — under the shell of the surface whose tree
   the screen sits in, a `shared/` screen under every shell that serves it, once
   the prototype runs one shell per UI surface — and note drift (pending component
   adoption, hardcoded data, ADR gaps). Insights land in the specs / screens /
   ADRs, not a prototype learnings file.
4. **Specs (SDD) coverage.** Find action descriptors whose `## Purpose` wikilinks back
   to this feature. Search `inspire_kb/04_domain/**/*.md` for `[[{feature-id}]]`.
   Flag if zero realizing actions exist. For each, report `id`, `lifecycle`, and a
   one-line `## Purpose` summary.
5. **ADR alignment.** If the feature references an ADR (`[[adr-xxx]]`), verify it
   exists and is not superseded or rejected — an ADR present is the current decision
   at its maturity. Surface prototype drift items that reference unimplemented ADR
   requirements.

**Output format (single):**

```markdown
# Feature Review: {feature-id} · {feature-name} | {date}

## Feature
- File: {path}
- Module: {module}
- Priority / State: {priority} / {state}
- ADRs referenced: {list}

## Coverage Matrix

| Layer | Status | Detail |
|-------|--------|--------|
| Feature (03_features) | ✅ | {file} |
| screen spec (05_screens) | ✅/❌/N/A | Screens: {list} |
| Prototype (/prototype) | ✅/⚠️/❌/N/A | Drift: {count} |
| Specs (04_domain) | ✅/❌/N/A | Actions: {list} |
| ADR alignment | ✅/⚠️/❌ | |

## Issues
- [{severity}] {description} — {file}:{line} | Fix: `/{skill}`

## OK
```

The screen-spec line is **one row per UI surface in the feature's blast radius** —
`screen spec ({surface})`, listing what that surface's tree covers plus the
`shared/{module}/` screens it inherits. When the blast radius is a single UI
surface that is the one unqualified row shown above, exactly as before.

### Batch mode (module)

Reviews ALL features of a module in parallel.

1. Enumerate `inspire_kb/03_features/{module}/*.md` — excluding `_*.md` and
   `README.md` — for all feature/use-case IDs; the glob is the index.
2. Present the list to the user and **ask for confirmation** before proceeding.
3. On confirmation, **launch one Agent per feature in parallel** — each runs the
   single-feature review.
4. Collect results.
5. **Synthesize** a consolidated report: aggregated coverage matrix, issues grouped
   by severity, and patterns (e.g. "5 features missing screen spec coverage").
6. If issues are found, present a **correction plan**: ordered actions grouped by
   the skill to invoke.

**Output format (batch):**

```markdown
# Feature Review: {module} (batch) | {date}

## Scope
{N} features reviewed: {list}

## Aggregated Coverage Matrix
| Feature | 03_features | screen spec | Prototype | Specs | ADR |
|---------|-------------|--------|-----------|-------|-----|
| PRV-01  | ✅          | ✅     | ⚠️ (3)    | ❌    | ✅  |
| ...     |             |        |           |       |     |

## Summary
- Full coverage: {N} · Gaps: {N} · Drift items pending: {count}

## Issues by Severity
### Critical / Important / Minor

## Correction Plan
1. `/inspire-screens` — Add screens for: {list}
2. `/inspire-prototype` — Adopt components for: {list}
```
