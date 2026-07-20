# `.inspire` — the guardrail runtime (staged)

This folder holds the **deployable guardrail runtime** — the half of INSPIRE that
executes:

- [`skills/`](skills) — the `inspire-*` agent skills (the judgment half).
- [`bin/`](bin) — the validators + golden fixtures (the mechanical half).
  Test suite: `bash .inspire/bin/test/run-tests.sh`.
- [`hooks/`](hooks) — enforcement hooks: git-time `pre-commit` / `pre-pr`, plus
  `session-start` (injects the project's `output_language` into every session).
- [`templates/`](templates) — product-side files materialized at instantiation
  (the `prototype/` + `source/` README stubs).
- [`install.sh`](install.sh) — the instantiation script.

## Why it's staged here (dormant) instead of in `.claude/`

Claude Code auto-loads skills from `.claude/skills/` and runs hooks registered in
`.claude/settings.json`. If this runtime lived in `.claude/` inside the template
repo, those skills would fire while we **develop the template itself**. Keeping it
dormant in `.inspire/` avoids that; instantiation is what makes it live.

## Instantiate (run once per fork)

```bash
bash .inspire/install.sh
```

It copies `skills/`, `bin/`, `hooks/` into `.claude/` (where Claude Code discovers
and executes them), makes the scripts executable, wires the hooks into
`.claude/settings.json`, creates the product-side `prototype/` + `source/` folders
from `templates/`, and removes the template's own methodology `README.md` (the
fork gets its own via `/inspire_bootstrap init`). It is **idempotent** —
`.inspire/` stays the versioned source of truth, so re-run it after pulling
template updates to refresh `.claude/` (existing `prototype/`, `source/` and a
project's own `README.md` are left untouched).

> The skills reference each other and the validators via the **deployed** paths
> (`.claude/skills/…`, `.claude/bin/…`) — correct in a fork after install.

## What is NOT here

`.inspire/` is only the runtime. The rest of INSPIRE lives at the repo root:

- `.inspire_kb/` — the knowledge base (project content).
- `.manual/` — the methodology microsite.
- `prototype/` — the horizontal prototype · `source/` — the production monorepo.
  These are **not** in the template repo; `install.sh` creates them from
  `templates/` when a fork is instantiated.
