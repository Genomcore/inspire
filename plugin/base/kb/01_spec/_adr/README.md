# `_adr/` · Architecture Decision Records

The **why** behind the system's shape. Each decision is a pair of files: the
decision itself, and the rationale that explains it.

- **Skill:** `inspire-adr` (ADR lifecycle — create / update / promote /
  supersede / migrate).
- **Maturity ladder:** `design → prototyped → implemented`. A decision moves
  up the ladder as it is validated; superseded decisions stay in the tree with
  a pointer to what replaced them. At `implemented` both files of the pair are
  immutable: changing either one means superseding the decision.
- **Layout:** one `{slug}.adr.md` per decision and its `{slug}.adr.rationale.md`
  beside it. The typed extension is the catalog: a search for `*.adr.md` finds
  every decision, wherever it sits. Slug-only — no numeric prefix: numbers
  collide when two branches each grab the next one. The canonical id is
  `adr-{slug}`: the extension says the file is an ADR, so the name does not repeat
  `adr-`, and the prefix is added back when the id is read. The rationale's id is
  `adr-{slug}.rationale`, and a `[[adr-{slug}]]` wikilink always reaches the
  decision.
- **Three scopes:** this directory holds the **global** decisions. A decision that
  binds one module lives in that module's `_adr/`
  (`_modules/{module}/_adr/`), and one that binds one face in that face's
  (`_faces/{face}/_adr/`). The scope is the placement; nothing else declares it.

## The two files

| File | Holds | Read |
|---|---|---|
| `{slug}.adr.md` — the **decision** | optional `faces:` / `bundles:` frontmatter (a global decision's blast radius; absent means the whole project), the H1 title, `**Status:**`, `**Modules affected:**`, `**Rationale:** [[adr-{slug}.rationale]]`, any `Supersedes:` or `**Prototype:**` line, and `## Decision`: one or a few imperative statements | by every session: the session-start hook injects every live decision |
| `{slug}.adr.rationale.md` — the **rationale** | `**Decision:** [[adr-{slug}]]`, then `## Context`, `## Consequences` with `### Breaking changes`, `## Alternatives considered` and `## Related ADRs` | when someone questions or supersedes the decision |

The decision constrains; the rationale explains and constrains nothing. Status,
blast radius and modules live in the decision only.

An ADR written before the split is one file holding all five sections. The
validators still read it, and report it as waiting for `/inspire-adr migrate`,
which splits it without changing a word.

- **The project's action verbs** live in one ADR with the fixed id
  `adr-action-verbs`. `inspire-domain` reads it when it names an action, and
  uses its default verbs until it exists.

ADRs constrain the layers below them: specs, prototypes and UI must stay
aligned with any decision within its maturity's reach.
