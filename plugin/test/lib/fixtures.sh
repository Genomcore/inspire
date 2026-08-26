#!/usr/bin/env bash
# Builds a period-correct installed project from a git tag, using only
# read-only git operations against the source repo. The fixture gets its own
# throwaway git repo; the source repo is never written to.

# fixture_from_tag <tag> <workdir> <repo>  → prints the project root
#
# INSPIRE_FIXTURE_CACHE, when set and holding <tag>/proj, short-circuits the build
# to a `cp -R` of that tree. Period-correctness is untouched — the cache was built
# by this same function from this same tag — only the COUNT changes: the estate
# builds five trees per run instead of 42. With the variable unset this is
# byte-for-byte the old function, so a file run standalone behaves exactly as
# before: the cache is an accelerator, never a dependency.
#
# A CACHE HIT IS OBSERVABLE, and deliberately so: it creates no <workdir>/src,
# because it never unpacks the archive that a real build stages there. That
# absence is what the cache assertions in test-fixtures.sh key on — otherwise
# "the cache was read" and "the tree was rebuilt" are indistinguishable, which is
# the vacuity class this repo has been bitten by.
#
# `cp -Rp`, not `cp -R`: without `-p` the copy's modes go through the umask, so
# under `umask 077` a hit would hand the caller 600/700 where a fresh 0.3+ build
# sets 644/755 explicitly through _apply_write — a hit that differs from a build
# is exactly what this must not be. Under 022 (the suites' umask) the two are
# already equal, so nothing observable changes here; the flag makes it umask-proof.
fixture_from_tag() {
  local tag="$1" work="$2" repo="$3"
  local src="$work/src" proj="$work/proj" rc

  if [ -n "${INSPIRE_FIXTURE_CACHE:-}" ] && [ -d "$INSPIRE_FIXTURE_CACHE/$tag/proj" ]; then
    rm -rf "$proj"
    cp -Rp "$INSPIRE_FIXTURE_CACHE/$tag/proj" "$proj" || return 1
    printf '%s\n' "$proj"
    return 0
  fi

  mkdir -p "$src" "$proj"
  git -C "$repo" archive "$tag" | tar -x -C "$src" || return 1

  if [ -f "$src/.inspire/install.sh" ]; then
    # Pre-0.3: the fork IS the project. Install in place.
    rm -rf "$proj"
    cp -R "$src" "$proj"
    ( cd "$proj" \
      && git init -q \
      && git add -A \
      && git -c user.email=f@f -c user.name=f -c commit.gpgsign=false \
             -c core.hooksPath=/dev/null commit -qm "fixture $tag" \
      && bash .inspire/install.sh ) >/dev/null 2>&1
    rc=$?
  else
    # 0.3+: plugin materializes into a separate project root.
    ( cd "$proj" && git init -q \
        && bash "$src/plugin/scripts/materialize.sh" \
             --mode init \
             --plugin-root "$src/plugin" \
             --project-root "$proj" ) >/dev/null 2>&1
    rc=$?
  fi
  [ "$rc" -eq 0 ] || return 1

  printf '%s\n' "$proj"
}

fixture_cleanup() { [ -n "${1:-}" ] && rm -rf "$1"; }

# fixture_cache_build <cache-dir> <repo> <tag>...
#
# Build each tag into <cache-dir>/<tag>/ ONCE, in parallel, and return only when
# all of them are done (non-zero if any failed). INSPIRE_FIXTURE_CACHE is unset
# for each build: a cache is never built from a cache, or a corrupt entry would
# propagate itself forever.
#
# The staged <tag>/src is removed afterwards. It is the archive a build unpacks to
# install FROM, not part of the fixture, and leaving it would put ~900 files per
# pre-0.3 tag into the integrity fingerprint below — measuring the wrong tree, and
# slower.
fixture_cache_build() {
  local cache="$1" repo="$2"
  shift 2
  local tag pid pids="" rc=0
  mkdir -p "$cache" || return 1
  for tag in "$@"; do
    (
      unset INSPIRE_FIXTURE_CACHE
      rm -rf "$cache/$tag"
      mkdir -p "$cache/$tag" || exit 1
      fixture_from_tag "$tag" "$cache/$tag" "$repo" >/dev/null || exit 1
      rm -rf "$cache/$tag/src"
    ) &
    pids="$pids $!"
  done
  for pid in $pids; do wait "$pid" || rc=1; done
  return "$rc"
}

# fixture_cache_fingerprint <cache-dir> → one line
#
# A hash over `<path>\t<hash>\t<mode>` for every file in the cache, sorted
# LC_ALL=C. The runner compares it after building and before exit: the cache is
# shared read-only state, and a test that reached into it would otherwise poison
# its siblings silently. A mismatch is the FAIL.
#
# IT DOES NOT USE THE RUNTIME'S hash_paths, on purpose. This is the ruler that
# measures the fixtures the runtime is tested against; measuring with the code
# under test makes a hashing bug able to both corrupt a fixture and hide it (a
# dropped last path would be dropped from the fingerprint too). fixtures.sh is
# also sourced by test-fixtures.sh, which loads no runtime library at all.
fixture_cache_fingerprint() {
  local cache="$1" f n_p n_h n_m
  local w; w="$(mktemp -d)" || return 1
  local hasher="shasum -a 256"
  command -v sha256sum >/dev/null 2>&1 && hasher="sha256sum"
  local modefmt="-f %Lp"                                    # BSD
  stat -f '%Lp' "$w" >/dev/null 2>&1 || modefmt="-c %a"     # GNU

  ( cd "$cache" 2>/dev/null && find . -type f -print0 ) > "$w/list" 2>/dev/null
  : > "$w/table"
  if [ -s "$w/list" ]; then
    # Three columns produced by three batched passes, each in list order. That
    # alignment is the whole risk (an unreadable file prints no hash line and
    # would shift the rest), so the line counts are compared and a mismatch falls
    # back to a per-file walk that cannot misalign.
    ( cd "$cache" && xargs -0 $hasher -- < "$w/list" ) 2>/dev/null \
      | awk '{ h=$1; sub(/^\\/, "", h); print h }' > "$w/h"
    ( cd "$cache" && xargs -0 stat $modefmt -- < "$w/list" ) 2>/dev/null > "$w/m"
    tr '\0' '\n' < "$w/list" > "$w/p"
    n_p="$(wc -l < "$w/p" | tr -d ' ')"
    n_h="$(wc -l < "$w/h" | tr -d ' ')"
    n_m="$(wc -l < "$w/m" | tr -d ' ')"
    if [ "$n_p" = "$n_h" ] && [ "$n_p" = "$n_m" ]; then
      paste -d'\t' "$w/p" "$w/h" "$w/m" | LC_ALL=C sort > "$w/table"
    else
      while IFS= read -r f; do
        printf '%s\t%s\t%s\n' "$f" \
          "$($hasher "$cache/$f" 2>/dev/null | awk '{h=$1; sub(/^\\/,"",h); print h}')" \
          "$(stat $modefmt "$cache/$f" 2>/dev/null)"
      done < "$w/p" | LC_ALL=C sort > "$w/table"
    fi
  fi
  $hasher "$w/table" | awk '{ h=$1; sub(/^\\/, "", h); print h }'
  rm -rf "$w"
}
