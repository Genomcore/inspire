# Feature — review
> Part of [inspire-feature](../SKILL.md). Read when the entry's index routes here.

## Subcommand: review

### Single feature mode

Reviews one feature across all layers. Runs inline (no agents).

1. **Locate the feature.** Find `{feature-id}.feature.md` under
   `inspire_kb/01_spec/`. Read: description, actor/personas, dependencies, priority,
   state, ADRs referenced, blast radius. The module is the one whose directory holds
   the file.
2. **screen spec coverage.** Search every screen's `**Features:**` line for this
   feature ID: every `*.screen.md` under `inspire_kb/01_spec/`. Screens live in their
   face (`_faces/{face}/_screens/`), so the check runs once per face in the feature's
   blast radius (`faces:`; absent means every face —
   [`_references/face-scope.md`](../../_references/face-scope.md)). Flag if no
   screen covers a UI-facing feature — per face, since a feature can be covered in
   one and uncovered in another; note "No UI expected" for backend/infrastructure
   features.
3. **Prototype coverage.** For each covering screen, verify it is reflected in the
   horizontal prototype at the project's prototype root (`/prototype` by default;
   resolve `prototype_root` per
   [`_references/product-roots.md`](../../_references/product-roots.md), and report
   the layer `N/A` when it is `none`) — under the shell of the face that holds the
   screen, since the prototype runs one shell per face — and note drift (pending component
   adoption, hardcoded data, ADR gaps). Insights land in the specs / screens /
   ADRs, not a prototype learnings file.
4. **Specs (SDD) coverage.** Find action descriptors whose `## Purpose` links back
   to this feature. Search every `*.action.md` under `inspire_kb/01_spec/` for
   `{feature-id}.feature.md`.
   Flag if zero realizing actions exist. For each, report `id`, `lifecycle`, and a
   one-line `## Purpose` summary.
5. **ADR alignment.** If the feature references an ADR (`[adr-xxx](../../../_adr/xxx.adr.md)`), verify it
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
| Feature (`*.feature.md`) | ✅ | {file} |
| screen spec (`*.screen.md`) | ✅/❌/N/A | Screens: {list} |
| Prototype (/prototype) | ✅/⚠️/❌/N/A | Drift: {count} |
| Specs (`*.action.md`) | ✅/❌/N/A | Actions: {list} |
| ADR alignment | ✅/⚠️/❌ | |

## Issues
- [{severity}] {description} — {file}:{line} | Fix: `/{skill}`

## OK
```

The screen-spec line is **one row per face in the feature's blast radius** —
`screen spec ({face})`, listing the screens of that face that cover the feature.
When the blast radius is a single face, it is the one unqualified row shown above.

### Batch mode (module)

Reviews ALL features of a module in parallel.

1. Find every `*.feature.md` under `inspire_kb/01_spec/_modules/{module}/` for all
   feature/use-case IDs; the extension is the index.
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
| Feature | Use case | screen spec | Prototype | Specs | ADR |
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
