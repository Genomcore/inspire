# INSPIRE test estate — guide for Claude

`bash plugin/test/run.sh` runs everything (see the root `AGENTS.md`). This file
carries what matters only when working on the tests themselves.

## Golden jobs

The validators run via golden fixtures — `run-tests.sh <rule>` per rule, plus its
seven hand-wired siblings. A rule with more than a dozen fixtures is **sharded**
into several jobs, each `run-tests.sh <rule> <scenario>…` over a round-robin
slice, and reported as `golden/<rule>#N`: one `run-tests.sh` is one process
however many cores the machine has, so an unsharded 87-fixture rule sets the
run's floor on its own. The PASS/FAIL lines are per scenario either way, so
`--inventory` cannot tell whether a rule was sharded — which is what makes
changing the shard size safe. A filter still names the rule
(`run.sh golden/emanate-plan` runs all of its shards). `golden/emanate-derive`
is among the heaviest, at 87 fixtures: derive runs the rules that own the `OS-*`
classes rather than re-implementing them, so most fixtures spawn four validators
— the twelve catalog ones spawn none, because no review rule owns a component's
or a pattern's shape. **Each hand-wired sibling counts as one run-level
assertion**, so adding assertions inside one does not move `run.sh`'s total;
read its own summary for that.

## Running a single file

**Every file also runs on its own**, from any directory and with no
environment: `bash plugin/test/upgrade/06-hop-ops.sh` builds what it needs and
prints its own summary; the cache is an accelerator, never a dependency. The
shared assertion vocabulary is `plugin/test/lib/assert.sh` — `plugin/test/lib/`
holds no tests and the runner never runs it.

## Cost

A run takes minutes rather than seconds, and that is fixture builds and
process spawns, not a hang. **Do not record wall-clock figures in this file** —
measurements of the same job on the same machine vary by more than the jobs
differ from each other, so a number here measures load rather than the estate.
Measure it yourself when you need to know.

The shape is stable. The run is **spawn-bound**: roughly four-fifths kernel
time, `fork` and `exec` rather than computation. So raising `-j` past the core
count buys nothing, and the lever that works is "spawn fewer processes" rather
than "schedule better". Cost follows the process count almost exactly — the
`emanate-plan` fixtures run ~28,000 of them per sweep, and measured system time
matches that at the few milliseconds a `fork`+`exec` costs. The heavy jobs are
`emanate-derive` and `emanate-plan`, at 87 and 76 fixtures, because each
fixture spawns a rule and the validators under it; `run.sh` **shards** both
(see above). Next come a handful of `upgrade/` and `materialize/` files that
build several period-correct fixtures each.

## Parallel safety

Every job is **parallel-safe**: every scratch tree is a private `mktemp` one
and the repo is only ever read, so any number of copies — several worktrees at
once, the same file twice over, a single file beside a full run — run
concurrently without interfering. The one shared tree is the fixture cache each
`run.sh` builds inside its own `mktemp -d`: read-only to the jobs,
fingerprinted after the build and again before exit, so a job that writes into
it fails the run and the failure names the cache rather than the job. Keep the
cache inside `mktemp -d`: a fixed path under `/tmp` produces phantom failures
in the upgrade suite.

## Fixtures

Fixtures cost the repo nothing: every tag ships a runnable installer, so
`git archive <tag>` plus that era's own installer yields a genuine
period-correct project tree. `plugin/test/lib/fixtures.sh` does this — prefer it
over hand-built trees, and note that a pre-0.3 project legitimately retains
`.inspire/{bin,hooks,skills,templates}` as the staged source `install.sh` copied
FROM. An assertion on the destination alone is **vacuous** here: "the
destination exists" passes whether or not the code under test ran, and seven
assertions in this repo have been vacuous for exactly that reason. Assert the
source side too, or pick a path the old installer cannot have staged. When unsure,
stub the function to a no-op *on a copy* and confirm the assertion fails.
