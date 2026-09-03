#!/usr/bin/env bash
# .inspire/bin/lib/derive-catalog.sh
#
# Library — the CATALOG half of the derived contract: the `component` and
# `pattern` kinds (ED10). Sourced after `_lib.sh`, `_keyed-heads.sh`,
# `derive-json.sh` and `derive-refusals.sh`.
#
# THE THREE OWNERSHIPS ARE THE CONTRACT (D10). A component owns its props and
# the states it renders; a pattern owns its regions — named holes, each with a
# fill and an accepted content kind — and the geometry they sit in. Neither owns
# the other's half, so neither derives it, and a region naming the fields its
# content shows is a prop that leaked into a layout rather than a region derive
# should read.
#
# CLAIMS ARE WHAT A TEST CAN CITE: one per prop, per component state and per
# region, fingerprinted like every other kind's. `## Structure` and
# `## Variants` are carried and never claimed — a structural bullet is prose no
# oracle checks, and a claim no oracle can cover is a claim that reads as
# covered by construction.
#
# A CATALOG ENTRY'S LIFECYCLE IS ITS `**State:**`, mapped by
# `sdd_catalog_lifecycle` in `_lib.sh`: one definition, because `plan` reads the
# same line to decide what is in the frontier.
#
# NO REVIEW RULE OWNS A CATALOG ENTRY'S SHAPE — `screen-coherence` reads a
# pattern only through an adopting screen — so the sweep consults none for these
# two kinds and the `DR-C*` classes here are the whole of the strictness.

# The two region vocabularies, closed, and `screen-coherence.sh`'s own: `Fill`
# is required|optional and `Accepts` is one or more of data|dispatch|nav|static.
# An empty cell and a dash are the same non-answer both readers already tolerate
# — being stricter here than `screen-coherence`, which owns the join, would make
# two readers disagree about what a value IS. Neither list carries the empty
# string, so both cells are guarded on presence instead: `Accepts` by its token
# loop iterating zero times, `Fill` by the test below.
DERIVE_REGION_FILL=" required optional - — "
DERIVE_REGION_ACCEPTS=" data dispatch nav static - — "

# derive_catalog_rows <copy> <section> — that section's table data rows, one
# record per row. `derive_table` emits an `H` per table and an `R` per row; only
# the rows are read, because a catalog table's columns are positional and fixed
# by the entry format.
derive_catalog_rows() {
  derive_table "$1" "$2" | awk -F"$DERIVE_FS" -v fs="$DERIVE_FS" '
    $1 != "R" { next }
    { out = ""
      for (i = 2; i <= NF; i++) out = out (i > 2 ? fs : "") $i
      print out }
  '
}

# derive_catalog_key <file> <what> <key> <seen> — the key, once. Exit 1 when the
# row is unkeyed or repeats one already taken (DR-C4), because a claim keyed by
# nothing and two claims keyed alike are the same defect: the fingerprint stops
# naming one thing.
derive_catalog_key() {
  local file="$1" what="$2" key="$3" seen="$4"
  if [ -z "$key" ]; then
    derive_refuse "DR-C4" "$file" \
      "DR-C4: a $what row carries no key, so nothing can cite the claim it makes" \
      "$(derive_remedy "$file")"
    return 1
  fi
  case "$seen" in
    *"|$key|"*)
      derive_refuse "DR-C4" "$file" \
        "DR-C4: $what key \`$key\` is declared twice, so one of the two claims can never be told from the other" \
        "$(derive_remedy "$file")"
      return 1 ;;
  esac
  return 0
}

# derive_catalog_state <file> — the entry's `**State:**`, refused (DR-C1) when
# it is absent or outside the closed pair. The state is the entry's lifecycle,
# and a unit whose lifecycle nothing states is a unit no run can place.
derive_catalog_state() {
  local file="$1" state
  state="$(sdd_catalog_state "$file")"
  case "$state" in
    implemented|to-extract) printf '%s' "$state"; return 0 ;;
  esac
  if [ -z "$state" ]; then
    derive_refuse "DR-C1" "$file" \
      "DR-C1: the entry declares no \`**State:**\` line, so nothing says whether its code exists yet" \
      "$(derive_remedy "$file")"
  else
    derive_refuse "DR-C1" "$file" \
      "DR-C1: \`**State:** $state\` is outside the closed pair \`implemented\` | \`to-extract\`" \
      "$(derive_remedy "$file")"
  fi
  printf '%s' "$state"
}

