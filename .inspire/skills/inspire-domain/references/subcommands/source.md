# Subcommand: source

Show the back-source trail for every claim in the descriptor body. Read-only — nothing writes to disk.

## Flow

1. Read the descriptor.
2. Collect every `[[wikilink]]` in the body (feature sections, ADRs, other action ids).
3. For each wikilink, resolve the target and quote its first paragraph (or the specific section if the link carries an anchor).
4. Present the expanded trail in the conversation, claim by claim.

This is the operator's audit tool: every sentence in the descriptor should trace to a source. Unlinked sentences are flagged as potential gaps — the operator can then run `update` to add the missing wikilinks.
