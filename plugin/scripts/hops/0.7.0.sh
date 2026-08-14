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
#   · 02_modules/_index.md          — pristine seed, or derivable: the registry
#     table's row-set must equal what the module hubs themselves yield
#     (H1 → Module, frontmatter `prefix:` → Prefix, basename → hub wikilink;
#     hubs are 02_modules/*.md minus _*.md and README.md). Match → retire.
#     A hub missing its H1 or `prefix:`, or any parse doubt → not provable →
#     ask. Diverging rows → ask.
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
# THE THREE CONSTANTS are the sha256 of the seeds as shipped — byte-identical
# from v0.1.0 through v0.6.0 (verified against every tag). The seeds leave
# base/kb/ in this same release, so seed_kb cannot resurrect what this hop
# retires, and the constants lose their in-tree source: the shipped bytes are
# preserved as fixtures under plugin/test/fixtures/retired-seeds/, and
# test-upgrade.sh asserts fixture hash == constant, so a drift in either is
# caught.
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

_h7_root='inspire_kb'
[ -d "$PROJECT_ROOT/inspire_kb" ] || _h7_root='.inspire_kb'

# Row normalization — pinned here (and by fixtures) because both sides of the
# derive-then-diff must pass through the SAME funnel or the comparison tests
# formatting instead of content. Backticks are presentation (`AUTH` and AUTH
# are one prefix), wikilink display text is presentation ([[auth|Auth]] and
# [[auth]] are one link), whitespace runs are presentation. Anything this
# funnel does NOT normalize (markdown links instead of wikilinks, escaped
# pipes, reordered columns) makes the sets differ, and differing sets ASK —
# the safe direction, never a silent delete.
_h7_norm_rows() {
  sed -e 's/`//g' -e 's/\[\[\([^]|]*\)|[^]]*\]\]/[[\1]]/g' \
    | awk '{ gsub(/[ \t]+/," "); sub(/^ +/,""); sub(/ +$/,""); if ($0 != "") print }' \
    | LC_ALL=C sort -u
}

# The on-disk half: every table row in the file, minus separator rows and the
# canonical header. A reshaped header is deliberately NOT dropped — it lands in
# the row-set, the sets diverge, and the file is asked about rather than
# misread.
_h7_disk_rows() {
  awk '/^[ \t]*\|/' "$1" | _h7_norm_rows | awk '
    /^[|: -]+$/ { next }
    tolower($0) == "| module | prefix | hub |" { next }
    { print }'
}

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
  hop_rm "$_h7_r_actual"
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
    if [ "$_h7_derived" = "$(_h7_disk_rows "$_h7_abs")" ]; then
      _h7_verdict=retire
    else
      _h7_detail='edited: its rows differ from what the module hubs derive — keep (default) or retire with --take-base; as of 0.7.0 the hub files themselves are the registry'
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
hop_report 'As of 0.7.0 the KB keeps no index mirrors: module hubs are enumerated by glob (inspire_kb/02_modules/*.md minus _*.md and README.md), and pattern/component entries carry their own Purpose and State.'

# The chain sources every hop into one shell; the helpers are single-use and
# prefixed, so this is hygiene, not correctness. `unset` returns 0, which is
# also what a sourced hop's LAST command must do (see HOP_FAILED in
# lib/hop-ops.sh — the real failure channel is the counter, never the status).
unset -f _h7_norm_rows _h7_disk_rows _h7_derive_registry _h7_rm _h7_settle
unset _h7_sha_modules _h7_sha_patterns _h7_sha_components _h7_root _h7_abs _h7_verdict _h7_detail _h7_derived
