#!/usr/bin/env bash
#
# plugin/scripts/migrate-links.sh — rewrite every [[wikilink]] in a concept-layout
# knowledge base as a relative Markdown link to the target file (adr-markdown-links).
#
# The link engine behind /inspire:migrate: migrate-kb.sh runs it after the moves of a
# layered KB, and on a concept KB that still holds wikilinks it is the whole run.
#
# Usage:
#   migrate-links.sh [--kb DIR] [--dry-run] [--since REV] [--count]
#     --since REV   the commit before the KB moved, for a KB with no move record
#     --count       print how many wikilinks the KB holds outside code, and nothing else
#
# A link resolves through, in order: its path, mapped through the move record
# (01_spec/_migration/plan.tsv, else the renames `git diff -M` finds since the move)
# or as it stands; the id index; the pre-move file names of the move record; the
# screen id map (01_spec/_migration/id-map.json). An ambiguous key resolves nothing.
#
# Output (stdout): the plan, one tab-separated line per step —
#   link <file> <line> <source> <wikilink> <markdown> · unresolved <file> <line> <wikilink> ·
#   note <text>
# In act mode the files are rewritten and the plan is saved to
# 01_spec/_migration/links.tsv, when it converted anything.
#
# Exit: 0 converted (or nothing to do) · 1 refused · 2 usage.
#
# It leaves a link inside a code span or a fenced block, and a link it cannot resolve,
# as written. It reads git and never writes to it. bash 3.2 compatible.

set -uo pipefail

KB="inspire_kb"
DRY=0
COUNT=0
SINCE=""

usage() { sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    --kb) KB="${2:?}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --since) SINCE="${2:?}"; shift 2 ;;
    --count) COUNT=1; shift ;;
    -h|--help) usage ;;
    *) printf 'migrate-links: unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done

KB="${KB%/}"
SPEC="$KB/01_spec"
[ -d "$KB" ] || { printf 'migrate-links: no knowledge base at %s\n' "$KB" >&2; exit 1; }

WORK="$(mktemp -d -t inspire-links.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
FILES="$WORK/files.txt"
find "$KB" -type f -name '*.md' | awk -v p="$KB/" '{ print substr($0, length(p) + 1) }' | LC_ALL=C sort > "$FILES"

