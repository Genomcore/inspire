#!/usr/bin/env bash
# .inspire/bin/lib/gate-verdict.sh
#
# Library — the join. Reads the spools every other gate-*.sh unit wrote
# (claims, citations, gv04, results, previous) and renders BOTH shapes gate
# ever prints: the refused-contract verdict (GV-00, exit 4) and the normal
# one (exit 0/1). One `jq -n` program per shape, as derive does — the whole
# classification lives in jq, not in a bash loop, because the join (claim ×
# citing files × their results rows) is exactly what jq's `group_by` and set
# operators are for.
#
# `GV-*`'s one rule: verdict = (findings == 0) ? pass : fail. Every class in
# `_references/gate-verdict.md` maps to exactly one spot below; nothing here
# invents a class the doc does not carry.

GATE_JQ_PRELUDE='
  def recs($s; $fs): $s | split("\n") | map(select(length > 0)) | map(split($fs));
'

# gate_render_refused — the GV-00 exit-4 verdict: no claims, one finding per
# row `gate_contract_load` spooled, target forced to the unit id (the
# catalogue's own choice, not derive's per-entry target — a unit that never
# derived has no finer-grained thing to point at).
gate_render_refused() {
  jq -n \
    --rawfile refused "$GATE_TMP/refused.spool" \
    --argjson unit "$(cat "$GATE_TMP/unit.json")" \
    --arg fs "$GATE_FS" \
    "$GATE_JQ_PRELUDE"'
    { schema: "inspire.gate-verdict/1", unit: $unit, verdict: "fail", claims: [],
      findings: ( recs($refused; $fs)
                  | map({class: "GV-00", target: ($unit.id // "unknown"),
                         message: .[0], remedy: (.[1] // "")}) ),
      summary: { claims: 0, covered: 0, uncited: 0, cited_not_run: 0,
                 cited_failed: 0, store_uncited: 0,
                 oracles: {test: 0, store: 0},
                 tests: {total: 0, passed: 0, failed: 0, skipped: 0},
                 findings_by_class: {"GV-00": (recs($refused; $fs) | length)} } }
  ' > "$GATE_TMP/verdict.json"
}

# gate_render_verdict <unit_id> <have_previous:true|false> <results_path> —
# the normal path. Coverage is decided per claim from its CITING FILES' own
# results rows (never per test name, R3): failed beats not-run beats
# covered, and an uncited store claim is exempt from GV-01 by design (R4).
gate_render_verdict() {
  local unit_id="$1" have_previous="$2" results_path="$3"
  [ -f "$GATE_TMP/previous.spool" ] || : > "$GATE_TMP/previous.spool"
  jq -n \
    --rawfile claims_raw "$GATE_TMP/claims.spool" \
    --rawfile citations_raw "$GATE_TMP/citations.spool" \
    --rawfile gv04_raw "$GATE_TMP/gv04.spool" \
    --rawfile results_raw "$GATE_TMP/results.spool" \
    --rawfile previous_raw "$GATE_TMP/previous.spool" \
    --argjson unit "$(cat "$GATE_TMP/unit.json")" \
    --arg unit_id "$unit_id" \
    --arg results_path "$results_path" \
    --argjson have_previous "$have_previous" \
    --arg fs "$GATE_FS" \
    "$GATE_JQ_PRELUDE"'
    (recs($claims_raw; $fs) | map({id: .[0], oracle: .[1], fingerprint: .[2]})) as $claims
    | (recs($citations_raw; $fs) | map({id: .[0], file: .[1], line: (.[2] | tonumber)})) as $citations
    | (recs($gv04_raw; $fs) | map({file: .[0], line: (.[1] | tonumber)})) as $gv04rows
    | (recs($results_raw; $fs) | map({file: .[0], name: .[1], status: .[2], message: .[3]})) as $results
    | ($citations | group_by(.id)
       | map({key: .[0].id, value: (map({file, line}) | sort_by(.file, .line))})
       | from_entries) as $cbc
    | ($results | group_by(.file)
       | map({key: .[0].file, value: map({status, message, name})}) | from_entries) as $rbf
    | ($claims | map(
        . as $c
        | ($cbc[$c.id] // []) as $cits
        | ($cits | map(.file) | unique) as $cfiles
        | (if ($cfiles | length) == 0 then
             if $c.oracle == "store" then {status: "store-uncited", cls: null}
             else {status: "uncited", cls: "GV-01"} end
           else
             ([ $cfiles[] as $f | ($rbf[$f] // [])[] ]) as $entries
             | (any($entries[]; .status == "failed")) as $hf
             | (any($entries[]; .status == "passed")) as $hp
             | if $hf then {status: "cited-failed", cls: "GV-03"}
               elif $hp then {status: "covered", cls: null}
               else {status: "cited-not-run", cls: "GV-02"} end
           end) as $v
        | {id: $c.id, oracle: $c.oracle, fingerprint: $c.fingerprint,
           citations: $cits, status: $v.status,
           findings: (if $v.cls == null then [] else [$v.cls] end)}
      )) as $claim_objs
    | ([ $claim_objs[] | select((.findings | length) > 0) | . as $co | $co.findings[] as $cls
         | {class: $cls, target: $co.id,
            message: (if $cls == "GV-01" then
                        "claim " + $co.id + " (oracle: test) has no citing @claim token under any tests root"
                      elif $cls == "GV-02" then
                        "claim " + $co.id + " is cited, but every citing file is absent from the results or ran with every entry skipped"
                      else
                        "claim " + $co.id + " is cited by a file with at least one failed entry" end),
            remedy: (if $cls == "GV-01" then "have the tester cite this claim, or report it as untestable"
                     elif $cls == "GV-02" then "run the suite that covers the citing file(s), or scope --results to include them"
                     else "fix the failing test, or the code it exercises" end)}
       ]) as $claim_findings
    | ([ $gv04rows[] | {class: "GV-04", target: (.file + ":" + (.line | tostring)),
          message: ("citation names no claim declared by this unit (prefix-matched to " + $unit_id + ")"),
          remedy: "remove the stale @claim token, or re-point it at a live claim id"} ]) as $gv04_findings
    | ([ $results[] | select(.status == "failed") | .file ] | unique) as $failed_files
    | ($citations | map(.file) | unique) as $cited_files
    | ($failed_files - $cited_files) as $red_elsewhere
    | (if ($red_elsewhere | length) > 0 then
         [{class: "GV-05", target: $results_path,
           message: ("suite results show >=1 failed entry in file(s) [" + ($red_elsewhere | join(", ")) + "] that cite nothing for this unit"),
           remedy: "give --results a run scoped to this unit, or investigate the unrelated failure"}]
       else [] end) as $gv05_findings
    | (if ($claims | length) == 0 then
         [{class: "GV-06", target: $unit_id, message: "the derived contract carries an empty claims[] array",
           remedy: "confirm the unit truly makes no claims, or re-derive it"}]
       else [] end) as $gv06_findings
    | ($claim_findings + $gv04_findings + $gv05_findings + $gv06_findings) as $findings
    | (if $have_previous then
         (recs($previous_raw; $fs) | map({id: .[0], fingerprint: .[1]})) as $prev
         | ($claims | map(.id)) as $cur_ids
         | ($prev | map(.id)) as $prev_ids
         | {changed:   [ $claims[] as $c | $prev[] | select(.id == $c.id and .fingerprint != $c.fingerprint) | $c.id ],
            unchanged: [ $claims[] as $c | $prev[] | select(.id == $c.id and .fingerprint == $c.fingerprint) | $c.id ],
            new:       ($cur_ids - $prev_ids),
            retired:   ($prev_ids - $cur_ids)}
       else null end) as $delta
    | { schema: "inspire.gate-verdict/1", unit: $unit,
        verdict: (if ($findings | length) == 0 then "pass" else "fail" end),
        claims: $claim_objs, findings: $findings,
        summary: {
          claims: ($claims | length),
          covered: ([$claim_objs[] | select(.status == "covered")] | length),
          uncited: ([$claim_objs[] | select(.status == "uncited")] | length),
          cited_not_run: ([$claim_objs[] | select(.status == "cited-not-run")] | length),
          cited_failed: ([$claim_objs[] | select(.status == "cited-failed")] | length),
          store_uncited: ([$claim_objs[] | select(.status == "store-uncited")] | length),
          oracles: {test: ([$claims[] | select(.oracle == "test")] | length),
                    store: ([$claims[] | select(.oracle == "store")] | length)},
          tests: {total: ($results | length),
                  passed: ([$results[] | select(.status == "passed")] | length),
                  failed: ([$results[] | select(.status == "failed")] | length),
                  skipped: ([$results[] | select(.status == "skipped")] | length)},
          findings_by_class: ($findings | group_by(.class) | map({key: .[0].class, value: length}) | from_entries)
        }
      } + (if $have_previous then {delta: $delta} else {} end)
  ' > "$GATE_TMP/verdict.json"
}

# gate_check_no_match_diagnostic — stderr-only: an all-uncited run and a
# misspelled --tests-root look identical from inside the join, so this says
# which one it probably is instead of leaving the operator to guess.
gate_check_no_match_diagnostic() {
  local mismatch
  mismatch="$(jq -n --rawfile r "$GATE_TMP/results.spool" --rawfile c "$GATE_TMP/citations.spool" \
    --arg fs "$GATE_FS" \
    "$GATE_JQ_PRELUDE"'
    (recs($r; $fs) | map(.[0]) | unique) as $rf
    | (recs($c; $fs) | map(.[1]) | unique) as $cf
    | (($rf | length) > 0) and ( [ $rf[] | select(. as $x | $cf | index($x)) ] | length == 0 )
  ')"
  if [ "$mismatch" = "true" ]; then
    echo "emanate-gate.sh: warning: no entry in --results matches any file discovered under the tests root(s) — check --tests-root, or this may be an all-uncited run" >&2
  fi
}

# gate_report_stderr <verdict-json-file> — the grouped human report
# (`emanate-derive.sh`'s report_refusals/report_derived pattern): a head
# line, findings by class in id order, a counts tail.
gate_report_stderr() {
  local out="$1" verdict kind id test_oracles store_oracles
  verdict="$(jq -r '.verdict' "$out")"
  kind="$(jq -r '.unit.kind // "unknown"' "$out")"
  id="$(jq -r '.unit.id // "unknown"' "$out")"
  {
    printf 'GATE %s %s %s\n' "$verdict" "$kind" "$id"
    jq -r '.findings | sort_by(.class, .target) | .[] | "\(.class)\t\(.target)\t\(.message)\t\(.remedy)"' "$out" \
      | awk -F'\t' '$1 != last { printf "\n  %s\n", $1; last = $1 }
                    { printf "    %s\n      %s\n      remedy: %s\n", $2, $3, $4 }'
    printf '\n  claims %s (%s covered · %s uncited · %s cited-not-run · %s cited-failed · %s store-uncited)\n' \
      "$(jq -r '.summary.claims' "$out")" "$(jq -r '.summary.covered' "$out")" \
      "$(jq -r '.summary.uncited' "$out")" "$(jq -r '.summary.cited_not_run' "$out")" \
      "$(jq -r '.summary.cited_failed' "$out")" "$(jq -r '.summary.store_uncited' "$out")"
    printf '  findings %s\n' "$(jq -r '.findings | length' "$out")"
  } >&2
  test_oracles="$(jq -r '.summary.oracles.test' "$out")"
  store_oracles="$(jq -r '.summary.oracles.store' "$out")"
  if [ "$test_oracles" = "0" ] && [ "$store_oracles" -gt 0 ] 2>/dev/null; then
    echo "  no test-oracle claim in this unit — the schema is the oracle" >&2
  fi
}
