#!/usr/bin/env bash
# .inspire/bin/lib/derive-domain.sh
#
# Library — the entity and action halves of the derived contract. Sourced after
# `_lib.sh`, `_keyed-heads.sh`, `derive-json.sh`, `derive-types.sh` and
# `derive-refusals.sh`.
#
# Every reader here composes on a shipped one — `sdd_entities_touched`,
# `kh_entries`, `kh_constraints_of`, `kh_split_args`, `kh_oracle_of`. Nothing
# that already has a reader gets a second one: a second reader of the
# keyed-entry grammar is precisely the drift `_keyed-heads.sh` exists to
# prevent.
#
# CLAIM IDS come from `_references/keyed-heads.md` § Keyspaces, unchanged:
#   {module}.{entity}/field/{field}/{op}   {module}.{entity}/inv/I{n}
#   {action}/input/{param}/{op}            {action}/pre/P{n}
#   {action}/step/B{n}                     {action}/post/Q{n}
#   {action}/error/{code}
# One field claim per constraint WORD, so changing a constraint retires its own
# claim, mints the new one, and leaves every sibling's fingerprint untouched.
#
# A TOUCHED ENTITY'S CONSTRAINTS ARE CARRIED, NEVER CLAIMED. They appear in an
# action's contract because the contracter renders validation and persistence
# from them, but the claim about a field belongs to the entity's own contract
# and is minted exactly once, there.

# derive_constraints <copy> <parent-h2> <name> <spool> <owner> <claim-prefix|->
#   The constraint tokens of one H3, spooled and — unless the prefix is `-` —
#   claimed. A malformed list never reaches here: `constraints-mechanics.sh`
#   refused the artifact over it before derivation began.
derive_constraints() {
  local copy="$1" parent="$2" name="$3" spool="$4" owner="$5" prefix="$6"
  local list token oracle
  list="$(kh_constraints_of "$copy" "$parent" "$name")" || return 0
  while IFS= read -r token; do
    [ -n "$token" ] || continue
    derive_head_split "$token"
    oracle="$(kh_oracle_of "$DERIVE_HWORD")"
    derive_row "$spool" "$owner" "$DERIVE_HWORD" "$DERIVE_HARGS" "$oracle"
    [ "$prefix" = "-" ] && continue
    derive_claim "$prefix/$name/$DERIVE_HWORD" "$oracle" "$DERIVE_HCANON"
    case "$DERIVE_HWORD" in
      references) derive_row requires entity "${DERIVE_HARGS//::/.}" ;;
    esac
  done < <(kh_split_constraints "$list")
}

# derive_type_cell <cell> <where> <target>
#   Resolves a `Type` cell into $DERIVE_TNAME / $DERIVE_TBASE, or refuses.
#   Sets globals rather than printing: a refusal recorded inside `$( … )` would
#   lose nothing on disk but everything in the caller's state, and refusing is
#   the whole point of this call. Never emits a generic type (D5) — a type
#   nothing recognizes is a rendering the contracter would have to guess at.
derive_type_cell() {
  local cell="$1" where="$2" target="$3" name rc
  derive_norm_g "$cell"
  name="${DERIVE_NORM//\`/}"
  DERIVE_TNAME="$name"
  DERIVE_TBASE="$(derive_type_base "$name")"; rc=$?
  [ "$rc" = "0" ] && return 0
  DERIVE_TNAME=""; DERIVE_TBASE=""
  case "$rc" in
    1) derive_refuse "DR-T2" "$target" \
         "DR-T2: $where declares no semantic type" "$(derive_remedy "$target")" ;;
    2) derive_refuse "DR-T1" "$target" \
         "DR-T1: $where names semantic type \`$name\`, which is in neither the universal vocabulary nor 00_bootstrap/semantic-types.md" \
         "$(derive_remedy "$target")" ;;
    3) derive_refuse "DR-T3" "$target" \
         "DR-T3: project semantic type \`$name\` declares no universal base type" \
         "declare a universal Base type for it in inspire_kb/00_bootstrap/semantic-types.md" ;;
  esac
}

# derive_keyed_section <copy> <section> <marker> <spool> <claim-prefix>
#   An unkeyed entry is skipped: in `## Errors` it is legitimate prose (an
#   inheritance note), and everywhere else the artifact was already refused for
#   carrying it, so keying a claim on the empty string would only invent a
#   referent nothing named.
derive_keyed_section() {
  local copy="$1" section="$2" marker="$3" spool="$4" prefix="$5"
  local key head first line prose oracle
  while IFS="$KH_FS" read -r key head first line; do
    [ -n "$key" ] || continue
    derive_head_split "$head"
    prose="$(derive_entry_prose "$line" "$key" "$head")"
    oracle="$(kh_oracle_of "$DERIVE_HWORD")"
    derive_row "$spool" "$key" "$DERIVE_HWORD" "$DERIVE_HARGS" "$prose" "$oracle"
    derive_claim "$prefix/$key" "$oracle" "$DERIVE_HCANON" "$prose"
  done < <(kh_entries "$copy" "$section" "$marker")
}

