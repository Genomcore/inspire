#!/usr/bin/env bash
# Emit the hash manifest for a released version, read from its git tag.
#
#   gen-manifest.sh --tag v0.2.1 --repo /path/to/inspire  > plugin/manifests/0.2.1.json
#
# Keys are PROJECT-RELATIVE MATERIALIZED paths for that version — what an
# installed project has on disk — because that is what gets compared to disk.
# Two layouts exist:
#   pre-0.3 : install.sh copied .inspire/{skills,bin,hooks} → .claude/{skills,bin,hooks}
#   0.3     : materialize.sh copies base/{bin,hooks,skills}  → .inspire/bin,
#             .claude/inspire/hooks, .claude/skills (excluding bin/test and template-*.sh)
#
# Only read-only git is used. Content hashes come from the blob, which is
# identical to the installed file: no installer transforms a runtime file
# (chmod does not change content).
set -uo pipefail
SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd -P)"
. "$SCRIPT_DIR/lib/common.sh"

TAG=""; REPO="."
while [ "$#" -gt 0 ]; do
  case "$1" in
    --tag)  TAG="$2";  shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    -h|--help) log "usage: gen-manifest.sh --tag <tag> [--repo <path>]"; exit 0 ;;
    *) log "gen-manifest.sh: unknown flag '$1'"; exit 1 ;;
  esac
done
[ -n "$TAG" ] || { log "gen-manifest.sh: --tag is required"; exit 1; }

git -C "$REPO" rev-parse -q --verify "refs/tags/$TAG" >/dev/null \
  || { log "gen-manifest.sh: no such tag '$TAG'"; exit 1; }

commit="$(git -C "$REPO" rev-list -n1 "$TAG")"

# Release identity moved from .inspire/manifest.json (pre-0.3) to
# plugin/.claude-plugin/plugin.json (0.3+).
if git -C "$REPO" cat-file -e "$TAG:plugin/.claude-plugin/plugin.json" 2>/dev/null; then
  LAYOUT="0.3"
  identity="$(git -C "$REPO" show "$TAG:plugin/.claude-plugin/plugin.json")"
  SRC_PREFIX="plugin/base"
  MAP_NAMES="bin hooks skills"
  MAP_DESTS=".inspire/bin .claude/inspire/hooks .claude/skills"
else
  LAYOUT="pre-0.3"
  identity="$(git -C "$REPO" show "$TAG:.inspire/manifest.json")"
  SRC_PREFIX=".inspire"
  MAP_NAMES="skills bin hooks"
  MAP_DESTS=".claude/skills .claude/bin .claude/hooks"
fi
version="$(printf '%s' "$identity"  | jq -r '.version  // "unknown"')"
released="$(printf '%s' "$identity" | jq -r '.released // "unknown"')"

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

i=0
for name in $MAP_NAMES; do
  i=$((i+1))
  dest="$(printf '%s' "$MAP_DESTS" | cut -d' ' -f"$i")"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    rel="${path#"$SRC_PREFIX/$name/"}"
    # 0.3 never materializes bin/test/ nor template-*.sh.
    if [ "$LAYOUT" = "0.3" ]; then
      case "$rel" in test/*) continue ;; esac
      case "$(basename "$rel")" in template-*.sh) continue ;; esac
    fi
    h="$(git -C "$REPO" show "$TAG:$path" | sha256_of /dev/stdin)"
    printf '%s\t%s\n' "$dest/$rel" "$h" >> "$tmp"
  done < <(git -C "$REPO" ls-tree -r --name-only "$TAG" -- "$SRC_PREFIX/$name")
done

files_json="$(LC_ALL=C sort "$tmp" | jq -R -s '
  split("\n") | map(select(length > 0) | split("\t") | {(.[0]): .[1]}) | add // {}
')"

jq -n -S \
  --arg v "$version" --arg r "$released" --arg c "$commit" --arg l "$LAYOUT" \
  --argjson files "$files_json" \
  '{version: $v, released: $r, commit: $c, layout: $l, files: $files}'
