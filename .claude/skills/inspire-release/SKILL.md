---
name: inspire-release
description: Prepare, merge and publish an INSPIRE release from this template repo — version bump in both manifests, the hash manifest, the CHANGELOG section, then the post-merge tag and GitHub release. Use when cutting, tagging or publishing an INSPIRE version.
---

# Releasing INSPIRE

## Preparing the release PR

A release needs both `plugin/.claude-plugin/plugin.json` and
`.claude-plugin/marketplace.json` bumped together, a matching
`plugin/manifests/<version>.json`, and a `CHANGELOG.md` section — the root
changelog is the release-note channel, one section per release, and the
convention starts at 0.9.0. `.claude/hooks/template-runtime-version.sh`
blocks `gh pr create` if the two versions diverge, if the runtime changed without a
bump, or if the version is already tagged. `plugin/scripts/` is deliberately **not**
exempt from that check: it decides how every install behaves. The manifest is
generated **last**, from the commit carrying the bump: it hashes
`plugin/base/{bin,hooks,skills,agents}`, so any change under those four
classes afterwards invalidates it — while `CHANGELOG.md`, `AGENTS.md`, `CLAUDE.md`,
`docs/`, `base/kb/` and `base/templates/` do not perturb it.

## After the merge

**Merging is not releasing.** Two steps follow the merge, in this order:

1. **Cut a lightweight tag `v<version>` on the merge commit** —
   `git tag v<version> <merge-sha> && git push origin v<version>`. Every
   release does it this way: `v0.9.0`, `v0.9.1` and `v0.9.2` all point at
   their PR's merge commit, not at the bump commit inside it.
2. **Publish a GitHub release** for that tag, titled `v<version>`, whose body
   is that version's `CHANGELOG.md` section with the `## <version> — <date>`
   heading dropped — `gh release create v<version> --title v<version>
   --notes-file <notes>`. The changelog section *is* the release notes; there
   is no second place to write them.

The tag carries two checks, and both go quiet without it.
`plugin/test/manifest/03-reproduction-sweep.sh` checks an
**untagged** manifest by regenerating from the commit the manifest itself
names — self-referential, so it only proves the manifest describes the commit
it claims to; the **tagged** path regenerates from the tag with `.commit`
excluded, which is the check that proves the manifest describes what was
actually released. And `fixture_from_tag` builds every period-correct fixture
with `git archive <tag>`, so a version that was never tagged can never become
a fixture, and the upgrade suite permanently loses the ability to test
upgrading *from* it.
