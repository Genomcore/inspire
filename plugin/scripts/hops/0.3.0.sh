#!/usr/bin/env bash
# Layout hop: pre-0.3 → 0.3.0.
#
# Sourced by lib/chain.sh with hop-ops already initialised. Every line below is
# a literal operation; nothing is derived, nothing is conditional.
#
# What moved in 0.3.0:
#   .inspire_kb/   → inspire_kb/
#   .claude/bin/   → .inspire/bin/            (bin/test/ dropped)
#   .claude/hooks/ → .claude/inspire/hooks/
#   .inspire/{skills,templates,install.sh,manifest.json} — the staged source, retired
# Skills did NOT move: .claude/skills/ is the same in both layouts.

hop_mv .inspire_kb inspire_kb

# DESIGN DECISION: .inspire/bin already exists at 0.2 as the STAGED SOURCE
# install.sh copied FROM (same 14 validators + the 114-file bin/test/ fixture
# tree, byte-identical to .claude/bin — verified against a real v0.2.1
# fixture). At 0.3 that same path becomes the DESTINATION for the moves
# below. hop_rm_owned cannot clear it first: the 0.2.1 manifest lists only
# materialized .claude/** paths, zero .inspire/** entries, so hop_rm_owned
# would find nothing "decided" and — worse than a no-op — would journal every
# one of those 128 files as "yours — not shipped by INSPIRE", which is false;
# we shipped every byte of it. There is no manifest-backed ownership rule that
# covers this prefix, so proving ownership per file is not available without
# inventing one, and doing that for a case that costs nothing to just report
# is not worth the complexity (see the lean-mode brief for this task).
#
# So: leave it alone and report it, exactly like the 0.2 staging source below.
# The per-file moves that follow still land correctly — hop_mv onto an
# existing FILE overwrites it, and content-wise both sides are ours with
# .claude/'s copy being the live one, so the result is the same as if this had
# been cleared first. Only .inspire/bin/test/ (114 files) has no destination
# at all in the 0.3 layout and is never touched by anything below; it is
# called out explicitly in the report so the operator knows it is inert
# residue, not a leftover the runtime still depends on.

hop_mv .claude/bin/_lib.sh                     .inspire/bin/_lib.sh
hop_mv .claude/bin/README.md                   .inspire/bin/README.md
hop_mv .claude/bin/review.sh                   .inspire/bin/review.sh
hop_mv .claude/bin/action-fields-in-entity.sh  .inspire/bin/action-fields-in-entity.sh
hop_mv .claude/bin/acyclic-deps.sh             .inspire/bin/acyclic-deps.sh
hop_mv .claude/bin/entity-coherence.sh         .inspire/bin/entity-coherence.sh
hop_mv .claude/bin/field-coverage.sh           .inspire/bin/field-coverage.sh
hop_mv .claude/bin/frontmatter-mechanics.sh    .inspire/bin/frontmatter-mechanics.sh
hop_mv .claude/bin/no-todos.sh                 .inspire/bin/no-todos.sh
hop_mv .claude/bin/rationale-wikilink.sh       .inspire/bin/rationale-wikilink.sh
hop_mv .claude/bin/sections-present.sh         .inspire/bin/sections-present.sh
hop_mv .claude/bin/stable-blockers.sh          .inspire/bin/stable-blockers.sh
hop_mv .claude/bin/touched-entity-lifecycle.sh .inspire/bin/touched-entity-lifecycle.sh
hop_mv .claude/bin/wikilinks-resolve.sh        .inspire/bin/wikilinks-resolve.sh

# bin/test/ never materialises from 0.3 on. Per file: an operator may have
# added fixtures of their own, and those survive and get reported.
hop_rm_owned .claude/bin/test

hop_mv .claude/hooks/session-start.sh .claude/inspire/hooks/session-start.sh
hop_mv .claude/hooks/pre-commit.sh    .claude/inspire/hooks/pre-commit.sh
hop_mv .claude/hooks/pre-pr.sh        .claude/inspire/hooks/pre-pr.sh

# Single files we shipped: ownership is provable by name.
hop_rm .inspire/install.sh
hop_rm .inspire/manifest.json
hop_rm .inspire/README.md

# The three 0.2 hook registrations point at .claude/hooks/ and carry no
# INSPIRE-MANAGED marker, so the marker-scoped re-merge cannot see them.
hop_unregister_hook '.claude/hooks/'

# NOT deleted. At 0.2 these were the operator's staging source: they edited
# here and ran install.sh. An edit never re-installed exists nowhere else, so
# deleting them can destroy work with no other copy. .inspire/bin/ joins this
# report for the reason argued above — it is also 0.2 staging residue, its
# stale bin/test/ fixture tree included, and nothing reads any of it any more.
hop_report '.inspire/skills/, .inspire/templates/ and .inspire/bin/ (including its stale bin/test/ fixture tree) were your 0.2 staging source — left untouched. Nothing reads them any more; remove them when you are satisfied the runtime is correct.'
hop_report '.manual/ and docs/adr/ came from the template fork — left untouched.'
