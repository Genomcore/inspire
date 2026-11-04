#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd -P "$(dirname "$0")/.." && pwd -P)"
PLUGIN_ROOT="$HERE/.."
CONFIG_SKILL="$PLUGIN_ROOT/base/skills/inspire-config"
. "$HERE/lib/assert.sh"

flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
DERIVE="$(flat "$CONFIG_SKILL/references/derive.md")"
VALIDATE="$(flat "$CONFIG_SKILL/references/validate.md")"

has "derive: the ratchet check is written when .escape-hatches.json exists" \
  "$DERIVE" "When \`.escape-hatches.json\` exists, phase \`quality\` runs the ratchet"
has "derive: Q6 lists the commit hooks' commands" \
  "$DERIVE" "every command the commit hooks run that no check covers"
has "validate: a ratchet config with no ratchet check is an error" \
  "$VALIDATE" "\`.escape-hatches.json\` exists and no run check calls \`.inspire/bin/escape-hatch-ratchet.sh\` | error"

run_line="$(grep -E "^ *run: '\.inspire/bin/escape-hatch-ratchet\.sh'" "$CONFIG_SKILL/references/derive.md")"
premise "derive.md carries exactly one ratchet run line" "[ \"\$(printf '%s\n' \"\$run_line\" | grep -c .)\" = 1 ]"
command="$(printf '%s' "$run_line" | sed -E "s/^ *run: '(.*)'$/\1/")"

proj="$(mktemp -d)/proj"
mkdir -p "$proj/.inspire" "$proj/source/src"
cp -R "$PLUGIN_ROOT/base/bin" "$proj/.inspire/bin"
rm -rf "$proj/.inspire/bin/test"
chmod +x "$proj/.inspire/bin/"*.sh
cat > "$proj/.escape-hatches.json" <<'EOF'
{
  "scope": ["source/src"],
  "extensions": ["ts"],
  "patterns": [{ "id": "as-any", "regex": "as any", "ceiling": 0 }]
}
EOF

as_factory() { ( cd "$proj" && bash -c "$command" >/dev/null 2>&1 ); }

printf '%s\n' '// The guard narrows it: `as any` would hide the missing field.' \
  'export const n = (v: unknown): number => (typeof v === "number" ? v : 0);' \
  > "$proj/source/src/a.ts"
as_factory
eq "the check passes on code that only mentions a hatch" "$?" "0"

printf '%s\n' 'export const n = (v: unknown): number => v as any;' > "$proj/source/src/a.ts"
as_factory
eq "the check fails on a hatch over the ceiling" "$?" "1"

summary
