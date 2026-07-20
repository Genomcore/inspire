# Subcommand: refactor

Rename, split, or merge actions. Used when the action's identity changes, not just its content.

## Flow

1. Clarify the intent: rename (same action, new id), split (one action becomes two or more), or merge (two actions collapse to one).
2. **Walk consumers.** Read every descriptor in the SDD tree that lists this action in `requires:` or references it via wikilink. Present the consumer list to the operator.
3. For each consumer, show the proposed diff and ask for explicit confirmation before applying. **No batch-update** — every consumer change is a separate operator decision.
4. On all confirmations: apply the rename / split / merge, update all confirmed consumers, delete or rename source files, run [consolidation](../consolidation.md).

The operator must confirm each consumer change individually. There is no `--cascade` flag.
