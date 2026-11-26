#!/usr/bin/env bash
# Report skills that are too big for an agent to load well. Maintainer tool: it reads,
# never writes, and ships no rule to a project.
#
#   skill-size.sh [path…]               # default: plugin/base/skills plugin/skills
#   skill-size.sh --sections SKILL.md   # each H2 section: line, lines, ~tokens, heading
#
# One line per finding, `ERROR|WARN <file>: <message>`; exit 1 when any ERROR.
#   ERROR description > 1024 chars           (rejected on upload; agentskills.io spec)
#   ERROR description + when_to_use > 1536   (cut from the skill listing Claude Code shows)
#   WARN  SKILL.md >= 500 lines              (Anthropic skill-authoring best practices)
#   WARN  SKILL.md body > 5000 tokens        (spec; after compaction Claude Code keeps only
#                                             the first 5000 tokens of each skill)
#   WARN  any other .md > 10000 tokens       (agent-ecosystem/skill-validator default)
# Characters are Unicode code points (wc -m); tokens are estimated as chars/4, since
# there is no public Claude tokenizer.
set -uo pipefail
export LC_ALL=C.UTF-8

MAX_DESC=1024 MAX_LISTING=1536 MAX_LINES=500 MAX_BODY_TOKENS=5000 MAX_REF_TOKENS=10000

body() { awk 'NR == 1 && /^---$/ { fm = 1; next } fm && /^---$/ { fm = 0; next } !fm' "$1"; }
chars() { printf %s "$1" | wc -m | tr -d ' '; }
fm() { yq --front-matter=extract "(.$2 // \"\")" "$1" 2>/dev/null; }

if [ "${1:-}" = --sections ]; then
  [ -f "${2:-}" ] || { echo "usage: skill-size.sh --sections <SKILL.md>" >&2; exit 2; }
  awk '
    BEGIN { h = "(before the first ##, frontmatter included)"; start = 1 }
    /^[ \t]*(```|~~~)/ { fence = !fence }
    !fence && /^## / { if (h) out(NR); h = $0; start = NR; n = 0 }
    h { n += length($0) + 1 }
    function out(end) { printf "%5d %5d ~%5d  %s\n", start, end - start, n / 4, h }
    END { if (h) out(NR + 1) }
  ' "$2"
  exit 0
fi

command -v yq >/dev/null || { echo "skill-size.sh: needs yq" >&2; exit 2; }
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
[ $# -gt 0 ] || set -- "$ROOT/plugin/base/skills" "$ROOT/plugin/skills"

errors=0
while IFS= read -r f; do
  if [ "$(basename "$f")" != SKILL.md ]; then
    t=$(( $(wc -m < "$f") / 4 ))
    [ "$t" -le $MAX_REF_TOKENS ] || echo "WARN $f: ~$t tokens (recommended <= $MAX_REF_TOKENS)"
    continue
  fi
  d=$(chars "$(fm "$f" description)"); w=$(chars "$(fm "$f" when_to_use)")
  [ "$d" -le $MAX_DESC ] || { echo "ERROR $f: description is $d chars (max $MAX_DESC)"; errors=1; }
  [ $((d + w)) -le $MAX_LISTING ] || { echo "ERROR $f: description + when_to_use is $((d + w)) chars (max $MAX_LISTING)"; errors=1; }
  l=$(wc -l < "$f" | tr -d ' ')
  [ "$l" -lt $MAX_LINES ] || echo "WARN $f: $l lines (recommended < $MAX_LINES)"
  t=$(( $(body "$f" | wc -m) / 4 ))
  [ "$t" -le $MAX_BODY_TOKENS ] || echo "WARN $f: body ~$t tokens (recommended <= $MAX_BODY_TOKENS)"
done < <(find "$@" -type f -name '*.md' ! -path '*/templates/*' | LC_ALL=C sort)
exit $errors
