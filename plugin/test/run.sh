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
sizes=""
for f in "$HERE"/*.sh "$HERE"/*/*.sh; do
  [ -f "$f" ] || continue
  case "$f" in "$HERE"/run.sh|"$HERE"/lib/*) continue ;; esac
  sizes="$sizes$(wc -c < "$f" | tr -d ' ')$TAB$f
"
done
# Largest first: the wall is the heaviest job plus whatever is launched after
# it, and file size is the one cost proxy that cannot go stale as blocks move.
while IFS="$TAB" read -r _sz f; do
  [ -n "$f" ] || continue
  n="${f#$REPO/}"
  keep "$n" || continue
  add file "$f" "" "$n"
  printf '%s\n' "$f" >> "$TMP/files"
done <<EOF
$(printf '%s' "$sizes" | LC_ALL=C sort -rn)
EOF

# The golden estate joins as jobs, not as a rewrite: run-tests.sh already
# narrows to one rule, and the three siblings it hand-wires keep the labels it
# prints for them — those labels are part of the estate's inventory.
if [ -d "$GOLDEN/fixtures" ]; then
  for d in "$GOLDEN/fixtures"/*/; do
    [ -d "$d" ] || continue
    r="$(basename "$d")"
    keep "golden/$r" && add golden "$r" "" "golden/$r"
  done
fi
for s in "lib-tests.sh${TAB}_lib.sh/readers" \
         "test-trust.sh${TAB}trust.sh/behaviour" \
         "test-harvest.sh${TAB}emanate-harvest.sh/behaviour"; do
  script="${s%%$TAB*}"; label="${s#*$TAB}"
  [ -f "$GOLDEN/$script" ] || continue
  keep "golden/$script" && add sibling "$script" "$label" "golden/$script"
done

njobs=${#KIND[@]}
if [ "$njobs" -eq 0 ]; then
  echo "run.sh: no jobs matched${filters:+ filter$filters}" >&2
  exit 2
fi

# One build per tag for the whole estate instead of one per call site. The tags
# are read off the call sites, so adding one needs no edit here.
tags=""
if [ -s "$TMP/files" ]; then
  tags="$(tr '\n' '\0' < "$TMP/files" \
          | xargs -0 grep -hoE "fixture_from_tag[ $TAB]+\"?v[0-9][0-9.]*" 2>/dev/null \
          | sed -e "s/.*[ $TAB]\"\{0,1\}//" | LC_ALL=C sort -u | tr '\n' ' ')"
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
        golden) bash "$GOLDEN/run-tests.sh" "$arg" ;;
        # Mirrors run-tests.sh's own wiring for these three: one verdict line,
        # the script's own output shown only when it fails.
        sibling)
          if bash "$GOLDEN/$arg" > "$TMP/$idx.sib" 2>&1; then
            echo "PASS $label"
          else
            echo "FAIL $label"; cat "$TMP/$idx.sib"
          fi ;;
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
