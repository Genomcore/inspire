#!/usr/bin/env bash
# .inspire/bin/lib/derive-json.sh
#
# Library — the readers, spools and JSON assembly the derive units share.
# Sourced after `_lib.sh` and `_keyed-heads.sh`; safe to source on its own.
# It carries: the scratch directory and the spool writers, `derive_norm` and the
# table / frontmatter / keyed-entry readers, the claim spool and its batched
# fingerprints, and the jq prelude every contract program opens with.
#
# A derived collection is accumulated as one separator-delimited record per line
# and rendered by a SINGLE `jq -n --rawfile` program per kind: one `jq` per
# object costs ~8 ms and a unit has dozens, and a record written through
# `derive_row` cannot be mis-escaped the way hand-built JSON can. Separators,
# outermost first — neither can occur in a markdown cell, which is what makes
# the encoding lossless without an escape rule:
#
#   DERIVE_FS  U+001F  between the fields of one record
#   DERIVE_LS  U+001E  between the items of a list inside one field
#
# THE FINGERPRINT is `sha256:<hex>` over the claim's payload bytes — its derived
# content, DERIVE_LS-joined, no trailing newline. Never the raw line and never
# the position: ordinals are not read and whitespace is collapsed, so two files
# differing only in spacing or numbering fingerprint identically. The payload
# per claim family is tabled in `_references/derived-contract.md`.
#
# Hashing is BATCHED — one digest process per unit rather than per claim, which
# is 0.4 s on a unit with thirty of them.

DERIVE_FS=$'\037'
DERIVE_LS=$'\036'

# derive_scratch — creates $DERIVE_TMP once and prints it. The caller owns the
# EXIT trap that removes it.
derive_scratch() {
  if [ -z "${DERIVE_TMP:-}" ]; then
    DERIVE_TMP="$(mktemp -d -t inspire-derive.XXXXXX)" || return 1
    mkdir -p "$DERIVE_TMP/h"
  fi
  printf '%s\n' "$DERIVE_TMP"
}

# derive_init_spools <name>... — create every spool this kind will render,
# empty. A collection with no rows still has to exist: `--rawfile` fails on a
# missing path, and "the unit declares none" must not read as a broken run.
derive_init_spools() {
  local name
  for name in "$@"; do : > "$DERIVE_TMP/$name.spool"; done
}

# derive_row <name> <field>... — append one record to a spool. A record is read
# back with `IFS="$DERIVE_FS" read -r marker c1 c2 …` and never by
# word-splitting an unquoted expansion: `read` does no pathname expansion, and a
# `Notes` cell containing `*` would otherwise become a directory listing.
derive_row() {
  local name="$1" out="" f
  shift
  for f in "$@"; do out="${out:+$out$DERIVE_FS}$f"; done
  printf '%s\n' "$out" >> "$DERIVE_TMP/$name.spool"
}

# derive_norm_g <text> — whitespace collapsed to single spaces and trimmed, left
# in $DERIVE_NORM. Pure parameter expansion, and the answer is a GLOBAL rather
# than stdout because the hot callers run it several times per keyed entry: a
# command substitution is a fork, and the forks, not the work, are what a
# derivation spends its time on.
derive_norm_g() {
  local s="$1"
  s="${s//$'\n'/ }"; s="${s//$'\t'/ }"; s="${s//$'\r'/ }"
  while [ "$s" != "${s//  / }" ]; do s="${s//  / }"; done
  while [ "${s# }" != "$s" ]; do s="${s# }"; done
  while [ "${s% }" != "$s" ]; do s="${s% }"; done
  DERIVE_NORM="$s"
}

# derive_norm <text> — the same, printed, for callers that read it once.
derive_norm() {
  derive_norm_g "$1"
  printf '%s' "$DERIVE_NORM"
}

# derive_fm_scalar <file> <key> — one frontmatter scalar, read from the file's
# own block: a yq process per screen is a derivation's largest avoidable cost.
# A quoted scalar is its quoted span and an unquoted ` #` opens a comment, or
# this reader and `sdd_fm_value` would disagree about an `id:` — and two readers
# that disagree about an id disagree about identity.
derive_fm_scalar() {
  awk -v key="$2" '
    NR == 1 { if ($0 != "---") exit; next }
    $0 == "---" { exit }
    index($0, key ": ") == 1 {
      v = substr($0, length(key) + 3)
      sub(/^[ \t]+/, "", v)
      q = substr(v, 1, 1)
      if (q == "\"" || q == "'"'"'") {
        e = index(substr(v, 2), q)
        if (e > 0) { print substr(v, 2, e - 1); exit }
      }
      c = index(v, " #")
      if (c > 0) v = substr(v, 1, c - 1)
      sub(/[ \t\r]+$/, "", v)
      print v
      exit
    }
  ' "$1"
}

