#!/usr/bin/env bash
# .inspire/bin/lib/gate-citations.sh
#
# Library — walk the tests root(s), grep the `@claim` token (tester.md's
# grammar, normative), and split what it finds into two spools: real
# citations against this unit's own claims, and GV-04 dangling ones. A token
# for some OTHER unit is neither — the prefix scope (R5) is what keeps a
# shared tests tree from turning every foreign token into a false positive.
#
# Granularity is the file (R3): a citation is `{file, line}`, never a test
# name — tester.md is explicit that a grep knows no test syntax.
#
# The brief's `grep -IHnoE` is run per file below rather than batched with
# `-H` across many: the loop already knows which file it is reading, so
# `-H`'s only job (naming the file in the match line) is redundant here, and
# the per-file form needs no colon-safe path quoting to unpick afterward.
# `-I` (skip binaries) is kept.

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

# gate_collect_citations <unit_id> <claim-ids-file> <root>... — populates
# $GATE_TMP/citations.spool (claim_id/file/line, real claims only) and
# $GATE_TMP/gv04.spool (file/line, dangling). Exits 3 on a discovered path
# with a `:` or a newline (CLAUDE.md's declared non-support) — that byte
# would make the per-file line:match split below ambiguous to unsplit.
gate_collect_citations() {
  local unit_id="$1" idfile="$2" root f
  shift 2
  : > "$GATE_TMP/citations.spool"
  : > "$GATE_TMP/gv04.spool"
  : > "$GATE_TMP/files.spool"

  for root in "$@"; do
    while IFS= read -r -d '' f; do
      case "$f" in
        *:*|*$'\n'*)
          die_code "$EXIT_INPUT" "discovered test path contains ':' or a newline (symlinks/exotic paths are unsupported, CLAUDE.md): $f" ;;
      esac
      printf '%s\n' "$(gate_norm_path "$f")" >> "$GATE_TMP/files.spool"
    done < <(find "$root" -type f -print0)
  done
  LC_ALL=C sort -u -o "$GATE_TMP/files.spool" "$GATE_TMP/files.spool"
  [ -s "$GATE_TMP/files.spool" ] || return 0

  local file lineno match id
  while IFS= read -r file; do
    while IFS=: read -r lineno match; do
      [ -n "$match" ] || continue
      id="${match#@claim}"
      id="$(printf '%s' "$id" | sed -E 's/^[[:space:]]+//')"
      if grep -qxF -- "$id" "$idfile"; then
        printf '%s%s%s%s%s\n' "$id" "$GATE_FS" "$file" "$GATE_FS" "$lineno" >> "$GATE_TMP/citations.spool"
      elif [ -n "$unit_id" ] && [ "${id%%/*}" = "$unit_id" ]; then
        printf '%s%s%s\n' "$file" "$GATE_FS" "$lineno" >> "$GATE_TMP/gv04.spool"
      fi
      # else: another unit's token, in a shared tests tree — ignored (R5).
    done < <(LC_ALL=C grep -InoE '@claim[[:space:]]+[^[:space:]]+' -- "$file" 2>/dev/null)
  done < "$GATE_TMP/files.spool"
}
