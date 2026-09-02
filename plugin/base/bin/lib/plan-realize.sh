#!/usr/bin/env bash
# .inspire/bin/lib/plan-realize.sh
#
# Library — which of the scope's frontier-ELIGIBLE units this run actually
# emanates, and how far. Three questions in one file, because each is a
# narrowing of the same node set:
#
#   REALIZATION (D9). A unit is realized when every claim of its CURRENT
#   derived contract is cited under a `--tests-root` by a token carrying a
#   MATCHING fingerprint. A realized unit leaves the frontier and satisfies an
#   edge the way a `stable` artifact does. The record is the tests themselves —
#   never a KB lifecycle flip, never a registry — so nothing has to be stamped,
#   an in-place spec edit un-realizes exactly the claims whose meaning moved,
#   and a discarded branch un-realizes its pieces by construction.
#
#   RE-EMANATION (`--reemanate`). The operator's graph selection, motive-free:
#   *why* a piece should be rebuilt is not a machine question, so there are no
#   motive-shaped flags. Selected units are treated as unrealized for this run;
#   everything unselected keeps its realization.
#
#   THE GOAL (`--goal`). Its remaining dependency closure is what the run has to
#   execute, and the deepest wave in that closure is the floor to the goal.
#
# CLOSURES WALK ORDERING EDGES ONLY — a navigation edge never extends one, the
# same exemption the waves have and for the same reason: list and detail screens
# navigate to each other in every real vault, so a nav-walking closure would
# pull a whole screen cluster into every selection.
#
# Sourced after `_lib.sh`, `plan-lib.sh` and `gate-citations.sh` (the `@claim`
# scanner is shared with `emanate-gate.sh` — one grammar, two readers).

