#!/usr/bin/env bash
# .inspire/bin/lib/gate-citations.sh
#
# Library — the `@claim` scanner, SHARED by `emanate-gate.sh` (coverage) and
# `emanate-plan.sh` (realization). It walks the tests root(s), greps the token
# (tester.md's grammar, normative) and reports every citation it finds; the
# split into this unit's own claims and GV-04's dangling ones stays gate's.
#
# The token carries an id and, since 0.9, an optional FINGERPRINT:
# `@claim <id> <sha256:…>`. Both forms parse. The id half is what gate's
# coverage classes read, so an id-only citation still covers a claim; the
# fingerprint half is what plan's realization reads, so an id-only citation
# never realizes a unit. That asymmetry is the whole point — coverage asks
# "did anyone test this claim", realization asks "did anyone test THIS
# VERSION of it", and only the second needs the meaning pinned.
#
# The second token is read as a fingerprint only when it is spelled
# `sha256:<hex>` (`derived-contract.md` § The fingerprint). Anything else
# after the id is prose and is ignored, exactly as it was before the second
# token existed — so a trailing comment can never be misread as a
# fingerprint, and the failure direction of a misread is always "not
# realized" rather than "realized on a stale claim".
#
# Granularity is the file (R3): a citation is `{file, line}`, never a test
# name — tester.md is explicit that a grep knows no test syntax.
#
# The brief's `grep -IHnoE` is run per file below rather than batched with
# `-H` across many: the loop already knows which file it is reading, so
# `-H`'s only job (naming the file in the match line) is redundant here, and
# the per-file form needs no colon-safe path quoting to unpick afterward.
# `-I` (skip binaries) is kept.
#
# Sourced by both tools, and standalone-safe: it depends on nothing from
# `_lib.sh` or the other `gate-*` units, and defaults its own separator so a
# caller that never sourced `gate-contract.sh` still works.

: "${GATE_FS:=$'\037'}"

# The grammar, in one place because two tools read it. `sha256:` is
# case-sensitive and lowercase-hex, matching what derive emits.
GATE_CLAIM_RE='@claim[[:space:]]+[^[:space:]]+([[:space:]]+sha256:[0-9a-f]+)?'

# gate_norm_path <path> — leading `./` stripped, repeated `/` collapsed,
# trailing `/` dropped (§5.3's join contract). Not sourced from `_lib.sh`'s
# `sdd_scope_norm`, which does the same thing: gate stays off that file on
# purpose (see emanate-gate.sh's header), so the lines are copied instead of
# shared — gate-results.sh carries the identical copy.
#
# The pattern and the replacement are VARIABLES: spelled inline, the `/` that
# opens the replacement half has to be escaped, and the backslash then lands
# in the result. One pass also leaves `///` as `//`, hence the loop.
gate_norm_path() {
  local p="$1" dbl='//' one='/'
  p="${p#./}"
  while [ "$p" != "${p//$dbl/$one}" ]; do p="${p//$dbl/$one}"; done
  p="${p%/}"
  printf '%s' "$p"
}

# gate_scan_citations <outfile> <root>... — every citation under the roots as
# `id<FS>fingerprint<FS>file<FS>line`, `LC_ALL=C` sorted and deduplicated; the
# fingerprint field is empty for an id-only token. Returns 1 with
# $GATE_SCAN_ERROR set when a discovered path carries a `:` or a newline
# (CLAUDE.md's declared non-support) — that byte would make the per-file
# `line:match` split below ambiguous to unsplit. The caller maps that to its
# own exit code rather than dying here, because the two tools do not share one.
gate_scan_citations() {
  local out="$1" root f files
  shift
  GATE_SCAN_ERROR=""
  : > "$out"
  files="$out.files"
  : > "$files"

  for root in "$@"; do
    while IFS= read -r -d '' f; do
      case "$f" in
        *:*|*$'\n'*)
          GATE_SCAN_ERROR="discovered test path contains ':' or a newline (symlinks/exotic paths are unsupported, CLAUDE.md): $f"
          return 1 ;;
      esac
      printf '%s\n' "$(gate_norm_path "$f")" >> "$files"
    done < <(find "$root" -type f -print0)
  done
  LC_ALL=C sort -u -o "$files" "$files"
  [ -s "$files" ] || return 0

  local file lineno match rest id fp
  while IFS= read -r file; do
    while IFS=: read -r lineno match; do
      [ -n "$match" ] || continue
      # The regex above fixes the shape — whitespace, the id, then optionally
      # whitespace and a `sha256:` fingerprint — so the split is two parameter
      # expansions rather than a subshell per citation.
      rest="${match#@claim}"
      id="${rest#"${rest%%[![:space:]]*}"}"
      fp=""
      case "$id" in
        *[[:space:]]*) fp="${id#*[[:space:]]}"; id="${id%%[[:space:]]*}" ;;
      esac
      [ -n "$id" ] || continue
      printf '%s%s%s%s%s%s%s\n' \
        "$id" "$GATE_FS" "$fp" "$GATE_FS" "$file" "$GATE_FS" "$lineno" >> "$out"
    done < <(LC_ALL=C grep -InoE "$GATE_CLAIM_RE" -- "$file" 2>/dev/null)
  done < "$files"
  # Deduplicated on the whole record, then ordered by (file, line, id) — the
  # order gate's own append loop produced before this scanner was shared, so
  # neither verdict list reorders.
  LC_ALL=C sort -u -o "$out.dedup" "$out"
  LC_ALL=C sort -t"$GATE_FS" -k3,3 -k4,4n -k1,1 -o "$out" "$out.dedup"
  rm -f "$out.dedup"
}

# gate_collect_citations <unit_id> <claim-ids-file> <root>... — populates
# $GATE_TMP/citations.spool (claim_id/file/line, real claims only) and
# $GATE_TMP/gv04.spool (file/line, dangling). A token for some OTHER unit is
# neither — the prefix scope (R5) is what keeps a shared tests tree from
# turning every foreign token into a false positive. Exits 3 on a path gate
# cannot address.
gate_collect_citations() {
  local unit_id="$1" idfile="$2"
  shift 2
  : > "$GATE_TMP/citations.spool"
  : > "$GATE_TMP/gv04.spool"

  gate_scan_citations "$GATE_TMP/scan" "$@" \
    || die_code "$EXIT_INPUT" "$GATE_SCAN_ERROR"
  cp "$GATE_TMP/scan.files" "$GATE_TMP/files.spool"

  # The fingerprint is dropped here on purpose: coverage is an id question, and
  # a citation that names a stale fingerprint still proves someone wrote a test
  # for the claim. Realization is where the fingerprint is load-bearing.
  local id fp file lineno
  while IFS="$GATE_FS" read -r id fp file lineno; do
    [ -n "$id" ] || continue
    if grep -qxF -- "$id" "$idfile"; then
      printf '%s%s%s%s%s\n' "$id" "$GATE_FS" "$file" "$GATE_FS" "$lineno" >> "$GATE_TMP/citations.spool"
    elif [ -n "$unit_id" ] && [ "${id%%/*}" = "$unit_id" ]; then
      printf '%s%s%s\n' "$file" "$GATE_FS" "$lineno" >> "$GATE_TMP/gv04.spool"
    fi
  done < "$GATE_TMP/scan"
}
