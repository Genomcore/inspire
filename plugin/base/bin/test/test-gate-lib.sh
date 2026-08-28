#!/usr/bin/env bash
# plugin/base/bin/test/test-gate-lib.sh — the claims about `gate` no
# fixture/expect.json can hold, modelled on test-derive-lib.sh:
#
#   WRITES NOTHING — a `run-tests.sh` fixture only ever inspects stdout/exit;
#   it has no vocabulary for "and the fixture directory itself is untouched
#   afterward". Proven here by hashing + mtime-stamping a COPY of a real
#   fixture tree, running gate over it, and diffing the manifest: no new
#   path, no changed byte, no bumped mtime.
#
#   `--contract -` — run-tests.sh's harness (plugin/base/bin/test/run-tests.sh)
#   redirects argv, never stdin, so the pipe form needs its own runner.
#
#   ACROSS A DOCUMENT AND THE CODE — that the `GV-*` ids the source can name
#   still equal the catalogue in `_references/gate-verdict.md`. The doc stays
#   the authority an operator reads; this is what keeps the two from drifting
#   silently, exactly as test-derive-lib.sh pins the semantic vocabulary.
#
#   STDOUT IS EMPTY on 2/3/5/127 — `expect.json` pins an exit code but has no
#   way to add "and nothing was printed", which is the other half of the
#   promise that a caller may parse stdout on sight of a verdict exit.
#
# EVERY GATE RUN BELOW IS CHECKED FOR HAVING RUN. A manifest diff and a stdout
# diff both pass trivially when both sides are empty, so each comparison is
# paired with an assertion that the run exited as expected and produced a
# parseable verdict.
#
# Usage: bash plugin/base/bin/test/test-gate-lib.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
BIN="$HERE/.."
FX="$HERE/fixtures/emanate-gate"
DOC="$BIN/../skills/_references/gate-verdict.md"

pass=0; fail=0
ok(){ echo "PASS $1"; pass=$((pass+1)); }
bad(){ echo "FAIL $1"; fail=$((fail+1)); }
eq(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$2', want '$3')"; fi; }

sha_of() { command -v sha256sum >/dev/null 2>&1 && sha256sum "$1" || shasum -a 256 "$1"; }

# manifest <dir> — one `path hash mtime` line per file, sorted, so two runs
# over the same tree diff byte-for-byte regardless of directory read order.
manifest() {
  local dir="$1" f
  find "$dir" -type f | LC_ALL=C sort | while IFS= read -r f; do
    printf '%s %s %s\n' "${f#"$dir"/}" "$(sha_of "$f" | awk '{print $1}')" "$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f")"
  done
}

WORK="$(mktemp -d -t inspire-gate-writes.XXXXXX)" || exit 1
SCRATCH="$(mktemp -d -t inspire-gate-lib.XXXXXX)" || exit 1
trap 'rm -rf "$WORK" "$SCRATCH"' EXIT

# ─────────────────────────────────────────────────────────────────────────────
# Writes nothing
# ─────────────────────────────────────────────────────────────────────────────

cp -R "$FX/all-covered/." "$WORK/"

before="$(manifest "$WORK")"
out="$( cd "$WORK" && bash "$BIN/emanate-gate.sh" --contract contract.json --tests-root tests --results results.json 2>/dev/null )"
code=$?
after="$(manifest "$WORK")"

eq "the writes-nothing run really ran (exit 0, a parsed pass verdict)" \
  "$code $(printf '%s' "$out" | jq -r '.verdict' 2>/dev/null)" "0 pass"
eq "a full run leaves the fixture tree byte- and mtime-identical" "$after" "$before"

# ─────────────────────────────────────────────────────────────────────────────
# --contract - reads the derived contract on stdin
# ─────────────────────────────────────────────────────────────────────────────

by_file="$( cd "$FX/all-covered" && bash "$BIN/emanate-gate.sh" \
  --contract contract.json --tests-root tests --results results.json 2>/dev/null | jq -S . )"
by_stdin="$( cd "$FX/all-covered" && bash "$BIN/emanate-gate.sh" \
  --contract - --tests-root tests --results results.json < contract.json 2>/dev/null | jq -S . )"

eq "the --contract <file> baseline is a parsed verdict over a non-empty claims[]" \
  "$(printf '%s' "$by_file" | jq -r 'if .verdict == "pass" and (.claims | length) > 0 then "ok" else "no" end' 2>/dev/null)" \
  "ok"
eq "--contract - reads the same verdict as --contract <file>" "$by_stdin" "$by_file"

