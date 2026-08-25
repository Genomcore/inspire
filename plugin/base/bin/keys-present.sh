#!/usr/bin/env bash
# .inspire/bin/keys-present.sh
#
# Rule: every section whose format spec declares KEYED entries carries them,
# well-formed. `sections-present.sh` asks whether a section is there;
# this rule asks whether the entries inside it are nameable.
#
# What is checked, per layer:
#
#   Entity document — `04_domain`, 2-segment leaf filename
#     `## Invariants` — a declared-none one-liner, or entries keyed `I{n}`
#     whose heads (when present) come from vocabulary V2.
#
#   Action descriptor — `04_domain`, 3-segment leaf filename
#     `## Preconditions` and `## Postconditions` — present, non-empty, and
#     either a declared-none one-liner or entries keyed `P{n}` / `Q{n}` whose
#     heads come from V3 / V4.
#     `## Behavior` — every numbered step keyed `B{n}`.
#     `## Errors` — error-code keys unique; heads (when present) from V5.
#
#   Use-case file — `03_features/{module}/{use-case}.md`
#     `## Main flow` — every numbered step keyed `B{n}`.
#     `## Preconditions` / `## Postconditions` — declared-none or keyed
#     `P{n}` / `Q{n}`.
#
# `## Behavior` and `## Main flow` steps carry NO heads. A step is prose by
# nature; a head there would restate a pre- or postcondition, and two spellings
# of one claim drift. Heads are therefore not validated in those two sections —
# which also means a step whose prose happens to end in a parenthesis can never
# be misread as a malformed head.
#
# SEVERITY splits by CLASS, not by rule, and the split is the point of the rule
# rather than a detail of it.
#
#   CONTENT classes — `OS-A2`, `OS-A5`, `OS-A6`, `OS-A8`, `OS-A9`, `OS-E5`,
#   `OS-E6` and the use-case classes — are lifecycle-progressive
#   (`sdd_progressive_severity`): warning at draft, error at accepted and
#   stable, warning again at superseded. `draft → accepted` is the human
#   pre-flight gate that declares a unit emanable, so a keyed entry that is
#   there but wrong has to block exactly there.
#
#   PRESENCE classes — `OS-A1`, `OS-A3`, `OS-A4` here, `OS-E1` in
#   `constraints-mechanics.sh`, and `OS-E3` — are FLAT WARNINGS at every
#   lifecycle in 0.8, the way `W-1` is. "New but unkeyed" and "pre-0.8" are the
#   same shape on disk, so ramping these would turn every `accepted` or
#   `stable` artifact in an upgraded vault red at pre-PR and at `promote`, and
#   an upgrade that leaves the vault broken is not an upgrade. Their messages
#   end `— derive refuses old-shape artifacts`, which is where the strictness
#   actually lives. `_keyed-heads.sh` § "Severity — the 0.8 grace on the
#   presence classes" holds the class list and the ramp schedule.
#
# Use-case files carry no `lifecycle:` at all, so they land on the warning side
# of `sdd_progressive_severity` regardless, which is where every finding in that
# layer already sits.
#
# Finding messages carry the old-shape class id from
# `.claude/skills/_references/keyed-heads.md` (`OS-E3`, `OS-A1`, …), so a
# finding, a golden fixture and that catalogue all name the same thing.
#
# Scope: the rule receives one `$1` and checks `$1 ∩ each of its layers` — see
# `bin/README.md` §Scope.
#
# Usage:
#   .inspire/bin/keys-present.sh                              # every layer
#   .inspire/bin/keys-present.sh inspire_kb/04_domain/auth     # domain only

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"
source "$SCRIPT_DIR/_keyed-heads.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-}"

# One scratch file for the whole run, created on first use and removed by the
# EXIT trap — an interrupted run leaves nothing behind.
KP_TMP=""
kp_cleanup() {
  local rc=$?
  [ -n "$KP_TMP" ] && rm -f "$KP_TMP"
  return $rc
}
trap kp_cleanup EXIT

