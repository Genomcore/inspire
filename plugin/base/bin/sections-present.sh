#!/usr/bin/env bash
# .inspire/bin/sections-present.sh
#
# Rule: every KB artifact whose format spec declares a body shape must carry
# that shape — the mandatory sections present, and (where the section is
# operator-authored) non-empty. A header alone is insufficient.
#
# Every layer below is checked against the format spec that owns it:
#
#   Action descriptor — `04_domain`, 3-segment leaf filename (severity: error)
#     ## Purpose · ## Inputs · ## Outputs · ## Entities · ## Preconditions ·
#     ## Behavior · ## Postconditions · ## Errors
#     in that fixed order (inspire-domain/references/format-action.md).
#
#     Six of those eight are checked for PRESENCE here, at flat error severity:
#     the pre-0.8 core. `## Preconditions` and `## Postconditions` are 0.8
#     additions, and their presence is checked by `keys-present.sh` instead, at
#     lifecycle-progressive severity — a vault upgraded to 0.8 must not have
#     every descriptor it already had blocking every commit on the day the
#     runtime moves. Both names are still in the ORDER list, because an order
#     check is a subsequence match: a descriptor that has not gained them yet
#     skips them cleanly, and one that has gained them in the wrong place is
#     genuinely out of canonical order.
#
#   Entity document — `04_domain`, 2-segment leaf filename (severity: error)
#     ## Purpose · ## Rationale · ## Invariants · ## Fields · ## Touched by
#     in that fixed order (inspire-domain/references/format-entity.md).
#
#   Use-case file — `03_features/{module}/{use-case}.md` (severity: warning)
#     ## Actor · ## Preconditions · ## Main flow · ## Alternative flows ·
#     ## Error flows · ## Postconditions · ## Acceptance criteria, plus the
#     AC-id shape inside the last of those.
#
#   ADR — `01_adr/adr-*.md` (severity: warning)
#     ## Context · ## Decision · ## Consequences · ## Alternatives considered ·
#     ## Related ADRs, plus `### Breaking changes` under ## Consequences.
#
#   Screen — `05_screens/**` (severity: warning)
#     an H1 title, the `**Features:**` and `**Pattern:**` header lines, and
#     ## Instantiation. `## Module-specific deviations`, `## Current prototype`
#     and `## Notes` are optional and presence-free: never flagged either way.
#
# The three non-domain layers carry no `lifecycle:` field, so nothing there can
# ramp: their findings are warnings at every moment of their life. Only the
# domain layer's order check ramps, by the checked object's own lifecycle.
#
# A section is "present" when an H2 header with the exact name exists in the
# body — not inside frontmatter, not inside a fenced code block (a template
# quoted in a fence documents a section, it does not declare one), and, for the
# three non-domain layers, not inside an HTML comment (their templates carry
# guidance comments that name the very sections this rule looks for).
# A section is "non-empty" when at least one line of body content (other than
# whitespace and section-only structural noise) appears under it.
#
# Two sections are deliberately presence-only rather than non-empty:
#
#   `## Touched by` (entity) is auto-populated by consolidation and is
#   legitimately empty on an entity no action touches yet. Requiring content
#   would report as a blocking error the same fact `field-coverage` reports as
#   a lifecycle-progressive warning.
#
#   `## Errors` (action) stays non-empty, because an action with no error cases
#   documents that explicitly — `- \`none\`` is a valid one-line body.
#
# Section ORDER is checked in the domain layer only, as a subsequence match: an
# unknown or optional H2 anywhere in the file skips cleanly, and only the known
# sections appearing in a different relative order than the format spec fixes
# is a violation.
#
# Scope: the rule receives one `$1` and checks `$1 ∩ each of its layers` — see
# `bin/README.md` §Scope. Absent `$1`, every layer scans its own full root:
# $SDD_SPEC_ROOT for the domain layer, $SDD_KB_ROOT/{03_features,01_adr,
# 05_screens} for the rest.
#
# Usage:
#   .inspire/bin/sections-present.sh                              # every layer
#   .inspire/bin/sections-present.sh inspire_kb                   # every layer
#   .inspire/bin/sections-present.sh inspire_kb/04_domain/auth    # domain only
#   .inspire/bin/sections-present.sh inspire_kb/03_features       # features only

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-}"

ACTION_SECTIONS=("Purpose" "Inputs" "Outputs" "Entities" "Preconditions" \
                 "Behavior" "Postconditions" "Errors")
# The subset whose ABSENCE is a flat error at every lifecycle — see the header.
# Defined as a second array rather than an index range so that reordering the
# canonical list above cannot silently move which sections are mandatory.
ACTION_CORE_SECTIONS=("Purpose" "Inputs" "Outputs" "Entities" "Behavior" "Errors")
ENTITY_SECTIONS=("Purpose" "Rationale" "Invariants" "Fields" "Touched by")
FEATURE_SECTIONS=("Actor" "Preconditions" "Main flow" "Alternative flows" \
                  "Error flows" "Postconditions" "Acceptance criteria")
