#!/usr/bin/env bash
# Manifest access and version detection. Sourced, never executed.
#
# The manifests shipped under plugin/manifests/ are the ONLY baseline for what
# INSPIRE shipped at a given version. .inspire.lock lives on the operator's
# machine and is never trusted: pre-0.3 locks carry no per-file hashes at all
# (and are skipped entirely when jq was missing at install), and a 0.3 lock
# rebaselines skipped files to their own drifted hash.

MANIFEST_FLOOR_PCT=50

manifest_path() {
  local f="$1/manifests/$2.json"
  [ -f "$f" ] && printf '%s\n' "$f"
}

manifest_versions() {
  local f v
  for f in "$1"/manifests/*.json; do
    [ -f "$f" ] || continue
    v="$(basename "$f" .json)"
    printf '%s\n' "$v"
  done | while IFS= read -r v; do printf '%s\n' "$v"; done | LC_ALL=C sort -t. -k1,1n -k2,2n -k3,3n
}

manifest_paths()  { jq -r '.files | to_entries[] | "\(.key)\t\(.value)"' "$1"; }
manifest_layout() { jq -r '.layout // "unknown"' "$1"; }

# _score <manifest> <project_root> → integer percent of manifest paths whose
# on-disk content matches what we shipped.
_score() {
  local mf="$1" root="$2" total=0 hit=0 path hash
  while IFS=$'\t' read -r path hash; do
    [ -n "$path" ] || continue
    total=$((total+1))
    [ -f "$root/$path" ] || continue
    [ "$(sha256_of "$root/$path")" = "$hash" ] && hit=$((hit+1))
  done < <(manifest_paths "$mf")
  [ "$total" -gt 0 ] || { printf '0\n'; return 0; }
  printf '%s\n' $(( hit * 100 / total ))
}

# detect_version <plugin_root> <project_root> [lock_hint]
#   → "<version>\t<score>"; exit 1 when it would have to guess.
#
# Scoring rather than exact matching, because a project is expected to diverge:
# operators edit skills, delete validators, add their own files. It also covers a
# project cloned from an untagged intermediate commit — it scores below 100%
# against the nearest release and is still nominated correctly.
detect_version() {
  local plugin_root="$1" root="$2" hint="${3:-}"
  local v s best="" best_s=-1 runner_up="" runner_s=-1
  local -a order=()

  # The lock's version is a hint about ORDER only, so the likely candidate is
  # scored first and wins an exact tie. It is never believed.
  [ -n "$hint" ] && order+=("$hint")
  while IFS= read -r v; do
    [ "$v" = "$hint" ] || order+=("$v")
  done < <(manifest_versions "$plugin_root")

  for v in "${order[@]}"; do
    local mf; mf="$(manifest_path "$plugin_root" "$v")" || continue
    [ -n "$mf" ] || continue
    s="$(_score "$mf" "$root")"
    if [ "$s" -gt "$best_s" ]; then
      runner_up="$best"; runner_s="$best_s"; best="$v"; best_s="$s"
    elif [ "$s" -gt "$runner_s" ]; then
      runner_up="$v"; runner_s="$s"
    fi
  done

  if [ -z "$best" ] || [ "$best_s" -lt "$MANIFEST_FLOOR_PCT" ]; then
    log "INSPIRE: cannot identify this project's INSPIRE version."
    log "  Best match was '${best:-none}' at ${best_s}% (floor ${MANIFEST_FLOOR_PCT}%)."
    log "  Refusing to guess — an upgrade from the wrong baseline can lose work."
    return 1
  fi

  # A tie is only dangerous across layouts: within one layout the tied versions
  # hop identically and the choice only affects which manifest supplies A.
  if [ "$runner_s" -eq "$best_s" ] && [ -n "$runner_up" ]; then
    local lb lr
    lb="$(manifest_layout "$(manifest_path "$plugin_root" "$best")")"
    lr="$(manifest_layout "$(manifest_path "$plugin_root" "$runner_up")")"
    if [ "$lb" != "$lr" ]; then
      log "INSPIRE: this project matches both $best ($lb) and $runner_up ($lr) equally."
      log "  Those layouts differ, so proceeding would mean guessing. Refusing."
      return 1
    fi
    if [ "$(version_cmp "$runner_up" "$best")" = "1" ]; then best="$runner_up"; fi
  fi

  printf '%s\t%s\n' "$best" "$best_s"
}
