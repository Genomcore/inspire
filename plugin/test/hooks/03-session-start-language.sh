#!/usr/bin/env bash
# session-start.sh and prose-style.sh read output_language from .inspire/config.json,
# then from project.md's frontmatter, where a project installed before 0.21.0 keeps it.
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
. "$HERE/lib/assert.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

project() {
  local p="$WORK/$1"
  mkdir -p "$p/.claude/inspire/hooks" "$p/.inspire/bin" "$p/inspire_kb/00_bootstrap" "$p/inspire_kb/01_spec"
  cp "$PLUGIN_ROOT/base/hooks/session-start.sh" "$p/.claude/inspire/hooks/"
  cp "$PLUGIN_ROOT/base/bin/_lib.sh" "$PLUGIN_ROOT/base/bin/prose-style.sh" "$p/.inspire/bin/"
  printf '%s\n' "$p"
}
language_of() {
  CLAUDE_PROJECT_DIR="$1" bash "$1/.claude/inspire/hooks/session-start.sh" </dev/null \
    | jq -r '.hookSpecificOutput.additionalContext' | sed -n 's/^INSPIRE output language — `output_language: \(.*\)`\.$/\1/p'
}
prose_note() { ( cd "$1" && bash .inspire/bin/prose-style.sh 2>&1 ); }
legacy() { printf -- '---\noutput_language: %s\n---\n# Project\n' "$2" > "$1/inspire_kb/00_bootstrap/project.md"; }

p="$(project neither)"
eq "no config and no project.md: English" "$(language_of "$p")" "en"

p="$(project legacy)"
legacy "$p" ca
eq  "a project without a config: project.md's language" "$(language_of "$p")" "ca"
has "prose-style reads it there too" "$(prose_note "$p")" "output_language: ca"

p="$(project config)"
legacy "$p" ca
printf '{"output_language": "es"}\n' > "$p/.inspire/config.json"
eq  "the config's language wins over project.md" "$(language_of "$p")" "es"
has "prose-style reads the config first" "$(prose_note "$p")" "output_language: es"

p="$(project english)"
legacy "$p" ca
printf '{"output_language": "en"}\n' > "$p/.inspire/config.json"
hasnt "an English config: prose-style skips nothing" "$(prose_note "$p")" "output_language:"

p="$(project broken)"
legacy "$p" ca
printf 'not json\n' > "$p/.inspire/config.json"
eq "a broken config reads as not declared" "$(language_of "$p")" "ca"

p="$(project no-key)"
printf '{"source_root": "."}\n' > "$p/.inspire/config.json"
eq "a config without the key: English" "$(language_of "$p")" "en"

# The validators find the code where the config says it is.
root_of() { ( cd "$1" && bash -c '. .inspire/bin/_lib.sh; printf "%s" "$SDD_SOURCE_ROOT"' ); }
eq "source_root: the config's value" "$(root_of "$p")" "."
printf -- '---\nsource_root: apps\n---\n' > "$p/inspire_kb/00_bootstrap/stack.md"
eq "source_root: the config wins over stack.md" "$(root_of "$p")" "."
rm "$p/.inspire/config.json"
eq "source_root: stack.md, for a project without a config" "$(root_of "$p")" "apps"
rm "$p/inspire_kb/00_bootstrap/stack.md"
eq "source_root: the default" "$(root_of "$p")" "source"
eq "source_root: the environment wins over all" "$(cd "$p" && SDD_SOURCE_ROOT=x bash -c '. .inspire/bin/_lib.sh; printf "%s" "$SDD_SOURCE_ROOT"')" "x"

summary