# derive_requires_fm <file> — the frontmatter `requires:` edges, unwrapped.
derive_requires_fm() {
  local dep
  while IFS= read -r dep; do
    [ -n "$dep" ] && derive_row requires action "$(kh_dotted "$(sdd_unwrap_wikilink "$dep")")"
  done < <(sdd_fm_list "$1" '.requires')
}

# ─────────────────────────────────────────────────────────────────────────────
# Entity
# ─────────────────────────────────────────────────────────────────────────────

derive_entity() {
  local file="$1" id="$2" copy="$DERIVE_TMP/unit.md"
  local marker name type notes
  kh_strip_comments "$file" > "$copy"
  derive_init_spools fields fieldcons invariants

  while IFS="$DERIVE_FS" read -r marker name type notes; do
    [ "$marker" = "R" ] || continue
    name="${name//\`/}"
    [ -n "$name" ] || continue
    derive_type_cell "$type" "field \`$name\`" "$file"
    derive_row fields "$name" "$DERIVE_TNAME" "$DERIVE_TBASE" "$notes"
    derive_constraints "$copy" "Fields" "$name" fieldcons "$name" "$id/field"
  done < <(derive_table "$copy" "Fields")

  derive_keyed_section "$copy" "Invariants" bullet invariants "$id/inv"
  derive_requires_fm "$file"
}

