#!/usr/bin/env bash
# Render the grouped operator-facing report. Sourced.
#
# Grouped by CONCEPT first, operation within. Operation-first says what
# happens; concept-first says whose files are being touched, which is the
# operator's actual question. Five sections, in order: RUNTIME (INSPIRE-
# owned), KNOWLEDGE BASE (theirs, additive only), HARNESS, PRODUCT (theirs,
# outside the runtime entirely — source/, prototype/, root CLAUDE.md — a
# fourth _group_of bucket that needs its own _emit_group call precisely
# because it is a legitimate answer to "whose files", not a catch-all to
# drop), and LEFT ALONE (report-verb notes with no path at all).
#
# Consumes two `<verb>\t<path>\t<detail>` files (see lib/hop-ops.sh and
# lib/merge.sh's classify): the hop journal (verbs move|delete|keep|
# unregister|report) and the verdict file (verbs noop|replace|keep|ask|
# create|restore|delete). `noop` lines mean nothing needs to change and are
# deliberately not surfaced — the operator does not need a line for every
# file INSPIRE chose not to touch.
#
# The two streams legitimately describe some of the same paths, so they are
# merged and de-duplicated on <verb>+<path> once, in render_report, and both the
# body and the footer read that one stream. The reasoning is written out there.
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

# _emit_group <title> <want> <merged>
# Prints the title once, lazily, only if a line for this group exists —
# an empty group is not shown at all. <merged> is the de-duplicated union of
# the two streams (see render_report), so a path both halves describe with the
# SAME verb is already down to one line by the time it gets here.
_emit_group() {
  local title="$1" want="$2" merged="$3" line verb path detail printed=0
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
  done < "$merged"
}

# render_report <from> <to> <hop_journal> <verdicts> <dry_run>
render_report() {
  local from="$1" to="$2" j="$3" v="$4" dry="$5"
  local banner=""
  [ "$dry" = 1 ] && banner="        DRY RUN · nothing will be written"

  printf '\nINSPIRE upgrade — %s → %s%s\n' "$from" "$to" "$banner" >&2

  # THE TWO STREAMS LEGITIMATELY OVERLAP, so they are merged and de-duplicated
  # ONCE, here, and everything below — body and footer alike — reads the result.
  #
  # The overlap is not a bug in either half: the hop journals `delete` for each
  # of the 114 pre-0.3 fixtures it removes, and classify independently reaches
  # `delete` for the same 114 because the target ships none of them. Rendered
  # raw that was 229 body lines about one prefix and a footer reading 232
  # deletions where 118 paths are deleted. Every line was true; the number an
  # operator judges the risk by was 2x reality, which is its own kind of false.
  #
  # De-duplication is on <verb>+<path> ONLY, deliberately:
  #   · same verb, same path → one fact stated twice, rendered once. The detail
  #     text may differ between the streams (`` vs "no longer part of INSPIRE");
  #     first line wins, and since the journal is concatenated first that is the
  #     hop's wording — the half that actually performed the operation.
  #   · DIFFERENT verbs on one path stay as separate lines: the 14 validators are
  #     genuinely both `move` (the hop relocates them) and `replace` (the content
  #     merge then installs a newer version at the new location). Collapsing those
  #     into one synthesised verb would invent an operation neither half performed.
  #   · a line with an EMPTY path is exempt: `report\t\t<message>` notes carry no
  #     path at all, so keying on verb+path would collapse every one of them into
  #     the first note. `$2==""` is checked before the seen[] test for that reason.
  local merged; merged="$(mktemp)"
  cat "$j" "$v" 2>/dev/null | awk -F'\t' '$2=="" || !seen[$1 FS $2]++' > "$merged"

  _emit_group 'RUNTIME — INSPIRE-owned'                          runtime "$merged"
  _emit_group 'KNOWLEDGE BASE — yours, additive only'            kb      "$merged"
  _emit_group 'HARNESS'                                          harness "$merged"
  _emit_group 'PRODUCT — yours, outside the INSPIRE runtime'     product "$merged"

  # Report-only notes carry no path, so they group by intent, not location.
  # Their whole point is an empty path (see _tsv_split) — plain `read` would
  # eat the message here, so this loop needs the same split. Read from $merged
  # like everything else, so ONE stream feeds the entire report: that is also
  # what makes the empty-path exemption in the de-dup filter load-bearing rather
  # than theoretical — without it, every note after the first would be dropped
  # here as a duplicate of the key `report<TAB>`.
  local line verb path detail any_note=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    _tsv_split "$line"; verb="$RVERB" path="$RPATH" detail="$RDETAIL"
    [ "$verb" = "report" ] || continue
    [ "$any_note" = 0 ] && { printf '\nLEFT ALONE — reported, never touched\n' >&2; any_note=1; }
    printf '  %s\n' "$detail" >&2
  done < "$merged"

  # Counted over the SAME de-duplicated stream the body renders, so the footer
  # and the lines above it can never disagree: one path with one verb is one
  # unit of work however many halves of the tool mention it. `unregister` and
  # `replace` are tallied too — the footer is the number an operator judges the
  # risk by, and silently omitting two of the seven verbs it could report makes
  # a small run look smaller than it is.
  local asks moves reps dels creates keeps unregs
  asks="$(awk    -F'\t' '$1=="ask"'                  "$merged" | wc -l | tr -d ' ')"
  moves="$(awk   -F'\t' '$1=="move"'                 "$merged" | wc -l | tr -d ' ')"
  reps="$(awk    -F'\t' '$1=="replace"'              "$merged" | wc -l | tr -d ' ')"
  dels="$(awk    -F'\t' '$1=="delete"'               "$merged" | wc -l | tr -d ' ')"
  creates="$(awk -F'\t' '$1=="create"||$1=="restore"' "$merged" | wc -l | tr -d ' ')"
  keeps="$(awk   -F'\t' '$1=="keep"'                 "$merged" | wc -l | tr -d ' ')"
  unregs="$(awk  -F'\t' '$1=="unregister"'           "$merged" | wc -l | tr -d ' ')"

  printf '\n%s decision(s) needed · %s moves · %s replacements · %s deletions · %s creations · %s keeps · %s hook registration(s) retired\n' \
    "$asks" "$moves" "$reps" "$dels" "$creates" "$keeps" "$unregs" >&2

  rm -f "$merged"

  if [ "$dry" = 1 ]; then
    printf '%s\n' \
      'Note: a move whose source is already absent is skipped silently, so this' \
      'list is a superset — some moves above may turn out to be no-ops.' >&2
  fi
}
