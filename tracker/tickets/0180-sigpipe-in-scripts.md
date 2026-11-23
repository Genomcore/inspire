---
id: 0180-sigpipe-in-scripts
title: "0180 — validators and hooks pipe into grep -q under pipefail"
created: 2026-11-17
updated: 2026-11-23
reporter: "@irene.gonzalez"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: Mid
skills: []
status: Open
blocked_by: []
related_to: []
---

## Origin

The same SIGPIPE pattern bit twice while releasing 0.18.0:

- The `Daily release` workflow piped `git show CHANGELOG.md` into an `awk` that stopped at
  the end of the version's section. `CHANGELOG.md` had grown past the 64 KB pipe buffer,
  `git show` died with SIGPIPE (141), `pipefail` failed the step, and `v0.18.0` was left
  untagged until it was published by hand. The workflow was fixed in PR #133.
- `upgrade/25-emanate-removal.sh` failed in CI with `printf: write error: Broken pipe` on
  an assertion whose text was in the output. Every `… | grep -q` in the test tree was
  rewritten in PR #135, and `plugin/test/AGENTS.md` records the rule.

Neither fix touched the shipped scripts, and they use the same pattern.

## Description

### The mechanism

`grep -q` exits on its first match. If the command writing into the pipe has more to
write, it gets SIGPIPE. Under `set -o pipefail` the pipeline's status is then 141, so a
condition that should be true reads as false. It only happens when the writer still has
output left after the match, which mostly means output larger than the pipe buffer, so it
is intermittent and depends on the size of the project.

### Where it appears in shipped code

Every file below runs with `set -o pipefail`, and each line tests the pipeline's status:

| File | Line | Pipe |
|---|---|---|
| `plugin/base/bin/screen-coherence.sh` | 241 | `printf '%s\n' "$SC_FACES" \| grep -qxF "$face"` |
| `plugin/base/bin/screen-coherence.sh` | 401 | `printf '%s\n' "$outcome" \| grep -qE '^set store …$'` |
| `plugin/base/bin/face-exposure.sh` | 102, 118 | `printf '%s\n' "$exposure" \| grep -qxF -e "$a" -e "$module"` (twice) |
| `plugin/base/bin/screen-presentation.sh` | 220–221 | `printf '%s' "$body" \| grep -qi …` (twice) |
| `plugin/base/bin/process-shape.sh` | 84 | `printf '%s\n' "$touched" \| grep -qxF "$e"` |
| `plugin/base/bin/spec-identity.sh` | 141 | `printf '%s\n' "$bundles" \| grep -qxF "$b"` |
| `plugin/base/bin/entity-datastore.sh` | 77 | `printf '%s\n' "$PROFILES" \| grep -Fxq -- "$stack"` |
| `plugin/base/bin/decisions.sh` | 48 | `head -1 "$1" \| grep -q '^---…$'` |
| `plugin/base/hooks/pre-commit.sh` | 46 | `printf '%s\n' "$modules" \| grep -qxF "$m"` |
| `plugin/scripts/visor.sh` | 168 | `ps -ww -p "$pid" -o command= \| grep -q …` |

A false negative there is a wrong result in the project, not a flaky test: a face or
bundle reported as undeclared, an exposure check skipped, a screen's hover check silently
not run.

Two hits of the same search are not affected: `migrate-kb.sh:289` reads a process
substitution, whose status is not part of the pipeline, and
`inspire-config/references/derive.md:72` is an example command in prose.

### What this ticket asks for

1. **Verify which lines can fail.** For each line above, decide whether the writer can
   still be writing after the match. `printf` of a variable writes in one call. A
   variable larger than the pipe buffer splits into several writes, so the size the
   variable can reach in a large project decides it. `head -1` writes one line, and
   `ps … -o command=` writes one short line, so both are probably safe.
2. **Fix the ones that can.** Use the form the tests now use, `… | grep [flags] >/dev/null …`,
   or a here-string, `grep -q … <<< "$var"`. Either way, no reader exits before the end of
   its input.
3. **Look at the other early readers.** About 16 `| head` pipes in `plugin/` outside the
   tests, and any `awk … exit`, have the same shape. Only those whose status is tested, or
   that run under `set -e`, matter.

If the verification shows that no shipped line can fail (every writer is a single write
smaller than the buffer), this ticket closes **Done with no code changed**. The close note
says why for each line.

## Acceptance criteria

- [ ] Each line in the table has a written verdict in this ticket: can fail, or cannot
      and why.
- [ ] Every line that can fail is rewritten so that no reader stops before the end of its
      input, and the validator's golden fixtures still pass.
- [ ] The `| head` and `awk … exit` pipes in `plugin/` outside the tests are checked the
      same way, and the ones that can fail are fixed.
- [ ] `plugin/base/bin/README.md` (or the validators' shared `_lib.sh` header) states the
      rule for new validators, as `plugin/test/AGENTS.md` does for tests.

## Notes

- The Factory's release workflow has the same template as this repository's. It was fixed
  in its own PR at the same time as PR #133. The Factory's own scripts are not covered
  here.
