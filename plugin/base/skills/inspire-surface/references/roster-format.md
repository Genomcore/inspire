# Surface roster — on-disk format

The roster is a single file, `inspire_kb/00_bootstrap/surfaces.md`, authored by
`/inspire-surface` and by nothing else. When it comes into existence, and what its
absence declares, are in
[`surface-scope.md`](../../_references/surface-scope.md).

This file defines the roster's **shape** only — its frontmatter, its body sections,
its fields and their defaults. The *semantics* — what a surface is, which ids are
reserved, how a skill resolves scope, what shape the screens tree takes — live in
[`.claude/skills/_references/surface-scope.md`](../../_references/surface-scope.md).

## Worked example

```markdown
---
kind: bootstrap-surfaces
status: active
surfaces: [portal, admin, api, ui-kit]
---

# Surfaces

## portal
**Kind:** ui
**Name:** Customer portal
**Profiles:** [react]
**Package:** apps/portal
**Shell:** /portal

## admin
**Kind:** ui
**Name:** Admin console
**Profiles:** [react]
**Package:** apps/admin
**Shell:** /admin

## api
**Kind:** headless
**Name:** Platform API
**Profiles:** [nestjs]
**Package:** apps/api

## ui-kit
**Kind:** lib
**Name:** Shared component library
**Profiles:** [react]
**Package:** packages/ui-kit
```

## Frontmatter

| key | value |
|---|---|
| `kind` | the literal `bootstrap-surfaces` — how a reader identifies the roster |
| `status` | `active` while the roster governs the suite |
| `surfaces` | the machine-readable list of ids, `[a, b, c]` |

**`surfaces:` MUST mirror the `##` headings** — same ids, nothing extra, nothing
missing. The session-start hook and any other machine reader take the frontmatter
list and never parse the body, so a drifted list is wrong in a way nothing else
notices. `/inspire-surface review` checks this first.

## Body — one `##` section per surface

The heading *is* the id: `## portal`, nothing else on the line. Fields follow as
bolded labels, one per line, no blank line between them.

| field | form | required | default |
|---|---|---|---|
| id (the `##` heading) | kebab slug, unique in the roster, not a reserved id | yes | — |
| `**Kind:**` | `ui` \| `headless` \| `lib` — `headless` is any service without a face (HTTP API, worker, event consumer), `lib` any shared package | yes | — |
| `**Name:**` | display name, prose | yes | — |
| `**Profiles:**` | bracketed list of stack profile ids, `[react]` | no | the global `profiles:` in `00_bootstrap/stack.md` |
| `**Package:**` | path **relative to the single `source_root`** | no | `apps/{id}` for `ui` and `headless`, `packages/{id}` for `lib` |
| `**Shell:**` | prototype route prefix, leading slash | UI only | `/{id}` |

Notes on the fields:

- **id** — the same token everywhere: `surfaces:` values, the screens tree
  directory, the shell route. The reserved ids and why they are refused are in
  [`surface-scope.md`](../../_references/surface-scope.md).
- **Kind** — the value is one of the three kinds that reference defines; the gloss
  in the table above is a reminder, not the definition.
- **Profiles** — omit it and the surface inherits the suite's global list. Present,
  it replaces that list for this surface; it does not extend it.
- **Package** — relative to `source_root`, which stays a single scalar (see
  [`_references/product-roots.md`](../../_references/product-roots.md)). Write the
  field even when it matches the default, so the emanation target is readable
  without knowing the default table. The roster records the path; it does not
  create the directory.
- **Shell** — omit the field entirely for `headless` and `lib` surfaces; they have
  no prototype route. Prefixes must be unique among UI surfaces.

Write only fields that exist. An omitted optional field means "the default"; an
empty one means nothing and is a defect.

## Anticipated, not supported: `design_system`

A per-surface `design_system: suite | own` field is anticipated for the surface
that is genuinely its own brand and does not consume the suite design system at
all — a declared fork rather than a shadow.

**It is not supported today.** The design system is a strict suite singleton; no
skill reads this field, and authoring it changes nothing. Do not write it, and do
not treat its absence as a decision the operator still owes.
