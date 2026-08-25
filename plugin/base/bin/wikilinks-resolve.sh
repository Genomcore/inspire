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
#   3. Screen id (e.g. `users.detail`, or a collision-minted
#      `admin.users.detail`): match against the `.id` frontmatter of every
#      screen file, via the screen-id index. Screen FILE NAMES stay
#      positional — the id is the referent — so a screen link can only ever
#      be resolved by id, never by guessing at a path.
#   4. Bare basename (e.g. `pdd-auth-user-management`, `adr-auth-01-...`,
#      `lifecycle-rules`): glob-search the vault for `<basename>.md`. A
#      PATH-SHAPED target (e.g. `../patterns/list` — the shape the screen layer
#      writes for catalog links) is reduced to its last segment and looked up
#      the same way. That leniency is deliberate: a `../` depth that shifted
#      when the screens tree split by surface still names the right file, and
#      the name is what a wikilink means. Resolving the path exactly instead
#      would answer differently only for a target outside the indexed roots,
#      which nothing in a KB writes.
#
# Anchored links (`[[file#section]]`) and aliased display links
# (`[[target|display]]` — pipe-syntax) are both supported: anchor is
# stripped before resolution; display text is ignored.
#
# Layers checked: `04_domain` action descriptors and entity documents, plus
# `05_screens` screen files — the layer whose navigation targets and action
# bindings ARE wikilinks. The rule receives one `$1` and checks
# `$1 ∩ each of its layers`; absent `$1`, each layer scans its own full root.
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
#   .inspire/bin/wikilinks-resolve.sh inspire_kb/04_domain/auth    # domain only
#   .inspire/bin/wikilinks-resolve.sh inspire_kb/05_screens        # screens only

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-}"

# Build SDD id index (covers actions only — sdd_build_id_index iterates
# sdd_find_actions). For entity documents, we use sdd_resolve_entity_id
# directly.
sdd_build_id_index "$SCOPE"

# Build a name→path basename index for non-SDD wikilink targets (PDD,
# ADR, references, etc), and a screen-id→path index for screen links.
# One row per file: key<TAB>path.
NAME_INDEX="$(mktemp -t sdd-name-index.XXXXXX)"
SCREEN_ID_INDEX="$(mktemp -t sdd-screen-id-index.XXXXXX)"
trap 'rm -f "${SDD_ID_INDEX_FILE:-}" "$NAME_INDEX" "$SCREEN_ID_INDEX"' EXIT

# Search the KB tree plus the deployed skills. Both indexes are vault-wide by
# construction, never scope-limited.
find "$SDD_KB_ROOT" .claude/skills 2>/dev/null \
  -type f -name "*.md" \
  ! -path "*/node_modules/*" \
  | while IFS= read -r p; do
      base="$(basename "$p" .md)"
      printf '%s\t%s\n' "$base" "$p"
    done >> "$NAME_INDEX"

while IFS= read -r screen_file; do
  [ -z "$screen_file" ] && continue
  screen_id="$(sdd_fm_value "$screen_file" '.id')"
  [ -n "$screen_id" ] && printf '%s\t%s\n' "$screen_id" "$screen_file" >> "$SCREEN_ID_INDEX"
done < <(sdd_find_screens "$SDD_KB_ROOT")

index_has() {
  awk -F'\t' -v k="$2" '$1 == k { found=1; exit } END { exit !found }' "$1"
}

resolve_wikilink() {
  local target="$1"
  # Strip anchor (#section).
  target="${target%%#*}"
  [ -z "$target" ] && return 1

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

  # Try a screen id. Screens are keyed by their write-once `id:`, so this is
  # the only route a screen link has.
  if index_has "$SCREEN_ID_INDEX" "$target"; then
    return 0
  fi

  # Path-shaped target: the name is what the link means (see the header).
  if [[ "$target" == */* ]]; then
    target="${target##*/}"
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

  # Extract every [[...]] occurrence from the body (skip frontmatter).
  # Output one target per line (after unwrapping pipe-syntax). A pipe escaped
  # for a markdown table cell (`[[a.b\|a::b]]`) unwraps the same way: the
  # backslash sits on the left of the pipe, and the right side is canonical.
  local links
  links="$(awk '
    /^---$/ { fm = !fm; next }
    fm { next }
    {
      s = $0
      while (match(s, /\[\[[^]]+\]\]/)) {
        token = substr(s, RSTART+2, RLENGTH-4)
        # Pipe-syntax: right side is canonical.
        p = index(token, "|")
        if (p > 0) token = substr(token, p+1)
        print token
        s = substr(s, RSTART + RLENGTH)
      }
    }
  ' "$file" | sort -u)"

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
SCREEN_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_KB_ROOT/05_screens")"

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
