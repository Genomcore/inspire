#!/usr/bin/env bash
# .inspire/bin/lib/plan-stack.sh
#
# Library — the stack half of `plan`: which profiles a unit is emanated under,
# and whether that set has a rendering home at all.
#
# D5 amends "missing profiles never block" for emanation alone: `emanate plan`
# REFUSES a unit whose stack declares no language profile, because an
# unattended run with no rendering table emits a guess that compiles. The
# resolution order — suite-wide `profiles:`, a UI surface's own `**Profiles:**`,
# then each framework profile's `language:` — is `inspire-code/profiles/
# README.md` § Resolution and `inspire-surface/references/roster-format.md`
# § Body; this file implements it and owns no rule of its own.
#
# There are TWO axes and each has its own refusal. The framework axis picks the
# one profile a persona spawn is briefed with (`PR-07`), narrowed by the unit's
# kind through `layer:`; the language axis asks whether that framework states
# how a semantic type renders (`PR-06`), per framework rather than per set.
#
# Sourced after `_lib.sh` and `plan-lib.sh`.

# plan_stack_declared — the suite-wide profile ids, one per line. Exit 1 when
# the stack declares none and none can be inferred, which is `PR-13`.
plan_stack_declared() {
  local f="$SDD_KB_ROOT/00_bootstrap/stack.md" out
  [ -f "$f" ] || return 1
  out="$(sdd_fm_list "$f" '.profiles')"
  [ -n "$out" ] || out="$(plan_stack_infer "$f")"
  [ -n "$out" ] || return 1
  printf '%s\n' "$out"
}

# plan_stack_infer <file> — the documented inference fallback, and only it:
# `## Frontend: React` yields `react`. A bulleted stack section names no profile
# id, and inventing one from prose would be the silent guess D5 forbids.
plan_stack_infer() {
  awk '
    /^## [A-Za-z].*:[ \t]*[^ \t]/ {
      name = substr($0, index($0, ":") + 1)
      gsub(/^[ \t]+|[ \t]+$/, "", name)
      gsub(/[ \t]+/, "-", name)
      print tolower(name)
    }
  ' "$1" | LC_ALL=C sort -u
}

# plan_surface_profiles <surface> — that surface's own `**Profiles:**` list, one
# id per line. Empty output means the surface declares none and inherits the
# suite-wide set; it does not extend it.
plan_surface_profiles() {
  local f="$SDD_KB_ROOT/00_bootstrap/surfaces.md"
  [ -f "$f" ] || return 0
  awk -v want="## $1" '
    $0 == want { inside = 1; next }
    /^## / { inside = 0 }
    inside && /^\*\*Profiles:\*\*/ {
      line = substr($0, length("**Profiles:**") + 1)
      gsub(/[][]/, "", line)
      n = split(line, a, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^[ \t]+|[ \t]+$/, "", a[i])
        if (a[i] != "") print a[i]
      }
      exit
    }
  ' "$f"
}

# The layers a FRAMEWORK profile declares. `language` is the other axis of the
# two-profile model — a rendering table rather than a build target — so it is
# deliberately absent from this list.
PLAN_FRAMEWORK_LAYERS=" frontend backend data tooling "

# plan_resolve_profiles <key> <declared-file> — read one declared set once.
# Writes `prof/<key>.resolved` (`id<TAB>layer<TAB>language` per declared id
# whose file is on disk) and `prof/<key>.missing` (the declared ids with no
# file). A declared id with no file stays OUT of the resolved set: "resolved"
# means a file was read, and what was missing is what `PR-07` names.
plan_resolve_profiles() {
  local key="$1" src="$2" out="$PLAN_TMP/prof/$key"
  [ -f "$out.resolved" ] && return 0
  local id file
  : > "$out.resolved.raw"; : > "$out.missing"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    file="$PLAN_PROFILES_ROOT/$id.md"
    if [ ! -f "$file" ]; then
      printf '%s\n' "$id" >> "$out.missing"
      continue
    fi
    printf '%s\t%s\t%s\n' "$id" \
      "$(sdd_fm_value "$file" '.layer')" "$(sdd_fm_value "$file" '.language')" \
      >> "$out.resolved.raw"
  done < "$src"
  LC_ALL=C sort -u "$out.resolved.raw" -o "$out.resolved.raw"
  mv "$out.resolved.raw" "$out.resolved"
  LC_ALL=C sort -u "$out.missing" -o "$out.missing"
}

