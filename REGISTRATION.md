# T7 — `emanate-harvest.sh` — registration notes

One insertion into one shared registration point, for the main session to
apply at merge. It is a literal find-and-replace; nothing here needs
judgement. Branch: `emanation/t07-harvest`.

`emanate-harvest.sh` is a tool, not a review rule (D8; trust.sh's precedent):
it is deliberately absent from `review.sh`'s `DEFAULT_RULES`, which stays
untouched by this package. Nothing here is required for
`bash plugin/base/bin/test/run-tests.sh` to pass — `run-tests.sh` itself
hand-wires `test-harvest.sh` in, the same way it already does for
`test-trust.sh`. What registration buys is the roster in
`plugin/base/bin/README.md` telling the truth about a fourth tool living
alongside `trust.sh`.

`CLAUDE.md`'s `base/bin/` bullet needs **no edit** — it names `trust.sh` as an
example of a tool living in `base/bin/`, not as an exhaustive list, so adding
a second tool falsifies no sentence there.

---

## 1 · `plugin/base/bin/README.md` — the Library table gains a row

Appended directly below the existing `trust.sh` row, so the table lists both
tools that are `review.sh`-exempt, in the order they shipped.

FIND:

```
| `trust.sh` | **A tool, not a review rule.** Artifact trust: `skill-sha` (composite hash of a deployed skill dir), `stamp` (the machine-owned `produced:` block), `endorse` (the human-owned `endorsed:` block), `report` (the trust signal). It emits no findings, is deliberately absent from `review.sh`'s `DEFAULT_RULES`, and `report` exits 0 whatever it finds — a signal, never a gate. Needs only `yq` (no `jq`), and does not source `_lib.sh`. | `stamp` / `endorse` from the owning skills; `report --summary` from the `pre-pr.sh` hook; the full `report` from `/inspire_workspace review` and the `/inspire:update` tail. |
```

REPLACE WITH:

```
| `trust.sh` | **A tool, not a review rule.** Artifact trust: `skill-sha` (composite hash of a deployed skill dir), `stamp` (the machine-owned `produced:` block), `endorse` (the human-owned `endorsed:` block), `report` (the trust signal). It emits no findings, is deliberately absent from `review.sh`'s `DEFAULT_RULES`, and `report` exits 0 whatever it finds — a signal, never a gate. Needs only `yq` (no `jq`), and does not source `_lib.sh`. | `stamp` / `endorse` from the owning skills; `report --summary` from the `pre-pr.sh` hook; the full `report` from `/inspire_workspace review` and the `/inspire:update` tail. |
| `emanate-harvest.sh` | **A tool, not a review rule.** Worktree diff → integration-branch commit (the emanation loop's harvest step, D4/D8): diffs a phase worktree against an integration branch since their common cut point, accepts only the phase's owned git pathspecs into one commit, refuses on conflict or an empty owned diff, and discards the worktree on request. Pure git plumbing — the integration branch is never checked out, and `--mode plan`/`--dry-run` writes no ref, reflog entry or index. It emits no findings and is deliberately absent from `review.sh`'s `DEFAULT_RULES`. Needs `jq` (for its JSON summary) and does not source `_lib.sh`. | The `emanate run` orchestrator's harvest step, once per phase per unit. |
```
