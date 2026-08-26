# Version manifests

One file per released version: `{version, released, commit, layout, files}`,
where `files` maps a **project-relative materialized path** to the sha256 of
what INSPIRE shipped at that version.

Generated, never hand-written:

    bash plugin/scripts/gen-manifest.sh --tag v0.4.0 --repo . > plugin/manifests/0.4.0.json

`plugin/test/test-manifest.sh` regenerates every file here and fails if any of
them differs from its tag. A manifest that cannot be reproduced means the
release is broken.

## `layout` names a tree SHAPE, not a payload inventory

The `layout` field points at a row in `plugin/scripts/hops/layouts.tsv`, and that
row says where each `base/` directory materializes. Only a **move** — a root
relocating, the way `bin/` went from `.claude/bin` to `.inspire/bin` at 0.3 — is
a new layout. A payload class that is merely **added** (0.8's `base/agents/` →
`.claude/agents/`) extends the existing row's `dest_map` and leaves every shipped
manifest's `layout` value exactly as it was.

That is not a convenience. An additive class changes no shape, so a new layout id
could only reuse 0.3's own structural markers — two ids `verify_layout` cannot
tell apart, and any score tie between them becomes the cross-layout tie
`detect_version` refuses outright instead of resolving to the higher version. The
full argument is in `layouts.tsv`'s header.

For the files here it means the addition is invisible: `gen-manifest.sh` reads the
new class per release, finds nothing under `plugin/base/agents/` at any tag up to
`v0.7.0`, and regenerates all nine manifests byte-identically. **Never edit a
shipped manifest to keep up with a new class** — if one stops reproducing, the
generator is wrong, not the manifest.

## Scope: releases only

Each file describes a *tagged release*, and every release maps to exactly one
commit. Untagged intermediate states do not appear here and never will.

One such state is worth knowing about because a stale comment in
`.claude/hooks/template-runtime-version.sh` describes it as "0.1.0 naming two
runtimes": `d41fd89` also declares `0.1.0`, but the bump to `0.2.0` landed in the
next commit (`1045ff9`) before `v0.2.0` was tagged, so `d41fd89` was never
released. A project cloned from the template inside that window has a runtime no
manifest describes. Detection degrades gracefully rather than failing: it scores
just under 100% against `0.1.0`, still nominates it, and — since 0.1 and 0.2
share a layout — hops identically. A few files may be treated as locally edited
when they were not, surfacing as extra prompts, never as lost work.
