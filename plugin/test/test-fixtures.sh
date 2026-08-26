#!/usr/bin/env bash
# Tests plugin/test/lib/fixtures.sh — the period-correct fixture builder.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
. "$HERE/lib/fixtures.sh"

# THIS SUITE'S SUBJECT IS THE BUILDER, so it must never inherit a cache: a runner
# that exports INSPIRE_FIXTURE_CACHE would otherwise turn every build below into a
# `cp -R` and the builder's own coverage would quietly vanish. Proved by probe:
# with the variable pointing at a deliberately corrupted cache, two of the 0.2.1
# assertions went red before this line existed. The cache assertions at the bottom
# set the variable per call instead, on a cache they build themselves.
unset INSPIRE_FIXTURE_CACHE

. "$HERE/lib/assert.sh"

w2="$(mktemp -d)"
p2="$(fixture_from_tag v0.2.1 "$w2" "$REPO")"

check "0.2.1 fixture: KB at .inspire_kb"      "[ -d '$p2/.inspire_kb' ]"
check "0.2.1 fixture: no inspire_kb"          "[ ! -d '$p2/inspire_kb' ]"
check "0.2.1 fixture: validators at .claude/bin" "[ -f '$p2/.claude/bin/review.sh' ]"
check "0.2.1 fixture: hooks at .claude/hooks"    "[ -f '$p2/.claude/hooks/session-start.sh' ]"
check "0.2.1 fixture: fixtures were copied"      "[ -d '$p2/.claude/bin/test' ]"
check "0.2.1 fixture: lock says 0.2.1" \
  "[ \"\$(jq -r .inspire_version '$p2/.inspire.lock')\" = '0.2.1' ]"
check "0.2.1 fixture: lock has no files map" \
  "[ \"\$(jq -r 'has(\"files\")' '$p2/.inspire.lock')\" = 'false' ]"
fixture_cleanup "$w2"

w3="$(mktemp -d)"
p3="$(fixture_from_tag v0.3.1 "$w3" "$REPO")"
check "0.3.1 fixture: KB at inspire_kb"       "[ -d '$p3/inspire_kb' ]"
check "0.3.1 fixture: validators at .inspire/bin" "[ -f '$p3/.inspire/bin/review.sh' ]"
check "0.3.1 fixture: no bin/test"            "[ ! -d '$p3/.inspire/bin/test' ]"
check "0.3.1 fixture: lock has files map" \
  "[ \"\$(jq -r 'has(\"files\")' '$p3/.inspire.lock')\" = 'true' ]"
fixture_cleanup "$w3"

# ---------------------------------------------------------------------------
# The per-run fixture cache.
#
# The BUILDER is still the subject of this suite — the two blocks above build from
# scratch and must never read a cache. These assertions are about the accelerator:
# that a hit is a faithful copy of a tree this same builder made, that it is
# DISTINGUISHABLE from a rebuild (it stages no src/), that an unset variable still
# takes the old path, and that the integrity fingerprint the runner will compare
# actually notices a mutation.
# ---------------------------------------------------------------------------
cache="$(mktemp -d)"
fixture_cache_build "$cache" "$REPO" v0.2.1 v0.6.0; cb_rc=$?
eq "fixture_cache_build returns 0" "$cb_rc" "0"
check "fixture_cache_build produced the pre-0.3 tag" "[ -f '$cache/v0.2.1/proj/.inspire.lock' ]"
check "fixture_cache_build produced the 0.3+ tag"    "[ -f '$cache/v0.6.0/proj/.inspire.lock' ]"
check "fixture_cache_build drops the staged src/"    "[ ! -d '$cache/v0.6.0/src' ]"

fp1="$(fixture_cache_fingerprint "$cache")"
eq "the cache fingerprint is stable across two calls" "$(fixture_cache_fingerprint "$cache")" "$fp1"
check "the cache fingerprint is a sha256" "printf '%s' '$fp1' | grep -Eq '^[0-9a-f]{64}$'"

# A one-byte mutation must move it — that comparison is the whole point of the
# check the runner makes after building and again before exit.
printf 'x' >> "$cache/v0.6.0/proj/.inspire.lock"
check "a one-byte mutation changes the cache fingerprint" \
  "[ \"\$(fixture_cache_fingerprint '$cache')\" != '$fp1' ]"
python3 - "$cache/v0.6.0/proj/.inspire.lock" <<'PY'
import sys
p = sys.argv[1]
d = open(p, 'rb').read()
open(p, 'wb').write(d[:-1])
PY
eq "removing that byte restores the fingerprint" "$(fixture_cache_fingerprint "$cache")" "$fp1"

# A hit: copied from the cache, and observably not rebuilt.
hw6="$(mktemp -d)"
p6h="$(INSPIRE_FIXTURE_CACHE="$cache" fixture_from_tag v0.6.0 "$hw6" "$REPO")"
check "a cache hit prints a project root" "[ -n '$p6h' ] && [ -d '$p6h' ]"
check "a cache hit stages no src/"        "[ ! -e '$hw6/src' ]"
eq "a cache hit is byte-identical to the cache entry (0.3+)" \
   "$(fixture_cache_fingerprint "$p6h")" "$(fixture_cache_fingerprint "$cache/v0.6.0/proj")"

# The full claim, on the tag whose build is deterministic: a hit equals an
# INDEPENDENT fresh build, modes included. The fresh build also shows that with
# the variable unset the old path is what ran — it stages src/, a hit never does.
fw6="$(mktemp -d)"; p6f="$(fixture_from_tag v0.6.0 "$fw6" "$REPO")"
check "premise: with the variable unset the builder really built (it staged src/)" \
  "[ -d '$fw6/src' ]"
eq "a cache hit equals an independent fresh build (0.3+)" \
   "$(fixture_cache_fingerprint "$p6h")" "$(fixture_cache_fingerprint "$p6f")"

# Pre-0.3, the same claim minus the two things a pre-0.3 build cannot reproduce:
# .git (its commit object carries a timestamp) and .inspire.lock, whose
# template_sha is that throwaway repo's own commit sha. Everything else matches
# exactly — measured, not assumed.
hw2="$(mktemp -d)"
p2h="$(INSPIRE_FIXTURE_CACHE="$cache" fixture_from_tag v0.2.1 "$hw2" "$REPO")"
check "a cache hit stages no src/ (pre-0.3)" "[ ! -e '$hw2/src' ]"
eq "a cache hit is byte-identical to the cache entry (pre-0.3)" \
   "$(fixture_cache_fingerprint "$p2h")" "$(fixture_cache_fingerprint "$cache/v0.2.1/proj")"
fw2="$(mktemp -d)"; p2f="$(fixture_from_tag v0.2.1 "$fw2" "$REPO")"
fx_prune(){ local d; d="$(mktemp -d)"; ( cd "$1" && tar cf - . ) | tar xf - -C "$d"
            rm -rf "$d/.git" "$d/.inspire.lock"
            fixture_cache_fingerprint "$d"; rm -rf "$d"; }
eq "a cache hit equals an independent fresh build (pre-0.3, minus .git and the lock)" \
   "$(fx_prune "$p2h")" "$(fx_prune "$p2f")"

fixture_cleanup "$hw6"; fixture_cleanup "$fw6"
fixture_cleanup "$hw2"; fixture_cleanup "$fw2"
rm -rf "$cache"

summary
