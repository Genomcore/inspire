#!/usr/bin/env bash
# Tests plugin/test/run.sh against synthetic estates.
#
# The estate is a scratch repo carrying one tag whose installer is two lines, so
# the cache path is exercised for real at a fraction of a released tag's cost;
# the runner under test is a copy, and nothing here touches this repo.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
. "$HERE/lib/assert.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

mk_estate() {
  local d="$1"
  mkdir -p "$d/.inspire" "$d/plugin/test/lib" "$d/plugin/test/synth"
  printf '#!/usr/bin/env bash\nmkdir -p installed\nprintf ok > installed/marker\n' \
    > "$d/.inspire/install.sh"
  ( cd "$d" && git init -q && git add -A \
    && git -c user.email=f@f -c user.name=f -c commit.gpgsign=false \
           -c core.hooksPath=/dev/null commit -qm synth \
    && git tag v0.0.1 ) >/dev/null 2>&1
  cp "$HERE/run.sh" "$d/plugin/test/run.sh"
  cp "$HERE/lib/assert.sh" "$HERE/lib/fixtures.sh" "$d/plugin/test/lib/"
}

# synth <estate> <name> <line>... — one job file, preamble and summary supplied.
synth() {
  local d="$1" n="$2" l
  shift 2
  { printf '#!/usr/bin/env bash\nset -uo pipefail\n'
    printf 'HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"\n'
    printf 'REPO="$(cd -P "$HERE/../.." && pwd -P)"\n'
    printf '. "$HERE/lib/assert.sh"\n'
    printf '. "$HERE/lib/fixtures.sh"\n'
    for l in "$@"; do printf '%s\n' "$l"; done
    printf 'summary\n'
  } > "$d/plugin/test/synth/$n.sh"
}

GREEN2='ok "synth green one"'
GREEN2b='ok "synth green two"'
CACHEJOB='w="$(mktemp -d)"; p="$(fixture_from_tag v0.0.1 "$w" "$REPO")"'
CACHEJOB2='check "synth cache: the fixture arrived" "[ -f '"'"'$p/installed/marker'"'"' ]"'
# Reads the environment, so it distinguishes "the runner derived the tag off
# this call site and pre-built it" from "the job built its own".
CACHEJOB3='check "synth cache: v0.0.1 was pre-built" "[ -d \"${INSPIRE_FIXTURE_CACHE:-/nonexistent}/v0.0.1/proj\" ]"'
CACHEJOB4='rm -rf "$w"'

# --- a green estate: exit code, filter, and -j equivalence ------------------
A="$WORK/a"; mk_estate "$A"
synth "$A" a-green "$GREEN2" "$GREEN2b"
synth "$A" b-green 'ok "synth other one"' 'ok "synth other two"'
synth "$A" c-cache "$CACHEJOB" "$CACHEJOB2" "$CACHEJOB3" "$CACHEJOB4"
synth "$A" g-build "$CACHEJOB" "$CACHEJOB2" "$CACHEJOB4"

a4="$(bash "$A/plugin/test/run.sh" -j 4 --inventory "$WORK/inv4" 2>&1)"; a4_rc=$?
eq "a green estate exits 0" "$a4_rc" "0"
eq "every job is reported once" \
   "$(printf '%s\n' "$a4" | grep -c '^PASS plugin/test/synth/' | tr -d ' ')" "4"
eq "the runner pre-built the tag its jobs name" \
   "$(printf '%s\n' "$a4" | grep -c '^PASS plugin/test/synth/c-cache.sh 2 assertions' | tr -d ' ')" "1"
eq "the inventory holds every assertion label" \
   "$(wc -l < "$WORK/inv4" | tr -d ' ')" "7"

# The cache is an accelerator, never a dependency.
bash "$A/plugin/test/synth/g-build.sh" >/dev/null 2>&1
eq "with no runner and no cache the same file still builds and passes" "$?" "0"

bash "$A/plugin/test/run.sh" -j 1 --inventory "$WORK/inv1" >/dev/null 2>&1
eq "-j 1 exits 0 too" "$?" "0"
eq "-j 1 and -j 4 give the same inventory" "$(cat "$WORK/inv1")" "$(cat "$WORK/inv4")"

