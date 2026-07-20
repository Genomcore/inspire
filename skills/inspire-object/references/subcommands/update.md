# Subcommand: update

Patch-style modification of an existing descriptor.

When the update introduces a new section's worth of content (e.g. fleshing out an empty `## Errors`, adding a touched entity), run the relevant slice of the [interview cadence](../../SKILL.md#interview-cadence) — don't draft the new content unprompted.

## Stable objects block

`update` refuses when the target object is at `lifecycle: stable`:

```
Cannot update auth::user::create — it is at lifecycle: stable.
Stable objects are frozen contracts; modifying them in place would silently
shift the contract under their consumers. To modify a stable object:
  1. /inspire_object demote auth::user::create     # stable → accepted
  2. /inspire_object update auth::user::create ... # apply the change
  3. /inspire_object promote auth::user::create stable
```

The demote-first gate is intentional: it makes the lifecycle regression an explicit, traceable act rather than a silent side-effect of an `update` call.

## Flow

1. Read the current descriptor and display it. If `lifecycle: stable`, refuse with the message above and stop.
2. If the invocation embedded a change description (natural-language continuation), apply it to the relevant field(s) and show a diff. Otherwise ask: "What would you like to change?".
3. For every new claim the update introduces — a new behavior step, a new error code, a new invariant, a changed field declaration — ask for its PDD source and embed the wikilink inline. Existing wikilinks are preserved untouched.
4. Show the proposed diff (unified ` ```diff ` block). Operator approves or iterates.
5. On approval: write the updated descriptor, then run [consolidation](../consolidation.md) to reconcile the affected entity document.

`update` does not rewrite sections the operator did not touch. Append `--full` to the invocation to walk every field explicitly — useful when doing a full audit of an existing descriptor.
