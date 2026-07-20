#!/usr/bin/env bash
# setup.sh — bootstrap the openbims-video pipeline. Idempotent: safe to run
# multiple times; existing pieces are left alone.
#
# Steps:
#   1. Verify system binaries (node, ffmpeg, python3). Refuse to continue if missing.
#   2. Bootstrap the demo/ workspace by copying templates + assets from the skill.
#   3. Create the Kokoro Python venv at /tmp/kokoro-venv (override via $KOKORO_VENV).
#   4. npm install in demo/.
#   5. Install Playwright Chromium.
#
# Usage:
#   bash setup.sh                    # full bootstrap
#   bash setup.sh --skip-kokoro      # skip the Python venv (e.g. running on CI without TTS)
#   KOKORO_VENV=~/.kokoro bash setup.sh
#
# After this script exits, run `bash doctor.sh` to verify.

set -euo pipefail

SKIP_KOKORO=0
for arg in "$@"; do
  case "$arg" in
    --skip-kokoro) SKIP_KOKORO=1 ;;
  esac
done

# Path resolution: setup.sh ships inside the skill's templates/ folder. The
# demo workspace is the user's project at <repo>/demo/. The skill itself
# lives at <repo>/.claude/skills/openbims-video/.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"        # .claude/skills/openbims-video
REPO_ROOT="$(cd "$SKILL_DIR/../../.." && pwd)"   # repo root
DEMO_DIR="${OPENBIMS_DEMO_DIR:-$REPO_ROOT/demo}"
KOKORO_VENV="${KOKORO_VENV:-/tmp/kokoro-venv}"

bold() { printf "\033[1m%s\033[0m\n" "$1"; }
note() { printf "  · %s\n" "$1"; }
err()  { printf "  \033[31m✗\033[0m %s\n" "$1"; }
ok()   { printf "  \033[32m✓\033[0m %s\n" "$1"; }

require_bin() {
  if ! command -v "$1" >/dev/null 2>&1; then
    err "$1 not found — install it before continuing ($2)"
    exit 1
  fi
}

bold "1/5 · System binaries"
require_bin node    "https://nodejs.org/ (≥ 20.x)"
require_bin npm     "ships with Node.js"
require_bin ffmpeg  "brew install ffmpeg"
require_bin ffprobe "brew install ffmpeg"
if [ "$SKIP_KOKORO" -eq 0 ]; then
  require_bin python3 "brew install python@3.12"
fi
ok "all required binaries present"

bold "2/5 · Bootstrap demo/ workspace"
mkdir -p "$DEMO_DIR/modules" "$DEMO_DIR/assets/lato"
for f in package.json playwright.config.js parse-timing.mjs collect.sh _helpers.js tts.sh validate-tts.mjs doctor.sh setup.sh; do
  if [ ! -f "$DEMO_DIR/$f" ]; then
    cp "$SCRIPT_DIR/$f" "$DEMO_DIR/$f"
    ok "copied $f"
  else
    note "$f already present (kept)"
  fi
done
# Assets
if [ ! -f "$DEMO_DIR/assets/openbims-logo.svg" ]; then
  cp "$SKILL_DIR/assets/openbims-logo.svg" "$DEMO_DIR/assets/openbims-logo.svg"
  ok "copied openbims-logo.svg"
else
  note "openbims-logo.svg already present"
fi
if [ -f "$SKILL_DIR/assets/genomcore-logo.avif" ] && [ ! -f "$DEMO_DIR/assets/genomcore-logo.avif" ]; then
  cp "$SKILL_DIR/assets/genomcore-logo.avif" "$DEMO_DIR/assets/genomcore-logo.avif"
  ok "copied genomcore-logo.avif"
fi
for w in 300 400 700 900; do
  src="$SKILL_DIR/assets/lato/lato-latin-${w}-normal.woff2"
  dst="$DEMO_DIR/assets/lato/lato-latin-${w}-normal.woff2"
  if [ ! -f "$dst" ] && [ -f "$src" ]; then
    cp "$src" "$dst"
    ok "copied lato-${w}"
  fi
done

bold "3/5 · Kokoro Python venv"
if [ "$SKIP_KOKORO" -eq 1 ]; then
  note "skipped (--skip-kokoro)"
else
  if [ ! -x "$KOKORO_VENV/bin/python3" ]; then
    note "creating venv at $KOKORO_VENV"
    python3 -m venv "$KOKORO_VENV"
    ok "venv created"
  else
    note "venv already exists at $KOKORO_VENV"
  fi
  KOKORO_PIP="$KOKORO_VENV/bin/pip"
  if ! "$KOKORO_VENV/bin/python3" -c "import kokoro_onnx" >/dev/null 2>&1; then
    note "installing kokoro-onnx + soundfile (this downloads a few hundred MB the first time)"
    "$KOKORO_PIP" install --quiet --upgrade pip
    "$KOKORO_PIP" install --quiet kokoro-onnx soundfile
    ok "kokoro-onnx + soundfile installed"
  else
    ok "kokoro-onnx already installed"
  fi
fi

bold "4/5 · npm install in demo/"
( cd "$DEMO_DIR" && npm install --silent --no-audit --no-fund )
ok "node_modules ready"

bold "5/5 · Playwright Chromium"
( cd "$DEMO_DIR" && npx --yes playwright install chromium >/dev/null )
ok "chromium installed"

echo
bold "Done."
note "Next: bash $DEMO_DIR/doctor.sh   # verify"
note "Then: cd code/openbims-console && npm run dev   # start the console for recording"
note "Then: invoke /openbims_video all <module>"
