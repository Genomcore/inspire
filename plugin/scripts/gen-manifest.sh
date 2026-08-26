#!/usr/bin/env bash
# Emit the hash manifest for a released version, read from its git tag.
#
#   gen-manifest.sh --tag v0.2.1 --repo /path/to/inspire  > plugin/manifests/0.2.1.json
#
# Keys are PROJECT-RELATIVE MATERIALIZED paths for that version — what an
# installed project has on disk — because that is what gets compared to disk.
# Two layouts exist:
#   pre-0.3 : install.sh copied .inspire/{skills,bin,hooks} → .claude/{skills,bin,hooks}
#   0.3     : materialize.sh copies base/{bin,hooks,skills,agents} → .inspire/bin,
#             .claude/inspire/hooks, .claude/skills, .claude/agents — excluding
#             whatever lib/merge.sh's _base_excluded rejects (today: the top-level
#             base/bin/test/ entry and any top-level template-*.sh entry).
#             That function is SOURCED here rather than re-expressed: it is the
#             single definition of the rule, and a manifest that disagreed with
#             the applier about what ships would make every such path read as
#             either a phantom deletion or a phantom creation.
#
# A PAYLOAD CLASS ADDED LATER COSTS PAST MANIFESTS NOTHING. The map below is
# read per class, and a class the release predates simply has no tree entries:
# `git ls-tree -r <commit> -- plugin/base/agents` is empty at every tag up to
# v0.7.0, so those manifests regenerate byte-identically with `agents` in the
# map — which is what test-manifest.sh's nine-manifest sweep asserts, and it is
# the mechanical half of the argument for extending the 0.3 layout rather than
# minting a new one (see scripts/hops/layouts.tsv). The layout id is therefore
# still decided by the release-identity file alone, never by which classes exist.
#
# Only read-only git is used. Content hashes come from the blob, which is
# identical to the installed file: no installer transforms a runtime file
# (chmod does not change content).
set -uo pipefail
SCRIPT_DIR="$(cd -P "$(dirname "$0")" && pwd -P)"
. "$SCRIPT_DIR/lib/common.sh"
# For _base_excluded, and only that. lib/merge.sh is pure function definitions
# with no top-level side effects; classify/apply_base need lib/manifest.sh at
# CALL time, and neither is called here.
. "$SCRIPT_DIR/lib/merge.sh"

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

# Accept a TAG by preference, but fall back to any resolvable revision. A release
# has to be generated BEFORE its tag exists — the version bump and the manifest land
# in the same PR, and the tag is only cut once that merges. Requiring a tag here made
# `--tag HEAD` impossible and left `template_sha` as the literal "unknown" for the
# whole pre-tag window, which is precisely the provenance hole this field exists to
# close. Regenerate from the real tag once it is cut; test-manifest.sh's sweep marks
# any manifest whose tag does not exist yet as SKIPPED so the pending step stays
# visible rather than silently passing.
if git -C "$REPO" rev-parse -q --verify "refs/tags/$TAG" >/dev/null; then
  commit="$(git -C "$REPO" rev-list -n1 "refs/tags/$TAG")"
elif git -C "$REPO" rev-parse -q --verify "$TAG^{commit}" >/dev/null; then
  commit="$(git -C "$REPO" rev-parse "$TAG^{commit}")"
  log "gen-manifest.sh: '$TAG' is not a tag — generating from revision $commit"
else
  log "gen-manifest.sh: cannot resolve '$TAG' to a tag or a commit"
  exit 1
fi

# Release identity moved from .inspire/manifest.json (pre-0.3) to
# plugin/.claude-plugin/plugin.json (0.3+).
if git -C "$REPO" cat-file -e "$commit:plugin/.claude-plugin/plugin.json" 2>/dev/null; then
  LAYOUT="0.3"
  IDENTITY_PATH="plugin/.claude-plugin/plugin.json"
  SRC_PREFIX="plugin/base"
  MAP_NAMES="bin hooks skills agents"
  MAP_DESTS=".inspire/bin .claude/inspire/hooks .claude/skills .claude/agents"
else
  LAYOUT="pre-0.3"
  IDENTITY_PATH=".inspire/manifest.json"
  SRC_PREFIX=".inspire"
  MAP_NAMES="skills bin hooks"
  MAP_DESTS=".claude/skills .claude/bin .claude/hooks"
fi

# A tag with neither identity file (e.g. history before either layout
# existed) must fail loudly, not fall through to an empty-but-well-formed
# manifest — that is worse than no manifest, because a caller cannot tell it
# apart from a real one.
identity="$(git -C "$REPO" show "$commit:$IDENTITY_PATH" 2>/dev/null)" \
  || { log "gen-manifest.sh: cannot read $IDENTITY_PATH at $TAG — no release identity, refusing to emit a manifest"; exit 1; }

version="$(printf '%s' "$identity"  | jq -r '.version  // "unknown"')"
released="$(printf '%s' "$identity" | jq -r '.released // "unknown"')"

tmp="$(mktemp)"; blobtmp="$(mktemp)"
trap 'rm -f "$tmp" "$blobtmp"' EXIT

i=0
for name in $MAP_NAMES; do
  i=$((i+1))
  dest="$(printf '%s' "$MAP_DESTS" | cut -d' ' -f"$i")"
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    rel="${path#"$SRC_PREFIX/$name/"}"
    # What 0.3 ships is one rule, defined once, in lib/merge.sh: the applier
    # (apply_base), the classifier (_base_src) and this generator all ask
    # _base_excluded. It was duplicated here until the final review; the copy
    # never diverged, but the only place a rule CAN drift is a second copy of it.
    # (Pre-0.3 needs no filter: install.sh copied .inspire/{skills,bin,hooks}
    # wholesale, bin/test/ included — that is precisely why 114 fixture paths sit
    # in the 0.2.1 manifest.)
    if [ "$LAYOUT" = "0.3" ]; then
      _base_excluded "$name" "$rel" && continue
    fi
    git -C "$REPO" show "$commit:$path" > "$blobtmp" \
      || { log "gen-manifest.sh: cannot read $path at $TAG"; exit 1; }
    h="$(sha256_of "$blobtmp")"
    printf '%s\t%s\n' "$dest/$rel" "$h" >> "$tmp"
  done < <(git -C "$REPO" ls-tree -r --name-only "$commit" -- "$SRC_PREFIX/$name")
done

files_json="$(LC_ALL=C sort "$tmp" | jq -R -s '
  split("\n") | map(select(length > 0) | split("\t") | {(.[0]): .[1]}) | add // {}
')"

jq -n -S \
  --arg v "$version" --arg r "$released" --arg c "$commit" --arg l "$LAYOUT" \
  --argjson files "$files_json" \
  '{version: $v, released: $r, commit: $c, layout: $l, files: $files}'
