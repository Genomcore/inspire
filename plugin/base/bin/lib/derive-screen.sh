#!/usr/bin/env bash
# .inspire/bin/lib/derive-screen.sh
#
# Library — the screen half of the derived contract. Sourced after `_lib.sh`,
# `_keyed-heads.sh`, `derive-json.sh` and `derive-refusals.sh`.
#
# BINDINGS ARE THE SCREEN'S OWN (D10/A11): the four `## Bindings` subsections
# are the contract whether or not a `**Pattern:**` is named, and every claim is
# keyed by the screen id and the row's own declared key —
#   {id}/data/{key} · {id}/dispatch/{key} · {id}/nav/{key} · {id}/state/{key}
# — never by slot and never by position, so a pattern change re-keys nothing and
# neither does a move.
#
# A DISPATCH'S OUTCOMES ARE PART OF ITS OWN CLAIM (A14 §2), not claims of their
# own: both outcome cells feed the dispatch's fingerprint, so changing one
# re-emanates that dispatch and nothing else. Outcomes are canonicalized to
# `nav:{id}` · `state:{key}` · `refresh:{key}` · `none` before they are
# fingerprinted, so the spellings `→ state \`x\`` and `state \`x\`` are one
# claim rather than two.
#
# PATTERNS AND COMPONENTS ARE NOT DERIVE KINDS. A screen's contract lists them
# as declared dependencies — id, resolved path, and a component's `**State:**`
# line — and readiness over those states is the `plan` script's question.

# derive_header_line <file> <marker> — the body of a `**Marker:**` header line.
derive_header_line() {
  awk -v pfx="$2" "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_SKIP}"'
      index($0, pfx) == 1 { print substr($0, length(pfx) + 1); exit }
    '"${SDD_AWK_FENCE_FUNCS}" "$1"
}

# derive_header_links <file> <marker> — every wikilink target on that header
# line, pipe-syntax unwrapped.
derive_header_links() {
  awk -v pfx="$2" "${SDD_AWK_FM_READER}${SDD_AWK_FENCE_SKIP}"'
      index($0, pfx) == 1 {
        s = $0
        while (match(s, /\[\[[^]]+\]\]/)) {
          t = substr(s, RSTART + 2, RLENGTH - 4)
          p = index(t, "|")
          if (p > 0) t = substr(t, p + 1)
          print t
          s = substr(s, RSTART + RLENGTH)
        }
        exit
      }
    '"${SDD_AWK_FENCE_FUNCS}" "$1"
}

# derive_bindings_table <copy> — `## Bindings` as records: `SUB<FS>{name}` per
# H3 and `R<FS>{cells…}` per data row, in document order, so one pass knows
# which subsection each row belongs to. The separator row is the discriminator,
# exactly as `derive_table` reads a table elsewhere.
derive_bindings_table() {
  sdd_body_section "$1" "Bindings" | awk -v fs="$DERIVE_FS" '
    function emit(line,   n, i, c, out) {
      gsub(/\\\|/, "\001", line)
      n = split(line, cell, "|")
      if (line ~ /\|[ \t]*$/) n--
      out = "R"
      for (i = 2; i <= n; i++) {
        c = cell[i]
        gsub(/\001/, "|", c)
        gsub(/^[ \t]+|[ \t]+$/, "", c)
        out = out fs c
      }
      print out
    }
    /^###[ \t]/ {
      h = $0; sub(/^###[ \t]+/, "", h)
      gsub(/^[ \t]+|[ \t]+$/, "", h)
      print "SUB" fs h
      sep = 0
      next
    }
    /^[ \t]*\|/ {
      probe = $0
      gsub(/[ \t|:-]/, "", probe)
      if (probe == "") { sep = 1; next }
      if (sep) emit($0)
      next
    }
    { sep = 0 }
  '
}

# derive_catalog_file <screen-dir> <target> — the pattern/component entry a
# header wikilink names. The same two-catalog fallback `screen-coherence.sh`
# uses, because a `../` depth shifts when a surface split moves the screen and
# the catalogs did not move with it.
derive_catalog_file() {
  local dir="$1" target="${2%%#*}" cand base
  [ -n "$target" ] || return 1
  for cand in "$dir/$target" "$dir/$target.md" "$target" "$target.md"; do
    [ -f "$cand" ] && { printf '%s' "$cand"; return 0; }
  done
  base="${target##*/}"
  for cand in "$SDD_KB_ROOT/05_screens/patterns/$base.md" \
              "$SDD_KB_ROOT/05_screens/components/$base.md"; do
    [ -f "$cand" ] && { printf '%s' "$cand"; return 0; }
  done
  return 1
}

