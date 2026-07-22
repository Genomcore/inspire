# 98 · Skill learnings

The **self-learning layer** — durable, version-stamped insights about the
`inspire-*` **skills themselves**, captured in a fork and bound *upstream* to
INSPIRE core. Where the rest of the knowledge base describes the **product**, this
layer describes how the **methodology fit** the product: where a skill helped, where
it got in the way, and what a fork changed locally.

Forks diverge from the template and rarely merge back. This layer is the
low-friction alternative to a git merge: instead of propagating code, a fork emits
**learnings** that the central INSPIRE team harvests to inform the next release.

- **Skill:** `inspire-learn` (`note` · `list` · `show` · `purge`).
- **Write-once & timestamp-named:** one `YYYYMMDD_<slug>.md` per learning,
  flat, created once and never edited. The date prefix lets an org sweep select a date
  range by string comparison on the first 8 characters — no frontmatter read. The
  on-disk contract (naming, write-once rules, frontmatter schema, enums, purge/sweep)
  lives in the `inspire-learn` skill's `references/learnings-format.md`.
- **Version-stamped:** every node freezes the `inspire_version` it was captured on
  (read from the root `.inspire.lock`), so upstream can tell whether a newer release
  already addressed it.
- **Authored in English**, regardless of the project's `output_language` — its
  reader is the cross-org INSPIRE core team, not the product team. This is the one
  deliberate exception to the output-language rule.

## Relationship to the tracker (`99_tracker`)

Both are trackers, aimed at different audiences:

| | `99_tracker` skill-feedback ticket | `98_skill_learnings` node |
|---|---|---|
| Audience | this project's team | the central INSPIRE team |
| Lifetime | transient — closed when acted on | durable — kept as a versioned record |
| Question | "someone here should act on this friction" | "this generalizes; INSPIRE core should adopt it" |

A recurring or confirmed friction ticket **graduates** into a learning: the ticket
tracks the local fix, the learning carries the generalizable insight upstream and
links back with `[[TASK-…]]`.

## Centralization

Consumption is always a **pull from above**: an external INSPIRE-core agent pulls the
org's forks and reads the raw `**/.inspire_kb/98_skill_learnings/*.md` (plus each fork's
`.inspire.lock` for its version), clusters the learnings by skill and theme, and feeds
them into INSPIRE core's own ADRs / tracker for the next release. Because learnings are
write-once and date-prefixed, the pull keeps a **date cursor** and reads only files
newer than it (comparing the first 8 characters), so it never re-processes what it
already ingested. The fork writes learnings and never contacts upstream.

> This is a **template skeleton**. On a new project the folder starts empty (just
> this `README.md`); `inspire-learn` fills it in as the fork accumulates learnings.