derive_entity_json() {
  local args=() a
  while IFS= read -r a; do args[${#args[@]}]="$a"; done < <(derive_rawfile_args)
  jq -n "${args[@]}" \
    --arg schema "$DERIVE_SCHEMA" --arg kind entity --arg id "$U_ID" \
    --arg path "$U_PATH" --arg lifecycle "$U_LIFECYCLE" --arg module "$U_MODULE" \
    --arg entity "$U_ENTITY" --arg purpose "$U_PURPOSE" \
    "$DERIVE_JQ_PRELUDE"'
      byowner($fieldcons; 1) as $fc
      | {schema: $schema,
         unit: {kind: $kind, id: $id, path: $path, lifecycle: $lifecycle,
                module: $module, entity: $entity},
         purpose: $purpose,
         requires: reqlist($requires),
         fields: (recs($fields)
                  | map({name: .[0], type: typ(cel(.;1); cel(.;2)),
                         notes: cel(.;3), constraints: ($fc[.[0]] // [])})),
         invariants: (recs($invariants) | map(entry(.))),
         claims: claimlist($claims)}
    '
}

# ─────────────────────────────────────────────────────────────────────────────
# Action
# ─────────────────────────────────────────────────────────────────────────────

# derive_touched <action-copy> <action-file>
#   The `## Entities` declarations, each carrying the touched entity's own
#   constraints for the fields this action touches — what a contracter needs to
#   render persistence and validation without opening a second document.
#
#   `sdd_entities_touched` speaks TSV and this reader does not: a tab is an IFS
#   *whitespace* character, so `IFS=$'\t' read` collapses runs of them, and a
#   row with an empty `Mapping` cell would shift every later cell one place
#   left. The rows are re-separated on DERIVE_FS, which read preserves.
derive_touched() {
  local copy="$1" file="$2" n=0 rows="$DERIVE_TMP/touched.rows"
  local rid ain effect field touch type mapping notes entfile entcopy
  sdd_entities_touched "$copy" \
    | awk -F'\t' -v OFS="$DERIVE_FS" 'NF { gsub(/::/, ".", $1); gsub(/`/, "", $5); print }' \
    > "$rows"
  while IFS="$DERIVE_FS" read -r rid ain effect; do
    [ -n "$rid" ] || continue
    derive_row touched "$rid" "$ain" "$effect"
    derive_row requires entity "$rid"
    if ! entfile="$(sdd_resolve_entity_id "$rid")"; then
      derive_refuse "DR-R1" "$file" \
        "DR-R1: ## Entities names \`$rid\`, which resolves to no entity document on disk" \
        "$(derive_remedy "$file")"
      continue
    fi
    n=$((n + 1))
    entcopy="$DERIVE_TMP/ent.$n.md"
    kh_strip_comments "$entfile" > "$entcopy"
    derive_target "$entfile" "$rid" entity
    while IFS="$DERIVE_FS" read -r field touch type mapping notes; do
      [ -n "$field" ] || continue
      derive_type_cell "$type" "\`$rid\` field \`$field\`" "$file"
      derive_row touchedfields "$rid" "$field" "$touch" "$DERIVE_TNAME" "$DERIVE_TBASE" "$mapping" "$notes"
      derive_constraints "$entcopy" "Fields" "$field" touchedcons \
        "$rid$DERIVE_LS$field" -
    done < <(awk -F"$DERIVE_FS" -v OFS="$DERIVE_FS" -v e="$rid" \
               '$1 == e { print $2, $3, $4, $5, $6 }' "$rows")
  done < <(awk -F"$DERIVE_FS" -v OFS="$DERIVE_FS" '{ print $1, $7, $8 }' "$rows" \
           | LC_ALL=C sort -u)
}

derive_action() {
  local file="$1" id="$2" copy="$DERIVE_TMP/unit.md"
  local marker c1 c2 c3 c4 name req desc hdr_required=no link
  kh_strip_comments "$file" > "$copy"
  derive_init_spools inputs inputcons outputs touched touchedfields touchedcons \
    preconditions behavior postconditions errors

  # `## Inputs` may drop its `Required` column when a lead-in states the fact
  # for every parameter, so the header decides which shape this table is.
  while IFS="$DERIVE_FS" read -r marker c1 c2 c3 c4; do
    if [ "$marker" = "H" ]; then
      if [ "$c3" = "Required" ]; then hdr_required=yes; else hdr_required=no; fi
      continue
    fi
    name="${c1//\`/}"
    [ -n "$name" ] || continue
    if [ "$hdr_required" = yes ]; then req="$c3"; desc="$c4"; else req=""; desc="$c3"; fi
    derive_type_cell "$c2" "input \`$name\`" "$file"
    derive_row inputs "$name" "$DERIVE_TNAME" "$DERIVE_TBASE" "$req" "$desc"
    derive_constraints "$copy" "Inputs" "$name" inputcons "$name" "$id/input"
  done < <(derive_table "$copy" "Inputs")

  while IFS="$DERIVE_FS" read -r marker c1 c2 c3; do
    [ "$marker" = "R" ] || continue
    name="${c1//\`/}"
    [ -n "$name" ] || continue
    derive_type_cell "$c2" "output \`$name\`" "$file"
    derive_row outputs "$name" "$DERIVE_TNAME" "$DERIVE_TBASE" "$c3"
  done < <(derive_table "$copy" "Outputs")

  # The whole-entity `## Outputs` one-liner defers the field shape to the entity
  # document on purpose (format-action.md), so the reference IS the contract.
  U_OUTPUT_ENTITY=""
  if [ ! -s "$DERIVE_TMP/outputs.spool" ]; then
    link="$(sdd_body_section "$copy" "Outputs" | grep -o '\[\[[^]]*\]\]' | head -1)"
    [ -n "$link" ] && U_OUTPUT_ENTITY="$(kh_dotted "$(sdd_unwrap_wikilink "$link")")"
  fi

  derive_touched "$copy" "$file"
  derive_keyed_section "$copy" "Preconditions" bullet preconditions "$id/pre"
  derive_keyed_section "$copy" "Behavior" step behavior "$id/step"
  derive_keyed_section "$copy" "Postconditions" bullet postconditions "$id/post"
  derive_keyed_section "$copy" "Errors" bullet errors "$id/error"
  derive_requires_fm "$file"
}

derive_action_json() {
  local args=() a
  while IFS= read -r a; do args[${#args[@]}]="$a"; done < <(derive_rawfile_args)
  jq -n "${args[@]}" \
    --arg schema "$DERIVE_SCHEMA" --arg kind action --arg id "$U_ID" \
    --arg path "$U_PATH" --arg lifecycle "$U_LIFECYCLE" --arg module "$U_MODULE" \
    --arg entity "$U_ENTITY" --arg action "$U_ACTION" --arg purpose "$U_PURPOSE" \
    --arg outent "$U_OUTPUT_ENTITY" \
    "$DERIVE_JQ_PRELUDE"'
      byowner($inputcons; 1) as $ic
      | byowner($touchedcons; 1) as $tc
      | {schema: $schema,
         unit: {kind: $kind, id: $id, path: $path, lifecycle: $lifecycle,
                module: $module, entity: $entity, action: $action},
         purpose: $purpose,
         requires: reqlist($requires),
         inputs: (recs($inputs)
                  | map({name: .[0], type: typ(cel(.;1); cel(.;2)),
                         required: cel(.;3), description: cel(.;4),
                         constraints: ($ic[.[0]] // [])})),
         outputs: {entity: (if $outent == "" then null else $outent end),
                   fields: (recs($outputs)
                            | map({name: .[0], type: typ(cel(.;1); cel(.;2)),
                                   description: cel(.;3)}))},
         entities: (recs($touched)
                    | map(.[0] as $e
                          | {id: $e, as_input: cel(.;1), effect: cel(.;2),
                             fields: (recs($touchedfields)
                                      | map(select(.[0] == $e))
                                      | map({field: .[1], touch: cel(.;2),
                                             type: typ(cel(.;3); cel(.;4)),
                                             mapping: cel(.;5), notes: cel(.;6),
                                             constraints: ($tc[$e + "\u001e" + .[1]] // [])}))})),
         preconditions: (recs($preconditions) | map(entry(.))),
         behavior: (recs($behavior) | map(entry(.))),
         postconditions: (recs($postconditions) | map(entry(.))),
         errors: (recs($errors) | map(entry(.))),
         claims: claimlist($claims)}
    '
}
