#!/usr/bin/env bash
# .inspire/bin/head-referents.sh
#
# Rule: every name a head or a constraint mentions is a name that exists. This
# is the resolution half of the keyed-head contract — `constraints-mechanics.sh`
# and `keys-present.sh` ask whether an expression is well-formed, and this rule
# asks whether what it points at is there.
#
# Four joins, each a real defect when it fails, with the old-shape class ids of
# `.claude/skills/_references/keyed-heads.md`:
#
#   OS-X1  A field carrying `unique` — on its own `Constraints:` line, or inside
#          a `unique(...)` invariant head — that some action WRITES obliges that
#          action to declare an error whose head is `unique(...)` covering the
#          field. A uniqueness constraint with no error path is a constraint
#          whose violation the contract does not describe. This is the join the
#          error heads exist for: without them the check could only guess from
#          an error code's spelling, and a guess cannot be a blocker.
#          `id` IS EXEMPT. Every entity's `id` carries `unique` by construction,
#          and its uniqueness is structural rather than a business rule: the
#          action mints the value, so no caller can collide with it. Demanding a
#          conflict error for a primary key would fire on every `create` ever
#          written, and a check that always fires teaches operators to ignore it.
#          The check is about BUSINESS-KEY uniqueness — the email, the slug, the
#          external id a caller supplies.
#
#   OS-X2  Every argument of an invariant head is a row in that entity's
#          `## Fields` table.
#
#   OS-X3  Every entity a `P{n}` or `Q{n}` head names appears in the
#          descriptor's `## Entities` section. A postcondition about an entity
#          the action never declares touching means one of the two documents is
#          wrong.
#          `unchanged(...)` IS THE EXCEPTION, and necessarily so: its entire
#          point is naming an entity the action does NOT touch, so demanding it
#          appear among the touched entities would make the regression guard
#          unwritable. What is checked instead is that the entity it names
#          resolves to a document on disk — a guard about a nonexistent entity
#          asserts nothing.
#
#   OS-X4  `returns({field})` names a row in `## Outputs`. Skipped when
#          `## Outputs` carries no table at all — the whole-entity one-liner
#          defers the field shape to the entity document on purpose, and this
#          rule does not reach across that indirection.
#
#   OS-E7  A `references({module}.{entity})` argument resolves to an entity
#          document on disk — whether it appears on a field's Constraints line
#          or as an invariant head.
#
# Severity is lifecycle-progressive throughout (`sdd_progressive_severity`), on
# the lifecycle of the artifact the finding is reported against — so OS-X1 ramps
# with the ACTION's lifecycle, since it is the action that is missing something.
#
# Every file is read through a comment-stripped copy, for the reason stated in
# `_keyed-heads.sh`: the 0.8 templates carry guidance comments naming the very
# heads this rule resolves, and a commented-out example must not produce a
# finding about a name that was never claimed.
#
# Scope: the rule receives one `$1` and checks `$1 ∩ its layer` (`04_domain`).
#
# Usage:
#   .inspire/bin/head-referents.sh
#   .inspire/bin/head-referents.sh inspire_kb/04_domain/auth

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"
source "$SCRIPT_DIR/_keyed-heads.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-}"

# Two scratch slots: one for the artifact under check, one for an entity
# document it points at. Both are created on first use and removed by the EXIT
# trap, so an interrupted run leaves nothing behind.
HR_TMP1=""
HR_TMP2=""
hr_cleanup() {
  local rc=$?
  [ -n "$HR_TMP1" ] && rm -f "$HR_TMP1"
  [ -n "$HR_TMP2" ] && rm -f "$HR_TMP2"
  return $rc
}
trap hr_cleanup EXIT

hr_copy1() {
  if [ -z "$HR_TMP1" ]; then
    HR_TMP1="$(mktemp -t sdd-referents1.XXXXXX)" || return 1
  fi
  kh_strip_comments "$1" > "$HR_TMP1"
}

hr_copy2() {
  if [ -z "$HR_TMP2" ]; then
    HR_TMP2="$(mktemp -t sdd-referents2.XXXXXX)" || return 1
  fi
  kh_strip_comments "$1" > "$HR_TMP2"
}

