#!/usr/bin/env bash
# .inspire/bin/lib/gate-results.sh
#
# Library — sniff, validate and spool the suite-results manifest
# (`inspire.suite-results/1`, R1). THE ONE PLACE a second results format
# would ever be added: a JUnit reader would be another function in this file
# alone, behind the same `gate_load_results` entry point, and nothing else
# in the gate package would need to change.
#
# Every failure here is exit 5 — "an old or foreign shape is an error, never
# a silently-empty section" (D7's ethos, applied to gate's own input) — and
# the XML sniff runs BEFORE any JSON parse attempt: a silent misread would
# mark every claim not-run, which is the vacuity trap in a new coat.

# gate_norm_path <path> — see gate-citations.sh for the contract and for why
# the pattern is a variable; duplicated byte-for-byte rather than shared so
# each gate-*.sh stays sourceable on its own.
gate_norm_path() {
  local p="$1" dbl='//' one='/'
  p="${p#./}"
  while [ "$p" != "${p//$dbl/$one}" ]; do p="${p//$dbl/$one}"; done
  p="${p%/}"
  printf '%s' "$p"
}

# gate_load_results <file> — writes $GATE_TMP/results.spool: one
# NUL-terminated file/name/status/message record per entry, path-normalized.
# Dies (exit 5) via die_code on any shape this schema does not allow; never
# returns on failure.
gate_load_results() {
  local file="$1" first schema_count

  first="$(LC_ALL=C tr -d '[:space:]' < "$file" 2>/dev/null | head -c1)"
  if [ "$first" = "<" ]; then
    die_code "$EXIT_RESULTS" \
      "results file looks like XML; emanate-gate reads inspire.suite-results/1 — see .claude/skills/_references/gate-verdict.md § Suite results"
  fi

  # jq collapses a genuinely duplicated top-level key to its last occurrence,
  # so the STREAM is what catches "declared twice" rather than silently
  # keeping one of the two. Counting lines instead would both miss a one-line
  # duplicate and reject a `schema` key nested inside a test entry, which the
  # schema tolerates like any other extra key.
  schema_count="$(jq -n --stream '
      [ inputs | select(length == 2 and (.[0] | length) == 1 and .[0][0] == "schema") ] | length
    ' "$file" 2>/dev/null)" \
    || die_code "$EXIT_RESULTS" "results file is not valid JSON; emanate-gate reads inspire.suite-results/1"
  [ "$schema_count" = "1" ] \
    || die_code "$EXIT_RESULTS" "results file: top-level schema key missing or duplicated (found $schema_count)"

  # Typed, not merely present: an object-valued `.file` satisfies a `has()`
  # check and then makes the spool's `join` error out, leaving an EMPTY spool
  # that marks every claim not-run — the vacuity trap this exit code exists
  # for. A missing key reads as null, so the type test subsumes the presence
  # test rather than adding to it.
  jq -e '
    (.schema == "inspire.suite-results/1") and
    (.tests | type == "array") and
    ([ .tests[] | ((.file | type) == "string" and (.name | type) == "string" and
       (.status == "passed" or .status == "failed" or .status == "skipped") and
       (.message == null or (.message | type) == "string")) ] | all)
  ' "$file" >/dev/null 2>&1 \
    || die_code "$EXIT_RESULTS" "results file is not a valid inspire.suite-results/1 manifest"

  # And SEPARATOR-FREE, over the same four fields the spool joins: a `$fs` in
  # `file` or `name` shifts the fields after it, forging a `passed` status for
  # a test the suite skipped. Refusing beats escaping — no runner emits one —
  # and covering all four keeps the property structural rather than positional,
  # while stopping the split from truncating a `message` at its first one.
  jq -e --arg fs "$GATE_FS" '
    [ .tests[] | ([.file, .name, .status, (.message // "")] | join("") | contains($fs) | not) ] | all
  ' "$file" >/dev/null 2>&1 \
    || die_code "$EXIT_RESULTS" \
         "results file: a test entry carries the record separator (U+001F) in file, name, status or message"

  # NUL-FRAMED, NOT LINE-ORIENTED, on both sides of the pipe: a `message`
  # legitimately carries newlines (a jest stack trace does), and a line read
  # splits one entry into a junk row with an empty status that the verdict's
  # `tests.total` then counts. Shaping that row into a forged `passed` needs a
  # separator as well, which is what the check above refuses.
  : > "$GATE_TMP/results.spool"
  while IFS="$GATE_FS" read -r -d '' f n s m; do
    printf '%s%s%s%s%s%s%s\0' "$(gate_norm_path "$f")" "$GATE_FS" "$n" "$GATE_FS" "$s" "$GATE_FS" "$m" \
      >> "$GATE_TMP/results.spool"
  done < <(jq -j --arg fs "$GATE_FS" \
             '.tests[] | ([.file, .name, .status, (.message // "")] | join($fs)) + ([0] | implode)' "$file")
}