# kp_read_copy <file> — sets KP_TMP to a comment-stripped copy and echoes its
# path. Sets a global rather than printing a mktemp result from a subshell,
# which would strand the file the trap is meant to remove.
kp_read_copy() {
  if [ -z "$KP_TMP" ]; then
    KP_TMP="$(mktemp -t sdd-keys.XXXXXX)" || return 1
  fi
  kh_strip_comments "$1" > "$KP_TMP" || return 1
  printf '%s\n' "$KP_TMP"
}

# ─────────────────────────────────────────────────────────────────────────────
# Checks
# ─────────────────────────────────────────────────────────────────────────────

# kp_keyed_section <read_file> <target> <section> <marker> <key-prefix>
#                  <vocab|-> <severity> <class-empty> <class-unkeyed>
#                  <class-badhead> <class-dup>
#   The shared pass over one keyed section. <vocab> of `-` skips head
#   validation. <class-empty> of `-` means the section is allowed to hold prose
#   that is not entries at all (used for `## Errors`, whose bullets may be
#   inheritance notes rather than error declarations).
kp_keyed_section() {
  local file="$1" target="$2" section="$3" marker="$4" prefix="$5"
  local vocab="$6" sev="$7" c_empty="$8" c_unkeyed="$9" c_badhead="${10}" c_dup="${11}"

  sdd_has_section "$file" "$section" || return 0

  if kh_is_declared_none "$file" "$section"; then
    return 0
  fi

  # Severity resolves per CLASS, not per section. The five presence classes are
  # graced to a flat warning in 0.8 while the content classes ramp with the
  # lifecycle, and one section emits both kinds — `## Invariants` reports
  # `OS-E3` next to `OS-E5` and `OS-E6`.
  local sev_empty sev_unkeyed sev_badhead sev_dup
  local note_empty note_unkeyed note_badhead note_dup
  sev_empty="$(kh_class_severity "$c_empty" "$sev")"
  sev_unkeyed="$(kh_class_severity "$c_unkeyed" "$sev")"
  sev_badhead="$(kh_class_severity "$c_badhead" "$sev")"
  sev_dup="$(kh_class_severity "$c_dup" "$sev")"
  note_empty="$(kh_class_note "$c_empty")"
  note_unkeyed="$(kh_class_note "$c_unkeyed")"
  note_badhead="$(kh_class_note "$c_badhead")"
  note_dup="$(kh_class_note "$c_dup")"

  local entries keyed=0 unkeyed=0 seen=" " dups=" "
  entries="$(kh_entries "$file" "$section" "$marker")"

  if [ -z "$entries" ]; then
    if [ "$c_empty" != "-" ] && [ -n "$(kh_section_content_lines "$file" "$section")" ]; then
      sdd_finding "$sev_empty" "keys-present" "$target" \
        "$c_empty: ## $section carries content that is neither a declared-none body ('None.') nor keyed \`$prefix{n}\` entries$note_empty"
      sdd_count_by_severity "$sev_empty"
    fi
    return 0
  fi

  local key head first line reason
  while IFS="$KH_FS" read -r key head first line; do
    [ -z "$key$head$first$line" ] && continue
    if [ -z "$key" ]; then
      unkeyed=$((unkeyed + 1))
      sdd_finding "$sev_unkeyed" "keys-present" "$target" \
        "$c_unkeyed: ## $section entry carries no \`$prefix{n}\` key: $line$note_unkeyed"
      sdd_count_by_severity "$sev_unkeyed"
      continue
    fi
    keyed=$((keyed + 1))
    if [ "$prefix" != "-" ] && ! [[ "$key" =~ ^${prefix}[0-9]+$ ]]; then
      sdd_finding "$sev_unkeyed" "keys-present" "$target" \
        "$c_unkeyed: ## $section entry key \`$key\` is not of the form \`$prefix{n}\`$note_unkeyed"
      sdd_count_by_severity "$sev_unkeyed"
      continue
    fi
    case "$seen" in
      *" $key "*)
        case "$dups" in
          *" $key "*) ;;
          *) dups="$dups$key "
             sdd_finding "$sev_dup" "keys-present" "$target" \
               "$c_dup: ## $section reuses key \`$key\` — keys are unique within a keyspace, never renumbered and never reused$note_dup"
             sdd_count_by_severity "$sev_dup" ;;
        esac ;;
      *) seen="$seen$key " ;;
    esac
    if [ "$vocab" != "-" ] && [ -n "$head" ]; then
      reason="$(kh_check_head "$head" "$vocab")"
      if [ -n "$reason" ]; then
        sdd_finding "$sev_badhead" "keys-present" "$target" \
          "$c_badhead: ## $section entry \`$key\` — $reason$note_badhead"
        sdd_count_by_severity "$sev_badhead"
      fi
    fi
  done <<< "$entries"
}

