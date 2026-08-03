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

# KNOWN LIMITATION: a path containing a literal TAB or NEWLINE is not
# representable in this format — the tab would read as a field separator and
# produce a 4-field line that downstream `awk -F'\t'` mis-parses. No
# INSPIRE-shipped path contains either character, and both are pathological in
# a repository, but git can store them, so a project-authored path could hit
# it. The consequence is confined to how the REPORT renders: what gets deleted
# and what gets kept is decided by the operations themselves, never by re-
# reading the journal. Deliberately not escaped or quoted here — the format is
# consumed by Tasks 8 and 11 with plain `awk -F'\t'`, and complicating it for a
# case that cannot arise from anything we ship is not worth the ripple.
_hop_journal() { printf '%s\t%s\t%s\n' "$1" "$2" "${3:-}" >> "$HOP_JOURNAL"; }

# ACT MODE MUTATES FIRST AND JOURNALS SECOND, always. The journal is the
# operator's report and nothing downstream ever cross-checks it against disk, so
# a line written before the operation is a claim we cannot support: a read-only
# mount, an immutable flag, a file created under sudo or a full disk all make the
# mutation fail while the line already says it succeeded. Failing that way is
# safe for the operator's DATA — nothing is destroyed — but it makes the report
# lie in the direction of "we cleaned up", which is exactly what this design
# forbids.
#
# _hop_reason turns a tool's stderr into a short reason fit for the journal's
# detail field: tabs and newlines flattened (they would corrupt the format), and
# the "rm: /long/abs/path: " prefix stripped so the operator reads "Permission
# denied" rather than a duplicated absolute path.
_hop_reason() {
  local msg
  msg="$(printf '%s' "${1:-}" | tr '\t\n' '  ' | sed 's/  */ /g; s/ *$//')"
  msg="${msg##*: }"
  [ -n "$msg" ] || msg="unknown error"
  printf '%s\n' "$msg"
}

# A missing source is a SILENT NO-OP. Operator deletion is expected — INSPIRE
# is a methodology, not a framework — and this is also what makes a
# half-completed hop safe to re-run: a finished move skips itself.
#
# An existing DIRECTORY at the destination is a hard refusal, because `mv a b`
# with `b` a directory does not replace `b` — it puts `a` INSIDE it, yielding
# `b/a` and reporting success. That is silent tree corruption of exactly the
# kind this design exists to prevent, and it is reachable: a pre-0.3 project
# retains `.inspire/bin` as the staged source install.sh copied FROM, so a hop
# moving `.claude/bin` onto it would produce `.inspire/bin/bin`. A hop that
# hits this is wrong and must stop, in BOTH modes, so a record-mode preview
# surfaces it before anything is touched. Nothing is journalled on the refusal
# path: the report must never claim a move that did not happen.
#
# CAVEAT: a symlink whose target is RELATIVE is moved verbatim, so moving it
# across directory depth leaves it dangling. `find plugin/base -type l` is empty
# today, so no shipped path can trigger it; written down so it is not
# rediscovered the hard way if that ever changes.
hop_mv() {
  local src="$1" dst="$2" err reason
  [ -e "$PROJECT_ROOT/$src" ] || return 0
  if [ -d "$PROJECT_ROOT/$dst" ]; then
    log "INSPIRE: refusing to move '$src' onto '$dst'."
    log "  '$dst' already exists and is a directory, so the move would nest the"
    log "  source inside it ('$dst/$(basename "$src")') instead of replacing it."
    log "  This is a bug in the hop script, not in your project. Nothing was moved."
    return 1
  fi
  # Record mode journals the INTENDED verb, because whether the mutation would
  # fail is not knowable without attempting it. That divergence is deliberate —
  # the preview is a superset of what act mode achieves — and must not later be
  # "fixed" into a claim act mode cannot honour.
  if [ "$HOP_RECORD" = 1 ]; then
    _hop_journal move "$src" "$dst"
    return 0
  fi
  mkdir -p "$(dirname "$PROJECT_ROOT/$dst")" 2>/dev/null
  err="$(mv "$PROJECT_ROOT/$src" "$PROJECT_ROOT/$dst" 2>&1)"
  if [ ! -e "$PROJECT_ROOT/$src" ] && [ -e "$PROJECT_ROOT/$dst" ]; then
    _hop_journal move "$src" "$dst"
    return 0
  fi
  reason="$(_hop_reason "$err")"
  log "INSPIRE: could not move '$src' to '$dst' — $reason."
  log "  Nothing was moved. The report will say so rather than claim otherwise."
  _hop_journal keep "$src" "could not be moved ($reason)"
  return 1
}

