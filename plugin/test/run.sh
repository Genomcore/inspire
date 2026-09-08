#!/usr/bin/env bash
# The one entry point for this repo's test estate.
#
#   bash plugin/test/run.sh [-j N] [--inventory FILE] [filter ...]
#
#   -j N           concurrent jobs (default: min(ncpu, 8); -j 1 is serial)
#   --inventory F  write every PASS/FAIL/SKIP line of the run, LC_ALL=C sorted
#   filter         run only jobs whose name contains it (upgrade, 06-hop-ops, golden)
#
# Every file under plugin/test/ is also runnable on its own; this schedules them
# and builds up front the fixtures they would otherwise each build.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
REPO="$(cd -P "$HERE/../.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
GOLDEN="$PLUGIN_ROOT/base/bin/test"
. "$HERE/lib/fixtures.sh"

TAB="$(printf '\t')"

jobs_n=""; inventory=""; filters=""
while [ $# -gt 0 ]; do
  case "$1" in
    -j)            jobs_n="$2"; shift 2 ;;
    -j*)           jobs_n="${1#-j}"; shift ;;
    --inventory)   inventory="$2"; shift 2 ;;
    --inventory=*) inventory="${1#--inventory=}"; shift ;;
    -h|--help)     sed -n '2,10p' "$0"; exit 0 ;;
    -*)            echo "run.sh: unknown option $1" >&2; exit 2 ;;
    *)             filters="$filters $1"; shift ;;
  esac
done
if [ -z "$jobs_n" ]; then
  jobs_n="$( (sysctl -n hw.ncpu || nproc) 2>/dev/null )"
  case "$jobs_n" in ''|*[!0-9]*) jobs_n=4 ;; esac
  [ "$jobs_n" -gt 8 ] && jobs_n=8
fi

TMP="$(mktemp -d)"
CACHE="$TMP/fixtures"
cleanup() { rm -rf "$TMP"; }
trap cleanup EXIT
trap 'exit 130' INT TERM

