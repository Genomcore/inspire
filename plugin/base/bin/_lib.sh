#!/usr/bin/env bash
# .claude/bin/_lib.sh — shared helpers for the SDD validation library
#
# Source this file from other scripts: `source "$(dirname "$0")/_lib.sh"`.
# Do NOT execute directly.

set -uo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Constants
# ─────────────────────────────────────────────────────────────────────────────

SDD_SPEC_ROOT="${SDD_SPEC_ROOT:-.inspire_kb/04_domain}"

# ─────────────────────────────────────────────────────────────────────────────
# Dependency checks
# ─────────────────────────────────────────────────────────────────────────────

sdd_require_tools() {
  local missing=()
  command -v yq >/dev/null 2>&1 || missing+=("yq")
  command -v jq >/dev/null 2>&1 || missing+=("jq")
  if [ ${#missing[@]} -gt 0 ]; then
    echo "error: missing required tools: ${missing[*]}" >&2
    echo "       install via: brew install ${missing[*]}" >&2
    return 127
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Frontmatter extraction
#
# Reads YAML frontmatter from a .md file using yq. Outputs the frontmatter as
# YAML on stdout. Empty output (and exit 0) if the file has no frontmatter.
# ─────────────────────────────────────────────────────────────────────────────

sdd_frontmatter() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "error: file not found: $file" >&2
    return 1
  fi
  yq --front-matter=extract '.' "$file" 2>/dev/null || true
}

# Extract a single frontmatter value by path expression (e.g. ".status" or
# ".surfaces.http"). Prints the value (or empty if missing) to stdout.
sdd_fm_value() {
  local file="$1"
  local path="$2"
  yq --front-matter=extract "$path // \"\"" "$file" 2>/dev/null || true
}

# Strip [[ and ]] wikilink wrappers and unwrap pipe-syntax to the canonical id.
# Prints the unwrapped id (colon::form) to stdout. No-op on already-bare strings.
#
# Pipe-syntax wikilinks (V3 convention) carry the dotted on-disk name on the
# left of `|` and the colon-form canonical id on the right:
#   "[[auth.password.hash|auth::password::hash]]" → "auth::password::hash"
# Bare wikilinks (no pipe) are returned as-is after stripping the brackets:
#   "[[auth::user::create]]" → "auth::user::create"
sdd_unwrap_wikilink() {
  local s="$1"
  s="${s#\[\[}"
  s="${s%\]\]}"
  # If there's a `|`, the right-hand side is the canonical id.
  if [[ "$s" == *"|"* ]]; then
    s="${s#*|}"
  fi
  printf '%s\n' "$s"
}

# Extract a frontmatter list value by path expression (e.g. ".depends_on").
# Prints one item per line on stdout. Empty output if the list is missing or
# the value isn't a list. The trailing "?" suppresses errors on missing keys.
sdd_fm_list() {
  local file="$1"
  local path="$2"
  yq --front-matter=extract "${path}[]?" "$file" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────
# ID resolution
#
# Build an index mapping artifact id → file path by reading the .id
# frontmatter of every SDD source file. The index is cached in a temp file
# for the lifetime of the calling script.
# ─────────────────────────────────────────────────────────────────────────────

SDD_ID_INDEX_FILE=""

sdd_build_id_index() {
  local scope="${1:-$SDD_SPEC_ROOT}"
  SDD_ID_INDEX_FILE="$(mktemp -t sdd-id-index.XXXXXX)"
  while IFS= read -r file; do
    [ -z "$file" ] && continue
    local id
    id="$(sdd_fm_value "$file" '.id')"
    if [ -n "$id" ]; then
      printf '%s\t%s\n' "$id" "$file" >> "$SDD_ID_INDEX_FILE"
    fi
  done < <(sdd_find_actions "$scope")
}

# Resolve an artifact id to its file path. Prints the path (or empty) to
# stdout. Requires sdd_build_id_index to have been called first.
sdd_resolve_id() {
  local id="$1"
  if [ -z "$SDD_ID_INDEX_FILE" ] || [ ! -f "$SDD_ID_INDEX_FILE" ]; then
    return 1
  fi
  awk -F'\t' -v id="$id" '$1 == id { print $2; exit }' "$SDD_ID_INDEX_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
# Artifact discovery
#
# Layout: .inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.{action}.md
#         (full-id leaf filename — 3 dotted segments).
# Per-entity documents sit alongside actions at the same path with one
# fewer segment: .inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.md (2
# dotted segments). Action discovery uses segment count to distinguish them.
# ─────────────────────────────────────────────────────────────────────────────

# All action descriptor files under .inspire_kb/04_domain/. Actions have 3-segment dotted
# leaf filenames ({module}.{entity}.{action}.md); entity documents
# ({module}.{entity}.md) have 2 segments and are excluded.
sdd_find_actions() {
  local scope="${1:-$SDD_SPEC_ROOT}"
  [ -d "$scope" ] || return 0
  find "$scope" -type f -name "*.md" 2>/dev/null \
    | grep -E '/[A-Za-z0-9_]+\.[A-Za-z0-9_]+\.[A-Za-z0-9_]+\.md$' \
    | sort
}

# All entity document files under .inspire_kb/04_domain/. Entity documents have
# 2-segment dotted leaf filenames ({module}.{entity}.md); action
# descriptors ({module}.{entity}.{action}.md) have 3 segments and are
# excluded.
sdd_find_entities() {
  local scope="${1:-$SDD_SPEC_ROOT}"
  [ -d "$scope" ] || return 0
  find "$scope" -type f -name "*.md" 2>/dev/null \
    | grep -E '/[A-Za-z0-9_]+\.[A-Za-z0-9_]+\.md$' \
    | grep -vE '/[A-Za-z0-9_]+\.[A-Za-z0-9_]+\.[A-Za-z0-9_]+\.md$' \
    | sort
}

# Resolve an entity id (canonical colon form, e.g. "auth::user") to its
# entity document file path under $SDD_SPEC_ROOT, by mapping
# {module}::{entity} → .inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.md.
# Prints the path if the file exists; empty string + non-zero exit otherwise.
sdd_resolve_entity_id() {
  local rid="$1"
  # Accept both colon form ("auth::user") and dotted form ("auth.user").
  local module entity
  if [[ "$rid" == *"::"* ]]; then
    module="${rid%%::*}"
    entity="${rid##*::}"
  else
    module="${rid%%.*}"
    entity="${rid##*.}"
  fi
  local path="${SDD_SPEC_ROOT}/${module}/${entity}/${module}.${entity}.md"
  if [ -f "$path" ]; then
    printf '%s\n' "$path"
    return 0
  fi
  return 1
}

# Read an entity document's `lifecycle:` frontmatter field, given its
# canonical id (colon or dotted form). Prints the lifecycle value (e.g.
# "draft", "accepted", "stable", "superseded") to stdout, or empty string
# if the entity file does not exist or has no lifecycle field.
sdd_entity_lifecycle() {
  local rid="$1"
  local file
  file="$(sdd_resolve_entity_id "$rid")" || return 0
  sdd_fm_value "$file" '.lifecycle'
}

# Read an entity document's `population:` frontmatter field, given its
# canonical id (colon or dotted form). Prints the population value
# ("external" or "internal"), defaulting to "internal" when the field is
# absent or the entity file does not exist.
sdd_entity_population() {
  local rid="$1"
  local file
  file="$(sdd_resolve_entity_id "$rid")" || { printf 'internal\n'; return 0; }
  local val
  val="$(sdd_fm_value "$file" '.population')"
  if [ -z "$val" ] || [ "$val" = "null" ]; then
    printf 'internal\n'
  else
    printf '%s\n' "$val"
  fi
}

# Module name extracted from an action descriptor path. The path layout is
# .inspire_kb/04_domain/{module}/{entity}/{module}.{entity}.{action}.md, so the
# module segment is the directory after `sdd/`. E.g.
# .inspire_kb/04_domain/auth/user/auth.user.create.md → "auth".
sdd_action_module() {
  local path="$1"
  echo "$path" | awk -F'/' '{ for(i=1;i<=NF;i++) if($i=="sdd"){print $(i+1); exit} }'
}

# Entity name extracted from an action descriptor path. E.g.,
# .inspire_kb/04_domain/auth/user/auth.user.create.md → "user".
sdd_action_entity() {
  local path="$1"
  echo "$path" | awk -F'/' '{ for(i=1;i<=NF;i++) if($i=="sdd"){print $(i+2); exit} }'
}

# ─────────────────────────────────────────────────────────────────────────────
# Finding emission
#
# Findings are JSON lines on stderr. Stdout is reserved for human summaries.
# ─────────────────────────────────────────────────────────────────────────────

# sdd_finding <severity> <rule> <target> <message>
#   severity: "error" | "warning"
#   rule:     short rule id (e.g. "entity-coherence")
#   target:   path or id the finding applies to
#   message:  human-readable description
sdd_finding() {
  local severity="$1"
  local rule="$2"
  local target="$3"
  local message="$4"
  jq -nc \
    --arg severity "$severity" \
    --arg rule     "$rule" \
    --arg target   "$target" \
    --arg message  "$message" \
    '{severity: $severity, rule: $rule, target: $target, message: $message}' >&2
}

# Counters for the calling script to track errors / warnings.
# Usage:
#   sdd_init_counters
#   ... emit findings ...
#   sdd_exit_with_counters     # exits 1 if errors > 0, else 0
sdd_init_counters() {
  SDD_ERRORS=0
  SDD_WARNINGS=0
}

sdd_count_error() {
  SDD_ERRORS=$((${SDD_ERRORS:-0} + 1))
}

sdd_count_warning() {
  SDD_WARNINGS=$((${SDD_WARNINGS:-0} + 1))
}

sdd_exit_with_counters() {
  local errors="${SDD_ERRORS:-0}"
  local warnings="${SDD_WARNINGS:-0}"
  if [ "$errors" -gt 0 ]; then
    return 1
  fi
  return 0
}

# sdd_progressive_severity <lifecycle>
#   Maps an object's lifecycle to the severity tier for lifecycle-
#   progressive rules (warning at draft, error at accepted+). Used by
#   field-coverage, rationale-wikilink, wikilinks-resolve.
#   Returns "warning" for draft (and empty/unknown), "error" for accepted+.
sdd_progressive_severity() {
  case "$1" in
    accepted|stable|superseded) printf 'error\n' ;;
    *) printf 'warning\n' ;;
  esac
}

# sdd_count_by_severity <severity>
#   Bumps the appropriate counter for a severity tier. Convenience wrapper
#   for lifecycle-progressive rules that compute severity dynamically.
sdd_count_by_severity() {
  case "$1" in
    error)   sdd_count_error ;;
    warning) sdd_count_warning ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
# Markdown body section extraction
#
# Extracts the content under a markdown H2 header (## SectionName) up to the
# next H2 or EOF. Frontmatter and prose above the first H2 are ignored.
# ─────────────────────────────────────────────────────────────────────────────

# sdd_body_section <file> <header_name>
#   Prints the body section content to stdout. Empty if not found.
sdd_body_section() {
  local file="$1"
  local header="$2"
  awk -v header="## $header" '
    /^---$/ { fm = !fm; next }
    fm { next }
    $0 == header { capture = 1; next }
    /^## / && capture { exit }
    capture { print }
  ' "$file"
}

# sdd_entities_touched <file>
#   Parses the `## Entities` body section's per-entity h3 sub-sections.
#   Each sub-section has a metadata line and a per-field table with 5 cols:
#     Field | Touch | Type | Mapping | Notes
#   The H3 header uses pipe-syntax wikilinks:
#     ### [[module.entity|module::entity]]
#   The Field column may wrap names in backticks (`field_name`); the parser
#   strips them so callers see bare field names.
#   Outputs TSV:
#     entity_id<TAB>field<TAB>touch<TAB>type<TAB>mapping<TAB>notes<TAB>as_input<TAB>effect
#   one row per declared field. `as_input` and `effect` are repeated on every
#   row of the same entity (denormalized for downstream awk-friendliness).
sdd_entities_touched() {
  local file="$1"
  sdd_body_section "$file" "Entities" \
    | awk '
      # Entity header: ### [[module.entity|module::entity]] (V3)
      # or:            ### [[module::entity]]                 (bare)
      /^###[[:space:]]+\[\[/ {
        match($0, /\[\[[^\]]+\]\]/)
        rid = substr($0, RSTART+2, RLENGTH-4)
        # If pipe-syntax, take the canonical id (right of the `|`).
        pipe = index(rid, "|")
        if (pipe > 0) rid = substr(rid, pipe + 1)
        as_input = ""; effect = ""
        next
      }
      # Metadata line: **As input:** X · **Effect:** Y
      # BSD awk has 2-arg match() only (no capture-group array form),
      # so we extract via sub() on copies of the line.
      /^\*\*As input:\*\*/ {
        as_input = $0
        sub(/^\*\*As input:\*\*[[:space:]]*/, "", as_input)
        sub(/[[:space:]]*·.*$/, "", as_input)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", as_input)
        if (index($0, "**Effect:**") > 0) {
          effect = $0
          sub(/^.*\*\*Effect:\*\*[[:space:]]*/, "", effect)
          gsub(/^[[:space:]]+|[[:space:]]+$/, "", effect)
        } else {
          effect = ""
        }
        next
      }
      # Standalone **Effect:** Y (no preceding As input).
      /^\*\*Effect:\*\*/ {
        effect = $0
        sub(/^\*\*Effect:\*\*[[:space:]]*/, "", effect)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", effect)
        next
      }
      # Field-table data row. Allows optional backticks around the field name:
      #   | `id` | written | uuid | ... |
      # or the bare form for back-compat:
      #   | id | written | uuid | ... |
      /^\|[[:space:]]*`?[A-Za-z_][A-Za-z0-9_]*`?[[:space:]]*\|/ {
        if (rid == "") next
        gsub(/^\|[[:space:]]*|[[:space:]]*\|$/, "")
        n = split($0, parts, /[[:space:]]*\|[[:space:]]*/)
        if (n < 3) next
        field   = parts[1]
        touch   = parts[2]
        type    = parts[3]
        mapping = (n >= 4) ? parts[4] : ""
        notes   = (n >= 5) ? parts[5] : ""
        # Strip surrounding backticks from cells (preserve mid-cell ticks).
        gsub(/^`|`$/, "", field)
        gsub(/^`|`$/, "", type)
        # Skip header / separator rows
        if (field == "Field" || field ~ /^-+$/) next
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n", rid, field, touch, type, mapping, notes, as_input, effect
      }
    '
}

