#!/usr/bin/env bash
# .inspire/bin/lib/derive-json.sh
#
# Library — spools, fingerprints and the JSON assembly `emanate-derive.sh` and
# its sibling units share. Sourced after `_lib.sh` and `_keyed-heads.sh`; safe
# to source on its own from any other bin script that wants the same readers
# (the reuse surface the `plan` and `gate` scripts compose on).
#
# THE SPOOL DISCIPLINE. A derived collection is accumulated as one
# separator-delimited record per line in a scratch file, and the whole contract
# is then rendered by a SINGLE `jq -n --rawfile` program per kind. Two reasons,
# both measured: one `jq` per derived object costs about 8 ms and a unit has
# dozens of them; and a record written through `derive_row` cannot be
# mis-escaped the way hand-built JSON can. Separators, outermost first:
#
#   DERIVE_FS  U+001F  between the fields of one record
#   DERIVE_LS  U+001E  between the items of a list INSIDE one field
#                      (a head's arguments; a fingerprint payload's parts)
#
# Neither character can occur in a markdown table cell or a keyed entry, which
# is what makes the encoding lossless without an escape rule.
#
# THE FINGERPRINT. `sha256:<hex>` over the claim's PAYLOAD BYTES — the derived
# content of the claim, DERIVE_LS-joined, with no trailing newline. Never the
# raw line and never the position: the markdown ordinal is not read, whitespace
# inside every part is collapsed, and a head is rendered canonically, so two
# files differing only in spacing or numbering fingerprint identically. The
# payload shape per claim family is catalogued in
# `.claude/skills/_references/derived-contract.md`.
#
# Hashing is BATCHED: every payload is spooled, written out as one small file
# each, and digested by a single `shasum`/`sha256sum` invocation. Per-claim
# invocations cost 13 ms each — 0.4 s on a unit with thirty claims, which would
# be most of a derivation.

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

# derive_fm_scalar <file> <key> — one top-level frontmatter scalar, read from
# the file's own block rather than through `yq`. The screen index reads one key
# from every screen in the vault, and a yq process per file is the largest
# avoidable cost in a derivation. Two YAML facts have to be honoured or the
# reader answers differently from `sdd_fm_value`, and two readers of one
# frontmatter that disagree about an `id:` disagree about identity itself: a
# quoted scalar is its quoted span, and an unquoted ` #` opens a comment — the
# shipped templates put the enum of a field in exactly such a comment.
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

# derive_head_split <head>
#   Splits a head once into three globals: $DERIVE_HWORD (the identifier),
#   $DERIVE_HARGS (its arguments, trimmed and DERIVE_LS-joined, for the record
#   field the JSON program turns back into an array) and $DERIVE_HCANON (the
#   canonical rendering `word` or `word(a1,a2)`).
#
#   One split, three answers: `kh_split_args` is an awk plus a sed, and a head
#   would otherwise be split once for its arguments and again for its canonical
#   form, on every constraint token in the file. Canonical rendering is what
#   makes `len(3, 64)` and `len(3,64)` one claim rather than two.
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

# derive_table <file> <section>
#   Every markdown table in that body section, as DERIVE_FS-joined records: one
#   `H` record per table carrying its header cells, then one `R` record per data
#   row. Header-keyed columns are what let a reader survive the optional
#   `Required` column `## Inputs` may drop.
#   The separator row is the discriminator (a header is the row before it), so a
#   pipe line that is not part of a table yields nothing; a `\|` escaped for a
#   wikilink is protected before the split and restored after.
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