# ─────────────────────────────────────────────────────────────────────────────
# A --tests-root spelled with repeated separators discovers the same files
# ─────────────────────────────────────────────────────────────────────────────

# The fixture `path-repeated-slashes` pins the results side of the same
# normalization; the ROOT side is a relationship between two runs, which no
# single expect.json holds.
by_doubled_root="$( cd "$FX/all-covered" && bash "$BIN/emanate-gate.sh" \
  --contract contract.json --tests-root tests// --results results.json 2>/dev/null | jq -S . )"

eq "--tests-root tests// reads the same verdict as --tests-root tests" "$by_doubled_root" "$by_file"

# ─────────────────────────────────────────────────────────────────────────────
# The GV-* ids the code names equal the catalogue that documents them
# ─────────────────────────────────────────────────────────────────────────────

# A class named only in a comment still counts: an id the catalogue does not
# carry is drift whichever side wrote it first.
code_ids="$(LC_ALL=C grep -hoE 'GV-[0-9]{2}' -- "$BIN/emanate-gate.sh" "$BIN"/lib/gate-*.sh \
            | LC_ALL=C sort -u | tr '\n' ' ')"
if [ ! -f "$DOC" ]; then
  bad "gate-verdict.md is where the gate scripts say it is"
else
  # The `id` column of § The GV-* catalogue: the table rows between that
  # heading and the next one, first cell, backticks off.
  doc_ids="$(awk '
      /^## The `GV-\*` catalogue/ { inside = 1; next }
      /^## / { inside = 0 }
      inside && /^\|/ {
        n = split($0, c, "|")
        if (n < 2) next
        t = c[2]
        gsub(/^[ \t]+|[ \t]+$/, "", t); gsub(/`/, "", t)
        if (t !~ /^GV-[0-9][0-9]$/) next
        print t
      }
    ' "$DOC" | LC_ALL=C sort -u | tr '\n' ' ')"
  eq "the GV-* ids the code names equal gate-verdict.md's catalogue" "$code_ids" "$doc_ids"
  eq "and the catalogue is not empty" "$([ -n "$doc_ids" ] && echo ok)" "ok"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Stdout is empty on every exit that carries no verdict
# ─────────────────────────────────────────────────────────────────────────────

# empty_stdout <label> <want-exit> <fixture> <arg>… — the exit code and the
# stdout byte count in ONE assertion: either half alone passes when gate never
# ran at all.
empty_stdout() {
  local label="$1" want="$2" fx="$3"; shift 3
  local f code
  f="$SCRATCH/stdout.$want"
  ( cd "$FX/$fx" && bash "$BIN/emanate-gate.sh" "$@" ) >"$f" 2>/dev/null
  code=$?
  eq "$label" "exit $code, $(wc -c <"$f" | tr -d ' ') bytes on stdout" "exit $want, 0 bytes on stdout"
}

empty_stdout "exit 2 (a missing --contract) prints nothing on stdout" 2 all-covered \
  --results results.json --tests-root tests
empty_stdout "exit 3 (a --tests-root that does not exist) prints nothing on stdout" 3 all-covered \
  --contract contract.json --results results.json --tests-root no-such-tree
empty_stdout "exit 5 (results that are not the manifest schema) prints nothing on stdout" 5 results-xml \
  --contract contract.json --results results.json --tests-root tests

# 127 needs a PATH holding every tool gate reaches for EXCEPT jq — an empty
# PATH would reach the same exit for the wrong reason, and gate resolves its
# own directory through `dirname` before it ever asks for jq.
NOJQ="$SCRATCH/nojq"
mkdir -p "$NOJQ"
for tool in bash sh dirname basename cat find grep sed sort awk tr head wc stat mktemp rm; do
  tool_path="$(command -v "$tool" 2>/dev/null)"
  case "$tool_path" in /*) ln -sf "$tool_path" "$NOJQ/$tool" ;; esac
done
eq "the jq-less PATH really is jq-less, and really has the rest" \
  "$(PATH="$NOJQ" command -v jq >/dev/null 2>&1 && echo jq)$(PATH="$NOJQ" command -v find >/dev/null 2>&1 && echo find)" \
  "find"

nojq_out="$SCRATCH/stdout.127"
( cd "$FX/all-covered" && PATH="$NOJQ" bash "$BIN/emanate-gate.sh" \
    --contract contract.json --results results.json --tests-root tests ) >"$nojq_out" 2>/dev/null
nojq_code=$?
eq "exit 127 (jq missing) prints nothing on stdout" \
  "exit $nojq_code, $(wc -c <"$nojq_out" | tr -d ' ') bytes on stdout" "exit 127, 0 bytes on stdout"

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