# ─────────────────────────────────────────────────────────────────────────────
# Readers
# ─────────────────────────────────────────────────────────────────────────────

# hr_unique_fields <entity_file> — every field of that entity carrying `unique`,
#   from either home: its own Constraints line, or a `unique(...)` invariant
#   head (where a composite tuple contributes each of its members, because
#   writing any member can produce the conflict).
hr_unique_fields() {
  local file="$1" h3 list token key head fseg line arg
  while IFS= read -r h3; do
    [ -z "$h3" ] && continue
    list="$(kh_constraints_of "$file" "Fields" "$h3")" || continue
    while IFS= read -r token; do
      [ "$(kh_head_word "$token")" = "unique" ] && printf '%s\n' "$h3"
    done < <(kh_split_constraints "$list")
  done < <(kh_h3_names "$file" "Fields")

  while IFS="$KH_FS" read -r key head fseg line; do
    [ -z "$head" ] && continue
    [ "$(kh_head_word "$head")" = "unique" ] || continue
    while IFS= read -r arg; do
      [ -n "$arg" ] && printf '%s\n' "$arg"
    done < <(kh_split_args "$(kh_head_args "$head")")
  done < <(kh_entries "$file" "Invariants" bullet)
}

# hr_error_unique_args <action_file> — every argument of every `unique(...)`
#   head in `## Errors`.
hr_error_unique_args() {
  local file="$1" key head fseg line arg
  while IFS="$KH_FS" read -r key head fseg line; do
    [ -z "$head" ] && continue
    [ "$(kh_head_word "$head")" = "unique" ] || continue
    while IFS= read -r arg; do
      [ -n "$arg" ] && printf '%s\n' "$arg"
    done < <(kh_split_args "$(kh_head_args "$head")")
  done < <(kh_entries "$file" "Errors" bullet)
}

# hr_in_list <needle> <newline-list>
hr_in_list() {
  local needle="$1" item
  [ -z "$2" ] && return 1
  while IFS= read -r item; do
    [ "$item" = "$needle" ] && return 0
  done <<< "$2"
  return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# Checks
# ─────────────────────────────────────────────────────────────────────────────

check_entity() {
  local file="$1" copy sev fields h3 list token arg key head fseg line word
  hr_copy1 "$file" || return 0
  copy="$HR_TMP1"
  sev="$(sdd_progressive_severity "$(sdd_fm_value "$file" '.lifecycle')")"
  fields="$(sdd_entity_fields "$copy")"

  # OS-E7 on field Constraints lines.
  while IFS= read -r h3; do
    [ -z "$h3" ] && continue
    list="$(kh_constraints_of "$copy" "Fields" "$h3")" || continue
    while IFS= read -r token; do
      [ "$(kh_head_word "$token")" = "references" ] || continue
      arg="$(kh_head_args "$token")"
      if [ -n "$arg" ] && ! sdd_resolve_entity_id "$arg" >/dev/null 2>&1; then
        sdd_finding "$sev" "head-referents" "$file" \
          "OS-E7: \`$h3\` references(\`$arg\`) resolves to no entity document"
        sdd_count_by_severity "$sev"
      fi
    done < <(kh_split_constraints "$list")
  done < <(kh_h3_names "$copy" "Fields")

  # OS-X2 / OS-E7 on invariant heads.
  while IFS="$KH_FS" read -r key head fseg line; do
    [ -z "$head" ] && continue
    word="$(kh_head_word "$head")"
    case "$word" in
      references)
        arg="$(kh_head_args "$head")"
        if [ -n "$arg" ] && ! sdd_resolve_entity_id "$arg" >/dev/null 2>&1; then
          sdd_finding "$sev" "head-referents" "$file" \
            "OS-E7: invariant \`$key\` references(\`$arg\`) resolves to no entity document"
          sdd_count_by_severity "$sev"
        fi
        ;;
      unique|nonnull|immutable)
        while IFS= read -r arg; do
          [ -z "$arg" ] && continue
          if ! hr_in_list "$arg" "$fields"; then
            sdd_finding "$sev" "head-referents" "$file" \
              "OS-X2: invariant \`$key\` head \`$word\` names \`$arg\`, which is not a row in ## Fields"
            sdd_count_by_severity "$sev"
          fi
        done < <(kh_split_args "$(kh_head_args "$head")")
        ;;
    esac
  done < <(kh_entries "$copy" "Invariants" bullet)
}

