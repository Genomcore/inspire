---
name: release-entry
description: Prepare a PR into the open release/YYYY-MM-DD branch so it carries the release with it — bump the version if the release has not yet, add this PR's CHANGELOG entry, regenerate the manifest. Use before opening or updating a PR into a release branch, when the Release check or the gh pr create hook reports a missing bump, a stale manifest or a missing CHANGELOG entry, or after rebasing such a PR onto the release.
---

# A PR's share of the release

Every PR into `release/YYYY-MM-DD` brings what the release needs to reach `main`,
so nothing is written by hand when the release closes. Three things, checked by
the Release check in CI and by `.claude/hooks/template-runtime-version.sh` on
`gh pr create --base release/…` (self-test:
`bash .claude/hooks/template-runtime-version.sh --check-release origin/<release> HEAD`):

1. **The version is above `main`'s** — in `plugin/.claude-plugin/plugin.json` and
   `.claude-plugin/marketplace.json`, the same value.
2. **The manifest describes the tree** — `plugin/manifests/<version>.json`.
3. **This PR adds its entry to `## <version>` in `CHANGELOG.md`**, if it changes
   the runtime (anything under `plugin/` except `plugin/test/`,
   `plugin/base/bin/test/` and `plugin.json` itself).

Work on the PR's branch, up to date with the release
(`git fetch origin && git rebase origin/release/YYYY-MM-DD`).

## 1. Version

Compare `version` in `plugin.json` on the branch with `origin/main`:

- **Already above `main`** (someone in this release bumped it, or this branch did):
  leave it.
- **Equal to `main`**: bump to the next **minor** (`0.21.0` → `0.22.0`) in both
  files, and set `released` in `plugin.json` to today. Commit
  `chore(release): <version>`. Every PR of the release makes this same change, so
  the first one to merge brings it and git merges it cleanly in the rest.

Patch versions are for `hotfix/` branches into `main`, not for the release.

## 2. CHANGELOG entry

Only if this PR changes the runtime. Read the top of `CHANGELOG.md` and the latest
section to match its voice, then:

- If there is no `## <version> — YYYY-MM-DD` section, add it above the previous
  release, with today's date and a lead paragraph that starts
  "Upgrade with `/inspire:update`" and says what an existing project must do. Keep
  the date of an existing section.
- Add this PR's bullets under the headings it needs, in this order: **Breaking for
  existing vaults**, **Added**, **Changed**, **Fixed**. Create a heading only if it
  does not exist yet; never reorder or rewrite other PRs' bullets.
- Write for someone maintaining a project that uses INSPIRE: what changes for them,
  in prose, starting with a bold phrase. Derive it from the diff and the ticket,
  not from commit messages. If the PR changes what a project must do after
  `/inspire:update`, add it to the lead paragraph too.

Commit `docs(changelog): <ticket or topic> in the <version> section`.

## 3. Manifest

Regenerate it after the commits above, from the branch's HEAD:

```sh
bash plugin/scripts/gen-manifest.sh --tag HEAD --repo . > plugin/manifests/<version>.json
```

Commit it if it changed (`chore(release): regenerate the <version> manifest`). The
`commit` field always names the commit before its own; the checks ignore it.

## Conflicts

Parallel PRs of the same release touch the same three places. When the branch
conflicts with the release after another PR merges:

- **Version files**: take the release's side; it is the same version.
- **`CHANGELOG.md`**: keep both sides' bullets under each heading.
- **The manifest**: take either side, then regenerate it (step 3) — never merge it
  by hand.

Then run the self-test above until it passes.
