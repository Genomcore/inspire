#!/usr/bin/env bash
# .inspire/bin/constraints-mechanics.sh
#
# Rule: `Constraints:` lines are well-formed. Three small mechanical checks
# grouped into one pass, the way `frontmatter-mechanics.sh` groups its three:
#
#   (1) THE `id` MARKER. Every entity document's `## Fields` table has an `id`
#       row, and that row has a `### id` sub-section carrying a
#       `Constraints:` line. Every entity has an `id` and its constraints are
#       always real (`nonnull, unique, immutable` at minimum), which makes this
#       the deterministic marker distinguishing an entity written in the current
#       format from one written before it. An entity with no `id` row at all is
#       reported as its own defect, so the marker can never pass vacuously.
#
#   (2) THE CLOSED VOCABULARY. Every token on a `Constraints:` line — under
#       `## Fields` in an entity, under `## Inputs` in an action descriptor — is
#       a word from vocabulary V1 of `.claude/skills/_references/keyed-heads.md`,
#       at that word's arity. A word outside V1, or a V1 word at the wrong
#       arity, is a defect and not prose: a typo in a constraint is a claim that
#       silently stops being asserted. `nonnull` is additionally rejected on an
#       INPUT line, because `## Inputs`' `Required` column is the only home for
#       required-ness and two spellings of one fact drift.
#
#       A `Constraints:` line is READ WHEREVER IT SITS in the H3 body, not only
#       as the first content line. The format still puts it first, and a line
#       that sits later is reported as `OS-E8` — but it is reported *and*
#       checked, because the alternative is the failure mode this rule exists
#       to prevent: a line written after a sentence of prose used to be
#       ignored in silence, typos and all, so a claim the author believed they
#       had made simply stopped being asserted.
#
#   (3) CONSTRAINT WORDS LEFT IN PROSE (W-1). A `Notes` or `Description` cell
#       still carrying a constraint after the constraint itself moved to a
#       `Constraints:` line — the entity's `## Fields` Notes, the descriptor's
#       `## Inputs` Description, and the descriptor's `## Entities` field-touch
#       Notes, which is where an action tends to narrate the entity's own rule.
#       Recognising a constraint word inside prose means matching words that
#       have legitimate prose uses, so this is a heuristic — it is a FLAT
#       WARNING at every lifecycle, never ramping and never a refusal, exactly
#       the posture the prose-style heuristics carry. Inline code is exempt: a
#       token quoted as a token names the constraint rather than restating it.
#
# Check (2) is lifecycle-progressive (`sdd_progressive_severity`): warning at
# draft, error at accepted and stable, warning again at superseded — and so is
# `OS-E8`, since a misplaced line is something the current format's own author
# got wrong. Check (1)'s `OS-E1` is the exception: it is one of the five
# OLD-SHAPE PRESENCE classes, which are FLAT WARNINGS at every lifecycle in
# 0.8 so that a vault upgraded to this release is not red at pre-PR and at
# `promote` on every entity it already had. The full reasoning, the class list
# and the ramp schedule live in `_keyed-heads.sh` § "Severity — the 0.8 grace
# on the presence classes"; `keys-present.sh` carries the same split.
#
# This rule resolves nothing on the filesystem: whether a `references(...)`
# argument names a real entity, and whether a head's arguments name real fields,
# is `head-referents.sh`'s question. The split is deliberate — grammar here,
# resolution there — so a vault with a broken link and a vault with a typo do
# not report as the same kind of problem.
#
# Scope: the rule receives one `$1` and checks `$1 ∩ each of its layers`.
#
# Usage:
#   .inspire/bin/constraints-mechanics.sh
#   .inspire/bin/constraints-mechanics.sh inspire_kb/04_domain/auth

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/_lib.sh"
source "$SCRIPT_DIR/_keyed-heads.sh"

sdd_require_tools || exit 127
sdd_init_counters

SCOPE="${1:-}"

CM_TMP=""
cm_cleanup() {
  local rc=$?
  [ -n "$CM_TMP" ] && rm -f "$CM_TMP"
  return $rc
}
trap cm_cleanup EXIT

