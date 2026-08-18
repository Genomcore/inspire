#!/usr/bin/env bash
# Layout hop: 0.6.x → 0.7.0 — retire the KB index mirrors.
#
# Sourced by lib/chain.sh with hop-ops already initialised. Unlike 0.3.0, which
# moved paths it could name blind, this hop DELETES files that live in the
# operator's KB — so nothing here is unconditional: every removal is either
# proved or asked about, per file, and the proof is computed identically in
# both modes.
#
# What 0.7.0 retires, and on what evidence (one source of truth on disk —
# the files ARE the index now):
#   · 02_modules/_index.md          — pristine seed, or derivable behind TWO
#     gates, both required: the registry table's row-set must equal what the
#     module hubs themselves yield (H1 → Module, frontmatter `prefix:` →
#     Prefix, basename → hub wikilink; hubs are 02_modules/*.md minus _*.md
#     and README.md), AND everything that is NOT a table row must still hash
#     to the seed's own non-row remainder — authored prose around a
#     perfectly-synced table is content the row compare cannot see, and
#     content we cannot see is content we never delete. Both gates hold →
#     retire. A hub missing its H1 or `prefix:`, zero hubs to derive from, or
#     any parse doubt → not provable → ask. Diverging rows or prose → ask.
#   · 05_screens/patterns/_index.md   — pristine seed only. The Purpose column
#   · 05_screens/components/_index.md — is authored prose (State too), so a
#     TOC that is not byte-identical to what we shipped is never "derived" at
#     it — anything edited is asked about, keep being the default.
#   · 01_adr/_index.md — INSPIRE never shipped one, so there is no seed to
#     prove against: exists → always ask; absent → no-op.
#   · Nothing else. Module hubs, READMEs, the screens `_index.md` files and
#     every other KB path are untouched by construction — they are simply not
#     in the list above.
#
# THE FIRST THREE CONSTANTS are the sha256 of the seeds as shipped —
# byte-identical from v0.1.0 through v0.6.0 (verified against every tag). The
# FOURTH is the sha256 of the modules seed's NON-ROW remainder (every line
# that is not a table row, extracted by the exact complement of the row
# filter below) — the second gate of the derive-equal verdict. The seeds
# leave base/kb/ in this same release, so seed_kb cannot resurrect what this
# hop retires, and the constants lose their in-tree source: the shipped bytes
# are preserved as fixtures under plugin/test/fixtures/retired-seeds/, and
# test-upgrade.sh asserts fixture hash == constant for all four, so a drift
# in either is caught.
#
# ROOT RESOLUTION IS EXISTENCE-FIRST AND MODE-BLIND, and must be: in record
# mode on a pre-0.3 project, hop 0.3.0 has journalled its moves but NOT
# performed them — hop_mv's record branch journals and returns before the mv
# (lib/hop-ops.sh, `if [ "$HOP_RECORD" = 1 ]` → `_hop_journal move; return 0`;
# the move itself is hops/0.3.0.sh:14) — so when chain.sh sources this hop in
# the same ascending pass of the same shell (lib/chain.sh:40-56, then the
# no-manifest fallback at :60-75 for the release being cut), the KB is still
# at .inspire_kb/. Act mode sees it at inspire_kb/ because 0.3.0 really moved
# it, and reconciliation never relocates the KB in any mode (inspire_kb/ is
# outside every dest_map — materialize.sh's module-state comment). Resolving
# by existence rather than by mode is what keeps the two modes' verdicts
# identical.
#
# EVERY JOURNALLED OR RESOLUTION-MATCHED PATH IS IN THE POST-HOP SPACE
# (inspire_kb/...), whichever root was read: the operator hands a path from
# the plan's ask[] straight back as --take-base/--take-mine, and a path
# journalled in the pre-hop space could never match — the answer would be
# silently discarded (see hop_ask in lib/hop-ops.sh, and the contract pinned
# in materialize.sh's _warn_unmatched_resolutions: a hop that consumes a
# --take-* path journals that path, whichever verb applies).
#
# Per the header rules in lib/hop-ops.sh: every variable here carries the
# _h7_ prefix (this file is sourced inside run_chain's frame), and the
# resolution arrays are only ever read through the `set -u` guard idiom.

_h7_sha_modules='db10676e1219546074e6e8cbaef5e33b1a0c78c4e7166331a791b0502c19b724'
_h7_sha_patterns='217d01a71ac258a06c1ea32eaf378d29872a3282d57d0afc2d1f303ecbb586e6'
_h7_sha_components='b899a06e4614bafe0996dad1027659cb6219cd0dc80db899cb09bc1ecca9f213'
_h7_sha_modules_prose='6e1bd27f4495caa4f0450f633302e510aae85eaab8f603f3f3ca73a788af09a2'