# derive_screen_index — path<TAB>id for every screen the finder reaches, built
# once, paths normalised the way every other path in a derivation is. A
# navigation target names a screen by ID, so nothing positional could answer
# "does this target exist".
derive_screen_index() {
  local f
  [ -f "$DERIVE_TMP/screens.tsv" ] && return 0
  : > "$DERIVE_TMP/screens.tsv"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s\t%s\n' "$(sdd_scope_norm "$f")" "$(derive_fm_scalar "$f" id)" \
      >> "$DERIVE_TMP/screens.tsv"
  done < <(sdd_find_screens "$SDD_KB_ROOT")
}

derive_screen_by_id() {
  awk -F'\t' -v k="$1" '$2 == k { print $1; exit }' "$DERIVE_TMP/screens.tsv"
}

# derive_nav_target <cell> <file> — the screen id a transition cell names,
# refused (DR-R3) when no screen declares it.
derive_nav_target() {
  local id
  id="$(derive_link_target "$1")" || { printf ''; return 0; }
  if [ -n "$id" ] && [ -z "$(derive_screen_by_id "$id")" ]; then
    derive_refuse "DR-R3" "$2" \
      "DR-R3: transition target \`$id\` resolves to no screen id in the vault" \
      "$(derive_remedy "$2")"
  fi
  printf '%s' "$id"
}

# derive_outcome <cell> <file> — an outcome cell in canonical form. A cell
# outside the three declared forms is left visible as `unresolved:…`; it never
# reaches a clean contract, because `screen-coherence.sh` already refused the
# screen over it (DR-S8).
derive_outcome() {
  local cell key
  cell="$(derive_norm "$1")"
  case "$cell" in
    ''|'-'|'—'|'–'|'n/a'|'none') printf 'none' ;;
    *'[['*']]'*)                 printf 'nav:%s' "$(derive_nav_target "$cell" "$2")" ;;
    'state '*|'→ state '*)       key="${cell##*state }"; printf 'state:%s' "$(derive_norm "${key//\`/}")" ;;
    'refresh '*|'→ refresh '*)   key="${cell##*refresh }"; printf 'refresh:%s' "$(derive_norm "${key//\`/}")" ;;
    *)                           printf 'unresolved:%s' "$cell" ;;
  esac
}

# derive_action_ref <cell> <file> — the action id a binding row names, refused
# (DR-R2) when no descriptor carries it. The path is the format spec's own
# ({module}/{entity}/{id}.md), which is what makes the lookup an O(1) stat
# rather than a frontmatter scan of the whole domain tree.
derive_action_ref() {
  local cell="$1" file="$2" id rest
  id="$(derive_link_target "$cell")" || id="$(derive_norm "$cell")"
  id="$(kh_dotted "$id")"
  [ -n "$id" ] || { printf ''; return 0; }
  rest="${id#*.}"
  if [ ! -f "$SDD_SPEC_ROOT/${id%%.*}/${rest%%.*}/$id.md" ]; then
    derive_refuse "DR-R2" "$file" \
      "DR-R2: binding names action \`$id\`, which resolves to no action descriptor" \
      "$(derive_remedy "$file")"
  fi
  printf '%s' "$id"
}

