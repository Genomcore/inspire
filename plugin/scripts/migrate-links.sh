#!/usr/bin/env bash
#
# plugin/scripts/migrate-links.sh — rewrite every [[wikilink]] in a concept-layout
# knowledge base as a relative Markdown link to the target file (adr-markdown-links).
#
# The link step of /inspire:migrate: its own run, once migrate-kb.sh's moves are
# committed, so git records every move as a rename (adr-markdown-links D6).
#
# Usage:
#   migrate-links.sh [--kb DIR] [--dry-run] [--since REV] [--count]
#     --since REV   the commit before the KB moved, for a KB with no move record
#     --count       print how many wikilinks the KB holds outside code, and nothing else
#
# A link resolves through, in order: its path, mapped through the move record
# (01_spec/_migration/plan.tsv, else the renames `git diff -M` finds since the move);
# its path against the current files; the id index (lib/wikilinks.sh), which resolves
# a wikilink the way the validators did before 0.16.1, the screen id map
# (01_spec/_migration/id-map.json) included, so the link names the file they read;
# its target as a pre-move file name, mapped through the move record, where a name
# two files had resolves nothing.
#
# A wikilink no route resolves is settled without a person, since one left in the KB
# stops the Factory (D6): an id that names an artifact type gets its draft from the
# shipped template, and anything else becomes its text.
#
# A Markdown link that names nothing where it stands is rebased through the move record
# and the layout (D7). One to a retired file, or a placeholder outside a template,
# becomes its text; the rest is listed as broken. No link is converted or rebased into
# 01_spec/_migration/.
#
# Output (stdout): the plan, one tab-separated line per step —
#   link <file> <line> <source> <wikilink> <markdown> ·
#   draft <file> <line> draft <wikilink> <markdown> · drafted <new file> <kind> ·
#   unlinked <file> <line> <link> <text> <why> ·
#   link <file> <line> rebased <old link> <new link> · broken <file> <line> <link> ·
#   note <text>
# In act mode the files are rewritten, the drafts written, and the plan is saved to
# 01_spec/_migration/links.tsv, when it changed anything.
#
# Exit: 0 converted (or nothing to do) · 1 refused (a layered KB, or moves git has not
# committed) · 2 usage.
#
# It leaves a link inside a code span or a fenced block as written, and no wikilink
# outside one. It reads git and never writes to it. bash 3.2 compatible.

set -uo pipefail

KB="inspire_kb"
DRY=0
COUNT=0
SINCE=""