KIND=(); ARG=(); LABEL=(); NAME=()
add() { KIND[${#KIND[@]}]="$1"; ARG[${#ARG[@]}]="$2"; LABEL[${#LABEL[@]}]="$3"; NAME[${#NAME[@]}]="$4"; }
keep() {
  [ -n "$filters" ] || return 0
  local f
  for f in $filters; do case "$1" in *"$f"*) return 0 ;; esac; done
  return 1
}

: > "$TMP/files"
# EVERY job is weighted into ONE largest-first order, golden ones included.
# They used to be appended after the sorted files, unsorted — so the estate's
# two heaviest jobs by far, golden/emanate-plan and golden/emanate-derive,
# launched last and ran out the tail nearly alone. The wall is the heaviest job
# plus whatever is launched after it, which is exactly what that ordering
# maximised.
#
# The proxies:
#   file    — its byte size, the one cost that cannot go stale as blocks move.
#   golden  — its fixture count × FIXTURE_WEIGHT. A fixture runs the rule and,
#             for the emanate ones, up to four validators under it, so it is
#             worth far more than a byte of test script. The constant only has
#             to order the list, and 250 is the figure that puts the estate's
#             heaviest golden job (67 fixtures) next to its heaviest file
#             (~17 KB), which is where measurement puts them.
#   sibling — one behavioural script, weighted like a mid-sized file, since
#             nothing about it can be counted without running it.
FIXTURE_WEIGHT=250
SIBLING_WEIGHT=8000

# Sharding: a rule with more than SHARD_MIN fixtures is split into jobs of
# about SHARD_SIZE, never more shards than there are slots to run them in.
# SHARD_MIN keeps the small rules whole — a 4-fixture rule is a second's work
# and three more processes would cost more than they save.
SHARD_MIN=12
SHARD_SIZE=10

# Row order is weight, kind, arg, name, LABEL LAST — and that is not cosmetic.
# Tab is IFS whitespace even when IFS is set to exactly a tab, so `read`
# collapses a run of them and strips a trailing one. `label` is the only field
# that is legitimately empty (every kind but `sibling` has none), so it goes
# last, where being stripped to empty is the right answer instead of shifting
# every field after it.
weights=""
w_add() { weights="$weights$1$TAB$2$TAB$3$TAB$4$TAB$5
"; }

for f in "$HERE"/*.sh "$HERE"/*/*.sh; do
  [ -f "$f" ] || continue
  case "$f" in "$HERE"/run.sh|"$HERE"/lib/*) continue ;; esac
  n="${f#$REPO/}"
  keep "$n" || continue
  w_add "$(wc -c < "$f" | tr -d ' ')" file "$f" "$n" ""
done

# The golden estate joins as jobs, not as a rewrite: run-tests.sh already
# narrows to one rule, and the siblings it hand-wires keep the labels it prints
# for them — those labels are part of the estate's inventory.
#
# A rule with many fixtures is SHARDED, because a single run-tests.sh is one
# process and therefore one core however many the machine has — which made the
# estate's two longest jobs, at 84 and 67 fixtures, its floor: no ordering can
# make a run shorter than its longest job, and no -j helps a job that cannot
# use a second core. Each shard is an ordinary job over a named subset, so the
# PASS/FAIL lines — and with them the run's inventory — are exactly the ones an
# unsharded run prints. Scenario names are directory names and carry no spaces
# (asserted by test-run.sh), which is what lets one job's argv ride in one
# string.
if [ -d "$GOLDEN/fixtures" ]; then
  for d in "$GOLDEN/fixtures"/*/; do
    [ -d "$d" ] || continue
    r="${d%/}"; r="${r##*/}"
    keep "golden/$r" || continue
    scen=""; nfix=0
    for x in "$d"*/; do
      [ -d "$x" ] || continue
      s="${x%/}"; scen="$scen ${s##*/}"; nfix=$((nfix + 1))
    done
    [ "$nfix" -gt 0 ] || continue
    if [ "$nfix" -le "$SHARD_MIN" ]; then
      w_add "$((nfix * FIXTURE_WEIGHT))" golden "$r" "golden/$r" ""
      continue
    fi
    # Round-robin, not consecutive blocks: fixture cost within a rule is
    # uneven and alphabetical neighbours are the ones most alike, so dealing
    # them out spreads the expensive ones instead of piling them into one shard.
    nshard=$(( (nfix + SHARD_SIZE - 1) / SHARD_SIZE ))
    [ "$nshard" -gt "$jobs_n" ] && nshard="$jobs_n"
    SHARD=(); SHARDN=()
    k=0
    while [ "$k" -lt "$nshard" ]; do SHARD[$k]=""; SHARDN[$k]=0; k=$((k + 1)); done
    i=0
    for s in $scen; do
      k=$(( i % nshard )); i=$((i + 1))
      SHARD[$k]="${SHARD[$k]} $s"
      SHARDN[$k]=$(( SHARDN[$k] + 1 ))
    done
    k=0
    while [ "$k" -lt "$nshard" ]; do
      w_add "$(( SHARDN[$k] * FIXTURE_WEIGHT ))" golden "$r${SHARD[$k]}" \
            "golden/$r#$((k + 1))" ""
      k=$((k + 1))
    done
  done
fi
for s in "lib-tests.sh${TAB}_lib.sh/readers" \
         "test-trust.sh${TAB}trust.sh/behaviour" \
         "test-harvest.sh${TAB}emanate-harvest.sh/behaviour" \
         "test-derive-lib.sh${TAB}emanate-derive.sh/library" \
         "test-plan-lib.sh${TAB}emanate-plan.sh/library" \
         "test-gate-lib.sh${TAB}emanate-gate.sh/library" \
         "test-results.sh${TAB}emanate-results.sh/behaviour"; do
  script="${s%%$TAB*}"; label="${s#*$TAB}"
  [ -f "$GOLDEN/$script" ] || continue
  keep "golden/$script" || continue
  w_add "$SIBLING_WEIGHT" sibling "$script" "golden/$script" "$label"
done

while IFS="$TAB" read -r _w kind arg name label; do
  [ -n "$kind" ] || continue
  add "$kind" "$arg" "$label" "$name"
  [ "$kind" = file ] && printf '%s\n' "$arg" >> "$TMP/files"
done <<EOF
$(printf '%s' "$weights" | LC_ALL=C sort -rn)
EOF

njobs=${#KIND[@]}
if [ "$njobs" -eq 0 ]; then
  echo "run.sh: no jobs matched${filters:+ filter$filters}" >&2
  exit 2
fi

# One build per tag for the whole estate instead of one per call site. The tags
# are read off the call sites, so adding one needs no edit here. Only tags this
# repo actually has are pre-built: test-run.sh names a synthetic one, and a
# mistyped tag must fail in the job that names it, not in the cache.
tags=""
if [ -s "$TMP/files" ]; then
  for tag in $(tr '\n' '\0' < "$TMP/files" \
               | xargs -0 grep -hoE "fixture_from_tag[ $TAB]+\"?v[0-9][0-9.]*" 2>/dev/null \
               | sed -e "s/.*[ $TAB]\"\{0,1\}//" | LC_ALL=C sort -u); do
    git -C "$REPO" rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1 || continue
    tags="$tags $tag"
  done
fi
fp0=""
if [ -n "$tags" ]; then
  if ! fixture_cache_build "$CACHE" "$REPO" $tags; then
    echo "FAIL fixture-cache (build failed for:$tags)"
    exit 1
  fi
  fp0="$(fixture_cache_fingerprint "$CACHE")"
  export INSPIRE_FIXTURE_CACHE="$CACHE"
fi

launch() {
  local idx="$1" kind="${KIND[$1]}" arg="${ARG[$1]}" label="${LABEL[$1]}"
  (
    SECONDS=0
    {
      case "$kind" in
        file)   bash "$arg" ;;
        # DELIBERATELY unquoted: a sharded job's arg is the rule followed by
        # its scenario names, and this is where that one string becomes argv.
        # Safe because a scenario name is a directory name with no whitespace
        # and no glob character in it.
        golden) bash "$GOLDEN/run-tests.sh" $arg ;;
        # Mirrors run-tests.sh's own wiring for these three: one verdict line,
        # the script's own output shown only when it fails. The script's status
        # is carried out of the block, not the verdict line's or the dump's —
        # report() reads this block's status as the whole job's verdict.
        sibling)
          bash "$GOLDEN/$arg" > "$TMP/$idx.sib" 2>&1; sib_rc=$?
          if [ "$sib_rc" -eq 0 ]; then
            echo "PASS $label"
          else
            echo "FAIL $label"; cat "$TMP/$idx.sib"
          fi
          ( exit "$sib_rc" ) ;;
      esac
    } > "$TMP/$idx.out" 2>&1
    echo "$?" > "$TMP/$idx.rc"
    echo "$SECONDS" > "$TMP/$idx.t"
    printf '%s\n' "$idx" >&3
  ) &
}

files_ok=0; files_bad=0; a_pass=0; a_fail=0; a_skip=0
report() {
  local idx="$1" rc n t p f s out
  out="$TMP/$idx.out"
  rc="$(cat "$TMP/$idx.rc" 2>/dev/null)"; [ -n "$rc" ] || rc=1
  t="$(cat "$TMP/$idx.t" 2>/dev/null)"; [ -n "$t" ] || t=0
  p="$(grep -c '^PASS ' "$out" 2>/dev/null | tr -d ' ')"
  f="$(grep -c '^FAIL ' "$out" 2>/dev/null | tr -d ' ')"
  s="$(grep -c '^SKIP ' "$out" 2>/dev/null | tr -d ' ')"
  n=$((p + f))
  a_pass=$((a_pass + p)); a_fail=$((a_fail + f)); a_skip=$((a_skip + s))
  # Zero assertions is a red job: a file that silently did nothing is the
  # vacuity class in a new coat.
  if [ "$rc" -eq 0 ] && [ "$n" -gt 0 ]; then
    files_ok=$((files_ok + 1))
    echo "PASS ${NAME[$idx]} $n assertions ${t}s"
  else
    files_bad=$((files_bad + 1))
    echo "FAIL ${NAME[$idx]} $n assertions ${t}s"
    sed 's/^/    /' "$out"
  fi
}

mkfifo "$TMP/done" || exit 1
exec 3<> "$TMP/done"
SECONDS=0
i=0; running=0
while [ $i -lt "$njobs" ] || [ $running -gt 0 ]; do
  if [ $i -lt "$njobs" ] && [ $running -lt "$jobs_n" ]; then
    launch $i; i=$((i + 1)); running=$((running + 1))
  else
    IFS= read -r fin <&3 || break
    report "$fin"; running=$((running - 1))
  fi
done
wall=$SECONDS

rc=0
[ "$files_bad" -eq 0 ] || rc=1
if [ -n "$fp0" ] && [ "$(fixture_cache_fingerprint "$CACHE")" != "$fp0" ]; then
  echo "FAIL fixture-cache (mutated during the run)"
  rc=1
fi

if [ -n "$inventory" ]; then
  cat "$TMP"/*.out 2>/dev/null | grep -E '^(PASS|FAIL|SKIP) ' | LC_ALL=C sort > "$inventory"
fi

echo ""
echo "Files: $files_ok/$files_bad · Assertions: $a_pass/$a_fail/$a_skip · Wall: ${wall} s"
exit "$rc"