_h7_root='inspire_kb'
[ -d "$PROJECT_ROOT/inspire_kb" ] || _h7_root='.inspire_kb'

# Row normalization — pinned here (and by fixtures) because both sides of the
# derive-then-diff must pass through the SAME funnel or the comparison tests
# formatting instead of content. Backticks are presentation (`AUTH` and AUTH
# are one prefix), wikilink display text is presentation ([[auth|Auth]] and
# [[auth]] are one link), whitespace runs and CR line endings are
# presentation. The funnel is only HALF the safety argument, though: it sees
# table rows and nothing else, so the derive-equal verdict stands on TWO
# gates — row-set equality through this funnel, AND the file's non-row
# remainder hashing to the seed's (see _h7_nonrow_sha). Within the rows,
# anything the funnel does not normalize (markdown links instead of
# wikilinks, escaped pipes, reordered columns) makes the sets differ, and
# differing sets ASK — the safe direction, never a silent delete. Plain
# `sort`, never `sort -u`: the derived side cannot produce duplicates (two
# hubs cannot share a basename), so a duplicated on-disk row must survive to
# diverge, not collapse into the single row it duplicates.
_h7_norm_rows() {
  sed -e 's/`//g' -e 's/\[\[\([^]|]*\)|[^]]*\]\]/[[\1]]/g' \
    | awk '{ gsub(/[ \t\r]+/," "); sub(/^ +/,""); sub(/ +$/,""); if ($0 != "") print }' \
    | LC_ALL=C sort
}

# The on-disk half: every table row in the file, minus separator rows and the
# canonical header. A separator is recognised by its SHAPE — at least one
# cell, every non-empty cell nothing but dashes with optional alignment
# colons — never by its character set alone: a loose class like [|: -]+ also
# swallowed rows of empty cells, and anything this filter eats is invisible
# to the compare, which only ever errs toward a silent delete. A reshaped
# header is deliberately NOT dropped either — it lands in the row-set, the
# sets diverge, and the file is asked about rather than misread.
_h7_disk_rows() {
  awk '/^[ \t]*\|/' "$1" | _h7_norm_rows | awk '
    {
      _h7_a_sep = 1; _h7_a_cells = 0
      _h7_a_n = split($0, _h7_a_c, "|")
      for (_h7_a_i = 1; _h7_a_i <= _h7_a_n; _h7_a_i++) {
        _h7_a_cell = _h7_a_c[_h7_a_i]
        gsub(/^[ \t]+|[ \t]+$/, "", _h7_a_cell)
        if (_h7_a_cell == "") continue
        _h7_a_cells++
        if (_h7_a_cell !~ /^:?-+:?$/) { _h7_a_sep = 0; break }
      }
      if (_h7_a_sep && _h7_a_cells > 0) next
    }
    tolower($0) == "| module | prefix | hub |" { next }
    { print }'
}

# The non-row remainder — the exact complement of _h7_disk_rows' extraction,
# so rows and remainder partition the file with nothing in between. Hashed
# from a pipe (mirroring lib/common.sh's tool choice) because record mode
# writes no file anywhere, temp files included.
_h7_sha_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}
_h7_nonrow_sha() { awk '!/^[ \t]*\|/' "$1" | _h7_sha_stdin; }

