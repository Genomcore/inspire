# Config — validating the file
> Part of [inspire-config](../SKILL.md). Read when the entry's index routes here.

Validation has three layers. The factory's reader decides the format. This skill
then checks what the reader cannot see. The image probe, which needs Docker, is
optional. INSPIRE keeps no copy of the format's rules: a copy would drift from the
reader, and the run applies the reader's rules anyway.

## 1. The factory's reader

Locate the factory checkout through `INSPIRE_FACTORY_ROOT`; when it is unset, ask
the operator for the path. Anyone who launches a factory run already has that
checkout and `bun`. Then run its project-file check on the draft, from the
project root:

```
bun --config="$INSPIRE_FACTORY_ROOT/orchestrator/bunfig.toml" --no-env-file \
  "$INSPIRE_FACTORY_ROOT/orchestrator/src/check-project.ts" .inspire/emanate.yml
```

| Exit | Meaning | Act |
|---|---|---|
| `0` | valid; the parsed config is printed as JSON | show the normalized roots and phases |
| `2` | usage | this skill built the command; report it as an internal error |
| `3` | the file is missing | write it first |
| `4` | invalid; the reader's message is on stderr | fix that one error and run again |

The reader stops at the first error, so loop one error per round until `0`. The
check also requires `image`, which the bare reader accepts absent and the runner
does not.

**No factory checkout, or no such command in it: say *validation pending*.**
Never present the file as valid on the strength of this skill's own reading.

## 2. What the reader cannot see

Run these after exit `0`. An error blocks the write; the operator may accept a
warning explicitly.

| Check | Severity | Why |
|---|---|---|
| a repeated key at any level | error | the parser keeps the last value silently. `yq '[.. \| select(tag == "!!map") \| (keys \| length) - (keys \| unique \| length)] \| max'` above 0 means one |
| an unquoted string value | error | a leading `&` or `!`, or a ` #`, changes the command without an error ([`format.md`](format.md) § Quoting) |
| `HOME`, `PATH`, `USER`, `DOCKER_*`, `LITELLM_*`, `ANTHROPIC_*` in `env` | error | they override the factory's own |
| `localhost` in an `env` URL | error | inside a unit the host is the service name |
| a `## Test infrastructure` row with no service | error, unless the operator accepts it as external (Q4) | every unit would start without it |
| a root that is `.`, a glob, or holds `node_modules`, `target`, `.venv`, `dist-newstyle` | error | silently uncited claims, or a scan of every dependency |
| `--watch`, `--watchAll`, `npm run dev`, a server in the foreground | error | no timeout: the unit hangs |
| `sudo`, `apt-get`, `npm install -g` in `setup` or a check | error | no root, `--cap-drop ALL` |
| a secret-looking value in `env` | warning | committed, and shown to every agent |
| an `env` URL host that is not a service | warning | it will not resolve |
| a root that does not exist yet | warning | skipped silently; fine when the scaffold will create it |
| a multi-line `run` without `set -e`, a pipe without `set -o pipefail` | warning | a red check reads green |
| `vitest` without `run`; Jest or Vitest with no worker limit | warning | the first may wait; the second risks running out of memory |
| `npm run <x>` with no script `<x>`; `npx --no-install <bin>` with `<bin>` not a dependency | warning | the command fails in every unit |
| an image tag ending `-slim` or `-alpine`, or `latest` | warning | no `git`, musl, or a toolchain that moves between runs |
| `uv sync --frozen` | warning | propose `--locked` |
| a review check whose name repeats another review check's | error | the runner stops before the release |
| a review `skills` name with no `.claude/skills/<name>/SKILL.md` committed, and not a factory skill | error | the runner stops before the release |
| a review `read` file not committed, or a `#Section` with no `## <Section>` heading in it (in no profile, for `{profiles}`) | error | the runner stops before the release |
| a review check without `focus` | warning | the reviewer judges every rule it was given |

## 3. The image probe (optional)

Only with Docker present and an explicit yes from the operator. Without it, write
the file and report the image as *not probed*. The probe mirrors the factory's own:

```
docker pull "$IMAGE"
docker run --rm --user 1000:1000 -e HOME=/tmp --cap-drop ALL \
  --security-opt no-new-privileges --workdir / --entrypoint bash "$IMAGE" \
  -c 'command -v git && ldd --version && node --version && npm --version'
```

Replace the tools in the last line with the ones `setup` and the checks call
(`uv`, `cargo clippy`, `cabal`). A failed pull means the run will fail the same
way. `1000:1000` is the factory's default orchestrator user.

Never start a service to try its healthcheck: services are the factory's, started
fresh for each unit. A wrong healthcheck surfaces in the run's first 60 seconds,
and its message names it.

## 4. Commit, then hand over

The factory clones the project's **base branch** and reads the file committed
there. The working tree never reaches it. The base branch is `base_branch` in
`.inspire/emanate.json`: `main` when the key or the file is absent, the current
branch when it is `null`. A file that is not committed passes the launcher and
then stops the run with
`.inspire/emanate.yml is missing: commit the project configuration (see emanate.example.yml)`.

The operator commits; offer the command, never run it unasked. Then close with:

- a table of key → origin (derived, proposed, answered);
- the phase rules from [`format.md`](format.md) § How the factory runs the phases;
- that agents cannot fix the file mid-run, so a wrong value costs every unit;
- that only the worktree persists between containers, so caches under `HOME` are
  lost;
- whatever is still undecided, and *validation pending* if layer 1 did not run.
