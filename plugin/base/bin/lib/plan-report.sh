#!/usr/bin/env bash
# .inspire/bin/lib/plan-report.sh
#
# Library — what a plan run PRINTS. Two products, and the split is the whole
# point of the `--mode plan` ethos: the JSON on stdout is what the orchestrator
# reads, the grouped report on stderr is what an operator reads, and neither is
# ever written to a file.
#
# The stderr shape mirrors `derive`'s `report_refusals` / `report_derived` and
# `harvest`'s banner line, so an operator reading all three reads one format:
# grouped by class, then by owning skill, then by target.
#
# Each list is rendered by ONE `jq -n --rawfile` program over the spools.
#
# Sourced after `plan-lib.sh`.

# plan_json_plan — the plan, on exits 0 and 1.
plan_json_plan() {
  jq -n --arg fs "$PLAN_FS" --arg schema "$PLAN_SCHEMA" \
    --rawfile scopes "$PLAN_TMP/scopes.out" \
    --rawfile units "$PLAN_TMP/units.spool" \
    --rawfile requires "$PLAN_TMP/requires.spool" \
    --rawfile profiles "$PLAN_TMP/profiles.spool" \
    --rawfile waves "$PLAN_TMP/waves.spool" \
    --rawfile findings "$PLAN_TMP/findings.spool" \
    --argjson floor "$PLAN_FLOOR" \
    --argjson ceiling "${PLAN_CEILING:-null}" \
    --argjson deliverable "$PLAN_DELIVERABLE" \
    --argjson ready "$PLAN_READY" \
    "$PLAN_JQ_PRELUDE"'
      (recs($requires) | group_by(.[0])
       | map({key: .[0][0], value: map({kind: .[1], id: .[2]})}) | from_entries) as $req
    | (recs($profiles) | group_by(.[0])
       | map({key: .[0][0], value: map(.[1])}) | from_entries) as $prof
    | (recs($waves) | map({key: .[1], value: (.[0] | tonumber)}) | from_entries) as $wave
    | {schema: $schema,
       scope: ($scopes | split("\n") | map(select(length > 0))),
       ready: $ready,
       floor: $floor,
       ceiling: $ceiling,
       deliverable_waves: $deliverable,
       units: (recs($units)
               | map({kind: cel(.;1), id: cel(.;0), path: cel(.;2),
                      lifecycle: cel(.;3), module: nul(cel(.;4)),
                      surface: nul(cel(.;5)),
                      profiles: ($prof[cel(.;0)] // []),
                      requires: ($req[cel(.;0)] // []),
                      wave: ($wave[cel(.;0)] // null),
                      claims: (cel(.;6) | tonumber)})
               | sort_by(.id)),
       waves: (recs($waves) | group_by(.[0] | tonumber)
               | sort_by(.[0][0] | tonumber) | map(map(.[1]) | sort)),
       findings: (recs($findings)
                  | map({code: cel(.;0), severity: cel(.;1),
                         unit: nul(cel(.;2)), target: nul(cel(.;3)),
                         owner: nul(cel(.;4)), message: cel(.;5),
                         remedy: cel(.;6), derive_class: nul(cel(.;7))})
                  | sort_by([.code, (.unit // ""), (.target // "")]))}
    '
}

# plan_json_refused — exit 4. No `waves`, no `floor`, no `units`: nothing was
# planned, and a key present with an empty value would read as "planned, and it
# is empty".
plan_json_refused() {
  jq -n --arg fs "$PLAN_FS" --arg schema "$PLAN_SCHEMA" \
    --rawfile scopes "$PLAN_TMP/scopes.out" \
    --rawfile refused "$PLAN_TMP/refused.spool" \
    "$PLAN_JQ_PRELUDE"'
      {schema: $schema,
       scope: ($scopes | split("\n") | map(select(length > 0))),
       ready: false,
       refused: (recs($refused)
                 | map({code: cel(.;0), target: nul(cel(.;1)),
                        message: cel(.;2), remedy: cel(.;3)})
                 | sort_by([.code, (.target // "")]))}
    '
}

# plan_banner <verdict>
plan_banner() {
  printf 'INSPIRE emanate plan — %s (%s)\n' "$PLAN_SCOPE_LABEL" "$1" >&2
}

# plan_report_findings — grouped by class, then owning skill, then target. A
# class with no target (the ceiling warning is the only one) prints its message
# under the class heading alone.
plan_report_findings() {
  local n code sev unit target owner msg remedy klass last=""
  n="$(LC_ALL=C grep -c . "$PLAN_TMP/findings.spool")"
  [ "$n" -gt 0 ] || return 0
  {
    printf '\nFINDINGS (%s)\n' "$n"
    while IFS="$PLAN_FS" read -r code sev unit target owner msg remedy klass; do
      [ -n "$code" ] || continue
      if [ "$code$owner" != "$last" ]; then
        printf '\n  %s%s\n' "$code" "${owner:+  $owner}"
        last="$code$owner"
      fi
      [ -n "$target" ] && printf '    %s\n' "$target"
      # Derive's own message usually opens with its class; naming it twice
      # reads as two defects.
      if [ -n "$klass" ]; then case "$msg" in "$klass:"*) klass="" ;; esac; fi
      printf '      %s%s\n' "${klass:+$klass: }" "$msg"
      printf '      remedy: %s\n' "$remedy"
    done < <(LC_ALL=C sort "$PLAN_TMP/findings.spool")
  } >&2
}

# plan_report_plan — the frontier, its waves, the floor-versus-ceiling line and
# the findings.
plan_report_plan() {
  local units
  units="$(LC_ALL=C grep -c . "$PLAN_TMP/units.spool")"
  plan_banner "$([ "$PLAN_READY" = true ] && echo READY || echo "NOT READY")"
  {
    printf '\nFRONTIER (%s unit%s)\n' "$units" "$([ "$units" = 1 ] || echo s)"
    awk -F'\t' '
      { if ($1 != w) { if (w != "") printf "\n"; printf "  wave %-3s ", $1; w = $1; sep = "" }
        printf "%s%s", sep, $2; sep = " · " }
      END { if (w != "") printf "\n" }
    ' "$PLAN_TMP/waves.tsv"
    printf '\nFLOOR %s · CEILING %s · DELIVERABLE %s of %s waves\n' \
      "$PLAN_FLOOR" "${PLAN_CEILING:-—}" "$PLAN_DELIVERABLE" "$PLAN_FLOOR"
  } >&2
  plan_report_findings
}

# plan_report_refused — the classes that stopped the run before anything was
# planned.
plan_report_refused() {
  local code target msg remedy last="" classes findings
  classes="$(cut -d"$PLAN_FS" -f1 "$PLAN_TMP/refused.spool" | LC_ALL=C sort -u | LC_ALL=C grep -c .)"
  findings="$(LC_ALL=C grep -c . "$PLAN_TMP/refused.spool")"
  plan_banner "REFUSED"
  {
    printf '\nREFUSED (%s class(es), %s finding(s))\n' "$classes" "$findings"
    while IFS="$PLAN_FS" read -r code target msg remedy; do
      [ -n "$code" ] || continue
      if [ "$code" != "$last" ]; then printf '\n  %s\n' "$code"; last="$code"; fi
      [ -n "$target" ] && printf '    %s\n' "$target"
      printf '      %s\n' "$msg"
      printf '      remedy: %s\n' "$remedy"
    done < <(LC_ALL=C sort -u "$PLAN_TMP/refused.spool")
  } >&2
}
