#!/usr/bin/env bash
# session-start.sh injects the decision digest decisions.sh prints.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

project() {
  local p="$WORK/$1"
  mkdir -p "$p/.claude/inspire/hooks" "$p/.inspire/bin" "$p/inspire_kb/00_bootstrap"
  cp "$PLUGIN_ROOT/base/hooks/session-start.sh" "$p/.claude/inspire/hooks/"
  cp "$PLUGIN_ROOT/base/bin/_lib.sh" "$PLUGIN_ROOT/base/bin/decisions.sh" "$p/.inspire/bin/"
  chmod +x "$p/.claude/inspire/hooks/session-start.sh" "$p/.inspire/bin/decisions.sh"
  printf '%s\n' "$p"
}

context_of() {
  CLAUDE_PROJECT_DIR="$1" bash "$1/.claude/inspire/hooks/session-start.sh" </dev/null \
    | jq -r '.hookSpecificOutput.additionalContext'
}

p="$(project with-adr)"
mkdir -p "$p/inspire_kb/01_adr"
printf '# Session tokens are opaque\n\n**Status:** implemented\n\n## Decision\nSession tokens are opaque.\n' \
  > "$p/inspire_kb/01_adr/adr-auth-sessions.md"
ctx="$(cd / && context_of "$p")"
has "a live ADR reaches the session, from any working directory" "$ctx" "INSPIRE decisions — 1 live ADR(s)"
has "with its decision"                       "$ctx" "  Session tokens are opaque."
has "beside the rest of the context"            "$ctx" "INSPIRE output language"

p="$(project no-adr)"
ctx="$(context_of "$p")"
hasnt "no ADR: no digest"                     "$ctx" "INSPIRE decisions"
has   "and the rest of the context still arrives" "$ctx" "INSPIRE writing contract"

p="$(project no-script)"
rm "$p/.inspire/bin/decisions.sh"
mkdir -p "$p/inspire_kb/01_adr"
cp "$WORK/with-adr/inspire_kb/01_adr/adr-auth-sessions.md" "$p/inspire_kb/01_adr/"
ctx="$(context_of "$p")"
hasnt "an install without decisions.sh: no digest" "$ctx" "INSPIRE decisions"
has   "and the session still starts"          "$ctx" "INSPIRE output language"

p="$(project large)"
mkdir -p "$p/inspire_kb/01_adr"
long="$(printf 'Every request carries a correlation id that each service logs. %.0s' $(seq 1 12))"
for i in $(seq 1 12); do
  printf '# Decision %s\n\n**Status:** design\n\n## Decision\n%s\n' "$i" "$long" \
    > "$p/inspire_kb/01_adr/adr-rule-$i.md"
done
full="$(cd "$p" && .inspire/bin/decisions.sh)"
premise "the full digest is over the hook's budget" '[ "${#full}" -gt 6000 ]'
ctx="$(context_of "$p")"
has "past the budget: the index"              "$ctx" "Their full text is over this digest's budget"
digest="${ctx#*INSPIRE decisions}"
check "the digest the hook injects stays within 6,000 characters" '[ $(( ${#digest} + 17 )) -le 6000 ]'

summary