# Removes ONE FILE whose ownership is provable from its name alone. A directory
# is refused: removing one requires proving we own everything inside it, which
# we cannot do from a name, and which is hop_rm_owned's job. Without this,
# `rm -f` leaked a raw "is a directory" error and the journal had already
# recorded a `delete` that never happened. Note `-d` follows symlinks, so a
# symlink pointing at a directory is refused too — the safe direction.
hop_rm() {
  local rel="$1" err reason
  [ -e "$PROJECT_ROOT/$rel" ] || return 0
  if [ -d "$PROJECT_ROOT/$rel" ]; then
    log "INSPIRE: refusing to delete '$rel' — it is a directory."
    log "  hop_rm removes a single file whose ownership is provable by name."
    log "  Removing a directory means proving we own everything inside it; that"
    log "  is hop_rm_owned's job. This is a bug in the hop script. Nothing was"
    log "  deleted."
    return 1
  fi
  # Record mode journals the intended verb — see hop_mv.
  if [ "$HOP_RECORD" = 1 ]; then
    _hop_journal delete "$rel"
    return 0
  fi
  err="$(rm -f "$PROJECT_ROOT/$rel" 2>&1)"
  # Disk is the arbiter, not the exit status: journal `delete` only once the
  # path is demonstrably gone.
  if [ ! -e "$PROJECT_ROOT/$rel" ]; then
    _hop_journal delete "$rel"
    return 0
  fi
  reason="$(_hop_reason "$err")"
  log "INSPIRE: could not delete '$rel' — $reason."
  log "  It is still on disk, and the report will say so rather than claim it"
  log "  was removed."
  _hop_journal keep "$rel" "could not be removed ($reason)"
  return 1
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
  local prefix="${1%/}" path hash abs err reason
  local edited_n=0 failed_n=0
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
    # "differs from what we shipped" rather than "you edited this": a hash
    # mismatch also covers a type swap (they deleted our file and mkdir'd the
    # same name) and an unreadable path. All are KEPT, which is right; only the
    # wording needed to stop asserting an edit we cannot prove.
    if [ "$(sha256_of "$PROJECT_ROOT/$path")" != "$hash" ]; then
      _hop_journal keep "$path" "differs from what we shipped — not removing it"
      edited_n=$((edited_n + 1))
      continue
    fi
    # Record mode journals the intended verb — see hop_mv.
    if [ "$HOP_RECORD" = 1 ]; then
      _hop_journal delete "$path"
      continue
    fi
    # Act: mutate first, then journal what actually happened. The old order
    # journalled `delete` for every owned file and never checked `rm`'s result,
    # so a chmod-555 parent produced a journal claiming 100% success, rc=0, and
    # nothing removed.
    err="$(rm -f "$PROJECT_ROOT/$path" 2>&1)"
    if [ ! -e "$PROJECT_ROOT/$path" ]; then
      _hop_journal delete "$path"
    else
      reason="$(_hop_reason "$err")"
      log "INSPIRE: could not delete '$path' — $reason."
      _hop_journal keep "$path" "could not be removed ($reason)"
      failed_n=$((failed_n + 1))
    fi
  done < <(manifest_paths "$HOP_SOURCE_MANIFEST")

  # `! -type d`, NOT `-type f`. A symlink is a directory entry regardless of
  # what it points at, so `-type f` counted zero survivors for a directory that
  # `rmdir` then refused to remove — act mode discovered this empirically via
  # the prune while record mode trusted the count, and the two modes returned
  # OPPOSITE directory verdicts on identical input. That is not the
  # dry-run-is-a-superset caveat (which licenses over-reporting a move that
  # turns out to be a no-op); it is a flat contradiction about a deletion. This
  # also picks up fifos, sockets and device nodes — equally foreign entries we
  # must never delete and must report. The DELETION loop above is unaffected:
  # its paths come from the manifest, never from `find`.
  if [ -d "$PROJECT_ROOT/$prefix" ]; then
    while IFS= read -r abs; do
      survivors+=("${abs#"$PROJECT_ROOT"/}")
    done < <(find "$PROJECT_ROOT/$prefix" ! -type d 2>/dev/null)
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
  if [ "${#unowned[@]}" -eq 0 ] && [ "$edited_n" -eq 0 ] && [ "$failed_n" -eq 0 ]; then
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
  elif [ "$edited_n" -gt 0 ]; then
    _hop_journal keep "$prefix/" "directory left in place — it still holds files you changed"
  else
    _hop_journal keep "$prefix/" "directory left in place — files in it could not be removed"
  fi

  # A failed FILE deletion is a real failure and must propagate: the caller has
  # to know the prefix was not cleared. A failed rmdir PRUNE must not — leftover
  # empty scaffolding is cosmetic, the journal already reports it honestly, and
  # a hop guarded by `|| return` must not abort over it. Hence: rmdir failure
  # → 0, file-deletion failure → non-zero. Remaining work is always completed
  # first; partial progress is fine because a hop is re-runnable.
  [ "$failed_n" -eq 0 ] || return 1
  return 0
}

# Queues a plain SUBSTRING. Any registered hook command containing it is
# retired by merge_settings. Deliberately not a glob: substring matching needs
# no regex escaping, and a jq `contains()` filter is trivially correct.
hop_unregister_hook() { _hop_journal unregister "$1" "retire stale hook registration"; }
hop_report()          { _hop_journal report "" "$1"; }