derive_screen() {
  local file="$1" id="$2" copy="$DERIVE_TMP/unit.md" dir
  local sub marker c1 c2 c3 c4 c5 key act trig ok err tgt entry state target feat
  dir="$(dirname "$file")"
  kh_strip_comments "$file" > "$copy"
  derive_screen_index
  derive_init_spools features data dispatches navigation states components

  while IFS= read -r feat; do
    feat="$(derive_norm "$feat")"
    [ -n "$feat" ] && derive_row features "$feat"
  done < <(derive_header_line "$copy" '**Features:**' | tr ',' '\n')

  U_PATTERN_ID=""; U_PATTERN_PATH=""
  target="$(derive_header_links "$copy" '**Pattern:**' | head -1)"
  if [ -n "$target" ]; then
    U_PATTERN_ID="${target##*/}"
    if entry="$(derive_catalog_file "$dir" "$target")"; then
      U_PATTERN_PATH="$entry"
    else
      derive_refuse "DR-R4" "$file" \
        "DR-R4: **Pattern:** names \`$target\`, which resolves to no pattern entry" \
        "$(derive_remedy "$file")"
    fi
    derive_row requires pattern "$U_PATTERN_ID"
  fi

  while IFS= read -r target; do
    [ -n "$target" ] || continue
    state=""
    if entry="$(derive_catalog_file "$dir" "$target")"; then
      state="$(awk 'index($0, "**State:**") == 1 { s = $0; sub(/^\*\*State:\*\*[ \t]*/, "", s); print s; exit }' "$entry")"
    else
      entry=""
      derive_refuse "DR-R4" "$file" \
        "DR-R4: **Components:** names \`$target\`, which resolves to no component entry" \
        "$(derive_remedy "$file")"
    fi
    derive_row components "${target##*/}" "$entry" "$(derive_norm "$state")"
    derive_row requires component "${target##*/}"
  done < <(derive_header_links "$copy" '**Components:**')

  sub=""
  while IFS="$DERIVE_FS" read -r marker c1 c2 c3 c4 c5; do
    case "$marker" in
      SUB) sub="$c1"; continue ;;
      R)   ;;
      *)   continue ;;
    esac
    key="$(derive_norm "${c1//\`/}")"
    [ -n "$key" ] || continue
    case "$sub" in
      Data)
        act="$(derive_action_ref "$c2" "$file")"
        derive_row data "$key" "$act" "$c3"
        [ -n "$act" ] && derive_row requires action "$act"
        derive_claim "$id/data/$key" test "$act" "$c3" ;;
      Dispatches)
        act="$(derive_action_ref "$c2" "$file")"
        trig="$c3"
        ok="$(derive_outcome "$c4" "$file")"
        err="$(derive_outcome "$c5" "$file")"
        derive_row dispatches "$key" "$act" "$trig" "$ok" "$err"
        [ -n "$act" ] && derive_row requires action "$act"
        case "$ok" in nav:?*) derive_row requires screen "${ok#nav:}" ;; esac
        case "$err" in nav:?*) derive_row requires screen "${err#nav:}" ;; esac
        derive_claim "$id/dispatch/$key" test "$act" "$trig" "$ok" "$err" ;;
      Navigation)
        tgt="$(derive_nav_target "$c2" "$file")"
        derive_row navigation "$key" "$tgt" "$c3"
        [ -n "$tgt" ] && derive_row requires screen "$tgt"
        derive_claim "$id/nav/$key" test "$tgt" "$c3" ;;
      States)
        derive_row states "$key" "$c2" "$c3"
        derive_claim "$id/state/$key" test "$c2" "$c3" ;;
    esac
  done < <(derive_bindings_table "$copy")
}

derive_screen_json() {
  local args=() a
  while IFS= read -r a; do args[${#args[@]}]="$a"; done < <(derive_rawfile_args)
  jq -n "${args[@]}" \
    --arg schema "$DERIVE_SCHEMA" --arg kind screen --arg id "$U_ID" \
    --arg path "$U_PATH" --arg lifecycle "$U_LIFECYCLE" --arg module "$U_MODULE" \
    --arg screen "$U_SCREEN" --arg purpose "$U_PURPOSE" \
    --arg pattern "$U_PATTERN_ID" --arg patternpath "$U_PATTERN_PATH" \
    --arg route "$U_ROUTE" \
    "$DERIVE_JQ_PRELUDE"'
      {schema: $schema,
       unit: {kind: $kind, id: $id, path: $path, lifecycle: $lifecycle,
              module: $module, screen: $screen},
       purpose: $purpose,
       requires: reqlist($requires),
       features: (recs($features) | map(.[0])),
       pattern: (if $pattern == "" then null
                 else {id: $pattern,
                       path: (if $patternpath == "" then null else $patternpath end)} end),
       components: (recs($components)
                    | map({id: .[0],
                           path: (if cel(.;1) == "" then null else cel(.;1) end),
                           state: cel(.;2)})),
       bindings: {
         data: (recs($data) | map({key: .[0], action: cel(.;1), notes: cel(.;2)})),
         dispatches: (recs($dispatches)
                      | map({key: .[0], action: cel(.;1), trigger: cel(.;2),
                             on_success: cel(.;3), on_error: cel(.;4)})),
         navigation: (recs($navigation)
                      | map({key: .[0], target: cel(.;1), trigger: cel(.;2)})),
         states: (recs($states)
                  | map({key: .[0], when: cel(.;1), presentation: cel(.;2)}))},
       route: {module: $module, screen: $screen, default: $route},
       claims: claimlist($claims)}
    '
}