usage() { sed -n '2,44p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

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

# The reader's span, fence and frontmatter rules come from the runtime library itself,
# pointed at this KB. The wikilink index names files by the normalized KB path, so the
# KB is normalized the same way.
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
{ . "$HERE/../base/bin/_lib.sh" && . "$HERE/lib/wikilinks.sh"; } || { printf 'migrate-links: cannot read the plugin library\n' >&2; exit 1; }
KB="$(sdd_scope_norm "$KB")"
SPEC="$KB/01_spec"
SDD_KB_ROOT="$KB"; SDD_SPEC_ROOT="$SPEC"
[ -d "$KB" ] || { printf 'migrate-links: no knowledge base at %s\n' "$KB" >&2; exit 1; }

WORK="$(mktemp -d -t inspire-links.XXXXXX)"
trap 'rm -rf "$WORK" "${WIKILINK_INDEX_FILE:-}" "${SDD_ENTITY_INDEX_FILE:-}"' EXIT
FILES="$WORK/files.txt"
# _migration/ holds what the migration could not place; no link there is converted,
# rebased or listed (D2).
find "$KB" -type f -name '*.md' | awk -v p="$KB/" '{ r = substr($0, length(p) + 1) } r !~ /(^|\/)_migration\// { print r }' \
  | LC_ALL=C sort > "$FILES"

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
# blocks(t) — t read with the reader's own block model (D4): BL[k] is line k, and
# MASK[k] the same line with its code spans blanked in place, for each line the reader
# scans (none in a fence); MFM[k] marks frontmatter.
function blocks(t,   n, k) {
  split("", MASK); split("", MFM)
  n = split(t, BL, "\n")
  for (k = 1; k <= n; k++) sdd_block(BL[k], k)
  sdd_block_end(n)
  return n
}
function sdd_line(raw, s, ln) { MASK[ln] = s; MFM[ln] = fm }
function sdd_code(kind, from, to, text) { }
# wikilinks(t) — the wikilinks in t that the reader reads: NL of them, each at LS
# (start) to LE (end, exclusive) on line LLN, inner text LIN; LFM marks frontmatter.
# NCODE counts those the reader takes for code.
function wikilinks(t,   n, k, base, line) {
  NL = 0; NCODE = 0; n = blocks(t); base = 0
  for (k = 1; k <= n; k++) {
    line = BL[k]
    if (k in MASK) NCODE += wiki_scan(line) - wiki_scan(MASK[k], line, base, k, MFM[k])
    else NCODE += wiki_scan(line)
    base += length(line) + 1
  }
}
# The reader's wikilink pattern over s; with raw given, each match is recorded
# from raw, which s masks code in without moving a byte.
function wiki_scan(s, raw, base, ln, fm,   c, off, m) {
  c = 0; off = 0
  while (match(substr(s, off + 1), /\[\[[^][]+\]\]/)) {
    m = off + RSTART; off = m + RLENGTH - 1; c++
    if (raw == "") continue
    NL++; LS[NL] = base + m; LE[NL] = base + off + 1; LLN[NL] = ln; LFM[NL] = fm
    LIN[NL] = substr(raw, m + 2, RLENGTH - 4); LPRE[NL] = substr(raw, 1, m - 1)
  }
  return c
}
AWK
AWK_LIB="$AWK_LIB$SDD_AWK_BLOCKS$SDD_AWK_SPAN_FUNCS$SDD_AWK_FENCE_FUNCS$SDD_AWK_MD_FUNCS"

if [ "$COUNT" -eq 1 ]; then
  LC_ALL=C awk -v KB="$KB" -v LIST="$FILES" "$AWK_LIB"'
    BEGIN {
      while ((getline f < LIST) > 0) files[++nf] = f
      close(LIST)
      for (n = 1; n <= nf; n++) { wikilinks(slurp(KB "/" files[n])); c += NL }
      print c + 0
    }'
  exit 0
fi

for l in 01_adr 02_modules 03_features 04_domain 05_screens; do
  if [ -d "$KB/$l" ]; then
    printf 'migrate-links: %s is on the layered layout. Run migrate-kb.sh and commit the moves first.\n' "$KB" >&2
    exit 1
  fi
done

# Moves not yet committed would land in one commit with the link edits, and git would
# lose them as renames (D6). The move plan, the link plan and the drafts an earlier
# conversion wrote are the converter's own files, so a second run before the commit
# is not refused.
uncommitted=""; git_note=""
if git -C "$KB" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  prefix="$(git -C "$KB" rev-parse --show-prefix)"
  OWN="$WORK/own.txt"; : > "$OWN"
  [ -f "$SPEC/_migration/links.tsv" ] && awk -F'\t' -v pre="$prefix" '
      $1 == "drafted" && (i = index($2, "/01_spec/")) { print pre substr($2, i + 1) }' "$SPEC/_migration/links.tsv" > "$OWN"
  uncommitted="$(GIT_OPTIONAL_LOCKS=0 git -C "$KB" -c core.quotepath=false status --porcelain --untracked-files=all -- . 2>/dev/null \
    | awk -v skip="${prefix}01_spec/_migration/" -v own="$OWN" '
        BEGIN { while ((getline l < own) > 0) OWNED[l] = 1 }
        { p = substr($0, 4); sub(/^.* -> /, "", p); gsub(/"/, "", p) }
        index(p, skip) == 1 || (p in OWNED) { next }
        substr($0, 1, 2) == "??" || substr($0, 1, 2) ~ /[RAD]/ { print "  " substr($0, 1, 2) " " p }')"
  if [ -n "$uncommitted" ] && [ "$DRY" -eq 0 ]; then
    printf 'migrate-links: %s has moves, additions or deletions git has not committed. Commit the moves on their own first (/inspire:migrate Step 3), then convert:\n%s\n' "$KB" "$(printf '%s\n' "$uncommitted" | head -10)" >&2
    exit 1
  fi
else
  git_note="the KB is not in a git work tree, so nothing checks that its moves are committed"
fi

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
    # No rename limit: above it git stops pairing edited moves and lists them as D + A.
    GIT_OPTIONAL_LOCKS=0 git -C "$KB" -c core.quotepath=false -c diff.renameLimit=0 diff --name-status -M --relative "$SINCE" HEAD 2>/dev/null \
      | awk -F'\t' '$1 ~ /^R/ { printf "%s\t%s\n", $2, $3 }' > "$RENAMES"
    record="git renames since $SINCE"
  else
    record="none: no plan.tsv, and git history shows no layered directory"
  fi
else
  record="none: no plan.tsv, and the KB is not in a git work tree"
fi

wikilink_index

# Every path under the KB, so a Markdown link is checked without reading a directory,
# which awk cannot open.
ALLF="$WORK/all-files.txt"; ALLD="$WORK/all-dirs.txt"
find "$KB" -type f | awk -v p="$KB/" '{ print substr($0, length(p) + 1) }' > "$ALLF"
find "$KB" -type d | awk -v p="$KB/" '{ print ($0 == substr(p, 1, length(p) - 1)) ? "." : substr($0, length(p) + 1) }' > "$ALLD"

# draft_file <kind> <path> <id parts…> — an artifact's draft from its shipped template
# (adr-kb-structure D4), in its first state. Each identity placeholder is filled, and a
# link whose target does not exist (a placeholder, a sample) becomes its text, so the
# draft links nothing that is not there.
TEMPLATES="$HERE/../base/skills"
draft_file() {
  local kind="$1" dest="$2" a="$3" b="$4" c="$5" tpl
  case "$kind" in
    adr) tpl="$TEMPLATES/inspire-adr/templates/adr.template.md" ;;
    adr.rationale) tpl="$TEMPLATES/inspire-adr/templates/adr.rationale.template.md" ;;
    entity|action) tpl="$TEMPLATES/inspire-domain/templates/$kind.template.md" ;;
    screen) tpl="$TEMPLATES/inspire-screens/templates/screen.template.md" ;;
  esac
  LC_ALL=C awk -v kind="$kind" -v a="$a" -v b="$b" -v c="$c" -v dir="$(dirname "$dest")" "$AWK_LIB"'
    function fill(s, from, to,   i, o) {
      o = ""; while ((i = index(s, from)) > 0) { o = o substr(s, 1, i - 1) to; s = substr(s, i + length(from)) }
      return o s
    }
    function there(p,   q) {
      q = (substr(p, 1, 1) == "/") ? p : dir "/" p; gsub(/\047/, "\047\\\047\047", q)
      return system("test -e \047" q "\047") == 0
    }
    function unlink(line, masked,   res, off, st, tok, d) {
      res = ""; off = 0
      while (sdd_next_md(substr(masked, off + 1))) {
        st = off + MS; tok = substr(line, st, ML)
        d = sdd_md_dest(substr(masked, st, ML), MT)
        if (d != "" && (MDPATH ~ /[{}]/ || !there(MDPATH))) tok = substr(tok, (substr(tok, 1, 1) == "!") + 2, MT - 2 - (substr(tok, 1, 1) == "!"))
        res = res substr(line, off + 1, st - off - 1) tok; off = st + ML - 1
      }
      return res substr(line, off + 1)
    }
    {
      l = $0
      if (kind ~ /^adr/) { title = a; gsub(/-/, " ", title); l = fill(fill(l, "{Title}", title), "{slug}", a) }
      else if (kind == "screen") {
        title = b; gsub(/-/, " ", title)
        l = fill(fill(fill(fill(fill(l, "{Screen Title}", title), "{face}", a), "{slug}", b), "{screen}", b), "{module}", "")
      }
      else l = fill(fill(fill(l, "{{MODULE}}", a), "{{ENTITY}}", b), "{{ACTION}}", c)
      text = text (NR > 1 ? "\n" : "") l
    }
    END { n = blocks(text); for (k = 1; k <= n; k++) print (k in MASK) ? unlink(BL[k], MASK[k]) : BL[k] }' "$tpl" > "$dest"
}