check_action() {
  local file="$1" copy sev touched_ids outputs section key head fseg line word arg
  hr_copy1 "$file" || return 0
  copy="$HR_TMP1"
  sev="$(sdd_progressive_severity "$(sdd_fm_value "$file" '.lifecycle')")"

  touched_ids="$(sdd_entities_touched_meta "$copy" \
    | awk -F'\t' 'NF { gsub(/::/, ".", $1); print $1 }' | sort -u)"
  outputs="$(kh_first_column "$copy" "Outputs")"

  # OS-X3 / OS-X4 over the pre/postcondition heads.
  for section in Preconditions Postconditions; do
    while IFS="$KH_FS" read -r key head fseg line; do
      [ -z "$head" ] && continue
      word="$(kh_head_word "$head")"
      case "$word" in
        exists|absent|state|created|updated|deleted)
          arg="$(kh_split_args "$(kh_head_args "$head")" | head -1)"
          arg="$(kh_dotted "$arg")"
          [ -z "$arg" ] && continue
          if ! hr_in_list "$arg" "$touched_ids"; then
            sdd_finding "$sev" "head-referents" "$file" \
              "OS-X3: ## $section \`$key\` head \`$word\` names entity \`$arg\`, which the descriptor's ## Entities does not touch"
            sdd_count_by_severity "$sev"
          fi
          ;;
        unchanged)
          # The regression guard names an entity the action does NOT touch, so
          # `## Entities` is the wrong place to look — see the header.
          arg="$(kh_dotted "$(kh_head_args "$head")")"
          [ -z "$arg" ] && continue
          if ! sdd_resolve_entity_id "$arg" >/dev/null 2>&1; then
            sdd_finding "$sev" "head-referents" "$file" \
              "OS-X3: ## $section \`$key\` unchanged(\`$arg\`) resolves to no entity document"
            sdd_count_by_severity "$sev"
          fi
          ;;
        returns)
          [ -z "$outputs" ] && continue
          arg="$(kh_head_args "$head")"
          if [ -n "$arg" ] && ! hr_in_list "$arg" "$outputs"; then
            sdd_finding "$sev" "head-referents" "$file" \
              "OS-X4: ## $section \`$key\` returns(\`$arg\`) names no row in ## Outputs"
            sdd_count_by_severity "$sev"
          fi
          ;;
      esac
    done < <(kh_entries "$copy" "$section" bullet)
  done

  # OS-X1 — the uniqueness ⇒ conflict-error join. Written touches only, sorted
  # by entity so each touched entity's unique-field set is read once.
  local err_args rows ent field prev_ent="" uniq="" entity_file reported=" "
  err_args="$(hr_error_unique_args "$copy")"
  rows="$(sdd_entities_touched "$copy" \
    | awk -F'\t' 'NF && $3 == "written" && $2 != "id" { gsub(/::/, ".", $1); print $1 "\t" $2 }' \
    | sort -u)"
  [ -z "$rows" ] && return 0
  while IFS=$'\t' read -r ent field; do
    [ -z "$ent" ] && continue
    if [ "$ent" != "$prev_ent" ]; then
      prev_ent="$ent"
      uniq=""
      if entity_file="$(sdd_resolve_entity_id "$ent")"; then
        hr_copy2 "$entity_file" && uniq="$(hr_unique_fields "$HR_TMP2")"
      fi
    fi
    [ -z "$uniq" ] && continue
    hr_in_list "$field" "$uniq" || continue
    case "$reported" in *" $ent/$field "*) continue ;; esac
    if ! hr_in_list "$field" "$err_args"; then
      reported="$reported$ent/$field "
      sdd_finding "$sev" "head-referents" "$file" \
        "OS-X1: writes \`$field\` on $ent, which carries \`unique\`, but ## Errors declares no \`unique($field)\` head"
      sdd_count_by_severity "$sev"
    fi
  done <<< "$rows"
}

DOMAIN_SCOPE="$(sdd_scope_intersect "$SCOPE" "$SDD_SPEC_ROOT")"

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

sdd_exit_with_counters
