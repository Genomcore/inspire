#!/usr/bin/env node
// parse-timing.mjs — turn Playwright stdout `[BEAT]` markers into timing.json.
// Each line looks like:  [BEAT] <beat-id> <submodule> <ms-since-epoch>
//
// Anchoring strategy: the Playwright recording starts at `page.goto`, but
// the first beat fires several seconds later (after networkidle + helper
// install + an initial wait). Anchoring at the first beat would push every
// caption that many seconds early on screen.
//
// Instead we infer the clip-time of the first beat from the bracketed
// sequence: the LAST beat is emitted at clip-time `clip_duration - tail_pad`,
// where `tail_pad` is the wall-clock between the last `markBeat` call and
// the end of the recording. Walking backwards by the wall-clock distance
// between first and last beat yields the clip-time of the first beat.
// Every subsequent beat is offset by that anchor.
//
// IMPORTANT: tail_pad MUST match the spec's last-beat trailing wait. The
// generated specs end with `markBeat(...); await beat(5000); await beat(800);`
// → 5800ms tail. If the spec's last beat uses a different pattern (e.g.
// `focusOn(holdMs: 3800)` followed by `beat(800)` → 4600ms), pass the
// matching `--tail-pad-ms` explicitly. Wrong tail_pad shifts every beat by
// the same delta, silently breaking caption / narration sync.

import { readFileSync } from 'node:fs';
import { execSync } from 'node:child_process';

function arg(name, dflt) {
  const idx = process.argv.indexOf(`--${name}`);
  if (idx === -1) return dflt;
  return process.argv[idx + 1];
}

const moduleName = arg('module');
const logPath = arg('log');
const videoPath = arg('video');
// Default 5800ms = beat(5000) + beat(800) — the trailing waits the generated
// spec emits after its last `markBeat`. Honors `TAIL_PAD_MS` env (passed by
// collect.sh) so a recipe with a different tail can override without editing
// the parser. CLI `--tail-pad-ms` still wins.
const tailPadMs = parseFloat(
  arg('tail-pad-ms', process.env.TAIL_PAD_MS || '5800')
);

if (!moduleName || !logPath) {
  console.error('Usage: parse-timing.mjs --module <name> --log <path> [--video <path>] [--tail-pad-ms 5800]');
  process.exit(1);
}

const log = readFileSync(logPath, 'utf8');
const re = /\[BEAT\]\s+(\S+)\s+(\S*)\s+([0-9.]+)/g;
const beats = [];
let m;
while ((m = re.exec(log)) !== null) {
  beats.push({ id: m[1], submodule: m[2] || '', ms: parseFloat(m[3]) });
}
if (beats.length === 0) {
  console.error('no [BEAT] markers found');
  process.exit(2);
}

// Probe video duration first; we anchor relative to it.
let durationS = null;
if (videoPath) {
  try {
    const probe = execSync(
      `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${videoPath}"`,
      { encoding: 'utf8' }
    );
    durationS = parseFloat(probe.trim());
  } catch {
    /* ffprobe missing; we'll fall back to first-beat anchor */
  }
}

let firstBeatClipMs;
if (durationS != null && beats.length >= 2) {
  // Anchor: video-end is at (duration - tail_pad) seconds in clip time.
  // first beat clip-time = (duration - tail_pad) - (lastBeatMs - firstBeatMs)/1000.
  const span = beats[beats.length - 1].ms - beats[0].ms;
  const lastClipS = durationS - tailPadMs / 1000;
  const firstClipS = lastClipS - span / 1000;
  firstBeatClipMs = beats[0].ms - firstClipS * 1000;
} else {
  // Fallback: anchor at first beat = t=0.
  firstBeatClipMs = beats[0].ms;
}

const out = {
  module: moduleName,
  duration_s: durationS,
  beats: beats.map((b) => ({
    id: b.id,
    submodule: b.submodule,
    t: +((b.ms - firstBeatClipMs) / 1000).toFixed(3),
  })),
};

process.stdout.write(JSON.stringify(out, null, 2));
