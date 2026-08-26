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

# _score <manifest_tsv> <hash_table> → integer percent of manifest paths whose
# on-disk content matches what we shipped.
#
# BOTH ARGUMENTS ARE FILES, not a manifest and a root, because the hashing is no
# longer per-score: detect_version dumps every candidate's `<path>\t<hash>` rows
# (the same single jq call this function used to make) and hashes the UNION of
# their paths in one process, then scores each candidate by joining its own rows
# against that one table. A path listed by three manifests is hashed once instead
# of three times, and 1 090 files cost one process instead of 2 180.
#
# The arithmetic is deliberately unchanged: awk only COUNTS — `total` is every
# non-empty path the manifest lists, `hit` is those present in the table carrying
# the hash we shipped — and bash still does the integer division, so this returns
# the same integer as before, truncation included. A path absent from the table is
# one that is not a regular file on disk, which is exactly what the old `[ -f ]`
# guard meant.
_score() {
  local tsv="$1" table="$2" th total hit
  th="$(LC_ALL=C awk -F'\t' -v tf="$table" '
    FILENAME == tf { if (NF >= 2) h[$2] = $1; next }
    $1 != "" { total++; if (($1 in h) && h[$1] == $2) hit++ }
    END { printf "%d\t%d\n", total + 0, hit + 0 }
  ' "$table" "$tsv")"
  total="${th%%$'\t'*}"
  hit="${th##*$'\t'}"
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
#
# Two-pass by construction: every candidate is scored once (pass 1), then the
# maximum is found and EVERY candidate at that maximum is collected (pass 2).
# A single min/max variable pair can only ever remember one "runner up", so a
# three-way (or wider) tie would silently lose all but one of the contenders —
# that is exactly the guess-across-layouts failure this function must refuse.
detect_version() {
  local plugin_root="$1" root="$2" hint="${3:-}"
  local v s mf i best_s
  local -a order=() versions=() scores=() tied=()

  # The lock's version is a hint about ORDER only, so the likely candidate is
  # scored first. It has no effect on the two-pass outcome below — a lock can
  # never tip a tie or hide a candidate — it is never believed.
  [ -n "$hint" ] && order+=("$hint")
  while IFS= read -r v; do
    [ -n "$v" ] || continue
    [ "$v" = "$hint" ] || order+=("$v")
  done < <(manifest_versions "$plugin_root")

  if [ "${#order[@]}" -eq 0 ]; then
    log "INSPIRE: no manifests found under '$plugin_root/manifests'."
    log "  Refusing to guess — an upgrade from the wrong baseline can lose work."
    return 1
  fi

  # ONE hashing pass for the whole detection, and it dies inside this function:
  # nothing mutates the project between the hash and the scores (the hops run
  # much later), so the files hashed here are the files that were hashed here
  # before — in one process instead of two per path per manifest.
  local work
  work="$(mktemp -d)" || {
    log "INSPIRE: could not create a temporary directory to detect the version."
    log "  Refusing to guess — an upgrade from the wrong baseline can lose work."
    return 1
  }

  # Pass 1a: dump every candidate's rows exactly once, in candidate order.
  local n=0
  for v in "${order[@]}"; do
    mf="$(manifest_path "$plugin_root" "$v")" || continue
    [ -n "$mf" ] || continue
    n=$((n+1))
    manifest_paths "$mf" > "$work/m$n.tsv"
    versions+=("$v")
  done

  if [ "${#versions[@]}" -eq 0 ]; then
    log "INSPIRE: no readable manifests under '$plugin_root/manifests'."
    log "  Refusing to guess — an upgrade from the wrong baseline can lose work."
    rm -rf "$work"
    return 1
  fi

  # Pass 1b: hash the union of every candidate's paths, once.
  LC_ALL=C awk -F'\t' '$1 != "" { print $1 }' "$work"/m*.tsv \
    | LC_ALL=C sort -u | tr '\n' '\0' > "$work/list"
  hash_paths "$root" "$work/list" "$work/table"

  # Pass 1c: score every candidate exactly once, against that one table.
  i=0
  while [ "$i" -lt "${#versions[@]}" ]; do
    s="$(_score "$work/m$((i+1)).tsv" "$work/table")"
    scores+=("$s")
    i=$((i+1))
  done
  rm -rf "$work"

  # Pass 2a: find the maximum score.
  best_s=-1
  i=0
  while [ "$i" -lt "${#scores[@]}" ]; do
    [ "${scores[$i]}" -gt "$best_s" ] && best_s="${scores[$i]}"
    i=$((i+1))
  done

  if [ "$best_s" -lt "$MANIFEST_FLOOR_PCT" ]; then
    log "INSPIRE: cannot identify this project's INSPIRE version."
    log "  Best match was at ${best_s}% (floor ${MANIFEST_FLOOR_PCT}%)."
    log "  Refusing to guess — an upgrade from the wrong baseline can lose work."
    return 1
  fi

  # Pass 2b: collect EVERY candidate at the maximum — not just the first two.
  i=0
  while [ "$i" -lt "${#scores[@]}" ]; do
    [ "${scores[$i]}" -eq "$best_s" ] && tied+=("${versions[$i]}")
    i=$((i+1))
  done

  local best="${tied[0]}"
  if [ "${#tied[@]}" -gt 1 ]; then
    # A tie is only dangerous across layouts: within one layout the tied
    # versions hop identically and the choice only affects which manifest
    # supplies the content baseline.
    local lb t lt
    lb="$(manifest_layout "$(manifest_path "$plugin_root" "$best")")"
    for t in "${tied[@]}"; do
      lt="$(manifest_layout "$(manifest_path "$plugin_root" "$t")")"
      if [ "$lt" != "$lb" ]; then
        log "INSPIRE: this project matches multiple versions equally at ${best_s}%: ${tied[*]}."
        log "  Those span different layouts, so proceeding would mean guessing. Refusing."
        return 1
      fi
      [ "$(version_cmp "$t" "$best")" = "1" ] && best="$t"
    done
  fi

  printf '%s\t%s\n' "$best" "$best_s"
}

# verify_layout <plugin_root> <project_root> <layout_id>
#
# Asserts STRUCTURE, never content. Three outcomes: match (0); no such layout
# (1); markers contradict each other (1, "ambiguous") — which happens when
# someone half-migrated by hand and we cannot tell which directory is live.
verify_layout() {
  local plugin_root="$1" root="$2" want="$3"
  local tsv="$plugin_root/scripts/hops/layouts.tsv"
  local layout musts nots dmap p
  local -a missing=() present=()

  [ -f "$tsv" ] || { log "INSPIRE: missing $tsv"; return 1; }

  while IFS=$'\t' read -r layout musts nots dmap; do
    case "$layout" in ''|\#*) continue ;; esac
    [ "$layout" = "$want" ] || continue

    for p in $musts;  do [ -e "$root/$p" ] || missing+=("$p"); done
    for p in $nots;   do [ -e "$root/$p" ] && present+=("$p"); done

    if [ "${#missing[@]}" -eq 0 ] && [ "${#present[@]}" -eq 0 ]; then
      return 0
    fi
    if [ "${#missing[@]}" -eq 0 ] && [ "${#present[@]}" -gt 0 ]; then
      log "INSPIRE: this project's layout is ambiguous."
      log "  Expected a '$layout' layout, which requires these to be absent,"
      log "  but they are present: ${present[*]}"
      log "  That usually means a migration was started by hand. We cannot tell"
      log "  which location holds your live content, and guessing risks it."
      log "  Resolve it by keeping one of each pair, then run the upgrade again."
      return 1
    fi
    log "INSPIRE: this project does not have the '$layout' layout."
    log "  Missing: ${missing[*]:-none}"
    log "  Unexpectedly present: ${present[*]:-none}"
    return 1
  done < "$tsv"

  log "INSPIRE: unknown layout id '$want' — not listed in $tsv"
  return 1
}

# layout_map <plugin_root> <layout_id> → that layout's dest_map
layout_map() {
  local tsv="$1/scripts/hops/layouts.tsv" want="$2" layout musts nots dmap
  while IFS=$'\t' read -r layout musts nots dmap; do
    case "$layout" in ''|\#*) continue ;; esac
    if [ "$layout" = "$want" ]; then printf '%s\n' "$dmap"; return 0; fi
  done < "$tsv"
  return 1
}
