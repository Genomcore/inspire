#!/usr/bin/env bash
# plugin/base/bin/test/test-gate-lib.sh — the two claims about `gate` no
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
# Usage: bash plugin/base/bin/test/test-gate-lib.sh

set -uo pipefail

HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
BIN="$HERE/.."
FX="$HERE/fixtures/emanate-gate"

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

# ─────────────────────────────────────────────────────────────────────────────
# Writes nothing
# ─────────────────────────────────────────────────────────────────────────────

WORK="$(mktemp -d -t inspire-gate-writes.XXXXXX)" || exit 1
trap 'rm -rf "$WORK"' EXIT
cp -R "$FX/all-covered/." "$WORK/"

before="$(manifest "$WORK")"
( cd "$WORK" && bash "$BIN/emanate-gate.sh" --contract contract.json --tests-root tests --results results.json ) >/dev/null 2>&1
after="$(manifest "$WORK")"

eq "a full run leaves the fixture tree byte- and mtime-identical" "$after" "$before"

# ─────────────────────────────────────────────────────────────────────────────
# --contract - reads the derived contract on stdin
# ─────────────────────────────────────────────────────────────────────────────

by_file="$( cd "$FX/all-covered" && bash "$BIN/emanate-gate.sh" \
  --contract contract.json --tests-root tests --results results.json 2>/dev/null | jq -S . )"
by_stdin="$( cd "$FX/all-covered" && bash "$BIN/emanate-gate.sh" \
  --contract - --tests-root tests --results results.json < contract.json 2>/dev/null | jq -S . )"

eq "--contract - reads the same verdict as --contract <file>" "$by_stdin" "$by_file"

echo ""
echo "Passed: $pass · Failed: $fail"
[ "$fail" -eq 0 ]