# Shared by the count and the conversion. Each file is read whole (RS is set to a byte
# a Markdown file never holds), so its bytes, the last newline included, survive.
read -r -d '' AWK_LIB <<'AWK'
function dir_of(p) { return match(p, /\/[^\/]*$/) ? substr(p, 1, RSTART - 1) : "" }
function join_path(d, t) { return (d == "" || substr(t, 1, 1) == "/") ? t : d "/" t }
function normpath(p,   n, a, s, i, k, r) {
  n = split(p, a, "/"); k = 0
  for (i = 1; i <= n; i++) {
    if (a[i] == "" || a[i] == ".") continue
    if (a[i] == ".." && k > 0 && s[k] != "..") { k--; continue }
    s[++k] = a[i]
  }
  r = ""; for (i = 1; i <= k; i++) r = r (i > 1 ? "/" : "") s[i]
  return r == "" ? "." : r
}
function relpath(p, start,   na, nb, a, b, i, c, r) {
  na = split(normpath(p), a, "/"); if (a[1] == ".") na = 0
  nb = split(normpath(start), b, "/"); if (b[1] == ".") nb = 0
  c = 0; while (c < na && c < nb && a[c + 1] == b[c + 1]) c++
  r = ""; for (i = c + 1; i <= nb; i++) r = r "../"
  for (i = c + 1; i <= na; i++) r = r a[i] "/"
  sub(/\/$/, "", r)
  return r == "" ? "." : r
}
function slurp(f,   t) { t = ""; RS = "\001"; getline t < f; close(f); return t }
# A fence is ``` to the next ```; an inline span is ` to the next ` on the same line.
function code_spans(t,   L, i, j, k, rest) {
  NCS = 0; L = length(t); i = 1
  while (i <= L) {
    j = index(substr(t, i), "`"); if (!j) break
    i += j - 1
    if (substr(t, i, 3) == "```" && (k = index(substr(t, i + 3), "```"))) {
      CS[++NCS] = i; CE[NCS] = i + k + 5; i = CE[NCS]; continue
    }
    rest = substr(t, i + 1)
    if ((k = match(rest, /[`\n]/)) && substr(rest, k, 1) == "`") {
      CS[++NCS] = i; CE[NCS] = i + k + 1; i = CE[NCS]; continue
    }
    i++
  }
  CI = 1
}
# Called with increasing positions only.
function in_code(i) {
  while (CI <= NCS && CE[CI] <= i) CI++
  return CI <= NCS && CS[CI] <= i
}
# next_link(t, from) — the next [[…]] not preceded by `!`: sets LS (start), LE (end,
# exclusive) and LINNER, and returns 0 when there is none.
function next_link(t, from,   i, j, rest) {
  while ((i = index(substr(t, from), "[["))) {
    i += from - 1
    if (i > 1 && substr(t, i - 1, 1) == "!") { from = i + 1; continue }
    rest = substr(t, i + 2)
    if (!(j = index(rest, "]"))) return 0
    if (j > 1 && substr(rest, j, 2) == "]]") {
      LS = i; LE = i + j + 3; LINNER = substr(rest, 1, j - 1); return 1
    }
    from = i + 1
  }
  return 0
}
AWK

if [ "$COUNT" -eq 1 ]; then
  awk -v KB="$KB" -v LIST="$FILES" "$AWK_LIB"'
    BEGIN {
      while ((getline f < LIST) > 0) files[++nf] = f
      close(LIST)
      for (n = 1; n <= nf; n++) {
        t = slurp(KB "/" files[n]); code_spans(t); pos = 1
        while (next_link(t, pos)) { if (!in_code(LS)) c++; pos = LE }
      }
      print c + 0
    }'
  exit 0
fi

for l in 01_adr 02_modules 03_features 04_domain 05_screens; do
  if [ -d "$KB/$l" ]; then
    printf 'migrate-links: %s is on the layered layout. Run migrate-kb.sh, which moves it and converts its links.\n' "$KB" >&2
    exit 1
  fi
done

# ── the move record: old <TAB> new, both relative to the KB ──────────────────
RENAMES="$WORK/renames.tsv"; : > "$RENAMES"
if [ -f "$SPEC/_migration/plan.tsv" ]; then
  # Plan paths carry the KB directory the migration ran with; the part before
  # /01_spec/ in a destination is that directory, whatever --kb says now.
  awk -F'\t' '
    ($1 == "move" || $1 == "unplaced") && (p = index($3, "/01_spec/")) {
      pre = substr($3, 1, p)
      if (index($2, pre) == 1) printf "%s\t%s\n", substr($2, length(pre) + 1), substr($3, length(pre) + 1)
    }' "$SPEC/_migration/plan.tsv" > "$RENAMES"
  record="01_spec/_migration/plan.tsv"
elif git -C "$KB" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  if [ -z "$SINCE" ]; then
    # The last commit that touched a layered directory is the one that moved it away.
    moved="$(GIT_OPTIONAL_LOCKS=0 git -C "$KB" log -1 --format=%H -- 01_adr 02_modules 03_features 04_domain 05_screens 2>/dev/null)"
    [ -n "$moved" ] && SINCE="$moved^"
  fi
  if [ -n "$SINCE" ]; then
    GIT_OPTIONAL_LOCKS=0 git -C "$KB" -c core.quotepath=false diff --name-status -M --relative "$SINCE" HEAD 2>/dev/null \
      | awk -F'\t' '$1 ~ /^R/ { printf "%s\t%s\n", $2, $3 }' > "$RENAMES"
    record="git renames since $SINCE"
  else
    record="none: no plan.tsv, and git history shows no layered directory"
  fi
else
  record="none: no plan.tsv, and the KB is not in a git work tree"
fi

# ── the id index: key <TAB> path, ambiguous keys dropped ─────────────────────
INDEX="$WORK/index.tsv"
awk -v KB="$KB" -v LIST="$FILES" "$AWK_LIB"'
  function add(k, p) {
    k = tolower(k); if (k == "") return
    if ((k in idx) && idx[k] != p) clash[k] = 1
    idx[k] = p
  }
  BEGIN {
    while ((getline f < LIST) > 0) files[++nf] = f
    close(LIST)
    T = "\\.(adr\\.rationale|module|feature|entity|action|adr|bundle|face|screen|process|component|layout|pattern|template)$"
    for (n = 1; n <= nf; n++) {
      f = files[n]; b = f; sub(/.*\//, "", b); b = substr(b, 1, length(b) - 3)
      if (b == "README" || b == "_index") continue
      add(b, f)
      if (match(b, T)) {
        s = substr(b, 1, RSTART - 1); ty = substr(b, RSTART + 1)
        add(ty == "adr" ? "adr-" s : ty == "adr.rationale" ? "adr-" s ".rationale" : s, f)
      }
      t = slurp(KB "/" f)
      if (substr(t, 1, 4) != "---\n" || !(k = index(substr(t, 5), "\n---"))) continue
      m = split(substr(t, 5, k - 1), line, "\n")
      for (i = 1; i <= m; i++) {
        if (substr(line[i], 1, 3) != "id:") continue
        v = substr(line[i], 4)
        sub(/^[ \t\r]+/, "", v); sub(/^"/, "", v); sub(/[ \t\r]+$/, "", v); sub(/"$/, "", v)
        if (v == "" || index(v, "\"")) continue
        add(v, f); gsub(/::/, ".", v); add(v, f)
        break
      }
    }
    for (k in idx) if (!(k in clash)) printf "%s\t%s\n", k, idx[k]
  }' > "$INDEX"

IDMAP="$WORK/idmap.tsv"; : > "$IDMAP"
if [ -f "$SPEC/_migration/id-map.json" ]; then
  jq -r '(if type == "object" then (.screens // .) else {} end) | to_entries[]
         | select(.value | type == "string") | [.key, .value] | @tsv' \
    "$SPEC/_migration/id-map.json" > "$IDMAP" 2>/dev/null || : > "$IDMAP"
fi

# ── convert ──────────────────────────────────────────────────────────────────
OUT="$WORK/out"; mkdir -p "$OUT"
PLAN="$WORK/links.tsv"
CHANGED="$WORK/changed.tsv"; : > "$CHANGED"
STATS="$WORK/stats.tsv"
awk -v KB="$KB" -v LIST="$FILES" -v RENAMES="$RENAMES" -v INDEX="$INDEX" -v IDMAP="$IDMAP" \
    -v OUT="$OUT" -v CHANGED="$CHANGED" -v STATS="$STATS" "$AWK_LIB"'
  function exists(p,   r, x) { r = (getline x < (KB "/" p)); if (r >= 0) close(KB "/" p); return r >= 0 }
  function resolve(src, target,   cand, seg, k) {
    if (index(target, "/")) {
      cand = normpath(join_path(dir_of((src in BACK) ? BACK[src] : src), target))
      if (cand !~ /\.md$/) cand = cand ".md"
      if ((cand in REN) && exists(REN[cand])) { HOW = "moved-path"; return REN[cand] }
      cand = normpath(join_path(dir_of(src), target))
      if (cand !~ /\.md$/) cand = cand ".md"
      if (exists(cand)) { HOW = "path"; return cand }
    }
    seg = target; sub(/.*\//, "", seg); seg = tolower(seg); sub(/\.md$/, "", seg)
    if (seg in IDX) { HOW = "id"; return IDX[seg] }
    k = seg; gsub(/::/, ".", k)
    if (k in IDX) { HOW = "id"; return IDX[k] }
    if ((seg in STEM) && !(seg in STEMCLASH) && exists(STEM[seg])) { HOW = "moved-stem"; return STEM[seg] }
    if ((seg in IDM) && (IDM[seg] in IDX)) { HOW = "id-map"; return IDX[IDM[seg]] }
    return ""
  }
  function flat(s) { gsub(/[\t\n]/, " ", s); return s }
  function trim(s) { sub(/^[ \t\n\r]+/, "", s); sub(/[ \t\n\r]+$/, "", s); return s }
  BEGIN {
    while ((getline l < RENAMES) > 0) {
      split(l, a, "\t"); REN[a[1]] = a[2]; BACK[a[2]] = a[1]
      if (a[1] !~ /\.md$/) continue
      s = a[1]; sub(/.*\//, "", s); s = tolower(substr(s, 1, length(s) - 3))
      if ((s in STEM) && STEM[s] != a[2]) STEMCLASH[s] = 1
      STEM[s] = a[2]
    }
    while ((getline l < INDEX) > 0) { split(l, a, "\t"); IDX[a[1]] = a[2] }
    while ((getline l < IDMAP) > 0) { split(l, a, "\t"); IDM[tolower(a[1])] = tolower(a[2]) }
    while ((getline f < LIST) > 0) files[++nf] = f
    close(LIST)
    for (n = 1; n <= nf; n++) {
      f = files[n]; t = slurp(KB "/" f); code_spans(t)
      out = ""; pos = 1; from = 1; ln = 1; lnpos = 1; changed = 0
      while (next_link(t, from)) {
        from = LE
        if (in_code(LS)) { st["code"]++; continue }
        chunk = substr(t, lnpos, LS - lnpos); ln += gsub(/\n/, "", chunk); lnpos = LS
        inner = LINNER; target = inner; alias = ""
        if ((p = index(inner, "|"))) {
          alias = substr(inner, p + 1)
          target = substr(inner, 1, p - ((p > 1 && substr(inner, p - 1, 1) == "\\") ? 2 : 1))
        }
        target = trim(target)
        path = resolve(f, target)
        if (path == "") {
          st["unresolved"]++
          printf "unresolved\t%s/%s\t%d\t%s\n", KB, f, ln, flat("[[" inner "]]")
          continue
        }
        if (alias != "") text = trim(alias)
        else { text = target; sub(/.*\//, "", text) }
        md = "[" text "](" relpath(path, dir_of(f)) ")"
        out = out substr(t, pos, LS - pos) md; pos = LE; changed = 1
        st[HOW]++; st["converted"]++
        printf "link\t%s/%s\t%d\t%s\t%s\t%s\n", KB, f, ln, HOW, flat("[[" inner "]]"), flat(md)
      }
      if (!changed) continue
      out = out substr(t, pos)
      if (out == t) continue
      nchanged++
      printf "%s", out > (OUT "/" n); close(OUT "/" n)
      printf "%s\t%s\n", f, OUT "/" n > CHANGED
    }
    close(CHANGED)
    printf "files\t%d\n", nchanged > STATS
    for (k in st) printf "%s\t%d\n", k, st[k] > STATS
  }' > "$PLAN"

tally() { awk -F'\t' -v k="$1" '$1 == k { print $2; f = 1 } END { if (!f) print 0 }' "$STATS"; }
converted="$(tally converted)"
{
  printf 'note\tmove record: %s (%s renames)\n' "$record" "$(wc -l < "$RENAMES" | tr -d ' ')"
  printf 'note\tlinks: %s converted in %s file(s) (moved-path %s, path %s, id %s, moved-stem %s, id-map %s), %s unresolved and left as written, %s in code left as written\n' \
    "$converted" "$(tally files)" "$(tally moved-path)" "$(tally path)" "$(tally id)" "$(tally moved-stem)" "$(tally id-map)" \
    "$(tally unresolved)" "$(tally code)"
} >> "$PLAN"

if [ "$DRY" -eq 1 ]; then
  cat "$PLAN"
  printf 'note\tdry run: nothing was written\n'
  exit 0
fi

while IFS="$(printf '\t')" read -r rel src; do
  cat "$src" > "$KB/$rel"
done < "$CHANGED"
if [ "$converted" -gt 0 ] && [ -d "$SPEC" ]; then
  mkdir -p "$SPEC/_migration"
  cp "$PLAN" "$SPEC/_migration/links.tsv"
fi
cat "$PLAN"
exit 0