# derive_link_target <cell> — the canonical id the first wikilink in a table
# cell names (right of the pipe, anchor dropped). Exit 1 when the cell carries
# no wikilink, so a caller can tell "no link" from "an empty link".
derive_link_target() {
  local s="$1" t
  case "$s" in *'[['*']]'*) ;; *) return 1 ;; esac
  t="${s#*[[}"; t="${t%%]]*}"
  case "$t" in *'|'*) t="${t#*|}" ;; esac
  t="${t%%#*}"
  derive_norm "$t"
}

# derive_header_line <file> <marker> — the body of a `**Marker:**` header line.
# Screens and catalog entries both state their dependencies on these lines, so
# the two readers live with the other shared markdown readers rather than in
# one kind's deriver.
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

# derive_head_split <head> — $DERIVE_HWORD, $DERIVE_HARGS (DERIVE_LS-joined) and
# $DERIVE_HCANON, from one pass. `kh_split_args` is an awk plus a sed and a head
# is otherwise split twice on every constraint token in the file. The canonical
# rendering is what makes `len(3, 64)` and `len(3,64)` one claim, not two.
derive_head_split() {
  local head="$1" args a
  DERIVE_HWORD=""; DERIVE_HARGS=""; DERIVE_HCANON=""
  [ -n "$head" ] || return 0
  DERIVE_HWORD="${head%%(*}"
  case "$head" in
    *\(*) ;;
    *) DERIVE_HCANON="$DERIVE_HWORD"; return 0 ;;
  esac
  args="$(kh_head_args "$head")"
  while IFS= read -r a; do
    derive_norm_g "$a"
    DERIVE_HARGS="${DERIVE_HARGS:+$DERIVE_HARGS$DERIVE_LS}$DERIVE_NORM"
  done < <(kh_split_args "$args")
  DERIVE_HCANON="$DERIVE_HWORD(${DERIVE_HARGS//$DERIVE_LS/,})"
}

# derive_table <file> <section> — every table in that section as records: one `H`
# per table, then one `R` per data row. The separator row is the discriminator,
# so a pipe line outside a table yields nothing; header cells are emitted because
# `## Inputs` may drop its `Required` column.
derive_table() {
  sdd_body_section "$1" "$2" | awk -v fs="$DERIVE_FS" '
    function emit(kind, line,   n, i, c, out) {
      gsub(/\\\|/, "\001", line)
      n = split(line, cell, "|")
      if (line ~ /\|[ \t]*$/) n--
      out = kind
      for (i = 2; i <= n; i++) {
        c = cell[i]
        gsub(/\001/, "|", c)
        gsub(/^[ \t]+|[ \t]+$/, "", c)
        out = out fs c
      }
      print out
    }
    /^[ \t]*\|/ {
      probe = $0
      gsub(/[ \t|:-]/, "", probe)
      if (probe == "") { if (prev != "") { emit("H", prev); sep = 1 }; prev = ""; next }
      if (sep) { emit("R", $0) } else { prev = $0 }
      next
    }
    { sep = 0; prev = "" }
  '
}

# derive_entry_prose <line> <key> <head> — the prose half of a keyed entry: the
# line with its marker, its backticked key and its head removed. Stripping is
# length-based after a QUOTED case match, never `${v#$head}`: a head carrying a
# regex (`pattern(/[a-z]+/)`) is a glob pattern to `#`, and the strip would
# silently fail exactly on the entries that matter most.
derive_entry_prose() {
  local line="$1" key="$2" head="$3" rest
  # Normalized once up front, so a single `${rest# }` is a complete trim after
  # each strip: runs of spaces no longer exist by then.
  derive_norm_g "$line"
  rest="$DERIVE_NORM"
  case "$rest" in
    '- '*)  rest="${rest#- }" ;;
    [0-9]*) rest="${rest#*.}" ;;
  esac
  rest="${rest# }"
  if [ -n "$key" ]; then
    case "$rest" in '`'"$key"'`'*) rest="${rest:$((${#key} + 2))}" ;; esac
    rest="${rest# }"
    case "$rest" in "$KH_EM"*) rest="${rest:${#KH_EM}}" ;; esac
    rest="${rest# }"
  fi
  if [ -n "$head" ]; then
    case "$rest" in "$head"*) rest="${rest:${#head}}" ;; esac
    rest="${rest# }"
    case "$rest" in "$KH_EM"*) rest="${rest:${#KH_EM}}" ;; esac
    rest="${rest# }"
  fi
  printf '%s' "$rest"
}

