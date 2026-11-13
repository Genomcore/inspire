#!/usr/bin/env bash
# The skills tree links to itself with relative Markdown links, and each resolves
# (adr-markdown-links D9). The tree has the same shape in this repository
# (plugin/base/skills) and in a project (.claude/skills), so a relative link holds in both.
# The KB skeleton (plugin/base/kb) follows the same rule: its links stay in the KB.
#
# Two rules, one assertion per file each:
#   - every relative Markdown link names a file that exists inside the tree;
#   - no backtick path names a file inside the tree: it is written as a link instead.
#
# Skipped, because the text is not a reference between runtime files:
#   - fenced blocks and inline code spans: examples of KB content or of a command;
#   - files under templates/: they are copied into the KB, where their links are KB
#     links (placeholders) and their deployed paths (`.claude/skills/...`) are correct;
#   - a backtick span that is a link's own text: [`x.md`](x.md) is the link, not a path.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
SKILLS="$HERE/../base/skills"
. "$HERE/lib/assert.sh"

# scan <file> — one line per candidate: `link<TAB>line<TAB>dest` or `span<TAB>line<TAB>text`.
scan() {
  awk '
    /^[ \t]*(```|~~~)/ { fence = !fence; next }
    fence { next }
    {
      rest = $0
      while (match(rest, /`[^`]+`/)) {
        pre = substr(rest, 1, RSTART - 1); span = substr(rest, RSTART + 1, RLENGTH - 2)
        post = substr(rest, RSTART + RLENGTH)
        if (span ~ /^[A-Za-z0-9_.\/-]+\.[A-Za-z]+$/ && !(substr(pre, length(pre), 1) == "[" && substr(post, 1, 2) == "](")) print "span\t" FNR "\t" span
        rest = post
      }
      bare = $0; gsub(/`[^`]*`/, "", bare)
      while (match(bare, /\]\([^)]*\)/)) {
        dest = substr(bare, RSTART + 2, RLENGTH - 3); bare = substr(bare, RSTART + RLENGTH)
        sub(/[ \t].*$/, "", dest); sub(/[#?].*$/, "", dest)
        if (dest == "" || dest ~ /^[A-Za-z][A-Za-z0-9+.-]*:/) continue
        print "link\t" FNR "\t" dest
      }
    }
  ' "$1"
}

# names_tree_file <root> <file> <span> — succeeds when the span, read from <file>, names a file in the tree.
names_tree_file() {
  local root="$1" file="$2" span="$3" t skill n
  printf '%s' "$span" | grep -Eq '^[A-Za-z0-9_./-]+\.[A-Za-z]+$' || return 1
  t="${span#.claude/skills/}"
  if [ "$t" != "$span" ]; then [ -f "$root/$t" ]; return; fi
  skill="${file#$root/}"; skill="$root/${skill%%/*}"
  if [ -f "$(dirname "$file")/$t" ] || [ -f "$skill/$t" ] || [ -f "$root/$t" ]; then return 0; fi
  # A bare file name counts when exactly one file in the tree carries it.
  case "$t" in */*|SKILL.md|README.md) return 1 ;; esac
  n="$(find "$root" -type f -name "$t" | wc -l | tr -d ' ')"
  [ "$n" = 1 ]
}

# violations <root> <file> <kind> — the violations of one rule in one file, as text.
violations() {
  local root="$1" file="$2" kind="$3" k ln arg p d rr
  rr="$(cd -P "$root" && pwd -P)"
  scan "$file" | while IFS=$'\t' read -r k ln arg; do
    [ "$k" = "$kind" ] || continue
    if [ "$kind" = link ]; then
      p="$(dirname "$file")/$arg"
      if [ ! -e "$p" ]; then echo "line $ln: $arg"; continue; fi
      # A link out of the tree resolves here and names nothing in a project (D9).
      if [ -d "$p" ]; then d="$(cd -P "$p" && pwd -P)"; else d="$(cd -P "$(dirname "$p")" && pwd -P)"; fi
      case "$d/" in "$rr"/*) ;; *) echo "line $ln: $arg leaves the tree" ;; esac
    elif names_tree_file "$root" "$file" "$arg"; then
      echo "line $ln: \`$arg\`"
    fi
  done
}

# A synthetic tree proves each rule can fail, so a green run is not vacuous.
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/_references" "$T/inspire-x"
: > "$T/_references/a.md"
printf '%s\n' \
  'See `_references/a.md`.' \
  '[b](missing.md) and [a](../_references/a.md)' \
  'In code: `[c](gone.md)` and [`_references/a.md`](../_references/a.md)' \
  '```' '`_references/a.md` [d](nope.md)' '```' > "$T/inspire-x/SKILL.md"
eq "premise: a backtick path to a tree file is reported" \
  "$(violations "$T" "$T/inspire-x/SKILL.md" span)" 'line 1: `_references/a.md`'
eq "premise: a broken link is reported, a resolving one is not" \
  "$(violations "$T" "$T/inspire-x/SKILL.md" link)" 'line 2: missing.md'
mkdir -p "$T/outer/skills/inspire-y" "$T/outer/bin"
: > "$T/outer/bin/review.sh"
printf '%s\n' '[review](../../bin/review.sh) and [tree](..)' > "$T/outer/skills/inspire-y/SKILL.md"
eq "premise: a link that leaves the tree is reported, though its file exists" \
  "$(violations "$T/outer/skills" "$T/outer/skills/inspire-y/SKILL.md" link)" 'line 1: ../../bin/review.sh leaves the tree'

premise "the skills tree exists" "[ -d '$SKILLS/_references' ]"
n=0
while IFS= read -r f; do
  n=$((n + 1))
  rel="${f#$SKILLS/}"
  case "$rel" in */templates/*) continue ;; esac
  out="$(violations "$SKILLS" "$f" link)"
  [ -z "$out" ] && ok "links resolve: $rel" || bad "links resolve: $rel ($out)"
  out="$(violations "$SKILLS" "$f" span)"
  [ -z "$out" ] && ok "no backtick path to a tree file: $rel" || bad "no backtick path to a tree file: $rel ($out)"
done < <(find "$SKILLS" -type f -name '*.md' | LC_ALL=C sort)
premise "the scan covered the tree" "[ $n -gt 100 ]"

# The KB skeleton names product roots and runtime directories in code spans and links
# only within the KB. Init seeds design-system.md from theme.md, so the copy holds it.
KB="$T/kb"; cp -R "$HERE/../base/kb" "$KB"
cp "$KB/01_spec/_design-system/theme.md" "$KB/01_spec/_design-system/design-system.md"
n=0
while IFS= read -r f; do
  n=$((n + 1)); rel="${f#$KB/}"
  out="$(violations "$KB" "$f" link)"
  [ -z "$out" ] && ok "seed links stay in the KB: $rel" || bad "seed links stay in the KB: $rel ($out)"
done < <(find "$KB" -type f -name '*.md' ! -name '*.template.md' ! -path "$KB/01_spec/_design-system/design-system.md" | LC_ALL=C sort)
premise "the scan covered the skeleton" "[ $n -gt 20 ]"

summary
