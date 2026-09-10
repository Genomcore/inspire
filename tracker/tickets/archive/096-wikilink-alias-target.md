---
id: 096-wikilink-alias-target
title: "096 — an aliased wikilink is resolved by its label, so a correct link reports as dangling"
created: 2026-09-10
updated: 2026-09-10
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-09-10
epic: follow-up
size: S
importance: Very High
skills: []
status: Done
blocked_by: []
related_to: [096-kebab-module-discovery]
---

## Description

Reported against 0.9.1 by a governed project running the runtime over its own vault.

`wikilinks-resolve.sh` unwraps `[[target|display]]` by taking the text **after** the pipe,
which for the standard alias form is the display text. The rule then looks up the label,
fails to find it, and reports the label as an unresolved wikilink:

```
{"severity":"warning","rule":"wikilinks-resolve",
 "message":"wikilink does not resolve: [[the audit decision]]"}
```

The link it came from — `[[../../../01_adr/adr-audit|the audit decision]]` — is correct, and
the file it names is on disk.

The severity is lifecycle-progressive, so at `draft` these read as noise and at `accepted`
they are errors that fail both hooks. In the reporting vault 53 findings were this, with no
genuinely broken link behind any of them, and promoting one module would have put 21 of them
at error severity with nothing an author could do to clear them.

`wikilinks-resolve.sh` contradicted itself in three places about which half is the target —
its header said the left, the comment above the extraction said the right, and
`resolve_wikilink` said the left — which is how the reading survived review.

The second site is `adr-maturity-matches-features.sh`: `adr_path_for` reads the target
through `sdd_unwrap_wikilink`, which is the id reader and also takes the right half, so an
aliased ADR citation resolves to nothing and the maturity claim behind it goes unchecked.

## Acceptance criteria

- [x] `[[target|display]]` resolves against the **target**, and the finding on a genuinely
      dangling link names the target rather than the label. — the target is the left half
      unconditionally. The reporting project proposed accepting either half; taking the left
      only is what the format docs already described, and it leaves one answer rather than
      two.
- [x] The escaped table-cell form the 0.9 screens substrate writes
      (`[[a.b\|a::b]]`) still resolves, and the id readers that legitimately want the right
      half are left alone and distinguishable from the target reader. — the trailing
      backslash is stripped off the target; `sdd_unwrap_wikilink` is untouched and now sits
      directly above `sdd_wikilink_target`, each stating what the other answers.
- [x] Regression cases cover all three shapes: an aliased prose link, an escaped table-cell
      id pair, and a bare link with no pipe. — `alias-left-is-the-target` and
      `alias-target-is-what-the-finding-names` are new, `screen-action-link-resolves`
      covers the escaped pair and now pins the target in the message it reports, and the
      bare shape was already covered by `clean` and `draft-unresolved-warning`.
- [x] Every site that reads a link **target** takes the same half, from one implementation.
      — `wikilinks-resolve.sh`'s awk stops at the brackets and calls the shared reader, and
      `adr-maturity-matches-features.sh`'s `adr_path_for` calls it too; the aliased ADR
      citation it used to skip is fixture `aliased-prose-link`.