ADR_SECTIONS=("Context" "Decision" "Consequences" "Alternatives considered" \
              "Related ADRs")

# The canonical orders are the section arrays themselves: the format specs
# state one list, in order, and a second copy here could only drift from it.

# Each layer's slice of the scope is resolved by `sdd_scope_intersect` in
# _lib.sh — the same helper the domain finders use, so this rule and the ten
# domain-shaped ones cannot drift on what a scope means. See the dispatch at
# the foot of this file.

# ─────────────────────────────────────────────────────────────────────────────
# Readers
# ─────────────────────────────────────────────────────────────────────────────

# Print 1 if the section body has at least one non-blank, non-header content
# line; print 0 otherwise. Pipes the body to a small awk that strips
# whitespace-only lines and HTML comments.
section_has_content() {
  local file="$1" header="$2"
  sdd_body_section "$file" "$header" \
    | awk '
        # Strip whitespace.
        { gsub(/^[[:space:]]+|[[:space:]]+$/, "") }
        # Skip blank lines.
        /^$/ { next }
        # Skip HTML comments-only lines.
        /^<!--.*-->$/ { next }
        { found = 1; exit }
        END { if (found) print 1; else print 0 }
      '
}

# strip_html_comments <file>
#   Prints the file with every HTML comment blanked out, line structure
#   preserved (a line that was entirely comment becomes an empty line, never a
#   deleted one, so nothing above and below it merges). Multi-line comments are
#   tracked across lines. Fenced blocks pass through verbatim: a comment quoted
#   inside a fence is sample text, and the section readers already ignore
#   fenced content on their own.
#
#   This exists because the feature / ADR / screen templates carry guidance
#   comments that name the very sections the checks below look for — the screen
#   template's header comment is the single source of its required/optional
#   split, and a naive reader would see those names as declarations.
strip_html_comments() {
  awk '
      !incomment && sdd_fence($0) { print; next }
      !incomment && sdd_in_fence() { print; next }
      {
        out = ""; rest = $0
        while (1) {
          if (incomment) {
            p = index(rest, "-->")
            if (p == 0) { break }
            rest = substr(rest, p + 3); incomment = 0
          } else {
            p = index(rest, "<!--")
            if (p == 0) { out = out rest; break }
            out = out substr(rest, 1, p - 1)
            rest = substr(rest, p + 4); incomment = 1
          }
        }
        print out
      }
    '"${SDD_AWK_FENCE_FUNCS}" "$1"
}

# h2_stream <file>
#   The file's H2 header names, in document order, read exactly the way
#   sdd_has_section reads them (outside frontmatter, outside fences). H3s are
#   not H2s, so per-field `### {field}` sub-sections never enter the stream.
h2_stream() {
  awk \
    "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_SKIP}"'
      /^## / {
        h = substr($0, 4)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", h)
        print h
      }
    '"${SDD_AWK_FENCE_FUNCS}" "$1"
}

# has_line_prefix <file> <prefix>
#   Exit 0 if some body line starts with the literal prefix, read outside
#   frontmatter and outside fences. Used for the screen header lines, which are
#   bold-run markers rather than headers.
has_line_prefix() {
  local file="$1" prefix="$2"
  awk -v pfx="$prefix" \
    "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_SKIP}"'
      index($0, pfx) == 1 { found = 1; exit }
      END { exit !found }
    '"${SDD_AWK_FENCE_FUNCS}" "$file"
}

# ─────────────────────────────────────────────────────────────────────────────
# Checks
# ─────────────────────────────────────────────────────────────────────────────

# sections_report <read_file> <target> <kind> <severity> <presence_only> <section...>
#   The presence + non-empty pass, shared by all four layers. <read_file> is
#   what is parsed and <target> is what the finding names: they differ for the
#   layers read through a comment-stripped copy. <presence_only> is one section
#   name exempted from the non-empty half (empty string for none).
sections_report() {
  local file="$1" target="$2" kind="$3" sev="$4" presence_only="$5"
  shift 5
  local missing="" empty="" section
  for section in "$@"; do
    if ! sdd_has_section "$file" "$section"; then
      missing="${missing:+$missing,}$section"
      continue
    fi
    if [ -n "$presence_only" ] && [ "$section" = "$presence_only" ]; then
      continue
    fi
    if [ "$(section_has_content "$file" "$section")" != "1" ]; then
      empty="${empty:+$empty,}$section"
    fi
  done

  if [ -n "$missing" ]; then
    sdd_finding "$sev" "sections-present" "$target" \
      "$kind missing required section(s): $missing"
    sdd_count_by_severity "$sev"
  fi
  if [ -n "$empty" ]; then
    sdd_finding "$sev" "sections-present" "$target" \
      "$kind has empty section(s) (header present but no body content): $empty"
    sdd_count_by_severity "$sev"
  fi
}

