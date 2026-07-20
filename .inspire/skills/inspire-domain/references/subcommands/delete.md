# Subcommand: delete

Remove an action descriptor and its references from the SDD tree.

## Flow

1. Read the descriptor. Check the full SDD tree for any descriptor with this action's id in its `requires:` list.
2. **Refuses if dependents exist.** If any action lists this one in `requires:`, display them and stop:

   ```
   Cannot delete auth::user::create — 2 actions depend on it:
     - auth::token::issue (requires auth::user::create)
     - auth::session::start (requires auth::user::create)
   Remove or update those requires entries first, then retry delete.
   Alternatively: promote auth::user::create superseded and supply a superseded_by pointer.
   ```

3. **No dependents** → confirm with the operator ("Delete `{id}`? This removes the descriptor and its rows in the entity document. [y/N]"). On confirmation, delete the file and re-run [consolidation](../consolidation.md) to remove the action's entries from `{module}.{entity}.md`.

There is no `--cascade` flag. Cascading deletes rewrite the requires graph silently — the operator must handle each consumer explicitly, so they can reason about what each consumer should do instead.