# plan_claim_pairs — every claim of every derived contract as
# `unit-id<FS>claim-id<FS>fingerprint`. ONE jq for the whole frontier: a process
# per unit costs ~8 ms and a plan holds hundreds. A refused contract carries no
# `claims` key and so contributes no row, which is what keeps it unrealizable.
plan_claim_pairs() {
  jq -rn --arg fs "$PLAN_FS" '
    inputs | . as $c | ($c.claims // [])[]
    | [($c.unit.id // ""), (.id // ""), (.fingerprint // "")] | join($fs)
  ' "$PLAN_TMP"/c/*.json 2>/dev/null
}

# plan_realize — the realized unit ids into `realized`, one per line. Empty when
# no `--tests-root` was given: plan never guesses a tests tree (the gate defaults
# to `tests`, but the gate is invoked per unit by an orchestrator that already
# resolved the profile's convention). Returns 1 with $PLAN_BROKE set on a tests
# path the scanner cannot address.
#
# A unit with zero claims is NOT realized. Vacuous realization would drop a unit
# `derive` refused out of the frontier and take its `PR-01` with it.
plan_realize() {
  : > "$PLAN_TMP/realized"
  [ "${#PLAN_TESTS_ROOTS[@]}" -gt 0 ] || return 0
  if ! gate_scan_citations "$PLAN_TMP/citations" "${PLAN_TESTS_ROOTS[@]}"; then
    PLAN_BROKE="$GATE_SCAN_ERROR"
    return 1
  fi
  # Read in the scanner's separator and written out in plan's — the same byte
  # today, and spelling both makes the boundary between the two tools legible.
  # Only fingerprinted citations count: an id-only token is valid for the gate's
  # coverage classes and says nothing about WHICH version of the claim was tested.
  awk -F"$GATE_FS" -v OFS="$PLAN_FS" '$2 != "" { print $1, $2 }' \
    "$PLAN_TMP/citations" | LC_ALL=C sort -u > "$PLAN_TMP/cited"
  plan_claim_pairs > "$PLAN_TMP/claims"
  awk -F"$PLAN_FS" '
    FNR == NR { cited[$0] = 1; next }
    { total[$1]++; if (($2 FS $3) in cited) ok[$1]++ }
    END { for (u in total) if (ok[u] + 0 == total[u]) print u }
  ' "$PLAN_TMP/cited" "$PLAN_TMP/claims" | LC_ALL=C sort > "$PLAN_TMP/realized"
}

# plan_ordering_edges <nodes-file> — the ordering edge set over those nodes, as
# `from<TAB>to`. Two exemptions, and they are the whole rule: an edge whose
# target is not itself a node is satisfied out of band (a `stable` artifact, a
# realized unit, an `accepted` unit in another run's scope), and a screen->screen
# edge is navigation, which never orders a wave.
plan_ordering_edges() {
  local nodes="$1"
  awk -F'\t' -v nodesf="$nodes" '
    FILENAME == nodesf { node[$1] = 1; next }
    !($1 in node) || !($5 in node) { next }
    $3 == "screen" && $4 == "screen" { next }
    { print $1 "\t" $5 }
  ' "$nodes" "$PLAN_TMP/deps.tsv" | LC_ALL=C sort -u
}

# plan_reach <edges-file> <seed-file> <up|down> — the reachable node set, seeds
# included. `up` follows an edge backwards (a node's transitive DEPENDENTS),
# `down` forwards (its transitive DEPENDENCIES).
plan_reach() {
  awk -F'\t' -v dir="$3" -v edges="$1" '
    FILENAME == edges {
      if (dir == "up") adj[$2] = adj[$2] SUBSEP $1
      else             adj[$1] = adj[$1] SUBSEP $2
      next
    }
    { if (!($1 in seen)) { seen[$1] = 1; q[++qn] = $1 } }
    END {
      # qn is re-read each iteration, so appending to the queue inside the loop
      # is the breadth-first walk rather than a bug.
      for (i = 1; i <= qn; i++) {
        n = split(adj[q[i]], nb, SUBSEP)
        for (j = 1; j <= n; j++) {
          if (nb[j] == "" || (nb[j] in seen)) continue
          seen[nb[j]] = 1; q[++qn] = nb[j]
        }
      }
      for (k in seen) print k
    }
  ' "$1" "$2" | LC_ALL=C sort -u
}

# plan_match_sel <pattern> <nodes-file> — the node ids a selector endpoint
# names. One matcher for both spellings: a bare id is a glob with no
# metacharacter, so `users.list` and `users.*` need no separate branch.
plan_match_sel() {
  local pat="$1" id
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    case "$id" in $pat) printf '%s\n' "$id" ;; esac
  done < "$2"
}

# plan_selector_set <sel> <nodes-file> <edges-file> <out-prefix> — the node set
# one selector names, into `<out-prefix>`. Exit 1 when it names none, which the
# caller reports as a usage error: a selector is something the operator typed,
# and a typo that quietly selected nothing would answer "rebuild these" with a
# green run that rebuilt nothing.
#
#   X        one node, or a glob over ids
#   X..      X and its transitive dependents ("from here onwards")
#   X..Y     the segment: every node on an ordering path from X up to Y,
#            inclusive — the dependents of X intersected with the dependencies
#            of Y, which is what "on a path between" means on a DAG
plan_selector_set() {
  local sel="$1" nodes="$2" edges="$3" out="$4" left right
  : > "$out"
  case "$sel" in
    *..*)
      left="${sel%%..*}"; right="${sel#*..}"
      [ -n "$left" ] || return 1
      plan_match_sel "$left" "$nodes" > "$out.l"
      [ -s "$out.l" ] || return 1
      if [ -z "$right" ]; then
        plan_reach "$edges" "$out.l" up > "$out"
      else
        plan_match_sel "$right" "$nodes" > "$out.r"
        [ -s "$out.r" ] || return 1
        plan_reach "$edges" "$out.l" up   > "$out.up"
        plan_reach "$edges" "$out.r" down > "$out.down"
        LC_ALL=C comm -12 "$out.up" "$out.down" > "$out"
      fi ;;
    *) plan_match_sel "$sel" "$nodes" > "$out" ;;
  esac
  [ -s "$out" ]
}

# plan_edges_all — the ordering edges over every frontier-eligible node,
# memoized. Both selector consumers need the SAME graph: a closure computed over
# the post-realization node set could not select a realized unit at all.
plan_edges_all() {
  [ -f "$PLAN_TMP/edges.all" ] && return 0
  plan_ordering_edges "$PLAN_TMP/nodes.all" > "$PLAN_TMP/edges.all"
}