# ── convert ──────────────────────────────────────────────────────────────────
OUT="$WORK/out"; mkdir -p "$OUT"
PLAN="$WORK/links.tsv"
CHANGED="$WORK/changed.tsv"; : > "$CHANGED"
STATS="$WORK/stats.tsv"
DRAFTS="$WORK/drafts.tsv"; : > "$DRAFTS"
# Byte semantics in every pass, so a span is masked and a file rewritten byte for byte.
# A path that starts with `/` resolves from the repository root (D2), passed to awk
# relative to the KB.
KB_ABS="$(cd "$KB" && pwd -P)"; ROOT_ABS="$(cd "$(sdd_repo_root)" && pwd -P)"
LC_ALL=C awk -v KB="$KB" -v LIST="$FILES" -v RENAMES="$RENAMES" -v INDEX="$WIKILINK_INDEX_FILE" \
    -v ALLF="$ALLF" -v ALLD="$ALLD" -v KB_ABS="$KB_ABS" -v ROOT_ABS="$ROOT_ABS" \
    -v OUT="$OUT" -v CHANGED="$CHANGED" -v STATS="$STATS" -v DRAFTS="$DRAFTS" "$AWK_LIB$WIKILINK_AWK_RESOLVE"'
  function exists(p,   r, x) { r = (getline x < (KB "/" p)); if (r >= 0) close(KB "/" p); return r >= 0 }
  # A path outside the KB, or absolute, is asked of the file system once. A draft this
  # run makes is there.
  function present(p,   q) {
    if ((p in FSET) || (p in DSET) || (p in DRAFTED)) return 1
    if (substr(p, 1, 1) != "/" && p !~ /^\.\.(\/|$)/) return 0
    if (!(p in OUTSIDE)) {
      q = (substr(p, 1, 1) == "/") ? p : KB "/" p; gsub(/\047/, "\047\\\047\047", q)
      OUTSIDE[p] = (system("test -e \047" q "\047") == 0)
    }
    return OUTSIDE[p]
  }
  # rebase(f, t) — t with each Markdown link that names nothing rebased (D7), read
  # line by line with the reader rules: frontmatter is read, code is not.
  function rebase(f, t,   n, k, out) {
    n = blocks(t); out = ""
    for (k = 1; k <= n; k++) out = out (k > 1 ? "\n" : "") ((k in MASK) ? rebase_line(f, BL[k], k, MASK[k]) : BL[k])
    return out
  }
  # Tokens are found in the masked line and copied from the raw one.
  function rebase_line(f, line, ln, masked,   res, off, s, tok, d0, nd, rtok, inner, lead, w, ntok) {
    res = ""; off = 0
    while (sdd_next_md(substr(masked, off + 1))) {
      s = off + MS; tok = substr(masked, s, ML); rtok = substr(line, s, ML); ntok = rtok
      # A token that is no KB link (a URL, an anchor, an image) is never rebased or unlinked.
      nd = ""; UNLINK = ""
      if ((d0 = sdd_md_dest(tok, MT)) != "") nd = rebased(f, d0, MDPATH, ln, rtok)
      if (nd != "") {
        inner = substr(rtok, MT + 2, ML - MT - 2); lead = match(inner, /[^ ]/) - 1
        w = (substr(inner, lead + 1, 1) == "<") ? "<" d0 ">" : d0
        ntok = substr(rtok, 1, MT + 1) substr(inner, 1, lead) nd substr(inner, lead + length(w) + 1) ")"
        printf "link\t%s/%s\t%d\trebased\t%s\t%s\n", KB, f, ln, flat(rtok), flat(ntok)
      } else if (UNLINK != "") {
        ntok = md_text(rtok, MT)
        printf "unlinked\t%s/%s\t%d\t%s\t%s\t%s\n", KB, f, ln, flat(rtok), flat(ntok), UNLINK
      }
      res = res substr(line, off + 1, s - off - 1) ntok; off = s + ML - 1
    }
    return res substr(line, off + 1)
  }
  # The text of the link token rtok, whose `](` is at p.
  function md_text(rtok, p) {
    if (substr(rtok, 1, 1) == "!") { rtok = substr(rtok, 2); p-- }
    return substr(rtok, 2, p - 2)
  }
  # No link points into _migration/ (D7): what the migration could not place stays there.
  function placed(p) { return p !~ /^01_spec\/_migration(\/|$)/ }
  # layered(p) — where the layout puts what the layered path p named (D7): a layered
  # directory goes to the concept directory that took its contents, its README to the
  # README of that directory when there is one, a subdirectory to the directory of its
  # module or face with any deeper path kept, and a screen index to its face _index.md.
  function layered(p,   n, s, d, i) {
    n = split(p, s, "/")
    if (s[1] == "01_adr") d = "01_spec/_adr"
    else if (s[1] == "02_modules" || s[1] == "03_features" || s[1] == "04_domain") d = "01_spec/_modules"
    else if (s[1] == "05_screens") d = "01_spec/_faces"
    else return ""
    if (n == 1) return d
    if (n == 2 && s[2] == "README.md") return present(d "/README.md") ? d "/README.md" : d
    if (s[1] == "01_adr" || index(s[2], ".")) return ""
    d = d "/" s[2]; i = 3
    if (s[1] == "03_features") d = d "/_features"
    else if (s[1] == "04_domain") d = d "/_domain"
    else if (s[1] == "05_screens" && (n == 3 || n == 4) && s[n] == "_index.md") return d "/_index.md"
    else if (s[1] == "05_screens" && n >= 3) { d = d "/_screens"; i = 4 }
    for (; i <= n; i++) d = d "/" s[i]
    return d
  }
  # nearest(c) — c where it exists; where c is a directory (its last segment has no
  # extension) that does not, the nearest directory on that path that does (D7). A file
  # or a placeholder gets no stand-in.
  function nearest(c,   b) {
    if (present(c)) return c
    if (placeholder(c)) return ""
    b = c; sub(/.*\//, "", b)
    if (index(b, ".")) return ""
    while (sub(/\/[^\/]*$/, "", c)) if (placed(c) && present(c)) return c
    return ""
  }
  # retired(old) — a file the migration retired: its move record took it to
  # _migration/retired/, or it is the surface roster or a layered theme file (D6).
  function retired(old,   b) {
    if ((old in REN) && REN[old] ~ /^01_spec\/_migration\/retired\//) return 1
    b = old; sub(/.*\//, "", b)
    return b == "surfaces.md" || b == "theme.md" || b == "theme.tokens.json"
  }
  # A template placeholder: braces or an ellipsis where a name belongs.
  function placeholder(t) { return t ~ /[{}]/ || index(t, "…") }
  function is_template(f) { return f ~ /(^|\/)(_template|[^\/]*\.template)\.md$/ }
  # rebased(f, written, path) — the new destination of a link that names nothing
  # where it stands, or "" (the link is listed as broken unless it resolves).
  # A link to a retired file, or a placeholder outside a template, becomes its text:
  # UNLINK then holds the reason.
  function rebased(f, written, path, ln, rtok,   abs, cur, src, old, nt, c, anchor) {
    UNLINK = ""
    abs = (substr(path, 1, 1) == "/")
    cur = normpath(abs ? ROOT "/" substr(path, 2) : join_path(dir_of(f), path))
    if (present(cur)) return ""
    if (!abs) {
      src = (f in BACK) ? BACK[f] : f
      old = normpath(join_path(dir_of(src), path)); nt = ""
      # A placeholder in a template names no file: it takes the layout, and is not checked.
      if (is_template(f) && placeholder(path)) {
        if ((c = layered(old)) == "" || (c = angle(relpath(c, dir_of(f)))) == written) return ""
        st["rebased"]++; return c
      }
      if ((old in REN) && placed(REN[old]) && present(REN[old])) nt = REN[old]
      else if ((c = layered(old)) != "" && (c = nearest(c)) != "") nt = c
      else if (old != cur && placed(old) && present(old)) nt = old
      else if ((old in DMAP) && !(old in DCLASH) && placed(DMAP[old]) && present(DMAP[old])) nt = DMAP[old]
      if (nt != "") {
        anchor = (match(written, /[#?]/)) ? substr(written, RSTART) : ""
        st["rebased"]++
        return angle(relpath(nt, dir_of(f)) anchor)
      }
      if (retired(old)) UNLINK = "retired"
    }
    if (UNLINK == "" && placeholder(written) && !is_template(f)) UNLINK = "placeholder"
    if (UNLINK != "") { st["unlinked"]++; return "" }
    # A template is not checked (D2): its placeholders name nothing yet.
    if (is_template(f)) return ""
    st["broken"]++
    printf "broken\t%s/%s\t%d\t%s\n", KB, f, ln, flat(rtok)
    return ""
  }
  # The index holds files outside the KB too; a KB link converts only to a KB file.
  function in_kb(p) {
    if (p == "" || index(p, KB "/") != 1) return ""
    p = substr(p, length(KB) + 2)
    return exists(p) ? p : ""
  }
  # raw is the target as the reader takes it: untrimmed, anchor included.
  function resolve(src, raw, target,   cand, seg, p) {
    if (index(target, "/")) {
      cand = normpath(join_path(dir_of((src in BACK) ? BACK[src] : src), target))
      if (cand !~ /\.md$/) cand = cand ".md"
      if ((cand in REN) && placed(REN[cand]) && exists(REN[cand])) { HOW = "moved-path"; return REN[cand] }
      if ((p = layered(cand)) != "" && exists(p)) { HOW = "moved-path"; return p }
      cand = normpath(join_path(dir_of(src), target))
      if (cand !~ /\.md$/) cand = cand ".md"
      if (placed(cand) && exists(cand)) { HOW = "path"; return cand }
    }
    if ((p = in_kb(wiki_resolve(raw))) != "" && placed(p)) { HOW = "id"; return p }
    seg = target; sub(/.*\//, "", seg); seg = tolower(seg); sub(/\.md$/, "", seg)
    if ((seg in STEM) && !(seg in STEMCLASH) && placed(STEM[seg]) && exists(STEM[seg])) { HOW = "moved-stem"; return STEM[seg] }
    return ""
  }
  # settle(src, target) — a wikilink no route resolves, settled without a person (D6).
  # An id that names an artifact type gets its draft: DRAFT is its path, recorded in
  # DRAFTS for the act run to create from the template. Anything else becomes its
  # text: DRAFT is "" and WHY says why.
  function settle(src, target,   t, c, n, s, m, f2, cand) {
    DRAFT = ""; WHY = ""; t = target
    if (placeholder(t)) { WHY = "placeholder"; return }
    cand = normpath(join_path(dir_of((src in BACK) ? BACK[src] : src), t))
    if (cand !~ /\.md$/) cand = cand ".md"
    if (retired(cand)) { WHY = "retired"; return }
    if (t ~ /^adr-[a-z0-9][a-z0-9-]*(\.rationale)?$/) {
      m = substr(t, 5); c = (m ~ /\.rationale$/); sub(/\.rationale$/, "", m)
      draft("adr", "01_spec/_adr/" m ".adr.md", m)
      draft("adr.rationale", "01_spec/_adr/" m ".adr.rationale.md", m)
      DRAFT = "01_spec/_adr/" m (c ? ".adr.rationale.md" : ".adr.md"); return
    }
    c = t; gsub(/::/, ".", c)
    if (c !~ /^[a-z0-9][a-z0-9_-]*(\.[a-z0-9][a-z0-9_-]*)+$/) { WHY = "no artifact type"; return }
    n = split(c, s, ".")
    if (n == 3 && exists("01_spec/_modules/" s[1] "/_domain/" s[2] "/" s[2] ".entity.md")) {
      DRAFT = "01_spec/_modules/" s[1] "/_domain/" s[2] "/" s[2] "." s[3] ".action.md"
      draft("action", DRAFT, s[1] "\t" s[2] "\t" s[3]); return
    }
    if (n != 2) { WHY = "no artifact type"; return }
    m = (("01_spec/_modules/" s[1]) in DSET); f2 = (("01_spec/_faces/" s[1]) in DSET)
    if (m && (index(t, "::") || !f2)) {
      DRAFT = "01_spec/_modules/" s[1] "/_domain/" s[2] "/" s[2] ".entity.md"
      draft("entity", DRAFT, s[1] "\t" s[2]); return
    }
    if (f2 && !index(t, "::") && !m) {
      DRAFT = "01_spec/_faces/" s[1] "/_screens/" s[2] ".screen.md"
      draft("screen", DRAFT, s[1] "\t" s[2]); return
    }
    WHY = (m && f2) ? "a module and a face share the name" : "no artifact type"
  }
  # One line per draft file, once, unless the file is already there.
  function draft(kind, p, ids) {
    if ((p in DRAFTED) || exists(p)) return
    DRAFTED[p] = 1; st["drafts"]++
    printf "%s\t%s\t%s\n", kind, p, ids > DRAFTS
  }
  function flat(s) { gsub(/[\t\n]/, " ", s); return s }
  function trim(s) { sub(/^[ \t\n\r]+/, "", s); sub(/[ \t\n\r]+$/, "", s); return s }
  # A destination with a space or a parenthesis goes in <…>, the CommonMark form.
  function angle(p) { return p ~ /[ ()]/ ? "<" p ">" : p }
  # A frontmatter link is a quoted YAML string (D3): inside quotes it is escaped for
  # them, and where it starts a value unquoted it gets double quotes of its own.
  function yaml(md, pre,   dq, sq, s) {
    s = pre; gsub(/\\./, "", s); dq = gsub(/"/, "", s) % 2; sq = gsub(/\047/, "", s) % 2
    if (sq) { gsub(/\047/, "\047\047", md); return md }
    if (!dq && pre !~ /(^|[:,[-])[ \t]*$/) return md
    s = ""; while (match(md, /[\\"]/)) { s = s substr(md, 1, RSTART - 1) "\\" substr(md, RSTART, 1); md = substr(md, RSTART + 1) }
    return dq ? s md : "\"" s md "\""
  }
  BEGIN {
    ROOT = relpath(ROOT_ABS, KB_ABS)
    while ((getline l < RENAMES) > 0) {
      split(l, a, "\t"); REN[a[1]] = a[2]; BACK[a[2]] = a[1]
      if (a[1] !~ /\.md$/) continue
      s = a[1]; sub(/.*\//, "", s); s = tolower(substr(s, 1, length(s) - 3))
      if ((s in STEM) && STEM[s] != a[2]) STEMCLASH[s] = 1
      STEM[s] = a[2]
    }
    # A directory whose moved files all went to one directory moved there.
    for (o in REN) {
      od = dir_of(o); nd = dir_of(REN[o])
      if (od == "") continue
      if ((od in DMAP) && DMAP[od] != nd) DCLASH[od] = 1
      DMAP[od] = nd
    }
    while ((getline l < ALLF) > 0) FSET[l] = 1
    while ((getline l < ALLD) > 0) DSET[l] = 1
    while ((getline l < INDEX) > 0) wiki_ix_add(l)
    while ((getline f < LIST) > 0) files[++nf] = f
    close(LIST)
    for (n = 1; n <= nf; n++) {
      f = files[n]; t = slurp(KB "/" f); wikilinks(t); st["code"] += NCODE
      out = ""; pos = 1; changed = 0
      for (w = 1; w <= NL; w++) {
        inner = LIN[w]; ln = LLN[w]; target = inner; alias = ""
        if ((p = index(inner, "|"))) {
          alias = substr(inner, p + 1)
          target = substr(inner, 1, p - ((p > 1 && substr(inner, p - 1, 1) == "\\") ? 2 : 1))
        }
        raw = target; target = trim(target); anchor = ""
        if ((p = index(target, "#"))) { anchor = substr(target, p); target = trim(substr(target, 1, p - 1)) }
        if (target == "" && anchor != "") { HOW = "path"; rel = "" }
        else if ((path = resolve(f, raw, target)) != "") rel = relpath(path, dir_of(f))
        else {
          settle(f, target)
          if (DRAFT != "") { HOW = "draft"; path = DRAFT; rel = relpath(path, dir_of(f)) }
          else {
            md = (alias != "") ? alias : target anchor
            if (LFM[w]) md = yaml(md, LPRE[w])
            out = out substr(t, pos, LS[w] - pos) md; pos = LE[w]; changed = 1
            st["unlinked"]++
            printf "unlinked\t%s/%s\t%d\t%s\t%s\t%s\n", KB, f, ln, flat("[[" inner "]]"), flat(md), WHY
            continue
          }
        }
        if (alias != "") text = alias
        else if (target == "") text = substr(anchor, 2)
        else { text = target; sub(/.*\//, "", text) }
        md = "[" text "](" angle(rel anchor) ")"
        if (LFM[w]) md = yaml(md, LPRE[w])
        out = out substr(t, pos, LS[w] - pos) md; pos = LE[w]; changed = 1
        st[HOW]++; if (HOW != "draft") st["converted"]++
        printf "%s\t%s/%s\t%d\t%s\t%s\t%s\n", (HOW == "draft" ? "draft" : "link"), KB, f, ln, HOW, flat("[[" inner "]]"), flat(md)
      }
      out = changed ? out substr(t, pos) : t
      if (changed) nchanged++
      out = rebase(f, out)
      if (out == t) continue
      printf "%s", out > (OUT "/" n); close(OUT "/" n)
      printf "%s\t%s\n", f, OUT "/" n > CHANGED
    }
    close(CHANGED); close(DRAFTS)
    printf "files\t%d\n", nchanged > STATS
    for (k in st) printf "%s\t%d\n", k, st[k] > STATS
  }' > "$PLAN"

awk -F'\t' -v kb="$KB" '{ print "drafted\t" kb "/" $2 "\t" $1 }' "$DRAFTS" >> "$PLAN"
tally() { awk -F'\t' -v k="$1" '$1 == k { print $2; f = 1 } END { if (!f) print 0 }' "$STATS"; }
converted="$(tally converted)"
{
  printf 'note\tmove record: %s (%s renames)\n' "$record" "$(wc -l < "$RENAMES" | tr -d ' ')"
  [ -n "$git_note" ] && printf 'note\t%s\n' "$git_note"
  [ -n "$uncommitted" ] && printf 'note\tthe act run refuses until the moves are committed: git lists %s uncommitted move(s), addition(s) or deletion(s)\n' "$(printf '%s\n' "$uncommitted" | wc -l | tr -d ' ')"
  printf 'note\tlinks: %s converted in %s file(s) (moved-path %s, path %s, id %s, moved-stem %s), %s draft link(s), %s new draft(s), %s in code left as written\n' \
    "$converted" "$(tally files)" "$(tally moved-path)" "$(tally path)" "$(tally id)" "$(tally moved-stem)" \
    "$(tally draft)" "$(tally drafts)" "$(tally code)"
  printf 'note\tMarkdown links: %s rebased through the move record, %s broken and left as written\n' \
    "$(tally rebased)" "$(tally broken)"
  printf 'note\tunlinked: %s link(s) became their text\n' "$(tally unlinked)"
} >> "$PLAN"

if [ "$DRY" -eq 1 ]; then
  cat "$PLAN"
  printf 'note\tdry run: nothing was written\n'
  exit 0
fi

while IFS="$(printf '\t')" read -r rel src; do
  cat "$src" > "$KB/$rel"
done < "$CHANGED"
# Every draft is on disk before any is filled, so an ADR and its rationale link each other.
while IFS="$(printf '\t')" read -r kind rel _; do
  mkdir -p "$(dirname "$KB/$rel")" && : > "$KB/$rel"
done < "$DRAFTS"
while IFS="$(printf '\t')" read -r kind rel a b c; do
  draft_file "$kind" "$KB/$rel" "$a" "$b" "$c"
done < "$DRAFTS"
if [ -s "$CHANGED" ] && [ -d "$SPEC" ]; then
  mkdir -p "$SPEC/_migration"
  cp "$PLAN" "$SPEC/_migration/links.tsv"
fi
cat "$PLAN"
exit 0
