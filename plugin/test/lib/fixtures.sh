#!/usr/bin/env bash
# Builds a period-correct installed project from a git tag, using only
# read-only git operations against the source repo. The fixture gets its own
# throwaway git repo; the source repo is never written to.

# fixture_from_tag <tag> <workdir> <repo>  → prints the project root
fixture_from_tag() {
  local tag="$1" work="$2" repo="$3"
  local src="$work/src" proj="$work/proj" rc
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
