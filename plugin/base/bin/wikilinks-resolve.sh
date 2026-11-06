#!/usr/bin/env bash
# .inspire/bin/wikilinks-resolve.sh
#
# Rule: every `[[wikilink]]` in an object's body must resolve to an
# existing .md file somewhere in the vault. Pipe-syntax wikilinks are
# unwrapped to their canonical form before resolution.
#
# Resolution strategy (in order):
#   1. SDD object id (colon form, e.g. `auth::user::create`): match
#      against the `.id` frontmatter of any SDD file via the id index.
#   2. SDD object id (dotted form, e.g. `auth.user.create`): the
#      pipe-syntax left side. Convert dots to ::, retry id-index lookup.
#   3. Screen id (`{face}.{slug}`): match against the `.id` frontmatter of
#      every screen file, via the screen-id index. A screen id written before
#      the migration resolves through the migration's id map
#      (`01_spec/_migration/id-map.json`), because a screen's `## Bindings` is
#      never rewritten (adr-kb-structure D10).
#   4. Name (e.g. `adr-auth-sessions`, `list`, `lifecycle-rules`): the id a
#      file name gives, which is its name without the typed extension
#      (`list.pattern.md` is `list`, `foo.adr.md` is `adr-foo`, D3), or the
#      plain name of an untyped file. A PATH-SHAPED target (`../patterns/list`,
#      the shape links took before the typed layout) is reduced to its last
#      segment and looked up the same way: the name is what a wikilink means,
#      and the directory is for people (D4).
#
# Anchored links (`[[file#section]]`) and aliased display links
# (`[[target|display]]` — pipe-syntax) are both supported: anchor is
# stripped before resolution; display text is ignored.
#
# Files checked: action descriptors, entity documents and screens — the
# artifacts whose navigation targets and action bindings ARE wikilinks. The rule
# receives one `$1` and checks those files in `$1 ∩ 01_spec`.
# The two INDEXES are always built vault-wide, whatever the scope: a scoped run
# must still resolve a link that points outside its scope.
#
# Severity: lifecycle-progressive.
#   - object at lifecycle: draft              → warning
#   - object at lifecycle: accepted or stable → error
#   - object at lifecycle: superseded         → warning (terminal: the object
#     is history, and history does not block a commit)
#
# A screen carrying no frontmatter at all — every screen written before the
# identity block existed — reads as draft, so it warns and never blocks.
#
# Usage:
#   .inspire/bin/wikilinks-resolve.sh                  # every layer
#   .inspire/bin/wikilinks-resolve.sh inspire_kb/01_spec/_modules/auth   # one module
#   .inspire/bin/wikilinks-resolve.sh inspire_kb/01_spec/_faces          # every face

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-}"

# Build SDD id index (covers actions only — sdd_build_id_index iterates
# sdd_find_actions). For entity documents, we use sdd_resolve_entity_id
# directly.
#
# The spec root, never $SCOPE: an index is what a link resolves AGAINST, and a
# scoped run must still resolve a link that points outside its scope. Handing the
# scope through instead would empty the index on a run scoped to one face, and
# every action binding on every accepted screen would be reported as dangling.
sdd_build_id_index "$SDD_SPEC_ROOT"

# Build a name→path basename index for non-SDD wikilink targets (PDD,
# ADR, references, etc), and a screen-id→path index for screen links.
# One row per file: key<TAB>path.
NAME_INDEX="$(mktemp -t sdd-name-index.XXXXXX)"
SCREEN_ID_INDEX="$(mktemp -t sdd-screen-id-index.XXXXXX)"
trap 'rm -f "${SDD_ID_INDEX_FILE:-}" "$NAME_INDEX" "$SCREEN_ID_INDEX"' EXIT

# Search the KB tree plus the deployed skills. Both indexes are vault-wide by
# construction, never scope-limited.
# Each file is indexed under its plain name and, for a typed file, under the id its
# name gives (D3) — one awk for the whole list, not a fork per file.
find "$SDD_KB_ROOT" .claude/skills 2>/dev/null \
  -type f -name "*.md" \
  ! -path "*/node_modules/*" \
  | awk '
      {
        p = $0; n = split(p, seg, "/"); base = seg[n]; sub(/\.md$/, "", base)
        print base "\t" p
        if (base ~ /\.adr\.rationale$/) { s = base; sub(/\.adr\.rationale$/, "", s); print "adr-" s ".rationale\t" p }
        else if (base ~ /\.adr$/) { s = base; sub(/\.adr$/, "", s); print "adr-" s "\t" p }
        else if (base ~ /\.(module|feature|entity|action|bundle|face|screen|process|component|layout|pattern)$/) {
          s = base; sub(/\.[a-z]+$/, "", s); print s "\t" p
        }
      }' >> "$NAME_INDEX"

while IFS= read -r screen_file; do
  [ -z "$screen_file" ] && continue
  screen_id="$(sdd_fm_value "$screen_file" '.id')"
  [ -n "$screen_id" ] && printf '%s\t%s\n' "$screen_id" "$screen_file" >> "$SCREEN_ID_INDEX"
done < <(sdd_find_screens "$SDD_SPEC_ROOT")