# sdd_entities_touched_meta <file>
#   Convenience: outputs only the per-entity metadata, deduplicated.
#   TSV: entity_id<TAB>as_input<TAB>effect (one row per touched entity).
sdd_entities_touched_meta() {
  sdd_entities_touched "$1" \
    | awk -F'\t' '{ print $1 "\t" $7 "\t" $8 }' \
    | sort -u
}

# sdd_expand_whole_reads
#   Pipeline filter. Reads touch rows on stdin in the 8-column TSV format
#   emitted by sdd_entities_touched:
#     entity_id<TAB>field<TAB>touch<TAB>type<TAB>mapping<TAB>notes<TAB>as_input<TAB>effect
#   For each row whose effect is "read-whole", resolves the entity doc and
#   enumerates its ## Fields, emitting one synthetic `read` row per declared
#   field. The synthetic rows carry an empty Type/Mapping and a sentinel
#   Notes value of "<synthetic:read-whole>" so consumers can filter if
#   needed. Originals pass through unchanged.
sdd_expand_whole_reads() {
  local input
  input="$(mktemp -t sdd-expand.XXXXXX)"
  cat > "$input"
  # 1. Emit originals verbatim.
  cat "$input"
  # 2. For each unique (entity_id) appearing with effect=read-whole, emit
  #    synthetic per-field reads. Repeated invocations on the same entity
  #    inside one action stream collapse to one set of synthetic rows.
  local rid entity_file field as_input
  awk -F'\t' '$8 == "read-whole" { print $1 "\t" $7 }' "$input" \
    | sort -u \
    | while IFS=$'\t' read -r rid as_input; do
        [ -z "$rid" ] && continue
        entity_file="$(sdd_resolve_entity_id "$rid")" || continue
        while IFS= read -r field; do
          [ -z "$field" ] && continue
          printf '%s\t%s\tread\t\t\t<synthetic:read-whole>\t%s\tread-whole\n' \
            "$rid" "$field" "$as_input"
        done < <(sdd_entity_fields "$entity_file")
      done
  rm -f "$input"
}

# sdd_entity_fields <file>
#   Parses the `## Fields` body section of an entity document and emits one
#   field name per line. The table layout is:
#     | Field | Type | Notes |
#   Field names may be wrapped in backticks (`field_name`); the parser strips
#   them. Header and separator rows are skipped. Empty output if the section
#   is missing or contains no rows.
sdd_entity_fields() {
  local file="$1"
  sdd_body_section "$file" "Fields" \
    | awk '
      /^\|[[:space:]]*`?[A-Za-z_][A-Za-z0-9_]*`?[[:space:]]*\|/ {
        gsub(/^\|[[:space:]]*|[[:space:]]*\|$/, "")
        n = split($0, parts, /[[:space:]]*\|[[:space:]]*/)
        if (n < 1) next
        field = parts[1]
        gsub(/^`|`$/, "", field)
        if (field == "Field" || field ~ /^-+$/) next
        print field
      }
    '
}