# derive_claim <claim_id> <oracle> <payload-part>...
#   Records one claim and the payload its fingerprint covers. Normalization
#   happens here rather than at every call site, so no caller can spool a
#   payload carrying whitespace two authors spelled differently.
derive_claim() {
  local id="$1" oracle="$2" payload="" p
  shift 2
  for p in "$@"; do
    derive_norm_g "$p"
    payload="${payload:+$payload$DERIVE_LS}$DERIVE_NORM"
  done
  derive_row claims "$id" "$oracle" "$payload"
}

# derive_sha_cmd — the host's sha256 tool, as a command word list. `xargs`
# cannot call a shell function, and batching the digest through `xargs` is what
# keeps a thirty-claim unit from paying thirty process spawns.
derive_sha_cmd() {
  if command -v sha256sum >/dev/null 2>&1; then
    printf 'sha256sum'
  else
    printf 'shasum -a 256'
  fi
}

# derive_hash_claims — rewrites the claims spool with each claim's fingerprint
# in place of its payload. One digest process for the whole unit; see header.
#   The join back is `paste`, not a lookup per claim: the payload files are
#   named by the claim's ordinal, so sorting the digests by name puts them in
#   the spool's own order.
derive_hash_claims() {
  local spool n=0 id oracle payload
  spool="$DERIVE_TMP/claims.spool"
  [ -s "$spool" ] || return 0
  while IFS="$DERIVE_FS" read -r id oracle payload; do
    [ -n "$id" ] || continue
    n=$((n + 1))
    printf '%s' "$payload" > "$DERIVE_TMP/h/$(printf '%06d' "$n")"
  done < "$spool"
  find "$DERIVE_TMP/h" -type f -print0 | LC_ALL=C xargs -0 $(derive_sha_cmd) \
    | awk '{ sha = $1; path = $2; sub(/^.*\//, "", path); print path "\t" sha }' \
    | LC_ALL=C sort \
    | awk -F'\t' '{ print "sha256:" $2 }' > "$DERIVE_TMP/h.shas"
  cut -d"$DERIVE_FS" -f1,2 "$spool" \
    | paste -d"$DERIVE_FS" - "$DERIVE_TMP/h.shas" > "$DERIVE_TMP/claims.hashed"
  mv "$DERIVE_TMP/claims.hashed" "$spool"
}

# The jq prelude every contract program opens with: the record readers, and the
# three shapes every unit kind shares.
DERIVE_JQ_PRELUDE='
  def recs($s): $s | split("\n") | map(select(length > 0)) | map(split("\u001f"));
  def items($s): if ($s // "") == "" then [] else ($s | split("\u001e")) end;
  def cel($r; $i): ($r[$i] // "");
  def hd($word; $args):
    if $word == "" then null else {word: $word, args: items($args)} end;
  def typ($name; $base):
    if $name == "" then null else {name: $name, base: $base} end;
  def entry($r):
    {key: cel($r;0), head: hd(cel($r;1); cel($r;2)),
     prose: cel($r;3), oracle: cel($r;4)};
  def cons($r): {word: cel($r;0), args: items(cel($r;1)), oracle: cel($r;2)};
  def byowner($s; $n):
    (recs($s) | group_by(.[0])
     | map({key: .[0][0], value: map(cons(.[$n:]))}) | from_entries);
  def claimlist($s): recs($s) | map({id: .[0], oracle: .[1], fingerprint: .[2]});
  def reqlist($s): recs($s) | map({kind: .[0], id: .[1]});
'

# derive_rawfile_args — the `--rawfile` triples for every spool this run
# created, named after the spool, one argument per line for the caller to read
# into an array. A spool name is a bare identifier, so no quoting arises.
derive_rawfile_args() {
  local f base
  for f in "$DERIVE_TMP"/*.spool; do
    [ -f "$f" ] || continue
    base="$(basename "$f" .spool)"
    printf -- '--rawfile\n%s\n%s\n' "$base" "$f"
  done
}
