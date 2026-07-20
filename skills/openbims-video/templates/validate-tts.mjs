#!/usr/bin/env node
// validate-tts.mjs — verify each beat's narration WAV fits its window.
// Reads modules/{module}/clips/timing.json and modules/{module}/tts.txt
// (one line "<beat-id>|<text>", lines starting with # are comments and
// can also map a beat-id to a timing.json beat with `# map: <beat-id>=<timing-id>`).
//
// For each audio file, computes:
//   window = next_beat.t - this_beat.t
//   headroom = window - audio_duration
// Flags any beat with headroom < 0 (overflow) or < 0.3s (tight).
// Per the skill's "(a) flag pause" policy, exits non-zero on overflow.

import { readFileSync, existsSync } from 'node:fs';
import { execSync } from 'node:child_process';
import path from 'node:path';

function arg(name, dflt) {
  const idx = process.argv.indexOf(`--${name}`);
  if (idx === -1) return dflt;
  return process.argv[idx + 1];
}

const moduleName = arg('module');
const langArg = arg('lang', 'en');
const demoDir = path.resolve(path.dirname(new URL(import.meta.url).pathname), '.');
if (!moduleName) {
  console.error('Usage: validate-tts.mjs --module <name> [--lang en|es]');
  process.exit(1);
}

const modDir = path.join(demoDir, 'modules', moduleName);
const timingPath = path.join(modDir, 'clips', 'timing.json');

// Resolve tts source: prefer per-language file, fall back to legacy `tts.txt`
// when --lang en (single-language modules predate the bilingual layout).
const langTtsPath = path.join(modDir, `tts.${langArg}.txt`);
const legacyTtsPath = path.join(modDir, 'tts.txt');
let ttsTxtPath, audioDir;
if (existsSync(langTtsPath)) {
  ttsTxtPath = langTtsPath;
  audioDir = path.join(modDir, 'clips', 'audio', langArg);
} else if (langArg === 'en' && existsSync(legacyTtsPath)) {
  ttsTxtPath = legacyTtsPath;
  audioDir = path.join(modDir, 'clips', 'audio');
} else {
  console.error(`missing ${langTtsPath}`);
  process.exit(1);
}
if (!existsSync(timingPath)) { console.error(`missing ${timingPath}`); process.exit(1); }

const timing = JSON.parse(readFileSync(timingPath, 'utf8'));
const lines = readFileSync(ttsTxtPath, 'utf8').split('\n');

// Parse "# map: audio-id=beat-id submodule" lines for explicit mapping.
const map = {};
for (const ln of lines) {
  const m = ln.match(/^#\s*map:\s*(\S+)\s*=\s*(\S+)\s+(\S+)\s*$/);
  if (m) map[m[1]] = { beat: m[2], submodule: m[3] };
}
const audioIds = lines
  .filter((l) => l && !l.startsWith('#') && l.includes('|'))
  .map((l) => l.split('|', 1)[0].trim());

function findBeat(audioId) {
  if (map[audioId]) {
    const m = map[audioId];
    return timing.beats.find((b) => b.id === m.beat && b.submodule === m.submodule);
  }
  // Fallback: assume audioId equals timing beat id (works if you keep them aligned).
  return timing.beats.find((b) => b.id === audioId);
}

function dur(p) {
  const out = execSync(
    `ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "${p}"`,
    { encoding: 'utf8' }
  );
  return parseFloat(out.trim());
}

let overflow = 0, tight = 0;
console.log(`${'audio'.padEnd(22)} ${'t'.padStart(7)} ${'dur'.padStart(7)} ${'win'.padStart(7)} ${'head'.padStart(7)}  status`);
console.log('-'.repeat(70));

// b00-intro is the title-scene narration, fixed 5s window. The synthetic
// "intro" beat lives at composition-absolute t=0 with a hard 5s budget.
const INTRO_ID = 'b00-intro';
const INTRO_WINDOW_S = 5;

for (let i = 0; i < audioIds.length; i++) {
  const id = audioIds[i];
  if (id === INTRO_ID) {
    const wav = path.join(audioDir, `${id}.wav`);
    if (!existsSync(wav)) { console.log(`${id.padEnd(22)} missing ${wav}`); continue; }
    const d = dur(wav);
    const head = INTRO_WINDOW_S - d;
    let status = '✓';
    if (head < 0) { status = '✗ OVERFLOW'; overflow++; }
    else if (head < 0.3) { status = '⚠ tight'; tight++; }
    console.log(
      `${id.padEnd(22)} ${'0.00'.padStart(7)} ${d.toFixed(2).padStart(7)} ${INTRO_WINDOW_S.toFixed(2).padStart(7)} ${(head >= 0 ? '+' : '') + head.toFixed(2).padStart(6)}  ${status}`
    );
    continue;
  }

  const beat = findBeat(id);
  if (!beat) { console.log(`${id.padEnd(22)} no timing match`); continue; }

  // Skip b00-intro when looking for "next" so windows reference real beats.
  let nextIdx = i + 1;
  while (nextIdx < audioIds.length && audioIds[nextIdx] === INTRO_ID) nextIdx++;
  const next = nextIdx < audioIds.length ? findBeat(audioIds[nextIdx]) : null;
  const nextT = next ? next.t : timing.duration_s;
  const win = nextT - beat.t;

  const wav = path.join(audioDir, `${id}.wav`);
  if (!existsSync(wav)) { console.log(`${id.padEnd(22)} missing ${wav}`); continue; }

  const d = dur(wav);
  const head = win - d;
  let status = '✓';
  if (head < 0) { status = '✗ OVERFLOW'; overflow++; }
  else if (head < 0.3) { status = '⚠ tight'; tight++; }

  console.log(
    `${id.padEnd(22)} ${beat.t.toFixed(2).padStart(7)} ${d.toFixed(2).padStart(7)} ${win.toFixed(2).padStart(7)} ${(head >= 0 ? '+' : '') + head.toFixed(2).padStart(6)}  ${status}`
  );
}

if (overflow > 0) {
  console.error(`\n${overflow} OVERFLOW beat(s). Per skill policy (a): pause and shorten narration or relax recording pacing.`);
  process.exit(2);
}
if (tight > 0) {
  console.warn(`\n${tight} tight beat(s) (< 0.3s headroom). Acceptable but consider trimming.`);
}
