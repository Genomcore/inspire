#!/usr/bin/env bash
# Report skills that are too big for an agent to load well. Maintainer tool: it reads,
# never writes, and ships no rule to a project.
#
#   skill-size.sh [path…]               # default: plugin/base/skills plugin/skills
#   skill-size.sh --sections SKILL.md   # each H2 section: line, lines, ~tokens, heading
#
# One line per finding, `ERROR|WARN <file>: <message>`; exit 1 when any ERROR.
#   ERROR no readable description            (frontmatter missing or not valid YAML)
#   ERROR description > 1024 chars           (rejected on upload; agentskills.io spec)
#   ERROR description + when_to_use > 1536   (cut from the skill listing Claude Code shows)
#   WARN  SKILL.md >= 500 lines              (Anthropic skill-authoring best practices)
#   WARN  SKILL.md body > 5000 tokens        (spec; after compaction Claude Code keeps only
#                                             the first 5000 tokens of each skill)
#   WARN  any other .md > 10000 tokens       (agent-ecosystem/skill-validator default)
# Characters are Unicode code points; tokens are estimated as chars/4, since there is
# no public Claude tokenizer.
set -uo pipefail
export LC_ALL=C.UTF-8
HERE="$(cd -P "$(dirname "$0")" && pwd -P)"
. "$HERE/../base/bin/_lib.sh" || { echo "skill-size.sh: cannot read the plugin library" >&2; exit 2; }

MAX_DESC=1024 MAX_LISTING=1536 MAX_LINES=500 MAX_BODY_TOKENS=5000 MAX_REF_TOKENS=10000

if [ "${1:-}" = --sections ]; then
  [ -f "${2:-}" ] || { echo "usage: skill-size.sh --sections <SKILL.md>" >&2; exit 2; }
  awk "$SDD_AWK_FENCE_FUNCS"'
    BEGIN { h = "(before the first ##, frontmatter included)"; start = 1 }
    NR == 1 && $0 == "---" { fm = 1 }
    fm { n += length($0) + 1; if (NR > 1 && $0 == "---") fm = 0; next }
    !sdd_fence($0) && !sdd_in_fence() && /^## / { out(NR); h = $0; start = NR; n = 0 }
    { n += length($0) + 1 }
    function out(end) { printf "%5d %5d ~%5d  %s\n", start, end - start, n / 4, h }
    END { out(NR + 1) }
  ' "$2"
  exit 0
fi

command -v yq >/dev/null || { echo "skill-size.sh: needs yq" >&2; exit 2; }
[ $# -gt 0 ] || set -- "${HERE%/scripts}/base/skills" "${HERE%/scripts}/skills"

for p in "$@"; do [ -e "$p" ] || { echo "skill-size.sh: no such path: $p" >&2; exit 2; }; done

errors=0
while IFS= read -r f; do
  d="$(sdd_fm_value "$f" .description)"; w="$(sdd_fm_value "$f" .when_to_use)"
  [ -n "$d" ] || { echo "ERROR $f: no description (frontmatter missing or not valid YAML)"; errors=1; }
  [ ${#d} -le $MAX_DESC ] || { echo "ERROR $f: description is ${#d} chars (max $MAX_DESC)"; errors=1; }
  [ $((${#d} + ${#w})) -le $MAX_LISTING ] || { echo "ERROR $f: description + when_to_use is $((${#d} + ${#w})) chars (max $MAX_LISTING)"; errors=1; }
  l=$(wc -l < "$f")
  [ "$l" -lt $MAX_LINES ] || echo "WARN $f: $((l)) lines (recommended < $MAX_LINES)"
  t=$(( $(awk "$SDD_AWK_FM_READER"'{ print }' "$f" | wc -m) / 4 ))
  [ "$t" -le $MAX_BODY_TOKENS ] || echo "WARN $f: body ~$t tokens (recommended <= $MAX_BODY_TOKENS)"
done < <(find "$@" -type f -name SKILL.md | LC_ALL=C sort)

find "$@" -type f -name '*.md' ! -name SKILL.md ! -path '*/templates/*' -exec wc -m {} + |
  awk -v max=$MAX_REF_TOKENS '{ t = int($1 / 4); f = $0; sub(/^ *[0-9]+ /, "", f) }
    f != "total" && t > max { print "WARN " f ": ~" t " tokens (recommended <= " max ")" }' |
  LC_ALL=C sort
exit $errors
