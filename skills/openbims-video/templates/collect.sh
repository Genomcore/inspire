#!/usr/bin/env bash
# collect.sh — runs after Playwright records.
#   1. Pulls the latest .webm from .raw/<test>-* into modules/<module>/clips/
#   2. Converts to MP4 (H.264, yuv420p, 30fps, faststart) when ffmpeg present
#   3. Parses Playwright stdout log (record.log) for [BEAT] markers and
#      writes modules/<module>/clips/timing.json
#
# Env:
#   TAIL_PAD_MS — wall-clock between last `markBeat` and end of recording
#                 (default 5800ms = beat(5000) + beat(800), matching the
#                 generated spec's tail). Override per-module if the recipe
#                 uses a different last-beat trailing pattern.
set -euo pipefail

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
RAW_DIR="$DEMO_DIR/.raw"
MODULES_DIR="$DEMO_DIR/modules"
LOG="$DEMO_DIR/record.log"

if [ ! -d "$RAW_DIR" ]; then
  echo "No raw output at $RAW_DIR. Run 'npm run record' first."
  exit 1
fi

shopt -s nullglob
found_any=0
for spec in "$MODULES_DIR"/*/spec.js; do
  module="$(basename "$(dirname "$spec")")"
  out_dir="$MODULES_DIR/$module/clips"
  mkdir -p "$out_dir"

  spec_dir="$(ls -dt "$RAW_DIR/${module}-"*/ 2>/dev/null | head -n 1 || true)"
  if [ -z "$spec_dir" ]; then
    echo "skip ${module}: no raw dir"
    continue
  fi
  webm="$(ls -t "$spec_dir"*.webm 2>/dev/null | head -n 1 || true)"
  if [ -z "$webm" ]; then
    echo "skip ${module}: no .webm"
    continue
  fi

  cp "$webm" "$out_dir/${module}.webm"
  echo "✓ ${module}.webm"

  if command -v ffmpeg >/dev/null 2>&1; then
    # -g 30 -keyint_min 30 → keyframe every 1s. HyperFrames seeks the video
    # by composition time; sparse keyframes (Playwright's default ~8s) cause
    # frozen frames during seek.
    ffmpeg -y -loglevel error -i "$out_dir/${module}.webm" \
      -c:v libx264 -pix_fmt yuv420p -r 30 -g 30 -keyint_min 30 \
      -crf 17 -preset slow -tune film \
      -movflags +faststart \
      "$out_dir/${module}.mp4"
    echo "✓ ${module}.mp4"
  fi

  if [ -f "$LOG" ]; then
    TAIL_PAD_MS="${TAIL_PAD_MS:-}" node "$DEMO_DIR/parse-timing.mjs" \
      --module "$module" \
      --log "$LOG" \
      --video "$out_dir/${module}.mp4" \
      > "$out_dir/timing.json" || echo "  (timing parse failed; continuing)"
    echo "✓ ${module} timing.json"
  fi

  found_any=1
done

if [ "$found_any" -eq 0 ]; then
  echo "No clips collected."
  exit 1
fi

echo "Done."
