# Module — scan
> Part of [inspire-module](../SKILL.md). Read when the entry's index routes here.

## Subcommand: scan

The entry point for SDD-layer work on a module. It surfaces features that lack
realizing specs and chains authoring into `/inspire_domain`. Scan is **read-only**
with respect to `inspire_kb/04_domain/`; it never authors descriptors itself.

### Phase 1 — Environment setup

Check: are we in a git worktree, on the right per-module SDD branch (e.g.
`feat/sdd-{module}`), with a clean tree? If all yes, proceed. Otherwise surface
the gap and offer, conversationally, to bootstrap a fresh worktree:

```bash
git worktree add .claude/worktrees/sdd-{module} -b feat/sdd-{module} origin/main
```

Direct shell call via the Bash tool. **Do NOT defer to a third-party worktree
skill** — operators may not have it installed; the `inspire-*` skill family must
stay portable.

### Phase 2 — Candidate surfacing + narrowing

Read the module's features:
- `inspire_kb/02_modules/{module}.md` — the hub's overview and any action
  declarations.
- `inspire_kb/03_features/{module}/{use-case}.md` — feature descriptions and the
  actions they declare.

For each declared action (e.g. `platform::actions::resolve`):
- **Canonicalize plural → singular** (`platform::actions::resolve` →
  `platform::action::resolve`). This is a known layer-convention shift — apply it
  silently, don't surface it as a decision.
- Check whether `inspire_kb/04_domain/{module}/{entity}/{action}.md` exists.
- If not, it's a candidate.

Surface candidates and **dialogue** to narrow the set — one focused question at a
time, show-then-approve. Follow the conversational conventions of
[`/inspire_domain`](../../inspire-domain/SKILL.md). Do not enumerate decision-tree
options; let the conversation decide.

### Phase 3 — Chained authoring (only when the operator signals "start")

When the operator has chosen ≥1 action AND explicitly signaled start:
1. Create one `TaskCreate` per chosen action (canonicalized SDD id).
2. Mark the first `in_progress`.
3. Invoke `/inspire_domain define {first-id}` via the Skill tool. `inspire-domain`
   runs its socratic interview from here.
4. On completion, return to this frame and ask whether to continue with the next.

The interview may co-evolve action + entity documents in one `define` invocation;
`/inspire_domain` handles that bipartite walk. Scan's job ends at the handoff.

If the dialogue produces no chosen set (pure exploration), scan ends after Phase 2
without creating tasks. **Scan is valid as pure exploration** — it is not
"first-action-found-triggers-define".

### Phase 4 — Audit report

At the **end** of the report, scan still emits the SDD-layer audit signals:
features without realizing actions, orphan actions (no feature back-source), and
coherence conflicts (via `entity-coherence`). Render via
[`_references/findings-format.md`](../../_references/findings-format.md).

`scan {module}` batches over one module; `scan` without args batches over every
module present in `inspire_kb/02_modules/`.