check_entity() {
  local file="$1" copy sev
  copy="$(kp_read_copy "$file")" || return 0
  sev="$(sdd_progressive_severity "$(sdd_fm_value "$file" '.lifecycle')")"
  kp_keyed_section "$copy" "$file" "Invariants" bullet "I" "$KH_V2" "$sev" \
    "OS-E3" "OS-E3" "OS-E5" "OS-E6"
}

check_action() {
  local file="$1" copy sev section
  copy="$(kp_read_copy "$file")" || return 0
  sev="$(sdd_progressive_severity "$(sdd_fm_value "$file" '.lifecycle')")"

  # Presence of the two 0.8 sections is this rule's, not sections-present's —
  # see the header. An absent section and a section saying "nothing holds here"
  # are different claims, so `None.` satisfies presence and emptiness both.
  # OS-A3 / OS-A4 are presence classes: flat warning at every lifecycle in 0.8.
  local class psev pnote
  for section in Preconditions Postconditions; do
    class="OS-A3"
    [ "$section" = "Postconditions" ] && class="OS-A4"
    psev="$(kh_class_severity "$class" "$sev")"
    pnote="$(kh_class_note "$class")"
    if ! sdd_has_section "$copy" "$section"; then
      sdd_finding "$psev" "keys-present" "$file" \
        "$class: action descriptor is missing ## $section — an action with none states so explicitly ('None.')$pnote"
      sdd_count_by_severity "$psev"
    elif [ -z "$(kh_section_content_lines "$copy" "$section")" ]; then
      sdd_finding "$psev" "keys-present" "$file" \
        "$class: action descriptor has an empty ## $section (header present but no body content)$pnote"
      sdd_count_by_severity "$psev"
    fi
  done

  kp_keyed_section "$copy" "$file" "Preconditions" bullet "P" "$KH_V3" "$sev" \
    "OS-A5" "OS-A5" "OS-A6" "OS-A9"
  kp_keyed_section "$copy" "$file" "Postconditions" bullet "Q" "$KH_V4" "$sev" \
    "OS-A5" "OS-A5" "OS-A6" "OS-A9"
  kp_steps "$copy" "$file" "Behavior" "$sev" "OS-A1" "OS-A2" "OS-A9"
  # `## Errors` keys are the error codes themselves, so there is no `{prefix}{n}`
  # shape to enforce and an unkeyed bullet is legitimate prose (an inheritance
  # note). Only duplicate codes and unknown heads are defects.
  kp_error_bullets "$copy" "$file" "$sev"
}

