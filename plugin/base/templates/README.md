# `.inspire/templates` — files materialized at instantiation

Templates that [`materialize.sh`](../scripts/materialize.sh) writes into the **product
side** of a fork when the runtime is instantiated. They do **not** exist in the template
repo itself — they are created (idempotently, never clobbering existing content) in a
project the first time `materialize.sh` runs (via `/inspire:init`).

- `prototype-README.md` → `/prototype/README.md` — seeds the horizontal-prototype
  folder with its guidance stub.
- `source-README.md` → `/source/README.md` — seeds the production-monorepo folder
  with its guidance stub.
- `CLAUDE.md` → `/CLAUDE.md` — seeds the project root with a provisional stub
  orienting an agent to the INSPIRE-governed project (the KB layout, the
  `inspire_*` skills, the validators, `.inspire.lock`), with the project's name,
  purpose and stack left as clearly marked placeholders. `/inspire_bootstrap init`
  refines it in place afterwards. Never clobbered — a brownfield adopter's own
  `CLAUDE.md` is left untouched.

The project's own root `README.md` is **not** here: it is not a static copy but is
generated interactively by `/inspire_bootstrap init` (asking for title, git remote
and description). A project materialized from the plugin never carries the template's
own methodology README, so this is the only place it gets one.

`.gitignore` is likewise not a static template here: `materialize.sh` writes its
entries (chiefly `.claude/settings.local.json`) directly, appending them under a
marked block if a `.gitignore` already exists rather than replacing the file.
