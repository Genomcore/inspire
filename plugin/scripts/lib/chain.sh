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

# _hop_failure_since <count_before> → 0 (true) when the hop just sourced left
# more failed operations behind it than it started with.
#
# `. "$hop" || …` CANNOT DETECT THIS, and that is the whole reason this exists:
# a sourced script's exit status is its LAST command's. hops/0.3.0.sh ends with
# hop_report, which always returns 0, so every operation in the middle could
# fail and the source would still report success. Before this check a run whose
# 14 moves all failed with "Permission denied" exited 0 and stamped 0.3.1 into
# .inspire.lock — the version claiming a migration that never happened. The
# ops count their own failures in HOP_FAILED (see lib/hop-ops.sh); comparing
# before and after is what turns that into "THIS hop failed".
_hop_failure_since() { [ "${HOP_FAILED:-0}" -gt "$1" ]; }

# run_chain <plugin_root> <from> <to>
#
# Returns 2 as soon as any hop leaves an operation unperformed. The caller must
# honour that: --mode update stops without rewriting the lock (a stale version
# is recoverable, a lying one is not), and --mode plan stops rather than print a
# forecast the real run cannot deliver.
run_chain() {
  local plugin_root="$1" from="$2" to="$3" v hop before
  local ran=0
  CHAIN_RAN=""
  while IFS= read -r v; do
    [ "$(version_cmp "$v" "$from")" = "1" ] || continue
    [ "$(version_cmp "$v" "$to")"   = "1" ] && continue
    hop="$plugin_root/scripts/hops/$v.sh"
    [ -f "$hop" ] || continue
    log "  · hop $v"
    before="${HOP_FAILED:-0}"
    # shellcheck disable=SC1090
    . "$hop"
    if _hop_failure_since "$before"; then
      log "materialize.sh: hop $v failed — $(( ${HOP_FAILED:-0} - before )) operation(s)"
      log "  could not be completed. They are journalled individually above."
      return 2
    fi
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
      before="${HOP_FAILED:-0}"
      . "$hop"
      if _hop_failure_since "$before"; then
        log "materialize.sh: hop $to failed — $(( ${HOP_FAILED:-0} - before )) operation(s)"
        log "  could not be completed. They are journalled individually above."
        return 2
      fi
      ran=$((ran+1))
      CHAIN_RAN="${CHAIN_RAN:+$CHAIN_RAN }$to"
    fi
  fi
  return 0
}
