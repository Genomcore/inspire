# 98 · Lessons

The **self-teaching layer** — durable, version-stamped **lessons** about the
`inspire-*` **skills themselves**: single one-line instructions that change how a
skill behaves in this project. Where the rest of the knowledge base describes the
**product**, this layer describes how you've taught the **methodology** to fit it.

A lesson can be *learned* or *taught*; the folder is a **catalog of lessons** this
fork holds. Two audiences read it:

- **This project, across releases** — on update, lessons are re-applied to the new
  base so the agents keep behaving as taught (materialization / update model —
  roadmap, v1; see [`docs/adr/0001`](../../docs/adr/0001-runtime-lifecycle-and-lessons.md)).
- **INSPIRE core, via the observer** — an external pull-from-above reads the catalog
  across many forks and distills the patterns worth folding into the next release.
  The fork only ever writes lessons.

- **Skill:** `inspire-lesson` (`note` · `list` · `show` · `purge`).
- **One line, atomic:** the body is a single imperative (at most a `do` / `Not:` pair,
  plus an optional example as *support only*). The one-line limit enforces atomicity.
- **Relevance is local:** you capture a lesson because it matters *here* — never
  because you judged it generalizable. That call belongs to the observer.
- **Write-once & timestamp-named:** one `YYYYMMDD_<slug>.md` per lesson, flat, created
  once and never edited. The date prefix lets an org sweep select a date range by
  string comparison on the first 8 characters — no frontmatter read. Superseded /
  absorbed lessons move (never edited) into `archive/`. The on-disk contract (naming,
  the one-line body format, write-once rules, frontmatter schema, enums, archive/purge)
  lives in the `inspire-lesson` skill's `references/lessons-format.md`.
- **Version-stamped:** every node freezes the `inspire_version` it was captured on
  (read from the root `.inspire.lock`), so the observer can tell whether a newer
  release already learned it.
- **Authored in English**, regardless of the project's `output_language` — its reader
  is the cross-org INSPIRE core team, not the product team. This is the one deliberate
  exception to the output-language rule.

> **Not** spike / prototype **learnings.** Those (`06_spikes`, the prototype) are
> product insight — what a spike or the horizontal prototype taught you about *the
> product*. Lessons here are about the *skills*. Different concept, different layer.

## Relationship to the tracker (`99_tracker`)

Both are records, aimed at different audiences:

| | `99_tracker` skill-feedback ticket | `98_lessons` node |
|---|---|---|
| Audience | this project's team | the observer / INSPIRE core |
| Lifetime | transient — closed when acted on | durable — kept as a versioned record |
| Question | "someone here should act on this friction" | "the skill should behave this way here" |

A recurring or confirmed friction ticket **graduates** into a lesson: the ticket tracks
the local fix, the lesson carries the durable instruction and links back with
`[[TASK-…]]`.

## Distillation

Consumption is always a **pull from above**: an external observer pulls the org's forks
and reads the raw `**/.inspire_kb/98_lessons/*.md` (plus each fork's `.inspire.lock` for
its version), clusters the lessons by skill and theme, and feeds the patterns into
INSPIRE core's own ADRs / tracker for the next release — *not necessarily literally*.
Because lessons are write-once and date-prefixed, the pull keeps a **date cursor** and
reads only files newer than it, so it never re-processes what it already ingested. The
fork writes lessons and never contacts upstream.

> This is a **template skeleton**. On a new project the folder starts empty (just this
> `README.md`); `inspire-lesson` fills it in as the fork accumulates lessons.
