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

# 1. Copy the runtime into .claude/, one OWNED entry at a time. INSPIRE owns a
#    namespace, not the parent directory: it materializes exactly the entries it
#    ships — the inspire-* skills (+ the shared _references), the validators, and
#    the hooks — and replaces only those. Anything else you keep under
#    .claude/{skills,bin,hooks} (your own skills, hooks or scripts) is left
#    untouched. A wholesale `rm -rf "$DEST/$part"` would delete it — we never do
#    that. See docs/adr/0001-runtime-lifecycle-and-lessons.md (D2).
for part in skills bin hooks; do
  [ -d "$SRC/$part" ] || continue
  mkdir -p "$DEST/$part"
  copied=0
  for entry in "$SRC/$part"/*; do
    [ -e "$entry" ] || continue          # empty source dir → nothing to copy
    name="$(basename "$entry")"
    rm -rf "$DEST/$part/$name"           # replace ONLY this owned entry
    cp -R "$entry" "$DEST/$part/$name"
    copied=$((copied + 1))
  done
  echo "  · $SRC/$part → $DEST/$part ($copied owned entries; other files left as-is)"
done

# 2. Make the runtime's own scripts executable — derived from the source paths
#    under .inspire/, so ONLY the .sh files we just copied get +x. A foreign .sh
#    you keep in .claude/bin or .claude/hooks is never touched (same ownership
#    principle as step 1).
while IFS= read -r src_sh; do
  chmod +x "$DEST/${src_sh#"$SRC"/}" 2>/dev/null || true
done < <(find "$SRC/bin" "$SRC/hooks" -type f -name '*.sh' 2>/dev/null)

# 3. De-seed the TEMPLATE's own maintenance layer, then wire the runtime hooks
#    into .claude/settings.json.
#
#    The template repo carries hooks that maintain the template itself (e.g. the
#    release-identity guard that requires a manifest bump when .inspire/ changes).
#    Those are NOT part of the seeded runtime — a fork consumes the manifest via
#    .inspire.lock but never authors it — yet they are cloned along with everything
#    else, and step 1's ownership rule deliberately leaves foreign files in
#    .claude/hooks/ untouched. So remove them here, sentinel-checked on the marker
#    in their first line, exactly as step 6 removes the template's own README.
#    A project's own hooks never carry the marker and are never touched.
for maint in "$DEST"/hooks/template-*.sh; do
  [ -f "$maint" ] || continue
  if head -3 "$maint" | grep -q "INSPIRE-TEMPLATE-MAINTENANCE"; then
    rm -f "$maint"
    echo "  · removed template-maintenance hook $(basename "$maint") — not part of the seeded runtime"
  fi
done

#    Likewise the settings file that registers them. Sentinel is the reference to
#    a template-maintenance hook; a fork's own settings.json never mentions one,
#    so this can only ever match the template's. Removing it lets the wiring below
#    write the real runtime settings instead of reporting "already exists".
SETTINGS="$DEST/settings.json"
if [ -f "$SETTINGS" ] && grep -q "hooks/template-.*\.sh" "$SETTINGS"; then
  rm -f "$SETTINGS"
  echo "  · removed the template's own $SETTINGS — replacing it with the runtime's"
fi

#    Wire the runtime hooks (only if absent — never clobber a project's settings):
#    the git-time pre-commit / pre-pr guards, plus the SessionStart hook that
#    injects the project's output language every session.
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

# 5. Materialize the product-side folders at their CONFIGURED roots. Production code
#    lives at source_root, the horizontal prototype at prototype_root (declared in
#    00_bootstrap/stack.md frontmatter; defaults source/ + prototype/). These do NOT
#    ship in the template — they are created here from .inspire/templates/, seeded with
#    a guidance README. Brownfield roots are respected: `.` (the repo root already IS
#    the code) and `none` are skipped, so an existing project is never clobbered; an
#    existing folder is always left as-is. See
#    .inspire/skills/_references/product-roots.md.
STACK=".inspire_kb/00_bootstrap/stack.md"
read_root() {  # $1 = frontmatter key, $2 = default
  local v=""
  if [ -f "$STACK" ] && command -v yq >/dev/null 2>&1; then
    v="$(yq --front-matter=extract ".$1 // \"\"" "$STACK" 2>/dev/null || true)"
  fi
  if [ -n "$v" ] && [ "$v" != "null" ]; then printf '%s' "$v"; else printf '%s' "$2"; fi
}
SOURCE_ROOT="$(read_root source_root source)"
PROTOTYPE_ROOT="$(read_root prototype_root prototype)"

for pair in "prototype:$PROTOTYPE_ROOT" "source:$SOURCE_ROOT"; do
  concept="${pair%%:*}"; dir="${pair#*:}"
  TEMPLATE="$SRC/templates/$concept-README.md"
  case "$dir" in
    ""|.|none)
      echo "  · $concept root is '${dir:-unset}' — nothing to create (in place / disabled)" ;;
    *)
      if [ -d "$dir" ]; then
        echo "  · $dir/ already present — left as-is"
      elif [ -f "$TEMPLATE" ]; then
        mkdir -p "$dir"
        cp "$TEMPLATE" "$dir/README.md"
        echo "  · created $dir/ (seeded README from $TEMPLATE)"
      fi ;;
  esac
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

# 7. Freeze the runtime version into .inspire.lock (repo root). This is the fork's
#    provenance record — which INSPIRE release the runtime came from — written once at
#    install. It lives product-side, is read by the session-start hook and by
#    inspire-lesson (which stamps each 98_lessons node with the version it was
#    captured on), and is read by the upstream pull to know a fork's version. The fork
#    never contacts upstream — the read is always a pull from above.
MANIFEST="$SRC/manifest.json"
LOCK=".inspire.lock"
if [ -f "$MANIFEST" ] && command -v jq >/dev/null 2>&1; then
  VERSION="$(jq -r '.version // "unknown"' "$MANIFEST" 2>/dev/null || echo unknown)"
  RELEASED="$(jq -r '.released // "unknown"' "$MANIFEST" 2>/dev/null || echo unknown)"
  TEMPLATE_SHA="$(git rev-parse HEAD 2>/dev/null || echo unknown)"
  jq -n \
    --arg v "$VERSION" --arg r "$RELEASED" --arg sha "$TEMPLATE_SHA" \
    --arg ia "$(date +%Y-%m-%d)" \
    '{inspire_version: $v, released: $r, template_sha: $sha, installed_at: $ia}' \
    > "$LOCK"
  echo "  · froze runtime version $VERSION ($RELEASED) into $LOCK"
else
  echo "  ! manifest.json or jq missing — skipped writing $LOCK"
fi

echo "INSPIRE · done."
echo "  Guardrail runtime is live in $DEST/. The knowledge base stays at .inspire_kb/,"
echo "  the horizontal prototype at /prototype, and production code at /source."
echo "  Next: run /inspire_bootstrap init to configure the stack + theme and create"
echo "  the project's README."