# derive_catalog_prose <copy> — the `## Structure` items and the `## Variants`
# items, spooled. List items only: the tokens paragraph both sections sit beside
# points at the design system and restates nothing the entry owns.
derive_catalog_prose() {
  local copy="$1" section spool line
  for section in Structure Variants; do
    spool="$([ "$section" = Structure ] && echo structure || echo variants)"
    while IFS= read -r line; do
      derive_norm_g "$line"
      [ -n "$DERIVE_NORM" ] && derive_row "$spool" "$DERIVE_NORM"
    done < <(sdd_body_section "$copy" "$section" | awk '
        /^[ \t]*[0-9]+\.[ \t]/ { sub(/^[ \t]*[0-9]+\.[ \t]+/, ""); print; next }
        /^[ \t]*[-*][ \t]/     { sub(/^[ \t]*[-*][ \t]+/, "");     print; next }
      ')
  done
}

derive_component() {
  local file="$1" id="$2" copy="$DERIVE_TMP/unit.md"
  local key c1 c2 c3 seen=""
  kh_strip_comments "$file" > "$copy"
  derive_init_spools props states structure variants
  U_STATE="$(derive_catalog_state "$file")"
  derive_catalog_prose "$copy"

  while IFS="$DERIVE_FS" read -r c1 c2; do
    key="$(derive_norm "${c1//\`/}")"
    derive_catalog_key "$file" "prop" "$key" "$seen" || continue
    seen="$seen|$key|"
    derive_row props "$key" "$(derive_norm "$c2")"
    derive_claim "$id/prop/$key" test "$c2"
  done < <(derive_catalog_rows "$copy" "API / Slots")
  if [ ! -s "$DERIVE_TMP/props.spool" ]; then
    derive_refuse "DR-C2" "$file" \
      "DR-C2: component entry declares no \`## API / Slots\` props table, and its props are the whole of what it owns" \
      "$(derive_remedy "$file")"
  fi

  seen=""
  while IFS="$DERIVE_FS" read -r c1 c2 c3; do
    key="$(derive_norm "${c1//\`/}")"
    derive_catalog_key "$file" "state" "$key" "$seen" || continue
    seen="$seen|$key|"
    derive_row states "$key" "$(derive_norm "$c2")" "$(derive_norm "$c3")"
    derive_claim "$id/state/$key" test "$c2" "$c3"
  done < <(derive_catalog_rows "$copy" "States")
}

derive_pattern() {
  local file="$1" id="$2" copy="$DERIVE_TMP/unit.md"
  local key c1 c2 c3 c4 fill accepts tok bad="" seen="" target
  kh_strip_comments "$file" > "$copy"
  derive_init_spools regions structure variants
  U_STATE="$(derive_catalog_state "$file")"
  derive_catalog_prose "$copy"

  # A17: a pattern and a component order only by a DECLARED edge between them,
  # never by an assumed tier, and this line is the declaration.
  while IFS= read -r target; do
    [ -n "$target" ] || continue
    derive_row requires component "${target##*/}"
  done < <(derive_header_links "$copy" '**Components:**')

  while IFS="$DERIVE_FS" read -r c1 c2 c3 c4; do
    key="$(derive_norm "${c1//\`/}")"
    derive_catalog_key "$file" "region" "$key" "$seen" || continue
    seen="$seen|$key|"
    fill="$(derive_norm "${c2//\`/}")"
    accepts="$(derive_norm "${c3//\`/}")"
    if [ -n "$fill" ]; then
      case "$DERIVE_REGION_FILL" in
        *" $(printf '%s' "$fill" | tr '[:upper:]' '[:lower:]') "*) ;;
        *) bad="${bad:+$bad, }Fill \`$fill\`" ;;
      esac
    fi
    for tok in $(printf '%s' "$accepts" | tr ',|' '  ' | tr '[:upper:]' '[:lower:]'); do
      case "$DERIVE_REGION_ACCEPTS" in *" $tok "*) continue ;; esac
      bad="${bad:+$bad, }Accepts \`$tok\`"
    done
    derive_row regions "$key" "$fill" "$accepts" "$(derive_norm "$c4")"
    derive_claim "$id/region/$key" test "$fill" "$accepts" "$c4"
  done < <(derive_catalog_rows "$copy" "Regions")

  if [ ! -s "$DERIVE_TMP/regions.spool" ]; then
    derive_refuse "DR-C3" "$file" \
      "DR-C3: pattern entry declares no \`## Regions\` table, so it has no holes to inject and nothing to join a screen against" \
      "$(derive_remedy "$file")"
  fi
  [ -z "$bad" ] || derive_refuse "DR-C5" "$file" \
    "DR-C5: region value outside the closed vocabulary: $bad — \`Fill\` is required|optional, \`Accepts\` is one or more of data|dispatch|nav|static" \
    "$(derive_remedy "$file")"
}

# The two renderers share every field but the owned collection, and they are
# written out rather than folded into one: a contract's shape is what its
# consumers read, and a conditional key set is harder to read than two lists.
derive_component_json() {
  local args=() a
  while IFS= read -r a; do args[${#args[@]}]="$a"; done < <(derive_rawfile_args)
  jq -n "${args[@]}" \
    --arg schema "$DERIVE_SCHEMA" --arg kind component --arg id "$U_ID" \
    --arg path "$U_PATH" --arg lifecycle "$U_LIFECYCLE" --arg state "$U_STATE" \
    --arg purpose "$U_PURPOSE" \
    "$DERIVE_JQ_PRELUDE"'
      {schema: $schema,
       unit: {kind: $kind, id: $id, path: $path, lifecycle: $lifecycle,
              state: $state},
       purpose: $purpose,
       requires: reqlist($requires),
       structure: (recs($structure) | map(.[0])),
       variants: (recs($variants) | map(.[0])),
       props: (recs($props) | map({name: .[0], carries: cel(.;1)})),
       states: (recs($states)
                | map({key: .[0], when: cel(.;1), presentation: cel(.;2)})),
       claims: claimlist($claims)}
    '
}

derive_pattern_json() {
  local args=() a
  while IFS= read -r a; do args[${#args[@]}]="$a"; done < <(derive_rawfile_args)
  jq -n "${args[@]}" \
    --arg schema "$DERIVE_SCHEMA" --arg kind pattern --arg id "$U_ID" \
    --arg path "$U_PATH" --arg lifecycle "$U_LIFECYCLE" --arg state "$U_STATE" \
    --arg purpose "$U_PURPOSE" \
    "$DERIVE_JQ_PRELUDE"'
      {schema: $schema,
       unit: {kind: $kind, id: $id, path: $path, lifecycle: $lifecycle,
              state: $state},
       purpose: $purpose,
       requires: reqlist($requires),
       structure: (recs($structure) | map(.[0])),
       variants: (recs($variants) | map(.[0])),
       regions: (recs($regions)
                 | map({region: .[0], fill: cel(.;1), accepts: cel(.;2),
                        holds: cel(.;3)})),
       claims: claimlist($claims)}
    '
}
