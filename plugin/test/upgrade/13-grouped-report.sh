#!/usr/bin/env bash
# The grouped report.
# Moved from test-upgrade.sh:1012-1089.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"
. "$HERE/lib/fixtures.sh"
. "$PLUGIN_ROOT/scripts/lib/common.sh"
. "$PLUGIN_ROOT/scripts/lib/manifest.sh"
. "$PLUGIN_ROOT/scripts/lib/report.sh"

# ---- the grouped report -------------------------------------------------
. "$PLUGIN_ROOT/scripts/lib/report.sh"

j="$(mktemp)"; v="$(mktemp)"
printf 'move\t.claude/bin/review.sh\t.inspire/bin/review.sh\n'      >> "$j"
printf 'delete\t.claude/bin/test/run-tests.sh\t\n'                  >> "$j"
printf 'keep\t.claude/bin/test/my-fixture.sh\tyours\n'              >> "$j"
printf 'move\t.inspire_kb\tinspire_kb\n'                            >> "$j"
printf 'report\t\t.manual/ came from the fork\n'                    >> "$j"
printf 'replace\t.claude/skills/inspire-domain/SKILL.md\tstale\n'   >> "$v"
printf 'ask\t.claude/skills/inspire-task/SKILL.md\tboth changed\n'  >> "$v"
printf 'create\tinspire_kb/07_x/README.md\tnew\n'                   >> "$v"

out="$(render_report 0.2.1 0.4.0 "$j" "$v" 1 2>&1)"

check "report announces the dry run"  "printf '%s' \"\$out\" | grep -q 'DRY RUN'"
check "report shows the chain"        "printf '%s' \"\$out\" | grep -q '0.2.1 → 0.4.0'"
check "report has a RUNTIME group"    "printf '%s' \"\$out\" | grep -q 'RUNTIME'"
check "report has a KNOWLEDGE BASE group" \
      "printf '%s' \"\$out\" | grep -q 'KNOWLEDGE BASE'"
check "report has a LEFT ALONE group" "printf '%s' \"\$out\" | grep -q 'LEFT ALONE'"
check "report flags the decision"     "printf '%s' \"\$out\" | grep -q 'ASK'"
check "report counts the decision"    "printf '%s' \"\$out\" | grep -q '1 decision'"
check "report carries the superset caveat" \
      "printf '%s' \"\$out\" | grep -qi 'already absent'"
check "KB move lands in the KB group" \
      "printf '%s' \"\$out\" | awk '/KNOWLEDGE BASE/,/^\$/' | grep -q 'inspire_kb'"
rm -f "$j" "$v"

# A path outside .claude/*, .inspire/*, inspire_kb and the harness literals
# (source/, prototype/, root CLAUDE.md) is real product-space, not a catch-all
# to drop: _group_of buckets it as `product`, and render_report must give that
# bucket its own section, or the footer's tallies describe lines the operator
# is never shown at all.
pj="$(mktemp)"; pv="$(mktemp)"
printf 'delete\tsource/README.md\tstale product-space file\n' >> "$pj"
printf 'ask\tCLAUDE.md\tboth changed\n'                        >> "$pv"
pout="$(render_report 0.2.1 0.4.0 "$pj" "$pv" 0 2>&1)"
check "a product-space file is rendered in the body, not just tallied in the footer" \
      "printf '%s' \"\$pout\" | grep -q 'PRODUCT' && \
       printf '%s' \"\$pout\" | grep -q 'source/README.md' && \
       printf '%s' \"\$pout\" | grep -q 'CLAUDE.md' && \
       printf '%s' \"\$pout\" | grep -q '1 decision'"
rm -f "$pj" "$pv"

# The two streams legitimately describe the same paths, and the report merged
# them raw: the hop journals `delete` for each of the 114 pre-0.3 fixtures it
# removes and classify independently reaches `delete` for the same 114, so a
# clean v0.2.1 fixture read "232 deletions" where 118 paths are deleted, across
# 306 body lines of which 230 were about one prefix. The footer is the number an
# operator judges the risk by. Same verb + same path is ONE fact: render once,
# count once. Two DIFFERENT verbs on one path are two facts and both must stay.
dj="$(mktemp)"; dv="$(mktemp)"
printf 'delete\t.claude/bin/test/run-tests.sh\t\n'                          >> "$dj"
printf 'move\t.claude/bin/review.sh\t.inspire/bin/review.sh\n'              >> "$dj"
printf 'unregister\t.claude/hooks/\tretire stale hook registration\n'       >> "$dj"
printf 'report\t\tfirst note\n'                                             >> "$dj"
printf 'report\t\tsecond note\n'                                            >> "$dj"
printf 'delete\t.claude/bin/test/run-tests.sh\tno longer part of INSPIRE\n' >> "$dv"
printf 'replace\t.claude/bin/review.sh\tuntouched, takes the new version\n' >> "$dv"
dout="$(render_report 0.2.1 0.4.0 "$dj" "$dv" 1 2>&1)"

eq "a path both halves delete is rendered once, not twice" \
   "$(printf '%s' "$dout" | grep -c 'run-tests.sh')" "1"
eq "the surviving line is the hop's, which performed the deletion" \
   "$(printf '%s' "$dout" | grep -c 'no longer part of INSPIRE')" "0"
eq "two different verbs on one path stay two lines" \
   "$(printf '%s' "$dout" | grep -c 'review.sh')" "2"
check "the footer counts unique paths per verb, and tallies replace" \
   "printf '%s' \"\$dout\" | grep -q '1 moves · 1 replacements · 1 deletions'"
check "the footer tallies unregister too" \
   "printf '%s' \"\$dout\" | grep -q '1 hook registration(s) retired'"
# A `report` note has NO path, so a verb+path key would collapse every note into
# the first one. Path-less lines are exempt from de-duplication for that reason.
check "path-less notes are exempt from de-duplication" \
   "printf '%s' \"\$dout\" | grep -q 'first note' && printf '%s' \"\$dout\" | grep -q 'second note'"
rm -f "$dj" "$dv"

summary
