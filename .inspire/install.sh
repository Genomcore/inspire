#!/usr/bin/env bash
#
# .inspire/install.sh — instantiate the INSPIRE guardrail runtime into .claude/
#
# Run this ONCE after forking/cloning the template. It copies the guardrail
# runtime (skills, validators, hooks) from .inspire/ into .claude/ — where Claude
# Code discovers and executes it — makes the scripts executable, and wires the
# git-time hooks into .claude/settings.json.
#
# Why staged in .inspire/ and not directly in .claude/: keeping the runtime dormant
# in .inspire/ means Claude Code does NOT auto-load these skills while you develop
# the template itself. Instantiation (this script) is what makes them live.
#
# Idempotent: .inspire/ stays the versioned source of truth, so you can re-run this
# after pulling template updates to refresh .claude/.
#
# Prerequisites for the validators: bash 4+, yq (Mike Farah's v4), jq 1.6+.

set -euo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ROOT="$(cd -P "$SCRIPT_DIR/.." && pwd -P)"
cd "$ROOT"

SRC=".inspire"
DEST=".claude"

echo "INSPIRE · installing the guardrail runtime into $DEST/ …"
mkdir -p "$DEST"

# 1. Copy skills, bin, hooks into .claude/.
for part in skills bin hooks; do
  if [ -d "$SRC/$part" ]; then
    rm -rf "$DEST/$part"
    cp -R "$SRC/$part" "$DEST/$part"
    echo "  · $SRC/$part → $DEST/$part"
  fi
done

# 2. Make the validators and hooks executable.
chmod +x "$DEST"/bin/*.sh "$DEST"/bin/test/*.sh "$DEST"/hooks/*.sh 2>/dev/null || true

# 3. Wire the git-time hooks into .claude/settings.json (only if absent — never
#    clobber an existing settings file).
SETTINGS="$DEST/settings.json"
HOOKS_JSON='{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/pre-commit.sh" },
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/pre-pr.sh" }
        ]
      }
    ]
  }
}'

if [ ! -f "$SETTINGS" ]; then
  printf '%s\n' "$HOOKS_JSON" > "$SETTINGS"
  echo "  · wrote $SETTINGS with the pre-commit / pre-pr hooks"
else
  echo "  ! $SETTINGS already exists — not touching it. Merge these hooks yourself:"
  printf '%s\n' "$HOOKS_JSON" | sed 's/^/      /'
fi

# 4. Seed the live design system from the bootstrap theme template. The default
#    theme in 00_bootstrap/theme.md is copied to 05_screens/design-system.md,
#    which becomes the project's working design system (edit it later with
#    /inspire_screens design-system). Never clobber an existing one.
THEME=".inspire_kb/00_bootstrap/theme.md"
DESIGN_SYSTEM=".inspire_kb/05_screens/design-system.md"
if [ -f "$THEME" ] && [ ! -f "$DESIGN_SYSTEM" ]; then
  cp "$THEME" "$DESIGN_SYSTEM"
  echo "  · seeded $DESIGN_SYSTEM from $THEME"
elif [ -f "$DESIGN_SYSTEM" ]; then
  echo "  · $DESIGN_SYSTEM already present — left as-is"
fi

echo "INSPIRE · done."
echo "  Guardrail runtime is live in $DEST/. The knowledge base stays at .inspire_kb/,"
echo "  the horizontal prototype at /prototype, and production code at /source."