f="$(bash "$A/plugin/test/run.sh" -j 1 a-green 2>&1)"
eq "a filter narrows to the jobs whose name contains it" \
   "$(printf '%s\n' "$f" | grep -c '^PASS plugin/test/synth/' | tr -d ' ')" "1"
check "a filter leaves the other jobs out" \
  "! printf '%s\n' \"\$f\" | grep -q 'b-green'"

# --- a red job fails the whole run -----------------------------------------
B="$WORK/b"; mk_estate "$B"
synth "$B" a-green "$GREEN2" "$GREEN2b"
synth "$B" d-red 'ok "synth before the red"' 'bad "synth deliberate red"'
b="$(bash "$B/plugin/test/run.sh" -j 1 2>&1)"; b_rc=$?
eq "a red job fails the run" "$b_rc" "1"
check "the red job is named" "printf '%s\n' \"\$b\" | grep -q '^FAIL plugin/test/synth/d-red.sh'"
check "its output is dumped under it" "printf '%s\n' \"\$b\" | grep -q 'synth deliberate red'"
check "the green job beside it still reports PASS" \
  "printf '%s\n' \"\$b\" | grep -q '^PASS plugin/test/synth/a-green.sh'"

# --- a job that asserts nothing fails the run ------------------------------
C="$WORK/c"; mk_estate "$C"
synth "$C" a-green "$GREEN2" "$GREEN2b"
synth "$C" e-empty ': nothing asserted here'
c="$(bash "$C/plugin/test/run.sh" -j 1 2>&1)"; c_rc=$?
eq "a zero-assertion job fails the run" "$c_rc" "1"
check "and is reported as zero assertions, by name" \
  "printf '%s\n' \"\$c\" | grep -q '^FAIL plugin/test/synth/e-empty.sh 0 assertions'"

# --- a red hand-wired sibling fails the run too -----------------------------
# A sibling's verdict line and output dump are printed by run.sh itself, so its
# status has to be carried past them deliberately; a FAIL line alone would have
# left the run green.
E="$WORK/e"; mk_estate "$E"
synth "$E" a-green "$GREEN2" "$GREEN2b"
mkdir -p "$E/plugin/base/bin/test"
printf '#!/usr/bin/env bash\necho "synth sibling deliberate red"\nexit 1\n' \
  > "$E/plugin/base/bin/test/test-trust.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$E/plugin/base/bin/test/lib-tests.sh"
e="$(bash "$E/plugin/test/run.sh" -j 1 2>&1)"; e_rc=$?
eq "a red sibling job fails the run" "$e_rc" "1"
eq "it is counted as a failing file, beside the green sibling and job" \
   "$(printf '%s\n' "$e" | sed -n 's/^Files: \([0-9]*\/[0-9]*\) .*/\1/p')" "2/1"
check "the red sibling is named" \
  "printf '%s\n' \"\$e\" | grep -q '^FAIL golden/test-trust.sh'"
check "its output is dumped under it" \
  "printf '%s\n' \"\$e\" | grep -q 'synth sibling deliberate red'"

# --- a job that reaches into the shared cache fails the run ----------------
D="$WORK/d"; mk_estate "$D"
synth "$D" c-cache "$CACHEJOB" "$CACHEJOB2" "$CACHEJOB3" "$CACHEJOB4"
synth "$D" f-mutate 'printf x >> "$INSPIRE_FIXTURE_CACHE/v0.0.1/proj/installed/marker"' \
                    'ok "synth mutator ran"'
d="$(bash "$D/plugin/test/run.sh" -j 1 2>&1)"; d_rc=$?
check "premise: both jobs of the mutation estate went green" \
  "[ \"\$(printf '%s\n' \"\$d\" | grep -c '^PASS plugin/test/synth/')\" = 2 ]"
eq "a cache mutated during the run fails it" "$d_rc" "1"
check "the failure names the cache, not a test file" \
  "printf '%s\n' \"\$d\" | grep -q '^FAIL fixture-cache (mutated during the run)'"

summary
