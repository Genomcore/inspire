# Subcommand: promote

Walk lifecycle states forward. See [`lifecycle-rules.md`](../../../_references/lifecycle-rules.md) for the full per-state gate table and regression rules.

## Flow

1. Resolve the action id and read its current `lifecycle:`.
2. Refuse if the target state equals the current state, or if the target state is `superseded` without a `superseded_by:` pointer being provided or already present.
3. Run the quality_lib gates that apply to the target state via `.claude/bin/review.sh`. Filter findings to those targeting this descriptor.
   - **Error findings** → refuse promotion. Show the blockers. Operator fixes, then retries.
   - **Warning findings** → show them; ask "Promote anyway? [y/N]". On `N` → do not promote.
4. Apply the `lifecycle:` change, write the file.
5. If the promotion is to `stable` or `superseded`, re-run [consolidation](../consolidation.md) — these transitions change the action's visibility to consumers, and the entity document's Touched by entries need to track.

**Regression is `demote`, not `promote`.** Walking lifecycle backwards (`stable → accepted`, `accepted → draft`) is the `demote` subcommand. `promote` walks forward only; if the operator passes a target state earlier than the current lifecycle, `promote` redirects to `demote`.

**Hard rule:** never bypass an error finding. If the operator disagrees with a rule, the escape hatch is a manual edit outside this skill — accountability via git author.
