---
name: visor
description: "Serve this project's inspire_kb/ as a local website (Quartz) with search, backlinks and a graph coloured by unit kind. Use when the operator wants to browse or preview the knowledge base."
---

# /inspire:visor — the KB as a local site

Builds `inspire_kb/` with Quartz, using the configuration in `.inspire/visor/`, and serves
it on a local port. The site rebuilds when a KB file changes. The visor writes nothing in
`inspire_kb/` and changes no committed file under `.inspire/visor/`; Quartz and the built
site live in `.inspire/visor/.quartz/`, which is gitignored.

## Preconditions

1. `jq`, `yq` (Mike Farah v4) and `git` are on `PATH`.
2. Node 22 or later is on `PATH`, or Docker is running. Without Node, the visor runs
   Quartz in a container of the image `node_image` in `.inspire/visor/visor.yaml`.
3. The first run installs Quartz into `.inspire/visor/.quartz/` and needs the network.

## Step 1 — Start it

Run the launcher in the background (the Bash tool's `run_in_background`):

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/visor.sh" --project-root "$(git rev-parse --show-toplevel)"
```

Pass `--port N` when the operator asks for a port other than `port` in `visor.yaml`.
Live reload uses the next port, `N+1`.

## Step 2 — Report

Read the background output until it prints `Started a Quartz server listening at`, or
until the process exits.

- **It serves.** Give the operator the URL from the line
  `visor.sh: serving inspire_kb/ on http://localhost:N`.
- **Files left out.** If the output holds
  `visor.sh: left out of the site, their frontmatter does not parse:`, relay every path
  and parse error listed under it verbatim. The site serves without those files.
- **It exits.** Exit 1 is a refusal (the INSPIRE version of `.inspire.lock`, a missing
  `.inspire/visor/`, the Quartz version against a plugin's range, no Node and no Docker),
  3 is a failed Quartz install, 2 is a failed build. Relay the `visor.sh:` lines and the
  output after them verbatim, and do not work around them.

## Stopping it

Stop the background task. When the output named a Docker container
(`visor.sh: stop: docker stop inspire-visor-N`), also run that command.

## Checking without serving

`visor.sh --project-root … --check` runs every check and the build and serves nothing; it
exits 0 when the site builds.
