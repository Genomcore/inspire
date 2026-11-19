# Config — project identity
> Part of [inspire-config](../SKILL.md). Read when the entry's index routes here.

`[product]` The `identity` flow gives the project its name and purpose in the two
files a newcomer opens first: the seeded `CLAUDE.md` and the root `README.md`. A
project materialized from the plugin never carries the template's own methodology
README, so a fresh project has none until this flow writes it.

## `CLAUDE.md`

`/inspire:init` seeds a provisional stub (project name, purpose and stack left as
placeholders, clearly marked). Replace those placeholders **in place** with the
project's real name, a one- or two-line purpose, and a short summary of the
`stack.md` just confirmed — never append a second copy of the orientation content
below it. If no `CLAUDE.md` exists (a brownfield adopter removed it, or
`/inspire:init` was never run), create one carrying the same INSPIRE-orientation
content as the stub `/inspire:init` seeds as the project's `CLAUDE.md`, then refine
it the same way. Leave the rest of the file (the INSPIRE orientation, KB layer
list, skills, validators, lock note, and the § How prose is written here summary
of the writing contract) untouched — that part is generic and correct as shipped.

## `README.md`

Create (or update) the **project's root `README.md`** — the product's own front
door, not INSPIRE's. Keep it **easy and optional**: propose good defaults, ask in
one short pass, and let the operator skip any field with Enter. Write it in the
project's `output_language` (default English).

1. **Gather sensible defaults first** (don't make the operator supply what you can
   infer):
   - **Title** — default to the repo/directory name, humanized (e.g. `my-app` →
     "My App"). Confirm or override.
   - **Description** — ask for a one-line description (optional; skippable).
2. **Ask them together, all optional.** Present both prefilled and invite edits in
   a single exchange — e.g. "Title [My App] · Description [ ] — keep, or change?".
   Never block: Enter accepts the defaults, blanks are fine.
3. **If a `README.md` already exists** that is *not* the template's methodology
   README (the template one is removed at install), show a diff and confirm before
   overwriting — treat it as the operator's file.
4. **Write a lean project README** from the answers. Keep it minimal — this is a
   starting point the operator will grow:

   ```markdown
   # {Title}

   {Description — omit this line if skipped}

   ## Development

   Built with the [INSPIRE](https://inspire.openbims.dev) methodology. Project
   intent and specs live in [`inspire_kb/`](inspire_kb/); the guardrail runtime
   and agent skills are in `.claude/`{CLAUDE.md pointer}.
   ```

   `{CLAUDE.md pointer}` is `" (see [`CLAUDE.md`](CLAUDE.md))"` when `CLAUDE.md`
   exists at the project root — the normal case, since `/inspire:init` seeds it
   and § `CLAUDE.md` above refines it first — otherwise the empty string, so the
   README never links a file that isn't there.

   Drop any section whose input was skipped. If everything was skipped, write just
   the title heading plus the `## Development` note.
5. **The git remote is not a README field.** The wizard asks it, optionally, to wire
   local git ([`wizard.md`](wizard.md), T5); it is not stored here — don't add a
   "Repository" line.
