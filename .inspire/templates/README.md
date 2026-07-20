# `.inspire/templates` — files materialized at instantiation

Templates that [`install.sh`](../install.sh) writes into the **product side** of a
fork when the runtime is instantiated. They do **not** exist in the template repo
itself — they are created (idempotently, never clobbering existing content) in a
project the first time `install.sh` runs.

- `prototype-README.md` → `/prototype/README.md` — seeds the horizontal-prototype
  folder with its guidance stub.
- `source-README.md` → `/source/README.md` — seeds the production-monorepo folder
  with its guidance stub.

The project's own root `README.md` is **not** here: it is not a static copy but is
generated interactively by `/inspire_bootstrap init` (asking for title, git remote
and description). `install.sh` only removes the template's methodology README so
the fork starts without it.