# The derived half: one row per hub file. Returns 1 — not provable — the
# moment any hub lacks a usable H1 or `prefix:`; a registry we cannot fully
# re-derive is a registry we never diff, let alone delete. The `prefix:` value
# is read from the frontmatter block only, with a trailing `# comment`
# stripped (the shipped hub template carries one) and quoting/backticks
# normalized away. Single-quoted values are not normalized — they surface as a
# set difference, which asks.
_h7_derive_registry() {
  local _h7_d_dir="$1" _h7_d_hub _h7_d_base _h7_d_h1 _h7_d_prefix _h7_d_rows=''
  for _h7_d_hub in "$_h7_d_dir"/*.md; do
    [ -e "$_h7_d_hub" ] || continue
    _h7_d_base="${_h7_d_hub##*/}"
    case "$_h7_d_base" in _*|README.md) continue ;; esac
    [ -f "$_h7_d_hub" ] || return 1
    _h7_d_h1="$(awk '/^# /{ sub(/^# +/,""); sub(/[ \t]+$/,""); print; exit }' "$_h7_d_hub")"
    [ -n "$_h7_d_h1" ] || return 1
    _h7_d_prefix="$(awk '
      NR==1 { if ($0 !~ /^---[ \t]*$/) exit; next }
      /^---[ \t]*$/ { exit }
      /^prefix:/ { sub(/^prefix:[ \t]*/,"")
                   sub(/[ \t]+#.*$/,"")
                   gsub(/["`]/,"")
                   sub(/[ \t]+$/,"")
                   print; exit }' "$_h7_d_hub")"
    [ -n "$_h7_d_prefix" ] || return 1
    _h7_d_rows="${_h7_d_rows}| ${_h7_d_h1} | ${_h7_d_prefix} | [[${_h7_d_base%.md}]] |
"
  done
  # Zero rows is NOT a proof — it is nothing to prove WITH. An empty derived
  # set compares equal to any table-less file (the example row deleted, the
  # registry rewritten as a notes page), and "equal to nothing" must never
  # retire anything. No hubs → not provable → ask, like every other doubt.
  [ -n "$_h7_d_rows" ] || return 1
  printf '%s' "$_h7_d_rows" | _h7_norm_rows
  return 0
}

# Delete <post-hop rel path>, reading the file at whichever root exists. The
# indirection exists for exactly one reason: hop_rm journals the path it is
# given, and in record mode on a pre-0.3 tree the readable path (.inspire_kb/…)
# is not the answerable one (inspire_kb/…). So record mode replicates hop_rm's
# two guards against the ACTUAL path and journals the POST-HOP one; act mode
# calls hop_rm directly, and there the two paths are the same string because
# 0.3.0 really moved the tree before this hop was sourced. Same guards, same
# refusals, both modes — the directory refusal included, so a preview never
# forecasts a delete the real run would refuse.
_h7_rm() {
  local _h7_r_rel="$1" _h7_r_actual="$_h7_root/${1#inspire_kb/}"
  if [ "$HOP_RECORD" = 1 ]; then
    [ -e "$PROJECT_ROOT/$_h7_r_actual" ] || return 0
    if [ -d "$PROJECT_ROOT/$_h7_r_actual" ]; then
      log "INSPIRE: refusing to delete '$_h7_r_rel' — it is a directory."
      log "  hop_rm removes a single file; see lib/hop-ops.sh. Nothing was deleted."
      _hop_failed
      return 1
    fi
    _hop_journal delete "$_h7_r_rel"
    return 0
  fi
  # Act mode only ever reaches this hop through the post-hop root:
  # verify_layout refuses a tree where both roots exist (lib/manifest.sh's
  # ambiguity branch; layouts.tsv lists .inspire_kb under the 0.3 layout's
  # must_not_exist), and a pre-0.3 chain arrives here only after 0.3.0's
  # moves really happened. That argument lives three files away, though, so
  # it is CHECKED rather than assumed: hop_rm journals exactly the path it is
  # given, and handing it a pre-hop path would put an unanswerable path in
  # the operator's report.
  if [ "$_h7_r_actual" != "$_h7_r_rel" ]; then
    log "INSPIRE: refusing to delete '$_h7_r_rel' — act mode resolved the KB at"
    log "  '$_h7_root/', which is not the post-hop root. This is a bug in the"
    log "  hop or the chain, not in your project. Nothing was deleted."
    _hop_failed
    return 1
  fi
  hop_rm "$_h7_r_rel"
}

# One decision per file, in the one order that honours both the operator and
# the proof: an explicit --take-mine outranks everything (and is journalled as
# the keep it is — a consumed resolution must appear in the journal, see
# _warn_unmatched_resolutions); --take-base outranks the verdict (the operator
# may retire a file the verdict would have asked about); a proven verdict
# retires silently; everything else is a question. One path, one journal row.
_h7_settle() {
  local _h7_s_rel="$1" _h7_s_verdict="$2" _h7_s_detail="$3" _h7_s_p
  for _h7_s_p in ${TAKE_MINE[@]+"${TAKE_MINE[@]}"}; do
    [ "$_h7_s_p" = "$_h7_s_rel" ] || continue
    _hop_journal keep "$_h7_s_rel" 'kept on your instruction (--take-mine)'
    return 0
  done
  for _h7_s_p in ${TAKE_BASE[@]+"${TAKE_BASE[@]}"}; do
    [ "$_h7_s_p" = "$_h7_s_rel" ] || continue
    _h7_rm "$_h7_s_rel"
    return $?
  done
  case "$_h7_s_verdict" in
    retire) _h7_rm "$_h7_s_rel" ;;
    *)      hop_ask "$_h7_s_rel" "$_h7_s_detail" ;;
  esac
}

