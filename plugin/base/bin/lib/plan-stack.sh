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

# plan_resolve_profiles <key> <declared-file> — resolve one declared set once.
# Writes `prof/<key>` (the ids that exist on disk, the named languages folded
# in) and `prof/<key>.gap` (the `PR-06` target, written only when nothing in the
# set yields a language profile).
#
# A declared id with no file stays OUT of the resolved set: "resolved" means a
# file was read. What was missing is what the gap names.
plan_resolve_profiles() {
  local key="$1" src="$2" out="$PLAN_TMP/prof/$key"
  [ -f "$out" ] && return 0
  local id file layer language have=0 gap="" absent=""
  : > "$out.raw"
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    file="$PLAN_PROFILES_ROOT/$id.md"
    if [ ! -f "$file" ]; then
      [ -n "$absent" ] || absent="$file"
      continue
    fi
    printf '%s\n' "$id" >> "$out.raw"
    layer="$(sdd_fm_value "$file" '.layer')"
    language="$(sdd_fm_value "$file" '.language')"
    [ "$layer" = "language" ] && have=1
    [ -n "$language" ] || continue
    if [ -f "$PLAN_PROFILES_ROOT/$language.md" ]; then
      printf '%s\n' "$language" >> "$out.raw"
      have=1
    else
      [ -n "$gap" ] || gap="$PLAN_PROFILES_ROOT/$language.md"
    fi
  done < "$src"
  LC_ALL=C sort -u "$out.raw" -o "$out.raw"
  mv "$out.raw" "$out"
  : > "$out.gap"
  [ "$have" = 1 ] || printf '%s' "${gap:-${absent:-$PLAN_PROFILES_ROOT}}" > "$out.gap"
}

# plan_unit_profile_key <kind> <surface> — the declared set a unit resolves
# under. Only a UI surface partitions the set; the domain-versus-service
# partition is an ADR decision and is not machine-readable in 0.8, so entities
# and actions always take the suite-wide one.
plan_unit_profile_key() {
  local kind="$1" surface="$2"
  if [ "$kind" = "screen" ] && [ -n "$surface" ] \
     && [ -f "$SDD_KB_ROOT/00_bootstrap/surfaces.md" ]; then
    printf 'surface-%s' "$surface"
  else
    printf 'suite'
  fi
}