# join_list <item...> — ", "-joined, for the order message.
join_list() {
  local out="" item
  for item in "$@"; do out="${out:+$out, }$item"; done
  printf '%s\n' "$out"
}

# check_order <file> <kind> <canonical section...>
#   Subsequence match over the H2 stream: the file's KNOWN sections must appear
#   in the canonical relative order. Unknown or optional H2s are skipped, so a
#   file that adds a section is not penalised for it. The comparison is
#   non-decreasing rather than strictly increasing, so a section repeated
#   ADJACENTLY passes; a section repeated later in the file reads as a jump
#   backwards and does trip the check, which is the honest reading — by then
#   the H2 stream genuinely is out of canonical order.
#   Lifecycle-progressive: what a draft may still be reshaping, an accepted or
#   stable object has fixed.
check_order() {
  local file="$1" kind="$2"
  shift 2
  local canon=("$@")
  local idx_list="" name_list="" h i idx section

  while IFS= read -r h; do
    [ -z "$h" ] && continue
    idx=-1
    i=0
    for section in "${canon[@]}"; do
      if [ "$section" = "$h" ]; then idx=$i; break; fi
      i=$((i + 1))
    done
    [ "$idx" -lt 0 ] && continue
    idx_list="$idx_list $idx"
    name_list="${name_list:+$name_list, }$h"
  done < <(h2_stream "$file")

  local prev=-1 v
  for v in $idx_list; do
    if [ "$v" -lt "$prev" ]; then
      # The lifecycle is read only here, on the violation path: the common case
      # is an ordered file, and that case should not pay for a yq call.
      local sev
      sev="$(sdd_progressive_severity "$(sdd_fm_value "$file" '.lifecycle')")"
      sdd_finding "$sev" "sections-present" "$file" \
        "$kind section order: known sections appear out of canonical order (expected: $(join_list "${canon[@]}"); found: $name_list)"
      sdd_count_by_severity "$sev"
      return 0
    fi
    prev="$v"
  done
}

check_action() {
  local file="$1"
  sections_report "$file" "$file" "action descriptor" "error" "" \
    "${ACTION_CORE_SECTIONS[@]}"
  check_order "$file" "action descriptor" "${ACTION_SECTIONS[@]}"
}

check_entity() {
  local file="$1"
  # `## Touched by` is presence-only: see the header comment.
  sections_report "$file" "$file" "entity document" "error" "Touched by" \
    "${ENTITY_SECTIONS[@]}"
  check_order "$file" "entity document" "${ENTITY_SECTIONS[@]}"
}

# check_acceptance_criteria <read_file> <target>
#   Two checks inside `## Acceptance criteria`, both warnings:
#     - format:    every top-level `- ` bullet in the section is a criterion
#                  line of the form `- [ ] AC-N: …`. The anchor is the line
#                  start, so an indented sub-bullet elaborating a criterion is
#                  not itself one, and a wrapped continuation line is not
#                  either. The checkbox state is free — a ticked criterion is a
#                  criterion.
#     - duplicate: no AC number appears on two criterion lines in one file.
#   There is deliberately NO contiguity check: ids are stable, never renumbered
#   and never reused, so gaps are the id contract working, not a defect.
check_acceptance_criteria() {
  local file="$1" target="$2"
  sdd_has_section "$file" "Acceptance criteria" || return 0

  local ac_re='^- \[[ xX]\] AC-([0-9]+):'
  local seen=" " dups=" " line num

  while IFS= read -r line; do
    case "$line" in
      "- "*) ;;
      *) continue ;;
    esac
    if [[ "$line" =~ $ac_re ]]; then
      num="${BASH_REMATCH[1]}"
      case "$seen" in
        *" $num "*)
          case "$dups" in
            *" $num "*) ;;
            *) dups="$dups$num " ;;
          esac
          ;;
        *) seen="$seen$num " ;;
      esac
    else
      sdd_finding "warning" "sections-present" "$target" \
        "AC-id format: acceptance criterion is not of the form '- [ ] AC-N: ...': $line"
      sdd_count_warning
    fi
  done < <(sdd_body_prose "$file" "Acceptance criteria")

  if [ "$dups" != " " ]; then
    local msg="" d
    for d in $dups; do msg="${msg:+$msg,}AC-$d"; done
    sdd_finding "warning" "sections-present" "$target" \
      "AC-id duplicate: criterion id(s) used more than once in this file: $msg"
    sdd_count_warning
  fi
}