# --- 02_modules/_index.md — pristine, or derive-then-diff -------------------
_h7_abs="$PROJECT_ROOT/$_h7_root/02_modules/_index.md"
if [ -e "$_h7_abs" ]; then
  _h7_verdict=ask
  _h7_detail='edited, and not provably derivable from the module hubs — keep (default) or retire with --take-base; as of 0.7.0 the hub files themselves are the registry'
  if [ -f "$_h7_abs" ] && [ "$(sha256_of "$_h7_abs")" = "$_h7_sha_modules" ]; then
    _h7_verdict=retire
  elif [ -f "$_h7_abs" ] && _h7_derived="$(_h7_derive_registry "$PROJECT_ROOT/$_h7_root/02_modules")"; then
    # BOTH gates, and only then: rows the hubs re-derive, around prose that is
    # still the seed's. The row compare is blind to everything that is not a
    # table row, so authored content above or below a perfectly-synced table
    # would otherwise be deleted unseen.
    if [ "$_h7_derived" = "$(_h7_disk_rows "$_h7_abs")" ] \
       && [ "$(_h7_nonrow_sha "$_h7_abs")" = "$_h7_sha_modules_prose" ]; then
      _h7_verdict=retire
    else
      _h7_detail='edited: its rows or its prose differ from the seeded registry the module hubs derive — keep (default) or retire with --take-base; as of 0.7.0 the hub files themselves are the registry'
    fi
  fi
  _h7_settle 'inspire_kb/02_modules/_index.md' "$_h7_verdict" "$_h7_detail"
fi

# --- 05_screens/{patterns,components}/_index.md — pristine only -------------
_h7_abs="$PROJECT_ROOT/$_h7_root/05_screens/patterns/_index.md"
if [ -e "$_h7_abs" ]; then
  _h7_verdict=ask
  if [ -f "$_h7_abs" ] && [ "$(sha256_of "$_h7_abs")" = "$_h7_sha_patterns" ]; then
    _h7_verdict=retire
  fi
  _h7_settle 'inspire_kb/05_screens/patterns/_index.md' "$_h7_verdict" \
    'edited since it was seeded — keep (default) or retire with --take-base; as of 0.7.0 each pattern entry describes itself'
fi

_h7_abs="$PROJECT_ROOT/$_h7_root/05_screens/components/_index.md"
if [ -e "$_h7_abs" ]; then
  _h7_verdict=ask
  if [ -f "$_h7_abs" ] && [ "$(sha256_of "$_h7_abs")" = "$_h7_sha_components" ]; then
    _h7_verdict=retire
  fi
  _h7_settle 'inspire_kb/05_screens/components/_index.md' "$_h7_verdict" \
    'edited since it was seeded — keep (default) or retire with --take-base; as of 0.7.0 each component entry describes itself'
fi

# --- 01_adr/_index.md — never shipped, so never proved ----------------------
_h7_abs="$PROJECT_ROOT/$_h7_root/01_adr/_index.md"
if [ -e "$_h7_abs" ]; then
  _h7_settle 'inspire_kb/01_adr/_index.md' ask \
    'INSPIRE never shipped an ADR index, so nothing proves this one derivable — keep (default) or retire with --take-base; as of 0.7.0 ADRs are enumerated from 01_adr/ directly'
fi

# States the doctrine, not this run's arithmetic — the retired/kept/asked files
# are their own lines above, and their absence is itself the answer when a
# project already carries none of these. No imperative verbs (see 0.3.0's
# lesson): what to do with a KEPT index is the operator's call.
#
# The _h7_* helpers stay defined after the source, deliberately: the prefix
# means they collide with nothing (see the header rule in lib/hop-ops.sh), and
# test-upgrade.sh drives the derive/normalize layer through them directly.
# hop_report always returns 0, which is what a sourced hop's LAST command must
# do — the real failure channel is HOP_FAILED, never the exit status.
hop_report 'As of 0.7.0 the KB keeps no index mirrors: module hubs are enumerated by glob (inspire_kb/02_modules/*.md minus _*.md and README.md), and pattern/component entries carry their own Purpose and State. 0.7.0 also restructured the skills, so an ASK on a SKILL.md means part of its content now lives in new references/ files beside it — shipped as create rows in this same run.'
