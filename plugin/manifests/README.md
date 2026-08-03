# Version manifests

One file per released version: `{version, released, commit, layout, files}`,
where `files` maps a **project-relative materialized path** to the sha256 of
what INSPIRE shipped at that version.

Generated, never hand-written:

    bash plugin/scripts/gen-manifest.sh --tag v0.4.0 --repo . > plugin/manifests/0.4.0.json

`plugin/test/test-manifest.sh` regenerates every file here and fails if any of
them differs from its tag. A manifest that cannot be reproduced means the
release is broken.

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
