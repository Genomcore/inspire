#!/usr/bin/env bash
# Render the grouped operator-facing report. Sourced.
#
# Grouped by CONCEPT first, operation within. Operation-first says what
# happens; concept-first says whose files are being touched, which is the
# operator's actual question. Five sections, in order:
#   · RUNTIME — INSPIRE-owned;
#   · KNOWLEDGE BASE — theirs; additive, except where a versioned hop retires
#     a file it can prove derivable or asks before touching one it cannot, and
#     the group's own title says which of the two this run is;
#   · HARNESS;
#   · PRODUCT — theirs, outside the runtime entirely (source/, prototype/,
#     root CLAUDE.md): a fourth _group_of bucket with its own _emit_group call
#     precisely because it is a legitimate answer to "whose files", not a
#     catch-all to drop;
#   · LEFT ALONE — report-verb notes with no path at all.
#
# Consumes two `<verb>\t<path>\t<detail>` files (see lib/hop-ops.sh and
# lib/merge.sh's classify): the hop journal (verbs move|delete|keep|
# unregister|report|ask) and the verdict file (verbs noop|replace|keep|ask|
# create|restore|delete). `ask` is the one verb BOTH streams emit — classify
# asks about a file both sides changed, a hop asks before retiring one it
# cannot prove derivable — and they render and tally identically, so the
# renderer needs no idea which half a question came from. `noop` lines mean
# nothing needs to change and are
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

# Where the rendered report is persisted, relative to the project root.
#
# ONE file, overwritten every run — not appended, not rotated, not timestamped.
# An upgrade that accumulated a log directory would be a new thing for the
# operator to maintain; the question this answers is only ever "what did the last
# upgrade do to this project", which the previous release could not answer at all
# (the grouped report went to stderr and nothing persisted, so a blind
# verification of a real 0.1→0.4 migration had to ask the operator what they ran).
#
# .inspire/ ROOT, deliberately, and never inside a dest_map root
# (.inspire/bin, .claude/inspire/hooks, .claude/skills): classify's pass 3 walks
# every dest_map root looking for project-authored files, so a log placed in one
# would come back on the NEXT run as `keep … yours — INSPIRE never shipped this`.
# That claim would be false, and it would repeat forever.
REPORT_LOG_REL='.inspire/last-upgrade.log'

# render_report <from> <to> <hop_journal> <verdicts> <dry_run> [<project_root>]
#
# With a project root, and in ACT MODE ONLY, the rendered report is also written
# to <project_root>/.inspire/last-upgrade.log. RECORD MODE WRITES NOTHING — that
# is its whole contract, asserted by a whole-tree hash taken before and after
# `--mode plan` — so the log is skipped there, and a caller that passes no root
# (the report's own unit tests) gets stderr only.
#
# The body is rendered with its stderr captured so the file and the terminal get
# the SAME bytes: a second rendering pass, or a tee of a subset of the lines, is
# how a persisted audit trail starts disagreeing with what the operator read.
render_report() {
  local from="$1" to="$2" j="$3" v="$4" dry="$5" root="${6:-}"
  local tmp=""

  if [ "$dry" != 1 ] && [ -n "$root" ]; then
    tmp="$(mktemp 2>/dev/null)" || tmp=""
  fi

  if [ -z "$tmp" ]; then
    _render_report "$from" "$to" "$j" "$v" "$dry" ""
    return 0
  fi

  _render_report "$from" "$to" "$j" "$v" "$dry" "$REPORT_LOG_REL" 2> "$tmp"
  cat "$tmp" >&2
  mkdir -p "$(dirname "$root/$REPORT_LOG_REL")" 2>/dev/null
  # 644 explicitly: mktemp's 0600 would be a surprising mode for a plain audit
  # log, and `cp` onto an existing file keeps whatever mode is already there.
  if cp "$tmp" "$root/$REPORT_LOG_REL" 2>/dev/null; then
    chmod 644 "$root/$REPORT_LOG_REL" 2>/dev/null
  else
    log "INSPIRE: the report above could not be saved to $REPORT_LOG_REL."
    log "  Nothing else is affected — the upgrade itself is unchanged."
  fi
  rm -f "$tmp"
  return 0
}

# _render_report <from> <to> <hop_journal> <verdicts> <dry_run> <log_rel_or_empty>
_render_report() {
  local from="$1" to="$2" j="$3" v="$4" dry="$5" logrel="${6:-}"
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

  # THE KB TITLE IS A CLAIM, so it is decided by this run's contents rather than
  # written once and hoped for. "additive only" was true while the KB was seeded
  # and never otherwise touched; as of 0.7.0 a versioned hop retires an index it
  # can prove derivable, and asks before touching one it cannot — and an
  # "additive only" heading printed directly above a `delete` row is the report
  # claiming what did not happen, which is the failure mode this renderer exists
  # to prevent. A hop_report note cannot carry the qualification instead: notes
  # render at the bottom, under LEFT ALONE — structurally distant and
  # semantically opposite.
  #
  # The predicate mirrors _group_of's kb case rather than matching `inspire_kb/`
  # alone: a pre-0.3 tree's `.inspire_kb/…` rows group here too, and a delete row
  # under a title that denies deletions is the same lie either way.
  # No version literal in the string: the predicate is version-agnostic (any
  # release's hop can retire a KB file), so a title naming one release would be
  # the same write-once-and-hope defect one layer in.
  local kb_title='KNOWLEDGE BASE — yours, additive only'
  if awk -F'\t' '($1=="delete" || $1=="ask") && $2 ~ /^\.?inspire_kb(\/|$)/ {found=1}
                 END {exit !found}' "$merged"; then
    kb_title='KNOWLEDGE BASE — yours; additive, except the index retirements below'
  fi

  _emit_group 'RUNTIME — INSPIRE-owned'                          runtime "$merged"
  _emit_group "$kb_title"                                        kb      "$merged"
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

  # Named inside the report itself, so an operator who reads this once knows where
  # to find it afterwards without being told separately.
  [ -n "$logrel" ] && \
    printf '\nThis report was also saved to %s (overwritten by the next run).\n' "$logrel" >&2

  if [ "$dry" = 1 ]; then
    printf '%s\n' \
      'Note: a move whose source is already absent is skipped silently, so this' \
      'list is a superset — some moves above may turn out to be no-ops. In one' \
      'narrow way it is also an under-report: the real run removes a directory its' \
      'own moves and deletions leave empty, which is not forecast here.' >&2
  fi
  return 0
}
