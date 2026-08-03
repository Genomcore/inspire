#!/usr/bin/env bash
# The five operations a hop script may perform. Sourced, never executed.
#
# Each one computes exactly what it would act on, then either ACTS or RECORDS,
# depending on HOP_RECORD. That is one implementation with a terminal switch —
# not a dry-run mirror that can drift from the real behaviour. (The current
# materialize.sh checks DRY_RUN in ~11 separate functions, each independently
# responsible for describing itself; that is the shape being replaced.)
#
# Journal format:  <verb>\t<path>\t<detail>
#
# Requires lib/common.sh (sha256_of) and lib/manifest.sh (manifest_paths) to
# have been sourced by the caller.

hop_ops_init() {
  PROJECT_ROOT="$1"
  HOP_SOURCE_MANIFEST="$2"
  HOP_RECORD="$3"
  HOP_JOURNAL="${HOP_JOURNAL:-$(mktemp)}"
  : > "$HOP_JOURNAL"
}

_hop_journal() { printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >> "$HOP_JOURNAL"; }

# A missing source is a SILENT NO-OP. Operator deletion is expected — INSPIRE
# is a methodology, not a framework — and this is also what makes a
# half-completed hop safe to re-run: a finished move skips itself.
hop_mv() {
  local src="$1" dst="$2"
  [ -e "$PROJECT_ROOT/$src" ] || return 0
  _hop_journal move "$src" "$dst"
  [ "$HOP_RECORD" = 1 ] && return 0
  mkdir -p "$(dirname "$PROJECT_ROOT/$dst")"
  mv "$PROJECT_ROOT/$src" "$PROJECT_ROOT/$dst" || return 1
}

hop_rm() {
  local rel="$1"
  [ -e "$PROJECT_ROOT/$rel" ] || return 0
  _hop_journal delete "$rel"
  [ "$HOP_RECORD" = 1 ] && return 0
  rm -f "$PROJECT_ROOT/$rel" || return 1
}

# Remove, PER FILE, exactly the paths the source manifest lists under <prefix>
# AND whose content still matches what we shipped. Two guards, not one:
#   · ownership — a directory-level rm is only permissible where we can prove we
#     own everything inside, and we cannot: an operator may have added files.
#   · modification — a file we shipped but the operator EDITED is never deleted.
#     Their edit exists nowhere else, and "never delete an edited file" applies
#     here exactly as it does in the content merge.
# Anything surviving either guard is reported, so the operator learns why the
# directory is still there and what of theirs was found in it.
hop_rm_owned() {
  local prefix="${1%/}" path hash abs
  local edited_n=0
  local -a survivors=() decided=() unowned=()

  while IFS=$'\t' read -r path hash; do
    [ -n "$path" ] || continue
    case "$path" in "$prefix"/*) ;; *) continue ;; esac
    [ -e "$PROJECT_ROOT/$path" ] || continue
    # Ruled on below either way. Remember the DECISION, not the mode: in record
    # mode nothing is removed, so the disk scan further down sees every shipped
    # file still sitting there and would otherwise report it as the operator's.
    # Keying off HOP_RECORD instead would make the label mode-dependent — and
    # in act mode it mislabelled a file we shipped as "yours".
    decided+=("$path")
    if [ "$(sha256_of "$PROJECT_ROOT/$path")" != "$hash" ]; then
      _hop_journal keep "$path" "you edited this — not removing it"
      edited_n=$((edited_n + 1))
      continue
    fi
    _hop_journal delete "$path"
    [ "$HOP_RECORD" = 1 ] && continue
    rm -f "$PROJECT_ROOT/$path"
  done < <(manifest_paths "$HOP_SOURCE_MANIFEST")

  if [ -d "$PROJECT_ROOT/$prefix" ]; then
    while IFS= read -r abs; do
      survivors+=("${abs#"$PROJECT_ROOT"/}")
    done < <(find "$PROJECT_ROOT/$prefix" -type f 2>/dev/null)
  fi

  # Anything on disk we never ruled on was never ours.
  local s d claimed
  for s in ${survivors[@]+"${survivors[@]}"}; do
    claimed=0
    for d in ${decided[@]+"${decided[@]}"}; do
      [ "$d" = "$s" ] && { claimed=1; break; }
    done
    [ "$claimed" = 1 ] && continue
    unowned+=("$s")
    _hop_journal keep "$s" "yours — not shipped by INSPIRE"
  done

  # The directory can go only if NOTHING will be left in it — neither files of
  # theirs nor files of ours they edited. Both modes evaluate the same
  # predicate, so record mode predicts exactly what act mode does.
  if [ "${#unowned[@]}" -eq 0 ] && [ "$edited_n" -eq 0 ]; then
    if [ "$HOP_RECORD" = 1 ]; then
      _hop_journal delete "$prefix/" "directory emptied and removed"
    else
      # Bottom-up, because the tree is deep (.claude/bin/test/ is ~230 nested
      # directories) and a single rmdir on the top could never succeed. rmdir
      # refuses a non-empty directory, so this clears our empty scaffolding and
      # stops dead at anything of theirs — never rm -rf. Best-effort: the
      # journal below reports what actually happened, not what we attempted.
      find "$PROJECT_ROOT/$prefix" -depth -type d -exec rmdir {} + 2>/dev/null
      if [ -d "$PROJECT_ROOT/$prefix" ]; then
        _hop_journal keep "$prefix/" "directory left in place — it could not be removed"
      else
        _hop_journal delete "$prefix/" "directory emptied and removed"
      fi
    fi
  elif [ "${#unowned[@]}" -gt 0 ]; then
    _hop_journal keep "$prefix/" "directory left in place — it still holds your files"
  else
    _hop_journal keep "$prefix/" "directory left in place — it still holds files you edited"
  fi

  # Never end on the status of a best-effort prune: a hop script guards these
  # calls with `|| return`, and a failed rmdir is not a failed migration.
  return 0
}

# Queues a plain SUBSTRING. Any registered hook command containing it is
# retired by merge_settings. Deliberately not a glob: substring matching needs
# no regex escaping, and a jq `contains()` filter is trivially correct.
hop_unregister_hook() { _hop_journal unregister "$1" "retire stale hook registration"; }
hop_report()          { _hop_journal report "" "$1"; }
