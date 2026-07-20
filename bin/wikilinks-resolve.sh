#!/usr/bin/env bash
# .claude/bin/wikilinks-resolve.sh
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
#   3. Bare basename (e.g. `pdd-auth-user-management`, `adr-auth-01-...`,
#      `lifecycle-rules`): glob-search the repo for `<basename>.md`.
#
# Anchored links (`[[file#section]]`) and aliased display links
# (`[[target|display]]` — pipe-syntax) are both supported: anchor is
# stripped before resolution; display text is ignored.
#
# Severity: lifecycle-progressive.
#   - object at lifecycle: draft     → warning
#   - object at lifecycle: accepted+ → error
#
# Usage:
#   .claude/bin/wikilinks-resolve.sh                  # scan whole tree
#   .claude/bin/wikilinks-resolve.sh spec/sdd/auth    # scoped scan

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-$SDD_SPEC_ROOT}"

# Build SDD id index (covers actions only — sdd_build_id_index iterates
# sdd_find_actions). For entity documents, we use sdd_resolve_entity_id
# directly.
sdd_build_id_index "$SCOPE"

# Build a name→path basename index for non-SDD wikilink targets (PDD,
# ADR, references, etc). One row per .md file: basename<TAB>path.
NAME_INDEX="$(mktemp -t sdd-name-index.XXXXXX)"
trap 'rm -f "${SDD_ID_INDEX_FILE:-}" "$NAME_INDEX"' EXIT

# Search the spec/ tree plus other plausible vault roots. Excludes
# .claude/worktrees/ to avoid cross-branch noise.
find spec .claude/skills 2>/dev/null \
  -type f -name "*.md" \
  ! -path "*/node_modules/*" \
  | while IFS= read -r p; do
      base="$(basename "$p" .md)"
      printf '%s\t%s\n' "$base" "$p"
    done >> "$NAME_INDEX"

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
    if awk -F'\t' -v b="$target" '$1 == b { found=1; exit } END { exit !found }' "$NAME_INDEX"; then
      return 0
    fi
  fi

  # Bare basename lookup (PDD, ADR, refs).
  if awk -F'\t' -v b="$target" '$1 == b { found=1; exit } END { exit !found }' "$NAME_INDEX"; then
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
  # Output one target per line (after unwrapping pipe-syntax).
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

while IFS= read -r action; do
  [ -z "$action" ] && continue
  check_file "$action"
done < <(sdd_find_actions "$SCOPE")

while IFS= read -r entity; do
  [ -z "$entity" ] && continue
  check_file "$entity"
done < <(sdd_find_entities "$SCOPE")

sdd_exit_with_counters
