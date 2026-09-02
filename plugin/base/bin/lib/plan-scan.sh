#!/usr/bin/env bash
# .inspire/bin/lib/plan-scan.sh
#
# Library — the snapshot half of `plan`: what the scope reaches, which of it is
# the frontier, one `emanate-derive.sh` run per frontier unit, and the record
# stream each contract is read back as.
#
# Derive is INVOKED, never sourced. `derived-contract.md` draws that line —
# "`emanate plan` aggregates the stdout objects — it must never parse stderr" —
# and the entry point is the only surface plan is allowed to depend on.
#
# Sourced after `_lib.sh`, `_keyed-heads.sh` and `plan-lib.sh`.

# Derive fans out to four validators of its own, so the process count is the
# product, not the sum. Four at a time keeps a whole-vault plan off the
# scheduler's floor without making a six-unit fixture serial.
PLAN_DERIVE_BATCH=4

# plan_enumerate <scope> — every unit the scope reaches, as `path<TAB>kind`.
# A FILE scope names one artifact: the finders only walk directories, so the
# walk runs over its parent and the result is filtered back down to it.
plan_enumerate() {
  local s="$1" dir="$s" only=""
  if [ -n "$s" ] && [ -f "$s" ]; then
    only="$(sdd_scope_norm "$s")"
    case "$only" in */*) dir="${only%/*}" ;; *) dir="." ;; esac
  fi
  {
    sdd_find_entities   "${dir:-$SDD_SPEC_ROOT}" | awk '{ print $0 "\tentity" }'
    sdd_find_actions    "${dir:-$SDD_SPEC_ROOT}" | awk '{ print $0 "\taction" }'
    sdd_find_screens    "${dir:-$SDD_KB_ROOT}"   | awk '{ print $0 "\tscreen" }'
    sdd_find_patterns   "${dir:-$SDD_KB_ROOT}"   | awk '{ print $0 "\tpattern" }'
    sdd_find_components "${dir:-$SDD_KB_ROOT}"   | awk '{ print $0 "\tcomponent" }'
  } | if [ -n "$only" ]; then awk -F'\t' -v p="$only" '$1 == p'; else cat; fi
}

# plan_lifecycle_of <path> <kind> — the lifecycle a unit declares, per kind. A
# catalog entry carries no `lifecycle:` field and states the same three things
# on its `**State:**` line; `sdd_catalog_lifecycle` owns that mapping and derive
# reads it through the same function, so the frontier and the contract cannot
# disagree about whether a component is already delivered.
plan_lifecycle_of() {
  case "$2" in
    component|pattern) sdd_catalog_lifecycle "$1" ;;
    *)                 sdd_fm_value "$1" '.lifecycle' ;;
  esac
}

# plan_scan — every in-scope unit into `scanned.tsv` (path, kind, lifecycle) and
# the accepted ones into `frontier.tsv`. The union over the scope list is
# deduplicated: two overlapping scopes name one vault, not two.
plan_scan() {
  local s path kind
  : > "$PLAN_TMP/scanned.raw"
  if [ -s "$PLAN_TMP/scopes" ]; then
    while IFS= read -r s; do
      [ -n "$s" ] || continue
      plan_enumerate "$s" >> "$PLAN_TMP/scanned.raw"
    done < "$PLAN_TMP/scopes"
  else
    plan_enumerate "" >> "$PLAN_TMP/scanned.raw"
  fi
  LC_ALL=C sort -u "$PLAN_TMP/scanned.raw" -o "$PLAN_TMP/scanned.raw"

  : > "$PLAN_TMP/scanned.tsv"
  : > "$PLAN_TMP/frontier.tsv"
  while IFS=$'\t' read -r path kind; do
    [ -n "$path" ] || continue
    local lc
    lc="$(plan_lifecycle_of "$path" "$kind")"
    printf '%s\t%s\t%s\n' "$path" "$kind" "$lc" >> "$PLAN_TMP/scanned.tsv"
    [ "$lc" = "accepted" ] && printf '%s\t%s\n' "$path" "$kind" >> "$PLAN_TMP/frontier.tsv"
  done < "$PLAN_TMP/scanned.raw"
}

# plan_derive_one <n> <kind> <path> — one derivation, stdout and exit code
# spooled under the unit's index. Stderr is discarded rather than read: it is
# the human report, and plan aggregates stdout only.
plan_derive_one() {
  "$PLAN_BIN/emanate-derive.sh" "$2" --file "$3" >"$PLAN_TMP/c/$1.json" 2>/dev/null
  printf '%s' "$?" > "$PLAN_TMP/c/$1.code"
}

# plan_derive_all — one derivation per frontier unit, in batches.
plan_derive_all() {
  local n=0 running=0 path kind
  while IFS=$'\t' read -r path kind; do
    [ -n "$path" ] || continue
    n=$((n + 1))
    plan_derive_one "$n" "$kind" "$path" &
    running=$((running + 1))
    if [ "$running" -ge "$PLAN_DERIVE_BATCH" ]; then wait; running=0; fi
  done < "$PLAN_TMP/frontier.tsv"
  wait
}

# plan_contract_records <file> — one contract as the record stream the reader
# consumes: U identity · R requires edge · X refusal. A refused unit needs no
# marker of its own: derive gives it no `claims` key, so its count is 0 and its
# `X` records say why.
#
# A screen's `pattern` and `components` keys are NOT read here. They restate
# edges the `requires[]` set already carries, and since ED10 made both catalog
# kinds units, one edge rule answers all five kinds — a second reading would be
# a second place for the pattern-and-component question to be answered
# differently.
plan_contract_records() {
  jq -r --arg fs "$PLAN_FS" '
    def row($a): $a | map(tostring) | join($fs);
    [ row(["U", (.unit.id // ""), (.unit.lifecycle // ""), (.unit.module // ""),
           ((.claims // []) | length)]) ]
    + ((.requires // []) | map(row(["R", .kind, .id])))
    + ((.refused // []) | map(row(["X", .class, .target, .message, .remedy])))
    | .[]
  ' "$1" 2>/dev/null
}

# plan_domain_index — id -> path for every domain artifact in the vault, built
# once and only when the path convention has already missed. Resolution is
# vault-wide even when ORDERING is scope-wide: an edge leaving the scope still
# has to resolve, or `PR-02` would fire on every narrowed run.
plan_domain_index() {
  [ -f "$PLAN_TMP/domain-ids.tsv" ] && return 0
  local f id
  : > "$PLAN_TMP/domain-ids.tsv"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    id="$(kh_dotted "$(sdd_fm_value "$f" '.id')")"
    [ -n "$id" ] || continue
    printf '%s\t%s\n' "$id" "$(plan_path_norm "$f")" >> "$PLAN_TMP/domain-ids.tsv"
  done < <(sdd_find_entities "$SDD_SPEC_ROOT"; sdd_find_actions "$SDD_SPEC_ROOT")
}

# plan_screen_index — id -> path for every screen. A screen's id is minted
# write-once and never re-derived from its location (A12), so there is no path
# convention to try first.
plan_screen_index() {
  [ -f "$PLAN_TMP/screen-ids.tsv" ] && return 0
  local f id
  : > "$PLAN_TMP/screen-ids.tsv"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    id="$(kh_dotted "$(sdd_fm_value "$f" '.id')")"
    [ -n "$id" ] || continue
    printf '%s\t%s\n' "$id" "$(plan_path_norm "$f")" >> "$PLAN_TMP/screen-ids.tsv"
  done < <(sdd_find_screens "$SDD_KB_ROOT")
}

# plan_index_lookup <file> <id>
plan_index_lookup() {
  awk -F'\t' -v want="$2" '$1 == want { print $2; exit }' "$1"
}

# plan_dep_path <kind> <id> — the artifact a `requires[]` edge names, or empty.
# The domain convention is tried first and the index only on a miss, mirroring
# derive: one yq per vault artifact is the cost of the fallback, not of the
# common case.
plan_dep_path() {
  local kind="$1" id="$2" p="" rest
  case "$kind" in
    entity) p="$SDD_SPEC_ROOT/${id%%.*}/${id##*.}/$id.md" ;;
    action) rest="${id#*.}"; p="$SDD_SPEC_ROOT/${id%%.*}/${rest%%.*}/$id.md" ;;
    screen)
      plan_screen_index
      plan_index_lookup "$PLAN_TMP/screen-ids.tsv" "$id"
      return 0 ;;
    # A catalog entry's name IS its filename stem and both catalogs are
    # suite-wide, so there is one place to look and no index to fall back to.
    pattern|component)
      p="$SDD_KB_ROOT/05_screens/${kind}s/$id.md"
      [ -f "$p" ] && plan_path_norm "$p"
      return 0 ;;
  esac
  if [ -f "$p" ]; then plan_path_norm "$p"; return 0; fi
  plan_domain_index
  plan_index_lookup "$PLAN_TMP/domain-ids.tsv" "$id"
}

# plan_surface_of <screen-path> — the surface a split screens tree puts it
# under, or empty for the flat suite-of-one shape.
plan_surface_of() {
  local rel="$1"
  case "$rel" in *05_screens/*) rel="${rel#*05_screens/}" ;; *) return 0 ;; esac
  case "$rel" in */*/*) printf '%s' "${rel%%/*}" ;; esac
}
