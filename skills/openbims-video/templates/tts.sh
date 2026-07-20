#!/usr/bin/env bash
# tts.sh — generate TTS narration audio per beat from a YAML-ish list.
#
# Reads modules/{module}/tts.{lang}.txt — one line per beat, format:
#   <beat-id>|<narration text>
# Generates modules/{module}/clips/audio/{lang}/<beat-id>.wav using HyperFrames'
# bundled Kokoro-82M model. Voice + speed configurable via env.
#
# Default voice per language:
#   en → af_sky
#   es → ef_dora
# Override via OPENBIMS_TTS_VOICE.
#
# Backward compat: if `tts.txt` exists (legacy single-language), it's treated
# as the en source and writes to clips/audio/ (no lang subfolder).
#
# Requirements:
#   - Python venv with kokoro-onnx + soundfile on PATH (see README in skill).
#   - HyperFrames installed in the demo project (npx hyperframes available).
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE="${1:-}"
LANG_ARG="${2:-en}"
if [ -z "$MODULE" ]; then
  echo "Usage: bash tts.sh <module> [<lang>]   # lang defaults to en"
  exit 1
fi

# Default voice per language; OPENBIMS_TTS_VOICE wins if set.
case "$LANG_ARG" in
  en) DEFAULT_VOICE="af_sky" ;;
  es) DEFAULT_VOICE="ef_dora" ;;
  *)  DEFAULT_VOICE="af_sky" ;;
esac
VOICE="${OPENBIMS_TTS_VOICE:-$DEFAULT_VOICE}"
SPEED="${OPENBIMS_TTS_SPEED:-1.0}"

# Resolve input file + output dir.
LEGACY_INPUT="$DEMO_DIR/modules/$MODULE/tts.txt"
LANG_INPUT="$DEMO_DIR/modules/$MODULE/tts.${LANG_ARG}.txt"
if [ -f "$LANG_INPUT" ]; then
  INPUT="$LANG_INPUT"
  OUT="$DEMO_DIR/modules/$MODULE/clips/audio/$LANG_ARG"
elif [ -f "$LEGACY_INPUT" ] && [ "$LANG_ARG" = "en" ]; then
  INPUT="$LEGACY_INPUT"
  OUT="$DEMO_DIR/modules/$MODULE/clips/audio"
else
  echo "Missing $LANG_INPUT (or legacy $LEGACY_INPUT)"
  exit 1
fi

echo "lang=$LANG_ARG  voice=$VOICE  in=$INPUT  out=$OUT"
mkdir -p "$OUT"
cd "$DEMO_DIR"

while IFS='|' read -r id text; do
  [ -z "${id// }" ] && continue
  case "$id" in \#*) continue ;; esac
  printf "%s ... " "$id"
  npx hyperframes tts "$text" -o "$OUT/${id}.wav" -v "$VOICE" -s "$SPEED" < /dev/null 2>&1 \
    | grep -oE "Generated [0-9.]+s" | head -1
done < "$INPUT"

echo "Done. Audio in $OUT/"
echo "Validate timing: node $DEMO_DIR/validate-tts.mjs --module $MODULE --lang $LANG_ARG"
