#!/usr/bin/env bash
# .inspire/bin/lib/plan-waves.sh
#
# Library — the layering half of `plan`. Kahn over the ordering edge set:
# `wave(u) = 1` when `u` has no in-frontier ordering edge, else
# `1 + max(wave(d))` over the ones it has. The wave COUNT is the floor — D11's
# "the minimum wave count = the critical dependency path's depth, known at
# t=0" — and a node the layering cannot consume is a cycle, which is `PR-11`.
#
# Waves are 1-based, matching D11's worked example (wave 1 = the entity and its
# components · wave 2 = the layout and the list action · wave 3 = the screen).
#
# Sourced after `plan-lib.sh`.

# plan_layer — `wave<TAB>id` for every node, `0` for one no wave could consume.
# Membership order inside a wave is awk's, and irrelevant: every list this
# feeds is sorted before it is read.
plan_layer() {
  awk -F'\t' -v nodesf="$PLAN_TMP/nodes" '
    FILENAME == nodesf { nodes[$1] = 1; remaining++; next }
    { ne++; efrom[ne] = $1; eto[ne] = $2 }
    END {
      wave = 0
      while (remaining > 0) {
        wave++
        nready = 0
        split("", ready)
        for (u in nodes) {
          if (u in assigned) continue
          ok = 1
          for (i = 1; i <= ne; i++) {
            if (efrom[i] != u) continue
            if (!(eto[i] in assigned)) { ok = 0; break }
          }
          if (ok) ready[++nready] = u
        }
        if (nready == 0) break
        for (i = 1; i <= nready; i++) { assigned[ready[i]] = wave; remaining-- }
      }
      for (u in nodes) {
        if (u in assigned) printf "%d\t%s\n", assigned[u], u
        else printf "0\t%s\n", u
      }
    }
  ' "$PLAN_TMP/nodes" "$PLAN_TMP/edges.tsv"
}

# plan_waves — layers the frontier into `waves.tsv`, sets $PLAN_FLOOR, and
# leaves any unconsumed node in `unconsumed`. Exit 1 when that file is not
# empty: the caller turns it into `PR-11` and plans nothing.
plan_waves() {
  plan_layer | LC_ALL=C sort -t"$(printf '\t')" -k1,1n -k2,2 > "$PLAN_TMP/waves.raw"
  awk -F'\t' '$1 == "0" { print $2 }' "$PLAN_TMP/waves.raw" > "$PLAN_TMP/unconsumed"
  awk -F'\t' '$1 != "0"' "$PLAN_TMP/waves.raw" > "$PLAN_TMP/waves.tsv"
  PLAN_FLOOR="$(awk -F'\t' '$1 > m { m = $1 } END { print m + 0 }' "$PLAN_TMP/waves.tsv")"
  [ ! -s "$PLAN_TMP/unconsumed" ]
}