cm_read_copy() {
  if [ -z "$CM_TMP" ]; then
    CM_TMP="$(mktemp -t sdd-constraints.XXXXXX)" || return 1
  fi
  kh_strip_comments "$1" > "$CM_TMP" || return 1
  printf '%s\n' "$CM_TMP"
}

# cm_table_column <file> <section> <n> — the nth column of that section's table,
#   one `name<TAB>cell` record per data row (column 1 is always the name).
cm_table_column() {
  sdd_body_section "$1" "$2" \
    | awk -v col="$3" '
      /^\|/ {
        gsub(/^\|[[:space:]]*|[[:space:]]*\|$/, "")
        n = split($0, parts, /[[:space:]]*\|[[:space:]]*/)
        if (n < 1) next
        name = parts[1]
        gsub(/^`|`$/, "", name)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
        if (name == "" || name ~ /^-+$/) next
        if (name == "Field" || name == "Parameter") next
        cell = (n >= col) ? parts[col] : ""
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", cell)
        printf "%s\t%s\n", name, cell
      }
    '
}

# cm_prose_hits <text> — the W-1 phrases the text carries, one per line.
cm_prose_hits() {
  printf '%s\n' "$1" | awk -v phrases="$KH_PROSE_CONSTRAINT_PHRASES" '
    BEGIN { np = split(phrases, P, ";") }
    {
      s = tolower($0)
      # Inline code is a token quoted as a token, not a claim about the system —
      # the same exemption prose-style.sh applies. `unique` in backticks is the
      # constraint being named, not a constraint left behind in prose.
      gsub(/`[^`]*`/, " ", s)
      # Non-letters become spaces so a phrase is matched as whole words without
      # needing anchors inside an alternation, which not every awk accepts.
      gsub(/[^a-z-]/, " ", s)
      s = " " s " "
      for (i = 1; i <= np; i++) {
        p = P[i]
        if (p == "") continue
        if (index(s, " " p " ") > 0) print p
      }
    }
  '
}

# cm_check_line <file> <target> <parent_h2> <name> <severity> <class>
#               <reject_nonnull>
#   The vocabulary pass over one `Constraints:` line, wherever in the H3 body
#   it sits. Returns 0 when the H3 carries a line at all (well-formed or not,
#   first or later), 1 when it carries prose only — which the caller needs,
#   because a prose-only H3 is legal for every field except `id`.
cm_check_line() {
  local file="$1" target="$2" parent="$3" name="$4" sev="$5" class="$6"
  local reject_nonnull="$7"
  local list rc token reason bad

  # OS-E8 — placement, which is independent of what the line says, so it is
  # checked before the vocabulary pass and reported even when the line is
  # malformed. One finding per misplaced line, which reports a SECOND
  # `Constraints:` line too: at most one line can be the H3's first.
  while IFS= read -r bad; do
    [ -z "$bad" ] && continue
    sdd_finding "$sev" "constraints-mechanics" "$target" \
      "OS-E8: \`$name\` carries a \`Constraints:\` line that is not the first content line of its \`### $name\` sub-section — the line is read and checked wherever it sits, but the format puts it first"
    sdd_count_by_severity "$sev"
  done < <(kh_constraints_misplaced "$file" "$parent" "$name")

  list="$(kh_constraints_of "$file" "$parent" "$name")"
  rc=$?
  if [ "$rc" = "1" ]; then return 1; fi
  if [ "$rc" = "2" ]; then
    sdd_finding "$sev" "constraints-mechanics" "$target" \
      "$class: \`$name\` has a Constraints line that is not a single backtick-quoted list"
    sdd_count_by_severity "$sev"
    return 0
  fi
  while IFS= read -r token; do
    [ -z "$token" ] && continue
    if ! kh_is_head_shape "$token"; then
      sdd_finding "$sev" "constraints-mechanics" "$target" \
        "$class: \`$name\` Constraints entry \`$token\` is not a constraint expression (expected a closed-vocabulary word, optionally with arguments)"
      sdd_count_by_severity "$sev"
      continue
    fi
    if [ "$reject_nonnull" = "yes" ] && [ "$(kh_head_word "$token")" = "nonnull" ]; then
      sdd_finding "$sev" "constraints-mechanics" "$target" \
        "$class: \`$name\` Constraints carries \`nonnull\` — an input's required-ness is the Required column's, and stating it twice drifts"
      sdd_count_by_severity "$sev"
      continue
    fi
    reason="$(kh_check_head "$token" "$KH_V1")"
    if [ -n "$reason" ]; then
      sdd_finding "$sev" "constraints-mechanics" "$target" \
        "$class: \`$name\` Constraints — $reason"
      sdd_count_by_severity "$sev"
    fi
  done < <(kh_split_constraints "$list")
  return 0
}

# cm_notes_pass <file> <target> <section> <column>
#   W-1: flat warning, one finding per (name, phrase) pair so the operator sees
#   exactly which cell to trim.
cm_notes_pass() {
  local file="$1" target="$2" section="$3" col="$4"
  local name cell hit
  while IFS=$'\t' read -r name cell; do
    [ -z "$name" ] && continue
    [ -z "$cell" ] && continue
    while IFS= read -r hit; do
      [ -z "$hit" ] && continue
      sdd_finding "warning" "constraints-mechanics" "$target" \
        "W-1: \`$name\` still states \"$hit\" in prose — a constraint belongs on the Constraints line, and the cell says what it means to a reader, not that it exists"
      sdd_count_warning
    done < <(cm_prose_hits "$cell")
  done < <(cm_table_column "$file" "$section" "$col")
}

check_entity() {
  local file="$1" copy sev fields h3 name has_id=no
  copy="$(cm_read_copy "$file")" || return 0
  sev="$(sdd_progressive_severity "$(sdd_fm_value "$file" '.lifecycle')")"

  fields="$(sdd_entity_fields "$copy")"
  while IFS= read -r name; do
    [ "$name" = "id" ] && has_id=yes
  done <<< "$fields"

  if [ "$has_id" != "yes" ]; then
    sdd_finding "$sev" "constraints-mechanics" "$file" \
      "OS-E2: entity document declares no \`id\` row in ## Fields"
    sdd_count_by_severity "$sev"
  fi

  # Every H3 under `## Fields` that carries a Constraints line is checked; the
  # `id` H3 is additionally required to carry one.
  while IFS= read -r h3; do
    [ -z "$h3" ] && continue
    cm_check_line "$copy" "$file" "Fields" "$h3" "$sev" "OS-E4" no
  done < <(kh_h3_names "$copy" "Fields")

  if [ "$has_id" = "yes" ]; then
    if ! kh_constraints_of "$copy" "Fields" "id" >/dev/null 2>&1; then
      # OS-E1 is a presence class: flat warning at every lifecycle in 0.8 —
      # see `_keyed-heads.sh` § "Severity — the 0.8 grace on the presence
      # classes".
      local e1_sev e1_note
      e1_sev="$(kh_class_severity "OS-E1" "$sev")"
      e1_note="$(kh_class_note "OS-E1")"
      sdd_finding "$e1_sev" "constraints-mechanics" "$file" \
        "OS-E1: entity document's \`id\` field carries no \`Constraints:\` line — the marker of a pre-keying entity; touch it with /inspire-domain update$e1_note"
      sdd_count_by_severity "$e1_sev"
    fi
  fi

  cm_notes_pass "$copy" "$file" "Fields" 3
}

check_action() {
  local file="$1" copy sev h3
  copy="$(cm_read_copy "$file")" || return 0
  sev="$(sdd_progressive_severity "$(sdd_fm_value "$file" '.lifecycle')")"

  while IFS= read -r h3; do
    [ -z "$h3" ] && continue
    cm_check_line "$copy" "$file" "Inputs" "$h3" "$sev" "OS-A7" yes
  done < <(kh_h3_names "$copy" "Inputs")

  cm_notes_pass "$copy" "$file" "Inputs" 4
  # The `## Entities` field-touch table's Notes column is the other place a
  # constraint gets restated — an action narrating the entity's rule instead of
  # letting the entity's Constraints line carry it. Column 5 across every
  # per-entity sub-table; the sub-tables share one column layout, so one pass
  # reads them all.
  cm_notes_pass "$copy" "$file" "Entities" 5
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
