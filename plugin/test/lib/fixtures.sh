#!/usr/bin/env bash
# Builds a period-correct installed project from a git tag, using only
# read-only git operations against the source repo. The fixture gets its own
# throwaway git repo; the source repo is never written to.

# fixture_from_tag <tag> <workdir> <repo>  → prints the project root
#
# INSPIRE_FIXTURE_CACHE, when set and holding <tag>/proj, makes this a copy of a
# tree this same function built from this same tag: period-correctness is
# untouched, only the count. `-p`, because without it the copy's modes go through
# the umask and a hit would differ from a build. A hit stages no <workdir>/src,
# which is how the assertions tell a copy from a rebuild.
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
# Each tag built once, in parallel; non-zero if any failed. The variable is unset
# per build, or a corrupt entry would propagate itself forever. The staged
# <tag>/src goes: it is the archive a build installs FROM, not part of the
# fixture, and it would put ~900 files per pre-0.3 tag into the fingerprint below.
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
# The runner compares this after building the cache and again before exit: the
# cache is shared read-only state, and a test that reached into it would poison
# its siblings silently. It deliberately hashes with its own hands rather than
# the runtime's — measuring the fixtures with the code under test would let one
# hashing bug both corrupt a fixture and hide it.
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
    # Three batched passes, each in list order: an unreadable file prints no hash
    # line and would shift the rest, so the counts are compared and a mismatch
    # falls back to a per-file walk that cannot misalign.
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
