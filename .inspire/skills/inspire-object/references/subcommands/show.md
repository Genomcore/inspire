# Subcommand: show

Render an existing descriptor with `[[wikilinks]]` resolved inline. Read-only — nothing writes to disk.

## Flow

1. Read the descriptor at `.inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.{action}.md`.
2. For every `[[wikilink]]` in the body, resolve it to the target document's title and first paragraph. Render inline — e.g. `[[auth.password.hash|auth::password::hash]]` expands to `auth::password::hash — Hashes a plaintext password using bcrypt...`.
3. For every `[[section]]` wikilink, resolve and quote the referenced feature passage.
4. Present the expanded view in the conversation.

Useful when the operator wants the operator-readable view without opening multiple files, and as a quick way to audit that wikilinks are grounded.