# kp_steps <read_file> <target> <section> <severity> <class-first> <class-mixed>
#          <class-dup>
#   Numbered-step sections. The FIRST step carrying no key is reported as the
#   old-shape marker for the whole artifact; further unkeyed steps alongside
#   keyed ones are reported as a mixed section. Splitting the two is what lets a
#   reader tell "this artifact predates keys" from "this artifact was edited
#   carelessly".
kp_steps() {
  local file="$1" target="$2" section="$3" sev="$4"
  local c_first="$5" c_mixed="$6" c_dup="$7"
  sdd_has_section "$file" "$section" || return 0
  local entries first_key="" n=0 keyed=0 unkeyed=0 seen=" " dups=" "
  local sev_first sev_mixed sev_dup note_first note_mixed note_dup
  sev_first="$(kh_class_severity "$c_first" "$sev")"
  sev_mixed="$(kh_class_severity "$c_mixed" "$sev")"
  sev_dup="$(kh_class_severity "$c_dup" "$sev")"
  note_first="$(kh_class_note "$c_first")"
  note_mixed="$(kh_class_note "$c_mixed")"
  note_dup="$(kh_class_note "$c_dup")"
  entries="$(kh_entries "$file" "$section" step)"
  [ -z "$entries" ] && return 0
  local key head fseg line
  while IFS="$KH_FS" read -r key head fseg line; do
    [ -z "$key$head$fseg$line" ] && continue
    n=$((n + 1))
    [ "$n" = "1" ] && first_key="$key"
    if [ -z "$key" ]; then
      unkeyed=$((unkeyed + 1))
      continue
    fi
    keyed=$((keyed + 1))
    if ! [[ "$key" =~ ^B[0-9]+$ ]]; then
      sdd_finding "$sev_mixed" "keys-present" "$target" \
        "$c_mixed: ## $section step key \`$key\` is not of the form \`B{n}\`$note_mixed"
      sdd_count_by_severity "$sev_mixed"
      continue
    fi
    case "$seen" in
      *" $key "*)
        case "$dups" in
          *" $key "*) ;;
          *) dups="$dups$key "
             sdd_finding "$sev_dup" "keys-present" "$target" \
               "$c_dup: ## $section reuses step key \`$key\` — the markdown ordinal is presentation, the key is identity$note_dup"
             sdd_count_by_severity "$sev_dup" ;;
        esac ;;
      *) seen="$seen$key " ;;
    esac
  done <<< "$entries"

  if [ -z "$first_key" ]; then
    sdd_finding "$sev_first" "keys-present" "$target" \
      "$c_first: ## $section step 1 carries no \`B{n}\` key — the artifact predates keyed steps$note_first"
    sdd_count_by_severity "$sev_first"
  fi
  if [ "$keyed" -gt 0 ] && [ "$unkeyed" -gt 0 ]; then
    sdd_finding "$sev_mixed" "keys-present" "$target" \
      "$c_mixed: ## $section mixes keyed and unkeyed steps ($keyed keyed, $unkeyed unkeyed)$note_mixed"
    sdd_count_by_severity "$sev_mixed"
  fi
}

kp_error_bullets() {
  local file="$1" target="$2" sev="$3"
  sdd_has_section "$file" "Errors" || return 0
  local entries key head fseg line seen=" " dups=" " reason
  entries="$(kh_entries "$file" "Errors" bullet)"
  [ -z "$entries" ] && return 0
  while IFS="$KH_FS" read -r key head fseg line; do
    [ -z "$key$head$fseg$line" ] && continue
    if [ -n "$key" ]; then
      case "$seen" in
        *" $key "*)
          case "$dups" in
            *" $key "*) ;;
            *) dups="$dups$key "
               sdd_finding "$sev" "keys-present" "$target" \
                 "OS-A9: ## Errors declares error code \`$key\` more than once"
               sdd_count_by_severity "$sev" ;;
          esac ;;
        *) seen="$seen$key " ;;
      esac
    fi
    if [ -n "$head" ]; then
      reason="$(kh_check_head "$head" "$KH_V5")"
      if [ -n "$reason" ]; then
        sdd_finding "$sev" "keys-present" "$target" \
          "OS-A8: ## Errors entry \`$key\` — $reason"
        sdd_count_by_severity "$sev"
      fi
    fi
  done <<< "$entries"
}

check_feature() {
  local file="$1" copy sev
  copy="$(kp_read_copy "$file")" || return 0
  # Use-case files carry no `lifecycle:`, so this resolves to warning — the
  # severity every finding in that layer already carries.
  sev="$(sdd_progressive_severity "$(sdd_fm_value "$file" '.lifecycle')")"
  kp_steps "$copy" "$file" "Main flow" "$sev" "OS-F1" "OS-F2" "OS-F4"
  kp_keyed_section "$copy" "$file" "Preconditions" bullet "P" "$KH_V3" "$sev" \
    "OS-F3" "OS-F3" "OS-F3" "OS-F4"
  kp_keyed_section "$copy" "$file" "Postconditions" bullet "Q" "$KH_V4" "$sev" \
    "OS-F3" "OS-F3" "OS-F3" "OS-F4"
}

# ─────────────────────────────────────────────────────────────────────────────
# Dispatch — one pass per layer, each over its own slice of the scope
# ─────────────────────────────────────────────────────────────────────────────

DOMAIN_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_SPEC_ROOT")"
FEATURE_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_KB_ROOT/03_features")"

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

sdd_exit_with_counters
