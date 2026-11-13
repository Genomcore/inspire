# Subcommand: show

Render an existing descriptor with its links resolved inline. Read-only — nothing writes to disk.

## Flow

1. Read the descriptor at `inspire_kb/01_spec/_modules/{module}/_domain/{entity}/{entity}.{action}.action.md` (found by its `id:`).
2. For every link in the body, open its target and take the target document's title and first paragraph. Render inline — e.g. `[auth::password::hash](../password/password.hash.action.md)` expands to `auth::password::hash — Hashes a plaintext password using bcrypt...`.
3. For every link with an anchor, quote the referenced feature passage.
4. Present the expanded view in the conversation.

Useful when the operator wants the operator-readable view without opening multiple files, and as a quick way to audit that links are grounded.