# plan_apply_reemanate — every `--reemanate` selector's set, unioned, out of the
# realized set. Sets $PLAN_BAD_SELECTOR and returns 1 on one that names nothing.
plan_apply_reemanate() {
  local sel n=0
  : > "$PLAN_TMP/reemanate"
  [ -s "$PLAN_TMP/reemanate-args" ] || return 0
  plan_edges_all
  while IFS= read -r sel; do
    [ -n "$sel" ] || continue
    n=$((n + 1))
    if ! plan_selector_set "$sel" "$PLAN_TMP/nodes.all" "$PLAN_TMP/edges.all" \
           "$PLAN_TMP/sel.$n"; then
      PLAN_BAD_SELECTOR="--reemanate $sel"
      return 1
    fi
    cat "$PLAN_TMP/sel.$n" >> "$PLAN_TMP/reemanate"
  done < "$PLAN_TMP/reemanate-args"
  LC_ALL=C sort -u -o "$PLAN_TMP/reemanate" "$PLAN_TMP/reemanate"
  LC_ALL=C comm -23 "$PLAN_TMP/realized" "$PLAN_TMP/reemanate" > "$PLAN_TMP/realized.kept"
  mv "$PLAN_TMP/realized.kept" "$PLAN_TMP/realized"
}

# plan_narrow — the frontier, minus what is realized. `nodes` is what the waves
# and every downstream check see; `units.spool` and `requires.spool` are filtered
# to match, so a realized unit is absent from `units[]` for the same reason a
# `stable` artifact is: it is not in the frontier.
#
# No finding needs filtering. A unit `derive` refused makes no claims and so can
# never realize, which is the one class (`PR-01`) `plan_ingest` emits before this
# runs.
plan_narrow() {
  if [ ! -s "$PLAN_TMP/realized" ]; then
    cp "$PLAN_TMP/nodes.all" "$PLAN_TMP/nodes"
    return 0
  fi
  LC_ALL=C comm -23 "$PLAN_TMP/nodes.all" "$PLAN_TMP/realized" > "$PLAN_TMP/nodes"
  local spool
  for spool in units requires; do
    awk -F"$PLAN_FS" -v nodesf="$PLAN_TMP/nodes" '
      FILENAME == nodesf { node[$1] = 1; next }
      $1 in node
    ' "$PLAN_TMP/nodes" "$PLAN_TMP/$spool.spool" > "$PLAN_TMP/$spool.kept"
    mv "$PLAN_TMP/$spool.kept" "$PLAN_TMP/$spool.spool"
  done
}

# plan_goal <sel> — the goal's remaining closure into `goal.units` and its floor
# into $PLAN_GOAL_FLOOR. The closure is matched over every frontier-ELIGIBLE
# node and then intersected with what this run still has to build, so naming an
# already-realized goal answers "nothing left" rather than "no such unit".
plan_goal() {
  local sel="$1"
  : > "$PLAN_TMP/goal.units"
  PLAN_GOAL_FLOOR=0
  plan_edges_all
  if ! plan_selector_set "$sel" "$PLAN_TMP/nodes.all" "$PLAN_TMP/edges.all" \
         "$PLAN_TMP/goal.match"; then
    PLAN_BAD_SELECTOR="--goal $sel"
    return 1
  fi
  plan_reach "$PLAN_TMP/edges.all" "$PLAN_TMP/goal.match" down > "$PLAN_TMP/goal.closure"
  LC_ALL=C comm -12 "$PLAN_TMP/goal.closure" "$PLAN_TMP/nodes" > "$PLAN_TMP/goal.units"
  PLAN_GOAL_FLOOR="$(awk -F'\t' -v goalf="$PLAN_TMP/goal.units" '
    FILENAME == goalf { want[$1] = 1; next }
    ($2 in want) && $1 > m { m = $1 }
    END { print m + 0 }
  ' "$PLAN_TMP/goal.units" "$PLAN_TMP/waves.tsv")"
}
