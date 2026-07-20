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

# 3. Wire the hooks into .claude/settings.json (only if absent — never clobber an
#    existing settings file): the git-time pre-commit / pre-pr guards, plus the
#    SessionStart hook that injects the project's output language every session.
SETTINGS="$DEST/settings.json"
HOOKS_JSON='{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.sh" }
        ]
      }
    ],
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
  echo "  · wrote $SETTINGS with the session-start + pre-commit / pre-pr hooks"
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

# 5. Materialize the product-side folders. These do NOT ship in the template repo
#    (they belong to the product you build, not to INSPIRE) — they are created here
#    from .inspire/templates/, seeded with a guidance README. Never clobber an
#    existing folder: a project's real prototype / source code is left untouched.
for part in prototype source; do
  TEMPLATE="$SRC/templates/$part-README.md"
  if [ -d "$part" ]; then
    echo "  · $part/ already present — left as-is"
  elif [ -f "$TEMPLATE" ]; then
    mkdir -p "$part"
    cp "$TEMPLATE" "$part/README.md"
    echo "  · created $part/ (seeded README from $TEMPLATE)"
  fi
done

# 6. Remove the template's own methodology README. Our README documents INSPIRE
#    the template — it is not the product's README. A project gets its own via
#    /inspire_bootstrap init (title, git remote, description). Sentinel-checked so
#    re-running this never deletes a project's own README.
README="README.md"
if [ -f "$README" ] && grep -q "A software engineering methodology for the agentic era" "$README"; then
  rm -f "$README"
  echo "  · removed the template README ($README) — create the project's own with /inspire_bootstrap init"
elif [ -f "$README" ]; then
  echo "  · $README is not the template's — left as-is"
fi

echo "INSPIRE · done."
echo "  Guardrail runtime is live in $DEST/. The knowledge base stays at .inspire_kb/,"
echo "  the horizontal prototype at /prototype, and production code at /source."
echo "  Next: run /inspire_bootstrap init to configure the stack + theme and create"
echo "  the project's README."
