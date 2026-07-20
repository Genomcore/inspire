#!/usr/bin/env bash
# doctor.sh — check that every dependency the openbims-video pipeline relies
# on is present and reachable. Read-only: never installs, never downloads.
# Reports OK / MISSING per dependency, then exits 0 (all OK) or 1 (any missing).
#
# Usage: bash doctor.sh
#
# Use `setup.sh` to install whatever this script flags as MISSING.

set -uo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
KOKORO_VENV="${KOKORO_VENV:-/tmp/kokoro-venv}"
CONSOLE_URL="${CONSOLE_URL:-http://localhost:5173}"

bold()  { printf "\033[1m%s\033[0m" "$1"; }
green() { printf "\033[32m%s\033[0m" "$1"; }
red()   { printf "\033[31m%s\033[0m" "$1"; }
yel()   { printf "\033[33m%s\033[0m" "$1"; }

fails=0
ok()    { printf "  %s  %s\n"        "$(green '✓')" "$1"; }
warn()  { printf "  %s  %s — %s\n"   "$(yel  '⚠')" "$1" "$2"; }
fail()  { printf "  %s  %s — %s\n"   "$(red  '✗')" "$1" "$2"; fails=$((fails+1)); }

check_bin() {
  local name="$1" url="$2"
  if command -v "$name" >/dev/null 2>&1; then
    ok "$name ($(command -v "$name"))"
  else
    fail "$name" "missing — install via $url"
  fi
}

echo
echo "$(bold 'openbims-video · environment check')"
echo

echo "$(bold 'System binaries')"
check_bin node    "https://nodejs.org/ (≥ 20.x)"
check_bin npm     "ships with Node.js"
check_bin npx     "ships with Node.js"
check_bin ffmpeg  "brew install ffmpeg"
check_bin ffprobe "brew install ffmpeg"
check_bin python3 "brew install python@3.12"
check_bin curl    "preinstalled on macOS / linux"

echo
echo "$(bold 'Kokoro TTS venv')"
KOKORO_PY="$KOKORO_VENV/bin/python3"
if [ -x "$KOKORO_PY" ]; then
  ok "venv at $KOKORO_VENV"
  if "$KOKORO_PY" -c "import kokoro_onnx" >/dev/null 2>&1; then
    ok "kokoro-onnx importable"
  else
    fail "kokoro-onnx" "venv exists but module missing — re-run setup.sh"
  fi
  if "$KOKORO_PY" -c "import soundfile" >/dev/null 2>&1; then
    ok "soundfile importable"
  else
    fail "soundfile" "venv exists but module missing — re-run setup.sh"
  fi
else
  fail "kokoro venv" "missing at $KOKORO_VENV — run setup.sh"
fi

echo
echo "$(bold 'Demo workspace')"
if [ -d "$DEMO_DIR/modules" ]; then
  ok "demo/modules/ exists"
else
  fail "demo workspace" "modules/ missing — run setup.sh"
fi
for f in package.json playwright.config.js parse-timing.mjs collect.sh _helpers.js tts.sh validate-tts.mjs; do
  if [ -f "$DEMO_DIR/$f" ]; then
    ok "$f"
  else
    fail "$f" "missing — run setup.sh"
  fi
done

echo
echo "$(bold 'Assets')"
if [ -f "$DEMO_DIR/assets/openbims-logo.svg" ]; then
  ok "openbims-logo.svg"
else
  fail "openbims-logo.svg" "missing in demo/assets/ — run setup.sh"
fi
lato_count=$(ls "$DEMO_DIR/assets/lato"/*.woff2 2>/dev/null | wc -l | tr -d ' ')
if [ "$lato_count" -ge 4 ]; then
  ok "Lato woff2 weights ($lato_count files)"
else
  fail "Lato fonts" "expected 4 .woff2 in demo/assets/lato/, found $lato_count"
fi
if [ -f "$DEMO_DIR/assets/genomcore-logo.avif" ]; then
  ok "genomcore-logo.avif"
else
  warn "genomcore-logo.avif" "not present (composition will render without 'powered by' badge)"
fi

echo
echo "$(bold 'Node deps in demo/')"
if [ -d "$DEMO_DIR/node_modules" ]; then
  ok "demo/node_modules/"
  for pkg in @playwright/test hyperframes; do
    if [ -d "$DEMO_DIR/node_modules/$pkg" ]; then
      ok "$pkg installed"
    else
      fail "$pkg" "not in demo/node_modules — run: cd demo && npm install"
    fi
  done
else
  fail "demo/node_modules" "missing — run: cd demo && npm install"
fi

# Playwright browsers cache: ~/.cache/ms-playwright on Linux, ~/Library/Caches/ms-playwright on macOS.
echo
echo "$(bold 'Playwright Chromium')"
PW_CACHE="${PLAYWRIGHT_BROWSERS_PATH:-}"
if [ -z "$PW_CACHE" ]; then
  case "$(uname)" in
    Darwin) PW_CACHE="$HOME/Library/Caches/ms-playwright" ;;
    Linux)  PW_CACHE="$HOME/.cache/ms-playwright" ;;
    *)      PW_CACHE="$HOME/.cache/ms-playwright" ;;
  esac
fi
if ls "$PW_CACHE"/chromium-*/chrome-* >/dev/null 2>&1; then
  ok "Chromium in $PW_CACHE"
else
  fail "Playwright Chromium" "not in $PW_CACHE — run: cd demo && npx playwright install chromium"
fi

echo
echo "$(bold 'Console dev server (info)')"
if curl -fs --max-time 2 "$CONSOLE_URL" -o /dev/null 2>&1; then
  ok "$CONSOLE_URL reachable"
else
  warn "$CONSOLE_URL" "not reachable — start with: cd code/openbims-console && npm run dev"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "$(green 'All required dependencies present.')"
  exit 0
else
  echo "$(red "$fails dependency check(s) failed.") Run \`bash setup.sh\` to install the missing pieces."
  exit 1
fi
