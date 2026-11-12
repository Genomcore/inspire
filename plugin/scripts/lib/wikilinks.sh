#!/usr/bin/env bash
# Wikilink resolution for the link conversion (adr-markdown-links D6). Sourced by
# migrate-links.sh after base/bin/_lib.sh, with SDD_KB_ROOT and SDD_SPEC_ROOT
# pointed at the KB.
#
# It resolves a wikilink by id the way the validators did before 0.17.0, so a
# converted link names the file they read. It lives here, not in base/bin/, because
# only migration reads wikilinks (D5) and base/bin/ materializes into projects.

# wikilink_index — `{kind}<TAB>{key}<TAB>{path}`, once: A action, E entity, S screen,
# M old screen id, N file id, F a file name a declared id displaces. The caller
# removes `$WIKILINK_INDEX_FILE` and `$SDD_ENTITY_INDEX_FILE` on exit.
WIKILINK_INDEX_FILE=""
wikilink_index() {
  [ -n "$WIKILINK_INDEX_FILE" ] && [ -f "$WIKILINK_INDEX_FILE" ] && return 0
  WIKILINK_INDEX_FILE="$(mktemp -t inspire-wikilink-index.XXXXXX)"
  local f id map="$SDD_SPEC_ROOT/_migration/id-map.json"
  {
    while IFS= read -r f; do
      id="$(sdd_fm_value "$f" '.id')"
      [ -n "$id" ] && printf 'A\t%s\t%s\n' "$id" "$f"
    done < <(sdd_find_actions "$SDD_SPEC_ROOT")
    _sdd_entity_index
    awk '{ print "E\t" $0 }' "$SDD_ENTITY_INDEX_FILE"
    while IFS= read -r f; do
      id="$(sdd_fm_value "$f" '.id')"
      [ -n "$id" ] && printf 'S\t%s\t%s\n' "$id" "$f"
    done < <(sdd_find_screens "$SDD_SPEC_ROOT")
    [ -f "$map" ] && jq -r '.screens // {} | to_entries[] | "M\t\(.key)\t\(.value)"' "$map" 2>/dev/null
    # F keeps `[[nightly-close]]` reaching `billing.nightly-close`; a screen has no F,
    # since its slug repeats a module name (`[[orders]]` is not `portal.orders`).
    find "$SDD_KB_ROOT" .claude/skills -type f -name '*.md' ! -path '*/node_modules/*' 2>/dev/null \
      | awk '
          function fm_id(f,   l, n, v) {
            v = ""; n = 0
            while ((getline l < f) > 0) {
              sub(/\r$/, "", l)
              if (++n == 1) { if (l != "---") break; continue }
              if (l == "---") break
              if (l ~ /^id:/) {
                v = l; sub(/^id:[ \t]*/, "", v); sub(/[ \t]+(#.*)?$/, "", v)
                gsub(/^["\047]|["\047]$/, "", v); break
              }
            }
            close(f)
            return v == "null" ? "" : v
          }
          {
            n = split($0, seg, "/"); base = seg[n]; sub(/\.md$/, "", base)
            print "N\t" base "\t" $0
            if (base ~ /\.adr\.rationale$/) { sub(/\.adr\.rationale$/, "", base); id = "adr-" base ".rationale" }
            else if (base ~ /\.adr$/) { sub(/\.adr$/, "", base); id = "adr-" base }
            else if (base ~ /\.(module|feature|entity|action|bundle|face|screen|process|component|layout|pattern)$/) {
              sub(/\.[a-z]+$/, "", base); id = base
            }
            else next
            fm = fm_id($0)
            if (fm == "") { print "N\t" id "\t" $0; next }
            print "N\t" fm "\t" $0
            alt = fm; if (index(alt, "::")) gsub(/::/, ".", alt); else gsub(/\./, "::", alt)
            if (alt != fm) print "N\t" alt "\t" $0
            if (fm != id && $0 !~ /\.screen\.md$/) print "F\t" id "\t" $0
          }'
  } > "$WIKILINK_INDEX_FILE"
}

# How a wikilink target resolves, as awk source: each index line goes through
# wiki_ix_add, and the first path a key names wins.
WIKILINK_AWK_RESOLVE='
  function wiki_ix_add(line,   r) {
    if (split(line, r, "\t") < 3) return
    if (!((r[1], r[2]) in ix)) ix[r[1], r[2]] = r[3]
  }

  function wiki_resolve(t,   c) {
    sub(/#.*/, "", t)
    if (t == "") return ""
    # A path-shaped target means its last segment (adr-kb-structure D4).
    if (index(t, "/")) { sub(/.*\//, "", t); sub(/\.md$/, "", t); if (t == "") return "" }
    if (index(t, "::")) {
      if (("A", t) in ix) return ix["A", t]
      c = t; gsub(/::/, ".", c)
      if (("E", c) in ix) return ix["E", c]
    } else if (index(t, ".")) {
      c = t; gsub(/\./, "::", c)
      if (("A", c) in ix) return ix["A", c]
      if (("E", t) in ix) return ix["E", t]
      if (("N", t) in ix) return ix["N", t]
    }
    if (("S", t) in ix) return ix["S", t]
    if ((("M", t) in ix) && (("S", ix["M", t]) in ix)) return ix["S", ix["M", t]]
    if (("N", t) in ix) return ix["N", t]
    if (("F", t) in ix) return ix["F", t]
    return ""
  }
'
