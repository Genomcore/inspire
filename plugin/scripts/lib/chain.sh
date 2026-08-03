#!/usr/bin/env bash
# Enumerate and run the layout hops between two versions. Sourced.
#
# There is no hop registry: the version chain is already enumerable from
# plugin/manifests/*.json, so a hop's ABSENCE is the no-op. A release that
# moves nothing costs nothing — not even a registry line.
#
# hop_ops_init is expected to have already been called by the caller (it sets
# PROJECT_ROOT / HOP_SOURCE_MANIFEST / HOP_RECORD / HOP_JOURNAL, all of which
# the sourced hop scripts and the ops they call rely on as globals).

# CHAIN_RAN — space-separated versions that actually ran, ascending order.
# Task 12 emits this as JSON; reset on every call so a stale value from a
# previous run_chain in the same process is never mistaken for this one's.
CHAIN_RAN=""

# run_chain <plugin_root> <from> <to>
run_chain() {
  local plugin_root="$1" from="$2" to="$3" v hop
  local ran=0
  CHAIN_RAN=""
  while IFS= read -r v; do
    [ "$(version_cmp "$v" "$from")" = "1" ] || continue
    [ "$(version_cmp "$v" "$to")"   = "1" ] && continue
    hop="$plugin_root/scripts/hops/$v.sh"
    [ -f "$hop" ] || continue
    log "  · hop $v"
    # shellcheck disable=SC1090
    . "$hop" || { log "materialize.sh: hop $v failed"; return 2; }
    ran=$((ran+1))
    CHAIN_RAN="${CHAIN_RAN:+$CHAIN_RAN }$v"
  done < <(manifest_versions "$plugin_root")

  # The target may be newer than any shipped manifest (it is, during the
  # release that introduces it), so its own hop is checked separately.
  hop="$plugin_root/scripts/hops/$to.sh"
  if [ -f "$hop" ] && [ "$(version_cmp "$to" "$from")" = "1" ]; then
    local seen; seen="$(manifest_path "$plugin_root" "$to")"
    if [ -z "$seen" ]; then
      log "  · hop $to"
      . "$hop" || { log "materialize.sh: hop $to failed"; return 2; }
      ran=$((ran+1))
      CHAIN_RAN="${CHAIN_RAN:+$CHAIN_RAN }$to"
    fi
  fi
  return 0
}
