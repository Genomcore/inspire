#!/usr/bin/env bash
# .inspire/bin/lib/gate-contract.sh
#
# Library — read + validate the derived contract `emanate-gate.sh` is handed,
# and tell an unusable one apart from a real, if empty, one. Sourced by
# emanate-gate.sh after it defines EXIT_* and die_code(); never invoked
# directly.
#
# "Unusable" (GATE_CONTRACT_STATUS=unusable, the caller's exit-4 path) covers
# three shapes at once: the file is not valid JSON at all, its `schema` is not
# `inspire.derived-contract/1`, or it carries no `claims` key (a derive
# refusal object, or anything else foreign). All three are read the same way
# — "a unit that did not derive cannot be gated" does not care which of the
# three broke it. GATE_CONTRACT_STATUS=ok means claims[] exists (possibly
# empty — an empty claims[] is GV-06, a normal verdict, not this).
#
# `$GATE_FS` (U+001F, derive's own separator) is defined here because this is
# the first unit sourced that needs it; every other gate-*.sh reuses it as a
# global rather than redefining it.

GATE_FS=$'\037'

# gate_contract_load <file> — sets GATE_CONTRACT_STATUS (ok|unusable) and
# GATE_UNIT_ID; writes $GATE_TMP/unit.json, $GATE_TMP/claims.spool
# (id/oracle/fingerprint, ok path only), $GATE_TMP/claim-ids.txt (ids only,
# for gate-citations.sh's GV-04 check) and $GATE_TMP/refused.spool
# (message/remedy rows, unusable path only).
gate_contract_load() {
  local file="$1" schema has_claims

  if ! jq -e . "$file" >/dev/null 2>&1; then
    GATE_CONTRACT_STATUS="unusable"
    printf '%s%s%s\n' \
      "the --contract file is not valid JSON" "$GATE_FS" \
      "re-run emanate-derive.sh for this unit and pass its stdout to --contract" \
      > "$GATE_TMP/refused.spool"
    printf '{}' > "$GATE_TMP/unit.json"
    GATE_UNIT_ID=""
    return 0
  fi

  schema="$(jq -r '.schema // ""' "$file")"
  has_claims="$(jq -r 'has("claims")' "$file")"
  jq -c '.unit // {}' "$file" > "$GATE_TMP/unit.json"
  GATE_UNIT_ID="$(jq -r '.unit.id // ""' "$file")"

  if [ "$schema" != "inspire.derived-contract/1" ] || [ "$has_claims" != "true" ]; then
    GATE_CONTRACT_STATUS="unusable"
    gate_contract_refusal_rows "$file" "$schema" "$has_claims" > "$GATE_TMP/refused.spool"
    return 0
  fi

  GATE_CONTRACT_STATUS="ok"
  jq -r --arg fs "$GATE_FS" '.claims[] | [.id, .oracle, .fingerprint] | join($fs)' "$file" \
    > "$GATE_TMP/claims.spool"
  jq -r '.claims[].id' "$file" > "$GATE_TMP/claim-ids.txt"
}

# gate_contract_refusal_rows <file> <schema> <has_claims> — one MESSAGE/REMEDY
# row per reason the contract is unusable; the row shape gate_render_refused
# reads, which is why neither branch below emits a third field. A genuine
# derive refusal object carries its own `refused[]`: GV-00 forces every target
# to the unit id, so derive's finer-grained target (the artifact path) is
# folded into the message here or it is lost. The class is folded in too,
# unless derive's own message already opens with it.
gate_contract_refusal_rows() {
  local file="$1" schema="$2" has_claims="$3"
  if [ "$has_claims" != "true" ] && jq -e 'has("refused")' "$file" >/dev/null 2>&1; then
    jq -r --arg fs "$GATE_FS" '
      .refused[]
      | {c: (.class // "?"), t: (.target // "unknown"),
         m: (.message // ""), r: (.remedy // "")} as $row
      | (if ($row.m | startswith($row.c + ":")) then $row.m
         else $row.c + ": " + $row.m end) as $msg
      | [($row.t + ": " + $msg), $row.r] | join($fs)
    ' "$file"
    return 0
  fi
  printf '%s%s%s\n' \
    "contract schema is '${schema:-<absent>}', expected 'inspire.derived-contract/1'" \
    "$GATE_FS" "re-run emanate-derive.sh for this unit and pass its stdout to --contract"
}

# gate_contract_load_previous <file> — the delta join only needs id +
# fingerprint, never oracle: a claim's oracle can't change without its id
# changing too (the id embeds the constraint word). An unusable --previous is
# not an error (the current contract still gates), but read as silence it
# would report every claim as `new`, so it says so on stderr.
gate_contract_load_previous() {
  local file="$1"
  if ! jq -e 'has("claims")' "$file" >/dev/null 2>&1; then
    echo "emanate-gate.sh: warning: --previous carries no claims[] (a derive refusal object, or a foreign shape) — every claim will report as new: $file" >&2
    : > "$GATE_TMP/previous.spool"
    return 0
  fi
  jq -r --arg fs "$GATE_FS" '.claims[] | [.id, .fingerprint] | join($fs)' "$file" \
    > "$GATE_TMP/previous.spool"
}
