# Vertical prototypes — external repo index

Vertical prototypes are **narrow, deep, functional spikes**, each living in its
**own external repository** (often its own stack). They are not vendored into this
repo. Instead, each one gets a file here that:

1. **Links** to its external repository, and
2. **Brings its learnings home** — so the knowledge outlives the spike repo.

## How to add one

Copy [`_template.md`](_template.md) to `{name}.md` (kebab-case, e.g.
`realtime-sync.md`) and fill it in. One file per vertical spike.

## Index

_List each vertical here with a one-line summary and its repo link:_

- _e.g._ [`realtime-sync`](_template.md) — spike on live collaboration — `github.com/org/spike-realtime-sync`

## Convention

- Keep the **repo link** current; if the spike repo is archived, note it but keep
  the learnings.
- The learnings are the durable asset — write them so they are useful even if the
  external repo disappears.
