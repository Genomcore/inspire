# Config — the spec config
> Part of [inspire-config](../SKILL.md). Read when the entry's index routes here.

`.inspire/config.json` holds the values every skill, validator and hook reads before
it does anything else. It is committed. `.inspire.lock` beside it records which
INSPIRE release the project runs and nothing more.

## Keys

| Key | Kind | Default | Meaning |
|---|---|---|---|
| `source_root` | technical | `source` | where the production code lives, relative to the repository root. `.` means the repository root is the code |
| `prototype_root` | technical | `prototype` | where the horizontal prototype lives. `none` means the project has no horizontal prototype |
| `output_language` | product | `en` | the language every knowledge-base artifact is written in: an ISO 639-1 code or a plain name |

```json
{
  "source_root": "source",
  "prototype_root": "prototype",
  "output_language": "en"
}
```

`/inspire:init` writes the file with these defaults, or with the roots and the
language it was given. `/inspire:update` adds a key the file lacks and replaces no
value. A key INSPIRE does not list is kept as it stands.

## Who reads it

| Reader | Key | How |
|---|---|---|
| the session-start hook | `output_language` | injects the language into every session |
| `.inspire/bin/prose-style.sh` | `output_language` | skips its English-only checks in another language |
| the validators (`.inspire/bin/_lib.sh`) | `source_root` | where the gates that read code look for tests |
| every skill | all three | [`product-roots.md`](../../_references/product-roots.md), [`output-language.md`](../../_references/output-language.md) |
| `/inspire:init`, `/inspire:update` | all three | create the product roots, and keep the file complete |

Each reader takes the key from this file. When the file or the key is absent it
reads the place a project installed before INSPIRE 0.20.0 kept the value — the
frontmatter of `00_bootstrap/stack.md` for the roots, of `00_bootstrap/project.md`
for the language — and then the default. `/inspire:update` builds the file from
those two frontmatters the first time, so nothing is asked again. It never edits the
KB, so the frontmatter keys stay until this skill removes them: propose the removal,
as a diff, whenever a flow here finds one.

## Checks

`review` runs these and writes nothing.

| Check | Severity |
|---|---|
| the file is missing | error — run `/inspire:update`, which writes it from what the project already declares |
| the file is not a JSON object (`jq -e 'type == "object"' .inspire/config.json`) | error — every reader falls back to the defaults until it is repaired |
| a listed key is missing, or its value is not a nonempty string | error |
| a root that is absolute or contains `..` | error — a root never leaves the repository |
| a root that names a directory not on disk (other than `.` and `none`) | warning |
| `source_root`, `prototype_root` still in `stack.md`'s frontmatter, or `output_language` in `project.md`'s | warning when the value equals the config's, error when it differs — the config is the one that is read |
| the file is excluded by `.gitignore` (`git check-ignore .inspire/config.json`) | error — an uncommitted config reaches no teammate and no factory run |
| a key INSPIRE does not list | info — kept, and read by nothing INSPIRE ships |

## Changing a root

A root is part of the product's shape. Changing one moves where every skill reads
and writes code, so it runs through the `stack` flow
([`stack-interview.md`](stack-interview.md) § Product roots) and is recorded as an
ADR. Write the new value here, then re-run `/inspire-config emanate`: every command
and claim root in `.inspire/emanate.yml` starts with the old one.

## Changing the language

`[product]` The `language` flow sets `output_language`: the single language every
INSPIRE skill writes its artifacts in
([`_references/output-language.md`](../../_references/output-language.md)).

1. Read the current value from `.inspire/config.json`.
2. Ask for the language: an ISO 639-1 code or a plain name, the current value
   offered first. Say what it governs and what it does not:
   - **Governs:** every KB artifact — specs, features, ADRs, screens, the tracker,
     the bootstrap documents — and the project README.
   - **Does not govern:** the conversation language, or the product's own i18n. The
     KB stays in one language so the context people and agents share stays stable
     and diffable.
3. **Warn before changing it on a project that has artifacts.** Count the
   specification files under `inspire_kb/01_spec` that are not templates or READMEs.
   When there is at least one, say, before asking for approval:

   > `{n}` artifacts are written in `{old}`. They stay in `{old}`: changing the
   > language translates nothing. From now on every skill writes in `{new}`, so the
   > knowledge base holds two languages until the existing artifacts are translated.
   > Translating them is a refactor of the whole knowledge base, done on request and
   > reviewed like any other change.

   Offer the translation as a separate, later step. Never start it unasked. Machine-read
   tokens (frontmatter keys and values, link paths, file names, ids, section ids)
   are never translated.
4. Show the one-line diff of `.inspire/config.json` and write it on approval. Remove
   `output_language` from `project.md`'s frontmatter in the same diff when it is
   still there.
5. When the language is not English and `00_bootstrap/style-tokens.md` has no rows,
   propose tokens in that language: for R6, words that narrate the past
   (`anteriormente`, `antes se`, `migrado desde`); for R7, intensifiers that rank a
   fact instead of stating one (`simplemente`, `por supuesto`, `sin duda`). Keep a
   word only if it almost never states present behavior in that language, and write
   the rows the operator approves. An empty list is a valid answer.
6. Tell the operator to commit the file, and that the new language reaches a session
   when it starts: the current session keeps the one it started with.
