---
name: migrate
description: "Move this project's knowledge base from the layered layout (01_adr, 02_modules, 03_features, 04_domain, 05_screens and the surface roster) to the concept layout under inspire_kb/01_spec/, where every artifact has a typed extension, and convert its [[wikilinks]] to relative Markdown links. Run once, on purpose, after /inspire:update reports the layered layout or counts wikilinks. Rebuilds nothing that is already built."
---

# /inspire:migrate — the KB by concept

INSPIRE 0.15.0 reads the specification only from `inspire_kb/01_spec/`, where every
artifact is found by its typed extension (`.module.md`, `.feature.md`, `.entity.md`,
`.action.md`, `.adr.md`, `.bundle.md`, `.face.md`, `.screen.md`, `.process.md`…).
This skill moves a KB written in the layered layout there, once. It is the only
step that moves anything in `inspire_kb/`: `/inspire:update` never does
([`adr-kb-structure`](https://github.com/Genomcore/inspire/blob/main/docs/adr/adr-kb-structure.md)
D10).

From 0.16.1 a KB link is a relative Markdown link to the target file,
`[adr-audit](../../_adr/audit.adr.md)`, and the skill converts every `[[wikilink]]`
in the same run
([`adr-markdown-links`](https://github.com/Genomcore/inspire/blob/main/docs/adr/adr-markdown-links.md)
D6). A KB already on the concept layout that still holds wikilinks gets a run that
converts its links and moves nothing.

**What it never does:** rename a module, an entity or an action; change any id but a
screen's; point a link at a different file; extract a shared screen into a pattern;
create a process, or a bundle with an artifact of its own; write to git.
Every screen id it changes goes into `inspire_kb/01_spec/_migration/id-map.json`,
which the INSPIRE Factory release that goes with 0.15.0 reads to rewrite the built
code instead of rebuilding it.

## Preconditions

1. The runtime is already on 0.15.0 or later (`/inspire:update` has run). The
   validators and skills of this version read only `01_spec/`.
2. `jq` and `yq` (Mike Farah v4) are on `PATH`.
3. **A clean working tree.** If `git status --porcelain` is non-empty, stop and ask the
   operator to commit or stash first: the moves must be committed on their own, before
   any edit, so git records them as renames and the history of every file survives.

## Step 1 — Dry run, and the questions it asks

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/migrate-kb.sh" --dry-run --kb inspire_kb
```

It prints the plan, one tab-separated line per step (`move`, `write`, `idmap`,
`unplaced`, `note`), and writes nothing. When it needs an answer it prints `ask` lines
instead and exits 3. Ask the operator each one, in their words, then run the dry run
again with the answers as flags:

| `ask` key | Question | Flag |
|---|---|---|
| `face` | No roster, but there are screens: every screen moves to one face. What is its id? Propose the project's name in kebab-case. | `--face ID` |
| `bundle` | No roster: every module is exposed by one bundle. What is its id (propose `api`), and which package exposes it (`source_root`-relative, for example `apps/api`)? | `--bundle ID --bundle-package PATH` |
| `bundle-modules:{id}` | The roster has several headless surfaces: which modules does `{id}` serve? Read the ADR that partitions them if there is one, and propose it. | `--bundle-modules {id}=m1,m2` |
| `lib:{id}` | The lib surface `{id}`: does it become a bundle (a package with code of its own) or part of the design system (a UI kit)? | `--lib {id}=bundle` or `--lib {id}=design-system` |
| `shared-face` | `05_screens/shared/` holds screens two faces use. Which face keeps them? Nothing is extracted; each other face can add its own screen later. | `--shared-face ID` |

Never answer a question yourself: these are specification decisions.

**Relay the plan grouped:** how many files move per kind, every screen id that changes
(the `idmap` lines, old → new), every file it cannot place (`unplaced`: moved under
`_migration/unplaced/`, never dropped), how many wikilinks the run converts, and every
`note`. Ask the operator to confirm before Step 2.

On a concept KB the dry run is the link conversion's own: one `link` line per link it
converts (file, line, the source that resolved it, the wikilink, the Markdown link)
and one `unresolved` line per link it cannot resolve. Relay the count per source and
every unresolved link.

## Step 2 — Migrate

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/migrate-kb.sh" --kb inspire_kb {the same answer flags} \
  --skeleton "${CLAUDE_PLUGIN_ROOT}/base/kb/01_spec"
```

`--skeleton` adds the READMEs, the starter patterns and the default theme the layered
layout never had, and seeds `design-system.md` from the theme if the project had none —
only where nothing is on disk. The plan it applied is saved to
`inspire_kb/01_spec/_migration/plan.tsv`.

After the moves it converts the links, and prints the `link` and `unresolved` lines
after the move plan. A link resolves through, in order: its path, mapped through the
move plan, or as it stands; the id index; the pre-move file names in the move plan;
the screen id map. A key two files share resolves nothing.
The text of the new link is the wikilink's alias, else its target as written, so a
link in a screen's `## Bindings` keeps the old screen id as its text. Links inside
code spans and fenced blocks stay as written. The link plan is saved to
`inspire_kb/01_spec/_migration/links.tsv`.

**Relay every `unresolved` line**: each one stays a wikilink, and `links-resolve`
reports it until it points at a file. Ask the operator which file each one means.

On a concept KB the same command converts the links only. Its move record is
`plan.tsv`, or, when there is none, the renames git holds since the commit before the
layered directories left, read and never written. When the history does not show
that commit, ask the operator for it and run
`"${CLAUDE_PLUGIN_ROOT}/scripts/migrate-links.sh" --kb inspire_kb --since REV`.

It refuses, and moves nothing, when:

- `01_spec/` already exists beside layered directories (a half-migrated KB) — find out
  what put it there before going on;
- a screen id is used by more than one screen — the id map would be ambiguous. Run
  `.inspire/bin/screen-coherence.sh` on the old tree with the previous runtime, or
  fix the duplicate by hand, and run again.

A second run on a migrated KB is a no-op.

## Step 3 — Commit the migration on its own

Tell the operator to commit now, before any other edit, so git sees the moves as
renames:

```bash
git add -A inspire_kb && git commit -m "chore(kb): move the KB to 01_spec and convert its links (/inspire:migrate)"
```

Do not commit for them unless they ask you to.

## Step 4 — Review, then narrow

```bash
.inspire/bin/review.sh inspire_kb
```

Expected after a migration, and fine to fix in a later commit:

- `face-exposure` warnings: every face lists every bundle, because the layered layout
  did not say which bundles a face uses. Narrow each face's `bundles:`.
- `spec-identity` warnings for a bundle with no `package:` — fill it in before the
  Factory plans the bundle's mount test.
- `links-resolve` errors for each link Step 2 listed as unresolved, until the operator
  points it at a file.

Anything else the review reports was already wrong before the migration, or is a
defect in it: report the second kind.

## Step 5 — The INSPIRE Factory

Tell the operator what comes next for code already built: the INSPIRE Factory release
that goes with INSPIRE 0.15.0 reads `_migration/id-map.json`, rewrites the screen
ids in the built code and the claim citations that name them, and commits that as a
branch for review, without running any agent. It rewrites literals only: code that
reads a screen id's shape (its first segment was the module, it is now the face) is
not text it can fix, so its report lists those sites to review by hand. The test
suite runs on that branch before it is merged. The only new units it plans are the
grouping bundles, one mount test each. An older Factory refuses this KB and says why.