# The migration's screen id map, read once: old id <TAB> new id.
SCREEN_ALIASES="$(mktemp -t sdd-screen-aliases.XXXXXX)"
trap 'rm -f "${SDD_ID_INDEX_FILE:-}" "$NAME_INDEX" "$SCREEN_ID_INDEX" "$SCREEN_ALIASES" "${SDD_ENTITY_INDEX_FILE:-}"' EXIT
if [ -f "$SDD_SPEC_ROOT/_migration/id-map.json" ]; then
  jq -r '.screens // {} | to_entries[] | "\(.key)\t\(.value)"' "$SDD_SPEC_ROOT/_migration/id-map.json" \
    > "$SCREEN_ALIASES" 2>/dev/null || :
fi

# The entity index, built here in the parent shell so that every resolution below
# — each one inside a `$(...)` subshell — reuses it instead of rebuilding it.
_sdd_entity_index

index_has() {
  awk -F'\t' -v k="$2" '$1 == k { found=1; exit } END { exit !found }' "$1"
}

resolve_wikilink() {
  local target="$1"
  # Strip anchor (#section).
  target="${target%%#*}"
  [ -z "$target" ] && return 1

  # Path-shaped target: the name is what the link means (see the header). Reduced
  # FIRST, because the last segment of a link written for the layered layout is
  # often an id — `../../users/user/users.user` names the entity `users::user`,
  # whose file is no longer called `users.user.md`.
  if [[ "$target" == */* ]]; then
    target="${target##*/}"
    target="${target%.md}"
    [ -z "$target" ] && return 1
  fi

  # Try SDD id (colon form).
  if [[ "$target" == *"::"* ]]; then
    local sdd_path
    sdd_path="$(sdd_resolve_id "$target")"
    if [ -n "$sdd_path" ]; then
      return 0
    fi
    # Try as an entity id.
    sdd_path="$(sdd_resolve_entity_id "$target" 2>/dev/null || true)"
    [ -n "$sdd_path" ] && return 0
  fi

  # Try SDD id (dotted form — pipe-syntax left side).
  if [[ "$target" == *"."* ]] && [[ "$target" != *::* ]]; then
    local colon_form="${target//./::}"
    local sdd_path
    sdd_path="$(sdd_resolve_id "$colon_form")"
    [ -n "$sdd_path" ] && return 0
    sdd_path="$(sdd_resolve_entity_id "$colon_form" 2>/dev/null || true)"
    [ -n "$sdd_path" ] && return 0
    # Some on-disk SDD filenames use the dotted form as the basename; try
    # the basename index too.
    if index_has "$NAME_INDEX" "$target"; then
      return 0
    fi
  fi

  # Try a screen id. Screens are keyed by their write-once `id:`; an id from
  # before the migration goes through its id map.
  if index_has "$SCREEN_ID_INDEX" "$target"; then
    return 0
  fi
  local alias
  alias="$(awk -F'\t' -v k="$target" '$1 == k { print $2; exit }' "$SCREEN_ALIASES")"
  if [ -n "$alias" ] && index_has "$SCREEN_ID_INDEX" "$alias"; then
    return 0
  fi

  # Bare basename lookup (PDD, ADR, refs).
  if index_has "$NAME_INDEX" "$target"; then
    return 0
  fi

  return 1
}

check_file() {
  local file="$1"
  local lifecycle severity
  lifecycle="$(sdd_fm_value "$file" '.lifecycle')"
  severity="$(sdd_progressive_severity "$lifecycle")"

  # Extract every [[...]] occurrence from the body (skip frontmatter), one raw
  # token per line. The awk stops at the brackets: reading the target out of a
  # token is `sdd_wikilink_target`'s single job, and a second copy of that
  # reading here is exactly how the two halves of a pipe came to disagree.
  # Deduplication happens after the read, so two aliases of one target are one
  # finding.
  local raw links
  raw="$(awk '
    /^---$/ { fm = !fm; next }
    fm { next }
    {
      s = $0
      while (match(s, /\[\[[^]]+\]\]/)) {
        print substr(s, RSTART+2, RLENGTH-4)
        s = substr(s, RSTART + RLENGTH)
      }
    }
  ' "$file")"

  [ -z "$raw" ] && return 0

  links="$(while IFS= read -r token; do
    [ -n "$token" ] && sdd_wikilink_target "$token"
  done <<< "$raw" | sort -u)"

  [ -z "$links" ] && return 0

  while IFS= read -r target; do
    [ -z "$target" ] && continue
    if ! resolve_wikilink "$target"; then
      sdd_finding "$severity" "wikilinks-resolve" "$file" \
        "wikilink does not resolve: [[$target]]"
      sdd_count_by_severity "$severity"
    fi
  done <<< "$links"
}

# ─────────────────────────────────────────────────────────────────────────────
# Dispatch — one pass per layer, each over its own slice of the scope
# ─────────────────────────────────────────────────────────────────────────────

DOMAIN_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_SPEC_ROOT")"
SCREEN_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_SPEC_ROOT")"

if [ -n "$DOMAIN_SCOPE" ]; then
  while IFS= read -r action; do
    [ -z "$action" ] && continue
    check_file "$action"
  done < <(sdd_find_actions "$DOMAIN_SCOPE")

  while IFS= read -r entity; do
    [ -z "$entity" ] && continue
    check_file "$entity"
  done < <(sdd_find_entities "$DOMAIN_SCOPE")
fi

if [ -n "$SCREEN_SCOPE" ]; then
  while IFS= read -r screen; do
    [ -z "$screen" ] && continue
    check_file "$screen"
  done < <(sdd_find_screens "$SCREEN_SCOPE")
fi

sdd_exit_with_counters
