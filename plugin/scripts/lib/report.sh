#!/usr/bin/env bash
# Render the grouped operator-facing report. Sourced.
#
# Grouped by CONCEPT first, operation within. Operation-first says what
# happens; concept-first says whose files are being touched, which is the
# operator's actual question.
#
# Consumes two `<verb>\t<path>\t<detail>` files (see lib/hop-ops.sh and
# lib/merge.sh's classify): the hop journal (verbs move|delete|keep|
# unregister|report) and the verdict file (verbs noop|replace|keep|ask|
# create|restore|delete). `noop` lines mean nothing needs to change and are
# deliberately not surfaced — the operator does not need a line for every
# file INSPIRE chose not to touch.
#
# A path containing a literal tab or newline is not representable in this
# format; see the caveat at _hop_journal in lib/hop-ops.sh. Not our problem
# to fix here — this renderer consumes the format as documented, plain
# `awk -F'\t'`, no escaping.
#
# stdout is reserved for materialize.sh's JSON summary; every line of this
# report goes to stderr.

# _group_of <path> → runtime | kb | harness | product
_group_of() {
  case "$1" in
    inspire_kb|inspire_kb/*|.inspire_kb|.inspire_kb/*) printf 'kb\n' ;;
    .claude/settings.json|.inspire.lock|.gitignore)    printf 'harness\n' ;;
    .claude/*|.inspire/*)                              printf 'runtime\n' ;;
    *)                                                 printf 'product\n' ;;
  esac
}

# _tsv_split <line> → sets RVERB / RPATH / RDETAIL.
#
# NOT `IFS=$'\t' read -r a b c`: bash classifies tab as "IFS whitespace"
# no matter what else is in $IFS, so `read` collapses runs of it — an empty
# MIDDLE field (report lines are `report\t\t<message>`, empty path) silently
# vanishes and the message shifts into the path slot. Parameter expansion
# does not collapse, so it is the only correct way to split this format.
_tsv_split() {
  local line="$1"
  RVERB="${line%%$'\t'*}"
  local rest="${line#*$'\t'}"
  RPATH="${rest%%$'\t'*}"
  RDETAIL="${rest#*$'\t'}"
}

# _emit_group <title> <want> <hop_journal> <verdicts>
# Prints the title once, lazily, only if a line for this group exists —
# an empty group is not shown at all.
_emit_group() {
  local title="$1" want="$2" j="$3" v="$4" line verb path detail printed=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    _tsv_split "$line"; verb="$RVERB" path="$RPATH" detail="$RDETAIL"
    [ -n "$path" ] || continue
    [ "$(_group_of "$path")" = "$want" ] || continue
    case "$verb" in
      move)   [ "$printed" = 0 ] && { printf '\n%s\n' "$title" >&2; printed=1; }
              printf '  move     %-46s → %s\n' "$path" "$detail" >&2 ;;
      delete) [ "$printed" = 0 ] && { printf '\n%s\n' "$title" >&2; printed=1; }
              printf '  delete   %-46s %s\n' "$path" "$detail" >&2 ;;
      keep)   [ "$printed" = 0 ] && { printf '\n%s\n' "$title" >&2; printed=1; }
              printf '  keep     %-46s %s\n' "$path" "$detail" >&2 ;;
      unregister)
              [ "$printed" = 0 ] && { printf '\n%s\n' "$title" >&2; printed=1; }
              printf '  unregister %-44s %s\n' "$path" "$detail" >&2 ;;
      replace|create|restore)
              [ "$printed" = 0 ] && { printf '\n%s\n' "$title" >&2; printed=1; }
              printf '  %-8s %-46s %s\n' "$verb" "$path" "$detail" >&2 ;;
      ask)    [ "$printed" = 0 ] && { printf '\n%s\n' "$title" >&2; printed=1; }
              printf '  ASK      %-46s %s\n' "$path" "$detail" >&2 ;;
      # noop: nothing changed, nothing to tell the operator — deliberately silent.
    esac
  done < <(cat "$j" "$v" 2>/dev/null)
}

# render_report <from> <to> <hop_journal> <verdicts> <dry_run>
render_report() {
  local from="$1" to="$2" j="$3" v="$4" dry="$5"
  local banner=""
  [ "$dry" = 1 ] && banner="        DRY RUN · nothing will be written"

  printf '\nINSPIRE upgrade — %s → %s%s\n' "$from" "$to" "$banner" >&2

  _emit_group 'RUNTIME — INSPIRE-owned'                runtime "$j" "$v"
  _emit_group 'KNOWLEDGE BASE — yours, additive only'  kb      "$j" "$v"
  _emit_group 'HARNESS'                                harness "$j" "$v"

  # Report-only notes carry no path, so they group by intent, not location.
  # Their whole point is an empty path (see _tsv_split) — plain `read` would
  # eat the message here, so this loop needs the same split.
  local line verb path detail any_note=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    _tsv_split "$line"; verb="$RVERB" path="$RPATH" detail="$RDETAIL"
    [ "$verb" = "report" ] || continue
    [ "$any_note" = 0 ] && { printf '\nLEFT ALONE — reported, never touched\n' >&2; any_note=1; }
    printf '  %s\n' "$detail" >&2
  done < "$j"

  local asks moves dels creates keeps
  asks="$(awk -F'\t'   '$1=="ask"'    "$v" 2>/dev/null | wc -l | tr -d ' ')"
  moves="$(awk -F'\t'  '$1=="move"'   "$j" 2>/dev/null | wc -l | tr -d ' ')"
  dels="$(cat "$j" "$v" 2>/dev/null | awk -F'\t' '$1=="delete"' | wc -l | tr -d ' ')"
  creates="$(awk -F'\t' '$1=="create"||$1=="restore"' "$v" 2>/dev/null | wc -l | tr -d ' ')"
  keeps="$(cat "$j" "$v" 2>/dev/null | awk -F'\t' '$1=="keep"' | wc -l | tr -d ' ')"

  printf '\n%s decision(s) needed · %s moves · %s deletions · %s creations · %s keeps\n' \
    "$asks" "$moves" "$dels" "$creates" "$keeps" >&2

  if [ "$dry" = 1 ]; then
    printf '%s\n' \
      'Note: a move whose source is already absent is skipped silently, so this' \
      'list is a superset — some moves above may turn out to be no-ops.' >&2
  fi
}
