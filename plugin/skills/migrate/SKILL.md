---
name: migrate
description: "Move this project's knowledge base from the layered layout (01_adr, 02_modules, 03_features, 04_domain, 05_screens and the surface roster) to the concept layout under inspire_kb/01_spec/, where every artifact has a typed extension. Run once, on purpose, after /inspire:update to 0.15.0 or later reports the layered layout. Rebuilds nothing that is already built."
---

# /inspire:migrate — the KB by concept

INSPIRE 0.15.0 reads the specification only from `inspire_kb/01_spec/`, where every
artifact is found by its typed extension (`.module.md`, `.feature.md`, `.entity.md`,
`.action.md`, `.adr.md`, `.bundle.md`, `.face.md`, `.screen.md`, `.process.md`…).
This skill moves a KB written in the layered layout there, once. It is the only
step that moves anything in `inspire_kb/`: `/inspire:update` never does
([`adr-kb-structure`](https://github.com/Genomcore/inspire/blob/main/docs/adr/adr-kb-structure.md)
D10).

**What it never does:** rename a module, an entity or an action; change any id but a
screen's; rewrite a link inside a screen's `## Bindings`; extract a shared screen
into a pattern; create a process, or a bundle with an artifact of its own; run git.
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
`_migration/unplaced/`, never dropped) and every `note`. Ask the operator to confirm
before Step 2.

## Step 2 — Migrate

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/migrate-kb.sh" --kb inspire_kb {the same answer flags} \
  --skeleton "${CLAUDE_PLUGIN_ROOT}/base/kb/01_spec"
```

`--skeleton` adds the READMEs, the starter patterns and the default theme the layered
layout never had, and seeds `design-system.md` from the theme if the project had none —
only where nothing is on disk. The plan it applied is saved to
`inspire_kb/01_spec/_migration/plan.tsv`.

It refuses, and moves nothing, when:

- `01_spec/` already exists beside layered directories (a half-migrated KB) — find out
  what put it there before going on;
- a screen id is used by more than one screen — the id map would be ambiguous. Run
  `.inspire/bin/screen-coherence.sh` on the old tree with the previous runtime, or
  fix the duplicate by hand, and run again.

A second run on a migrated KB is a no-op.

## Step 3 — Commit the moves on their own

Tell the operator to commit now, before any edit:

```bash
git add -A inspire_kb && git commit -m "chore(kb): move the KB to 01_spec (/inspire:migrate)"
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
- Old screen ids in `## Bindings` resolve through the id map and are not findings.

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
