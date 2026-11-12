# ADR — KB links are relative Markdown links

- **Status:** Accepted — 2026-11-12
- **Amends:** [adr-kb-structure](adr-kb-structure.md) **D4** (links resolve by path, and
  the target file gives the id) and **D10** (the migration rewrites links, those in a
  screen's `## Bindings` included). Upholds [adr-upgrade-path](adr-upgrade-path.md) **D10**
  (`/inspire:update` stays additive on the KB) and **D11** (git is read-only against the
  operator's repository).
- **Scope:** How one KB file links to another, how tools resolve a link, and how an
  existing project's links are converted. Not the layout, not ids.

---

## Context

A KB link is a wikilink that names an id: `[[adr-user-pools]]`,
`[[runtime.run.create|runtime::run::create]]`. Before 0.15.0 most ids were also file
names, so any reader that resolves by file name followed them. Under
[adr-kb-structure](adr-kb-structure.md) D3 the file name carries a typed extension and the
id does not, so `[[adr-user-pools]]` names no file (`user-pools.adr.md`). Only INSPIRE's
own id index still resolves it.

`/inspire:migrate` moves files and rewrites no links, so a wikilink that carries a path
(`[[../../01_adr/adr-audit]]`) points at a directory that no longer exists. INSPIRE's
resolvers read only the path's last segment and never report it.

Measured on two projects: links that resolve by file name or path fall from 95% to 0.7%
in one, and from 98% to 4% in the other, which still has 2,689 path links. Obsidian,
GitHub, editors and agents that open files by path cannot follow the KB.

A relative Markdown link names the file itself. Every reader follows it.

## Decisions

### D1 — A link is a relative Markdown link to the target file

`[text](path)`, where `path` is the target file's path relative to the linking file,
extension included: `[adr-user-pools](../../_adr/user-pools.adr.md)`. Skills and
templates write no wikilinks.

### D2 — The path resolves the link, and the target file gives the id

A tool resolves a link by joining its path to the linking file's directory. The id is the
target's id under adr-kb-structure D3: its frontmatter `id:`, or the derivation from its
file name. A path to a file that does not exist is a broken link: it names no id, and a
tool reports it instead of deriving an id from the path.

The text is for the reader. It is the target's id unless the sentence needs prose
(`[the audit decision](../../_adr/audit.adr.md)`). No tool reads an id from the text.

### D3 — A link in frontmatter has the same form, quoted

`requires: ["[runtime::run::create](../run/run.create.action.md)"]`. The path is relative
to the file that holds the frontmatter.

### D4 — A link inside a code span or a fenced block is an example

Tools skip it, and the conversion leaves it as written.

### D5 — Tools read both forms, and a wikilink is a finding

A project on this version may not have converted yet, so the validators resolve a
wikilink as before and a Markdown link by D2. `links-resolve.sh`, which replaces
`wikilinks-resolve.sh`, reports each wikilink as an error that names `/inspire:migrate`,
and each Markdown link whose target does not exist.

### D6 — `/inspire:migrate` converts the links

- The conversion is its own run, after the moves are committed. Git then records every
  move as a rename, because no file is edited in the same commit. A layered KB is moved,
  committed, then converted; a concept KB that still holds wikilinks is only converted.
- A link resolves through, in order: its path, mapped through the move record
  (`_migration/plan.tsv`, or git rename history read without writing); its path against
  the current files; the id index; its target as a pre-move file name, mapped through
  the move record; the screen id map (`_migration/id-map.json`).
- A link that resolves through none of them stays as written, and the run lists it.
- A link in a screen's `## Bindings` is converted like any other. Its text keeps the id
  it named, so the citations the Factory's remap reads do not change.

`/inspire:update` changes no link. It counts the wikilinks it finds and points at
`/inspire:migrate`.

### D7 — Moving a file rewrites the links to it

A path names a location, so a file that moves has every link to it rewritten in the same
change. `/inspire:migrate` does this for the moves it makes. A skill that writes a link
computes the path from the linking file. When the target is missing, the skill first
creates it from its template (adr-kb-structure D4).

### D8 — A conversion rebuilds nothing that is built

A claim whose payload quotes a link changes its fingerprint when the link is converted,
though it states the same thing. After a conversion, the Factory's remap rewrites, in the
built code, each fingerprint whose claim payload differs only in link syntax, as it
rewrites screen ids after a move (adr-kb-structure D10). A project that has not converted
keeps every fingerprint it has.

The plain text a fingerprint covers reduces a wikilink exactly as before this decision, and
a Markdown link to a specification file to its text, so moving a file (D7) changes no
fingerprint. A Markdown link inside a code span, or to anything else, stays as written.
A claim counts as changed only in link syntax when its links resolve to the same ids
before and after.

### D9 — The runtime's own files follow D1 within a payload class

A skill, its `references/` and the shared `_references/` link to one another with relative
Markdown links, because that tree has the same shape in this repository
(`plugin/base/skills/`) and in a project (`.claude/skills/`). A test resolves every one of
them. A reference from a skill to another class (`.inspire/bin/`, `inspire_kb/`) is
written as the deployed path in a code span: no relative path is valid in both places, and
those references are mostly commands to run.

## Consequences

- The INSPIRE Factory reads the KB's links to derive dependencies and bundle membership.
  It needs a release that reads Markdown links and applies D8 before a converted project
  is built.
- `wikilinks-resolve.sh` is removed. An upgrade deletes the shipped copy and keeps an
  edited one.