# One scratch file for the whole run, created on first use and removed by the
# EXIT trap — an interrupted run leaves nothing behind, which a per-file
# `mktemp` + `rm` could not promise.
SP_TMP=""
sp_cleanup() {
  local rc=$?
  [ -n "$SP_TMP" ] && rm -f "$SP_TMP"
  return $rc
}
trap sp_cleanup EXIT

# sp_strip_to_tmp <file> — writes the comment-stripped copy to $SP_TMP.
# Sets a global rather than printing a path: a command substitution would run
# the mktemp in a subshell, stranding the file the trap is meant to remove.
sp_strip_to_tmp() {
  if [ -z "$SP_TMP" ]; then
    SP_TMP="$(mktemp -t sdd-sections.XXXXXX)" || return 1
  fi
  strip_html_comments "$1" > "$SP_TMP"
}

check_feature() {
  local file="$1"
  sp_strip_to_tmp "$file" || return 0
  local tmp="$SP_TMP"
  sections_report "$tmp" "$file" "use-case file" "warning" "" \
    "${FEATURE_SECTIONS[@]}"
  check_acceptance_criteria "$tmp" "$file"
}

check_adr() {
  local file="$1"
  sp_strip_to_tmp "$file" || return 0
  local tmp="$SP_TMP"
  sections_report "$tmp" "$file" "ADR" "warning" "" "${ADR_SECTIONS[@]}"

  # `### Breaking changes` is presence-only — an ADR that breaks nothing still
  # says so — but it must sit under `## Consequences`: a heading that drifted
  # to another parent answers a different question. Reported only when
  # `## Consequences` itself is there, since its absence is already a finding.
  if sdd_has_section "$tmp" "Consequences"; then
    if ! sdd_has_section "$tmp" "Breaking changes" 3; then
      sdd_finding "warning" "sections-present" "$file" \
        "ADR missing required subsection: '### Breaking changes' under '## Consequences'"
      sdd_count_warning
    elif ! sdd_has_subsection "$tmp" "Consequences" "Breaking changes"; then
      sdd_finding "warning" "sections-present" "$file" \
        "ADR subsection '### Breaking changes' is present but not under '## Consequences'"
      sdd_count_warning
    fi
  fi
}

check_screen() {
  local file="$1" missing=""
  sp_strip_to_tmp "$file" || return 0
  local tmp="$SP_TMP"

  has_line_prefix "$tmp" "# "            || missing="${missing:+$missing,}H1 title"
  has_line_prefix "$tmp" "**Features:**" || missing="${missing:+$missing,}**Features:** line"
  has_line_prefix "$tmp" "**Pattern:**"  || missing="${missing:+$missing,}**Pattern:** line"

  if sdd_has_section "$tmp" "Instantiation"; then
    if [ "$(section_has_content "$tmp" "Instantiation")" != "1" ]; then
      sdd_finding "warning" "sections-present" "$file" \
        "screen file has empty section(s) (header present but no body content): Instantiation"
      sdd_count_warning
    fi
  else
    missing="${missing:+$missing,}## Instantiation"
  fi

  if [ -n "$missing" ]; then
    sdd_finding "warning" "sections-present" "$file" \
      "screen file missing required part(s): $missing"
    sdd_count_warning
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Dispatch — one pass per layer, each over its own slice of the scope
# ─────────────────────────────────────────────────────────────────────────────

DOMAIN_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_SPEC_ROOT")"
FEATURE_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_KB_ROOT/03_features")"
ADR_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_KB_ROOT/01_adr")"
SCREEN_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_KB_ROOT/05_screens")"

if [ -n "$DOMAIN_SCOPE" ]; then
  while IFS= read -r action; do
    [ -z "$action" ] && continue
    check_action "$action"
  done < <(sdd_find_actions "$DOMAIN_SCOPE")

  while IFS= read -r entity; do
    [ -z "$entity" ] && continue
    check_entity "$entity"
  done < <(sdd_find_entities "$DOMAIN_SCOPE")
fi

if [ -n "$FEATURE_SCOPE" ]; then
  while IFS= read -r feature; do
    [ -z "$feature" ] && continue
    check_feature "$feature"
  done < <(sdd_find_features "$FEATURE_SCOPE")
fi

if [ -n "$ADR_SCOPE" ]; then
  while IFS= read -r adr; do
    [ -z "$adr" ] && continue
    check_adr "$adr"
  done < <(sdd_find_adrs "$ADR_SCOPE")
fi

if [ -n "$SCREEN_SCOPE" ]; then
  while IFS= read -r screen; do
    [ -z "$screen" ] && continue
    check_screen "$screen"
  done < <(sdd_find_screens "$SCREEN_SCOPE")
fi

sdd_exit_with_counters