# plan_unit_layer <kind> — the profile `layer:` a unit of that kind is built by,
# empty for the kinds no layer answers for (R8). A screen, a component and a
# pattern are frontend by construction, and `layer:` is machine-readable, which
# is what lets the common two-framework suite resolve rather than refuse. An
# entity and an action take the whole framework set instead: the
# domain-versus-service partition is an ADR decision nothing on disk states, so
# the honest answer there is to refuse while the set is ambiguous.
plan_unit_layer() {
  case "$1" in screen|component|pattern) printf 'frontend' ;; esac
}

# plan_unit_profiles <key> <kind> — the profile selection this unit emanates
# under, memoized per (key, matching layer) and printed as its file prefix:
#   `<sel>.fw`   the framework ids that match, one per line — `PR-07`'s subject
#   `<sel>.set`  every profile id the unit is emanated under, `units[].profiles`
#   `<sel>.gap`  `why<TAB>framework-id<TAB>target` per framework with no
#                rendering home — `PR-06`'s subject, one record per FRAMEWORK
#                rather than one per set, because each framework a spawn could
#                pick needs a rendering table of its own.
#
# The three `why` values send an operator to three different repairs: `absent`
# (the named language file is not there), `not-language` (it is there and its
# `layer:` is not `language` — a framework naming another framework, or itself,
# resolves to a file and still states no rendering) and `no-language-declared`
# (no `language:` line at all, which is the shipped `ios` / `android` case).
plan_unit_profiles() {
  local key="$1" kind="$2" want sel
  want="$(plan_unit_layer "$kind")"
  sel="$PLAN_TMP/prof/$key.${want:-any}"
  [ -f "$sel.set" ] && { printf '%s' "$sel"; return 0; }
  local id layer language lfile
  : > "$sel.fw"; : > "$sel.set.raw"; : > "$sel.gap"
  while IFS=$'\t' read -r id layer language; do
    [ -n "$id" ] || continue
    if [ "$layer" = "language" ]; then
      printf '%s\n' "$id" >> "$sel.set.raw"
      continue
    fi
    case "$PLAN_FRAMEWORK_LAYERS" in *" $layer "*) ;; *) continue ;; esac
    [ -z "$want" ] || [ "$layer" = "$want" ] || continue
    printf '%s\n' "$id" >> "$sel.fw"
    printf '%s\n' "$id" >> "$sel.set.raw"
    if [ -z "$language" ]; then
      printf 'no-language-declared\t%s\t%s\n' "$id" "$PLAN_PROFILES_ROOT/$id.md" >> "$sel.gap"
      continue
    fi
    lfile="$PLAN_PROFILES_ROOT/$language.md"
    if [ ! -f "$lfile" ]; then
      printf 'absent\t%s\t%s\n' "$id" "$lfile" >> "$sel.gap"
      continue
    fi
    printf '%s\n' "$language" >> "$sel.set.raw"
    [ "$(sdd_fm_value "$lfile" '.layer')" = "language" ] \
      || printf 'not-language\t%s\t%s\n' "$id" "$lfile" >> "$sel.gap"
  done < "$PLAN_TMP/prof/$key.resolved"
  LC_ALL=C sort -u "$sel.set.raw" -o "$sel.set.raw"
  mv "$sel.set.raw" "$sel.set"
  printf '%s' "$sel"
}

# plan_unit_profile_key <kind> <surface> — the declared set a unit resolves
# under. Only a UI surface partitions the set: which surface a screen sits in is
# positional and readable, while the domain-versus-service partition an entity
# or an action would need is not. A catalog entry is suite-wide by construction
# — `patterns/` and `components/` never move into a surface tree.
plan_unit_profile_key() {
  local kind="$1" surface="$2"
  if [ "$kind" = "screen" ] && [ -n "$surface" ] \
     && [ -f "$SDD_KB_ROOT/00_bootstrap/surfaces.md" ]; then
    printf 'surface-%s' "$surface"
  else
    printf 'suite'
  fi
}
