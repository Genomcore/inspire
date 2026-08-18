# Workspace — structure
> Part of [inspire-workspace](../SKILL.md). Read when the entry's index routes here.

Validate the vault structure at the top level (not module-scoped).

### Checks

1. **CLAUDE.md** is present at the workspace root.
2. **Module hubs and ADR files:**
   - Module hubs are `inspire_kb/02_modules/*.md` excluding `_*.md` and
     `README.md` — the glob is the module registry. Every file matching it
     parses as a hub (H1 title + `prefix:` frontmatter); no stray non-hub
     `.md` sits at the `02_modules/` root — anything matching the glob must
     *be* a hub, and every module has exactly one.
   - ADR files are `inspire_kb/01_adr/adr-*.md` — the glob is the ADR
     catalog. Every file under `01_adr/` matches that naming rule.
3. **Screens module directories:** every `inspire_kb/05_screens/` module
   directory — flat `{module}/` or surface-first `{surface}/{module}/` (per
   [`_references/surface-scope.md`](../../_references/surface-scope.md)) —
   carries an `_index.md` with a route-map/coverage table. Existence and
   presence only; table content is a module-level concern
   (`/inspire_module review`), not this top-level check.
4. **Task tracker:**
   - `inspire_kb/99_tracker/tickets/` has valid `.md` files at top level (open)
     and under `archive/` (closed). Frontmatter parses, enums match, ID format
     `TASK-[a-z0-9]{6}`.
   - `id` matches filename; no duplicate IDs across `tickets/` and `archive/`.
   - **Location ↔ status invariant:** every top-level ticket is `Open`; every
     archived ticket is `Done`/`Cancelled`.
   - `blocked_by` / `related_to` references to other `TASK-*` IDs resolve (warning
     if not).
5. **No orphan files:** no stale `.md` at `inspire_kb/` root (except
   `CONTRIBUTING.md` if present); no legacy paths.

### Output

```markdown
# Vault Structure | {date}

## Module hubs and ADR files
- Module hubs: {ok | N issues}
- ADR files: {ok | N issues}

## Screens module directories
- Screens module dirs with _index.md coverage: {N}/{total}

## Task tracker
- tickets/: {N} open
- tickets/archive/: {N} closed ({Done: N, Cancelled: N})

## Issues
- [{severity}] {description}

## OK
```
