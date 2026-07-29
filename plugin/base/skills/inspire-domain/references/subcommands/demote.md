# Subcommand: demote

Walk lifecycle states **backwards**: `stable → accepted`, or `accepted → draft`. Used when modifying a stable object (you cannot `update` a stable directly — `demote` first, modify, then `promote` back) or when correcting a premature promotion.

Like `promote`, `demote` is **operator-initiated only**. Lifecycle transitions are intentional acts — the agent never auto-demotes an object as a side-effect of consolidation, refactor, or review.

## Flow

1. Resolve the object id and read its current `lifecycle:`. Refuse if already at `draft` (nothing to demote to) or `superseded` (a terminal state; use `delete` or supersede a different way).
2. **Cascade preview.** Read every other descriptor in the SDD tree. Identify consumers that depend on the current lifecycle state — i.e. any descriptor whose `requires:` list points at this object **and** whose own `lifecycle:` is at or above the target the gate would lift. The two cases that matter:
   - Demoting `stable → accepted`: list every **stable** consumer whose `requires:` includes this object. Each would violate `stable-blockers` (a stable action must not depend on a non-stable one) the moment this object demotes.
   - Demoting `accepted → draft`: list every **accepted-or-stable** consumer whose `requires:` includes this object. Each would have a `requires:` target at a regressed lifecycle.
3. **Refuse with cascade preview if consumers exist.** Show the consumer list and stop:

   ```
   Cannot demote auth::user::create from stable → accepted — 2 stable consumers depend on it:
     - auth::token::issue       [stable, requires auth::user::create]
     - auth::session::start     [stable, requires auth::user::create]
   To proceed, either:
     1. Demote each consumer first (then retry this demote), or
     2. Rethink the change — if the contract is shifting, the consumers may need different requires targets.
   ```

   There is no `--cascade` flag. The operator drives each demote individually so they can reason about what each consumer should do.
4. **No blocking consumers** → confirm with the operator ("Demote `{id}` from `{current}` → `{target}`? [y/N]"). On confirmation, apply the `lifecycle:` change, write the file.
5. Re-run [consolidation](../consolidation.md) if the demotion crosses the `stable ↔ accepted` boundary — the entity document's Touched by entries track lifecycle state and need to refresh.

**Hard rule:** the cascade preview is not optional. Even if the operator would prefer to demote silently and "fix consumers later," demote refuses — silent regressions are exactly the kind of contract breakage the lifecycle gates exist to prevent.
