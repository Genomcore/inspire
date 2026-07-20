---
name: openbims-video
description: "Lifecycle of a module video: script → mockplay → record → tts → postproduction. Generates commercial-style narrative tours of OpenBIMS modules using Playwright + HyperFrames + Kokoro TTS. Use when producing a demo video for any core or satellite module."
---

# /openbims_video — Module Video Production

## Scope

Owns the **video pipeline** for any OpenBIMS module. Each command writes to
the gitignored workspace `demo/modules/{module}/`; only the skill itself,
its templates, and its assets live in the repo.

The output is a 1920×1080 @ 30fps MP4 narrating the module's commercial
value over a real Playwright recording of the prototype console.

## Invocation

- `/openbims_video doctor` — check that every dependency is installed (read-only)
- `/openbims_video setup` — bootstrap the workspace: copy templates + assets, create the Kokoro venv, `npm install`, install Playwright Chromium
- `/openbims_video script {module} [--lang en|es]` — turn PDDs into a narrative shooting script (default `en`)
- `/openbims_video mockplay {module}` — turn the script into per-submodule Playwright recipes (lang-agnostic — recipes drive the camera, not the voice)
- `/openbims_video record {module}` — generate the spec, run Playwright, collect clips + timing (lang-agnostic — same video clip serves both languages)
- `/openbims_video tts {module} [--lang en|es]` — synthesize narration audio per beat (Kokoro-82M via HyperFrames). Default voice: `af_sky` for `en`, `ef_dora` for `es`.
- `/openbims_video postproduction {module} [--lang en|es]` — compose the final MP4 with HyperFrames. Generates `clips/{module}.{lang}.mp4` so both languages can coexist.
- `/openbims_video all {module} [--lang en|es]` — run the five steps in sequence

`{module}` is a folder name under `spec/pdd/core/` or `spec/pdd/satellite/`
(e.g. `ai-agents`, `marketplace`, `genomcore-cloud`).

### Language flag

The `--lang` flag controls the **voice + caption + narration + intro/outro copy + on-screen pills**. The Playwright tour (UI capture) is the same English console for both languages — the surrounding video composition is what gets translated.

- `record` and `mockplay` are lang-agnostic: one camera tour reused for every language render.
- `script`, `tts`, `postproduction` produce per-language artifacts:
  - `script.{lang}.md` (or one bilingual `script.md` with `narration_en` / `narration_es` siblings)
  - `tts.{lang}.txt` + `clips/audio/{lang}/*.wav`
  - `index.{lang}.html` + render `renders/{module}.{lang}.mp4`
- Default `--lang` is `en` so existing single-language modules keep working.

---

## Subcommand: doctor

Read-only environment check. Prints OK / MISSING for each dependency the pipeline relies on; exits non-zero if anything is missing. Run this first whenever the pipeline misbehaves.

```bash
bash demo/doctor.sh
```

Checks:
- System binaries: `node`, `npm`, `npx`, `ffmpeg`, `ffprobe`, `python3`, `curl`.
- Kokoro venv at `$KOKORO_VENV` (default `/tmp/kokoro-venv`) — verifies `kokoro_onnx` + `soundfile` are importable.
- Demo workspace: `demo/modules/`, `package.json`, `playwright.config.js`, `parse-timing.mjs`, `collect.sh`, `_helpers.js`, `tts.sh`, `validate-tts.mjs`.
- Assets: `demo/assets/openbims-logo.svg`, four Lato `.woff2` weights, optional `genomcore-logo.avif`.
- `demo/node_modules/` with `@playwright/test` + `hyperframes`.
- Playwright Chromium in `~/Library/Caches/ms-playwright` (macOS) or `~/.cache/ms-playwright` (Linux), or `$PLAYWRIGHT_BROWSERS_PATH`.
- Info-only: console dev server at `$CONSOLE_URL` (default `http://localhost:5173`).

## Subcommand: setup

Idempotent bootstrap. Run once at install time, or any time `doctor` flags something missing.

```bash
bash demo/setup.sh                    # full bootstrap
bash demo/setup.sh --skip-kokoro      # skip the Python venv (CI without TTS)
KOKORO_VENV=~/.kokoro bash demo/setup.sh
```

Steps:
1. Verify required system binaries present (node, ffmpeg, python3). Refuses to continue if any are missing.
2. Copy templates + assets from `.claude/skills/openbims-video/{templates,assets}/` into `demo/` (existing files are kept untouched).
3. Create the Kokoro venv at `$KOKORO_VENV` and `pip install kokoro-onnx soundfile` (skipped with `--skip-kokoro`).
4. `cd demo && npm install`.
5. `npx playwright install chromium`.

After setup, run `bash demo/doctor.sh` to verify, then start the console (`cd code/openbims-console && npm run dev`) and invoke `/openbims_video all <module>`.

---

## Workspace layout

```
demo/                                  # gitignored at repo root
├── package.json                       # copied from templates/
├── playwright.config.js               # copied from templates/
├── hyperframes.config.js              # generated per module on render
├── parse-timing.mjs                   # copied from templates/
├── collect.sh                         # copied from templates/
├── tts.sh                             # copied from templates/ (used by `tts`)
├── validate-tts.mjs                   # copied from templates/ (overflow check)
├── .raw/                              # Playwright raw output (gitignored)
├── record.log                         # last `record` stdout (overwritten each run)
├── renders/{module}.mp4               # final output of `postproduction`
├── assets/                            # copied from skill assets/ on bootstrap
│   ├── openbims-logo.svg
│   └── lato/lato-latin-{300,400,700,900}-normal.woff2
└── modules/
    └── {module}/
        ├── script.md                  # output of `script` (captions + narrations)
        ├── mockplay/
        │   └── {submodule}.md         # output of `mockplay`, one file per submodule
        ├── spec.js                    # generated by `record`
        ├── tts.txt                    # generated by `tts` from script.md narrations
        ├── index.html                 # composition; generated by `postproduction`
        ├── hyperframes.config.js      # generated by `postproduction`
        └── clips/
            ├── {module}.webm
            ├── {module}.mp4
            ├── timing.json
            └── audio/
                ├── b01-{slug}.wav     # one .wav per beat, output of `tts`
                ├── b02-{slug}.wav
                └── ...
```

If `demo/` does not exist when a command runs, **bootstrap it first**:

1. Copy `templates/package.json`, `templates/playwright.config.js`,
   `templates/parse-timing.mjs`, `templates/collect.sh`, `templates/_helpers.js`,
   `templates/tts.sh`, `templates/validate-tts.mjs` into `demo/`.
2. Copy `assets/openbims-logo.svg` into `demo/assets/`.
3. Copy `assets/lato/*.woff2` into `demo/assets/lato/`.

For TTS, also ensure a Python venv with Kokoro is on PATH (one-time):

```bash
brew install python@3.12          # if missing
python3.12 -m venv /tmp/kokoro-venv
/tmp/kokoro-venv/bin/pip install kokoro-onnx soundfile
export PATH="/tmp/kokoro-venv/bin:$PATH"   # add to shell profile for persistence
```

`hyperframes tts` looks up `python3` on PATH and imports `kokoro-onnx`. First voice synthesis downloads ~27MB of voice data into HyperFrames cache.
4. `cd demo && npm install && npx playwright install chromium`.

The composition template references assets as `../../assets/openbims-logo.svg`
and `../../assets/lato/*.woff2` from `demo/modules/{module}/index.html` — these
paths only resolve if step 2 + 3 ran.

## Corporate style (used by every composition)

- **Logo**: `assets/openbims-logo.svg` (copied from `code/openbims-console/public/openbims-logo.svg`); persistent top-left bar visible in every scene including the tour.
- **Typography**: Lato. Local woff2 in `assets/lato/`. Available weights: 300/400/700/900.
  - Lato has **no official 500 or 600**. Map `Medium` → 400, `Semibold` → 700.
  - Document the mapping in any caption work and keep typographic hierarchy via 400 / 700 with size + tracking.
- **Palette**: teal `#14b8a6`, teal-soft `#2dd4bf`, violet `#8b5cf6`, ink `#e6f5f3`, ink-dim `#9fc4be`, bg-1 `#0b1f1d`, bg-2 `#0f2a27`. Light cards on dark gradient background.
- **Layout**: 1920×1080 stage. Scene 1 = title (5s), Scene 2 = tour video framed at 1760×810 (offset 80px left, 140px top) with caption strip (variable), Scene 3 = outro (5s).
- **Capture size = frame size**: Playwright records the prototype at **1760×810** so the clip drops into the composition's `stage-frame` 1:1 with no `object-fit: cover` cropping. If you change the stage-frame in `templates/index.html`, mirror the same dimensions in `templates/playwright.config.js` `VIDEO_WIDTH` / `VIDEO_HEIGHT`.

---

## Subcommand: script

Turn the module's PDDs into a commercial narrative shooting script. Accepts `--lang en|es` (default `en`).

### Language

- `--lang en` (default) → write `demo/modules/{module}/script.md` with English narrations, captions, lede, intro.
- `--lang es` → write `demo/modules/{module}/script.es.md` (sibling file). Module name in the H1 stays as `Audit Module` etc. — only narration / captions / lede / outro headline / pill labels translate. The Genomcore corp-bar tagline and outro footer stay in English.
- The Spanish narration MUST follow the same anti-implementation-tech rules as the English version (no `Restate`, `Kratos`, `Keto`, `V8`, `OpenTelemetry`, etc.). PDD-level vocabulary, feature-first.
- Spanish narration tends to run ~15–25% longer than English. Aim ~10 % shorter than the English equivalent so Kokoro `ef_dora` fits the same beat windows.

### Inputs

- `spec/pdd/core/{module}/_index.md` (or `spec/pdd/satellite/{module}.md`)
- Every submodule file in the module folder
- `manual/modules/{module}/` if it exists (use as plain-language reference)
- `code/openbims-console/src/App.jsx` (extract real route prefixes)

### Steps

1. Read the module index and list submodules.
2. **Spawn N parallel agents** — one per submodule, `subagent_type: general-purpose`. Each agent receives:
   - Path to its submodule PDD
   - Module tagline + sibling submodule names (so it can position itself in the story)
   - Prompt skeleton:
     - "You are writing a commercial demo script segment for OpenBIMS module **{module}**, submodule **{submodule}**. Read its PDD. Write 80–120 words covering: (1) hook that opens with the buyer's problem, (2) what the submodule actually is, (3) what it composes/binds, (4) why a hospital procurement officer would care, (5) a `**Proof**` line naming one concrete hero entity from mock data — *for the camera only*, never quoted in caption or narration.
       **Voice/caption rules (load-bearing)**: Mock data is visual support, not narrative substance. Captions use feature-level labels (`Catalog`, `Detail`, `Versioned`, `Hash Chain`) — never entity IDs (`evt-005`, `agt-variant-interp`). Narration explains the **feature** at PDD level — what the section IS / DOES — and MUST NOT cite mock IDs, mock metrics (`v47`, `99.2%`, `12,450/day`), or mock people. Re-read `templates/script.md` for the anti-patterns block before writing.
       Tone: technical but commercial; no marketing fluff; no buzzwords like 'revolutionize'. Output only the structured block from `templates/script.md`. Do not invent features that aren't in the PDD."
3. Aggregate the N submodule blocks plus a module-level Hero + Story arc + a **Module intro** block. The intro block is a single PDD-derived sentence (≤ 11 words, fits the 5s title-scene window) describing what the module IS at a system level. Personas thread the arc, but per-beat narration stays at feature level.
4. Suggest a duration per submodule = `screens × (5–10s)`. Aim for **30s–2min total**.
5. Draft a caption track (label + text) per beat, ≤80 chars per text line. Captions are feature-level chyrons.
6. Write `demo/modules/{module}/script.md` from `templates/script.md`.

### Output

`demo/modules/{module}/script.md` — single source of truth for the rest of the pipeline. The user is expected to read it and tweak copy before running `mockplay`.

---

## Subcommand: mockplay

Turn the script into per-submodule Playwright recipes. **Reads code, picks selectors, picks hero entities. Does not run anything.**

### Inputs

- `demo/modules/{module}/script.md` (must exist)
- `mock-data/tables/*.jsonl` (filter by tables relevant to the module — `agent*`, `prompt*`, `guardrail*` for ai-agents; `mkt_*` for marketplace; etc.)
- `code/openbims-console/src/modules/{module}/pages/*.jsx`
- `code/openbims-console/src/App.jsx` (route ↔ component map)
- For satellite modules, look at the matching repo if it exists; if not, mark the recipe as "uses prototype only" and stick to console routes.

### Steps

1. Parse `script.md`. Extract submodules + suggested screens + caption track.
2. Pick **hero entities**: per relevant table, pick the row with the most populated fields and the most clinically/commercially meaningful name. Verify FK refs resolve across tables.
3. **Spawn N parallel agents** — one per submodule. Each receives:
   - The script block for its submodule
   - Hero entity IDs/names
   - JSX page paths for that submodule's screens
   - The shared caption track times (so beats line up with copy)
   - Prompt skeleton:
     - "You are writing a Playwright shooting recipe for OpenBIMS module **{module}**, submodule **{submodule}**. Read the JSX page(s) at the given paths to find robust selectors (prefer `getByRole` + accessible name, then `:has-text(\"hero name\")`). Translate each suggested screen + caption into a sequence of beats. Each beat is one focused interaction (5–10s on screen). Output the YAML block from `templates/mockplay.md`. Total `duration_ms` should match the script's suggested duration ±10%. Use real route paths from App.jsx, not guesses."
4. Aggregate to `demo/modules/{module}/mockplay/{submodule}.md`. The user can edit before `record`.

### Output

One markdown file per submodule under `demo/modules/{module}/mockplay/`.

---

## Subcommand: record

Generate one Playwright spec that walks the whole module, run it, collect the clip and timing.

### Pre-conditions

- All `demo/modules/{module}/mockplay/*.md` exist.
- Console dev server is reachable: `curl -fs $CONSOLE_URL >/dev/null` where `CONSOLE_URL` defaults to `http://localhost:5173`. If unreachable, **stop and tell the user** to `cd code/openbims-console && npm run dev`.

### Steps

1. **Bootstrap** `demo/` if missing (see top of file).
2. Read every `mockplay/{submodule}.md` in script order.
3. Generate `demo/modules/{module}/spec.js`:
   - Start from `templates/playwright-spec.js` (already wires
     `page.on('console')` to forward `[BEAT]` lines to `record.log`).
   - Concatenate beat sequences in submodule order.
   - On every navigation, call `installHighlights(page)` so click ring +
     focus ring re-attach.
   - Before each beat, emit `await markBeat(page, '<beat-id>', '<submodule>');`.
   - Map each YAML `action` to:
     - `wait-for-table` → `await page.waitForSelector(selector); await beat(page, duration_ms);`
     - `focus`          → `await focusOn(page, locator, { holdMs: duration_ms - 200 }); await clearFocus(page);`
     - `click`          → `await moveAndClick(page, locator); await page.waitForLoadState('networkidle'); await beat(page, duration_ms);`
     - `click-tab`      → **prefer URL-based pivot**: `await nav(page, url + '?<searchParam>=<id>');` — the project's `TabStrip` uses `<button>` (no `role="tab"`) and syncs with `searchParam`. `getByRole('tab', ...)` will hang. Read the page's JSX to find `searchParam` (`tab` for module detail / Models page; `type` for Skills catalog) and the `id` for each tab.
     - `scroll`         → `await smoothScroll(page, delta_y); await beat(page, duration_ms);`
     - `type`           → `await typeSlow(page, locator, text); await beat(page, duration_ms);`
     - `wait`           → `await beat(page, duration_ms);`
4. Run:
   ```bash
   cd demo
   CONSOLE_URL=$CONSOLE_URL npx playwright test modules/{module}/spec.js \
     --reporter=list 2>&1 | tee record.log
   ```
5. Run `bash collect.sh`. This:
   - Copies the latest `.webm` from `.raw/` to `modules/{module}/clips/{module}.webm`
   - Converts to MP4 (libx264, yuv420p, 30fps, **`-g 30 -keyint_min 30`** for
     dense keyframes — sparse keyframes from Playwright's webm cause
     freeze-on-seek inside HyperFrames) if ffmpeg is present
   - Generates `clips/timing.json` from `record.log` `[BEAT]` markers
     using `parse-timing.mjs`. The parser anchors beats by walking back
     from `clip_duration - tail_pad` (the wall-clock between the last
     `markBeat` and end-of-recording). `tail_pad` defaults to **5800ms**
     to match the generated spec's last-beat tail (`beat(5000) +
     beat(800)`); recipes whose last beat ends differently must export
     `TAIL_PAD_MS` before invoking `collect.sh`. Wrong `tail_pad` shifts
     every beat by the same delta and silently desyncs captions /
     narration — if `validate-tts` reports a 0.5s window on the last
     beat, the tail is mis-measured, not the narration.
6. Probe the MP4 duration with `ffprobe`. Report duration + beat count to the user.
7. Extract 3–6 frames at evenly spaced points with `ffmpeg -vf fps=1/N` for a quick sanity check; show them in the response.

### Failure handling

- If a route 404s mid-recording, do **not** retry blindly. Report: which beat, which selector, the suspected cause (prototype changed? mock entity renamed?). The user fixes mockplay or prototype, then re-runs `record`.

---

## Subcommand: tts

Generate narration audio per beat using HyperFrames' built-in Kokoro-82M model. Validate each WAV fits its beat window. Inserts the narration tracks into the composition.

### Language

Accepts `--lang en|es` (default `en`). Picks the voice + source script + output path:

| Flag        | Voice     | Source script               | Audio output dir              |
|-------------|-----------|-----------------------------|-------------------------------|
| `--lang en` | `af_sky`  | `script.md` (or `script.en.md`) → `tts.en.txt` | `clips/audio/en/*.wav` |
| `--lang es` | `ef_dora` | `script.es.md` → `tts.es.txt` | `clips/audio/es/*.wav` |

`tts.sh <module> <lang>` and `validate-tts.mjs --module <name> --lang <lang>` both honour the flag. Override the voice via `OPENBIMS_TTS_VOICE`.

### Pre-conditions

- `demo/modules/{module}/script.md` (or `script.{lang}.md`) has `narration:` strings under each caption, in the chosen language.
- `demo/modules/{module}/clips/timing.json` exists (from `record`) — the same timing serves every language since the camera tour is lang-agnostic.
- Python venv with `kokoro-onnx + soundfile` is on PATH (see Bootstrap). `ef_dora` is bundled with Kokoro-82M; first synthesis downloads ~27MB of ES voice data.

### Steps

1. Read `script.{lang}.md` (falling back to `script.md` for legacy `--lang en`). For each beat, extract the `narration:` string and pair it with a stable `<beat-id>` (use `b{NN}-{slug}` so playback order is obvious in `clips/audio/` listings).
   - **First beat is always `b00-intro`** — sourced from the `## Module intro` block (the 5-second title-scene narration). Map it with `# map: b00-intro=intro title` (synthetic beat; `validate-tts.mjs` treats it as fixed-window 5s).
   - Remaining beats follow submodule order.
2. Write `demo/modules/{module}/tts.{lang}.txt`. One line per beat, format: `<beat-id>|<narration text>`. Lines starting with `#` are comments. Optionally include a mapping comment `# map: <beat-id>=<timing-id> <submodule>` so `validate-tts.mjs` can join audio IDs to `timing.json` beats when their names diverge.
3. Run `bash demo/tts.sh {module} {lang}`. The script picks the voice from the lang flag (`af_sky` for `en`, `ef_dora` for `es`) — override via `OPENBIMS_TTS_VOICE` — and writes each WAV to `clips/audio/{lang}/<beat-id>.wav`.
4. Run `node demo/validate-tts.mjs --module {module} --lang {lang}`. The validator prints a table (`t / dur / win / head / status`) and exits non-zero on any overflow.
5. **Auto-shorten on overflow** (default policy — do NOT pause for user input). For each beat with `head < 0`:
   1. Spawn a subagent (`general-purpose`) with: original narration, target window in seconds, and overflow magnitude. Instruct: *"Trim N words while keeping all proper nouns, IDs, and key technical terms. Drop adjectives, hedging, redundant clauses. Output only the new sentence, no preamble."*
   2. Update the corresponding line in `tts.txt` with the trimmed text.
   3. Re-run `npx hyperframes tts` for that single beat only.
   4. Re-run validate. Loop up to **3 retries per beat** (each pass should reduce duration by ~15%).
   5. If still overflow after 3 retries, fall back to `OPENBIMS_TTS_SPEED=1.10` for that beat. Only then report to the user (rare).
6. Report total overflows fixed + final headroom table.

### Voice config

- Default: `af_sky` (American female, light timbre).
- Other available voices: `af_heart`, `af_nova`, `am_adam`, `am_michael`, `bf_emma`, `bf_isabella`, `bm_george`, plus non-English options. List with `npx hyperframes tts --list`.
- Speed multiplier: `OPENBIMS_TTS_SPEED=1.1` if narration regularly overflows by a small margin and shortening hurts copy.

### Output

- `clips/audio/*.wav` — one WAV per beat, ~kokoro 16kHz/24kHz.
- `tts.txt` — kept around so re-running `tts` only re-synthesizes lines whose text changed (TODO in current `tts.sh`: regenerate all; future iteration to diff).

---

## Subcommand: postproduction

Compose the final MP4 from the clip + timing + script.

### Pre-conditions

- `demo/modules/{module}/clips/{module}.mp4` and `clips/timing.json` exist.
- `demo/modules/{module}/script.md` exists (caption copy comes from here).

### Steps

1. Read `script.md` (caption track), `clips/timing.json` (real beat timestamps), and `clips/{module}.mp4` duration.
2. Generate `demo/modules/{module}/index.{lang}.html` from `templates/index.html`:
   - Replace `{{MODULE}}` (slug, e.g. `runtime`) and `{{MODULE_NAME}}` (Title Case, e.g. `Runtime` — H1 renders `{{MODULE_NAME}} Module` in EN, `Módulo {{MODULE_NAME}}` in ES).
   - **Do NOT marketize the H1.** No teasers, no accent splits, no tagline-as-title. Just `{Module Name} Module` (EN) / `Módulo {Module Name}` (ES).
   - `{{HERO_LEDE}}` is a short PDD-derived teaser (≤ 90 chars, ~10–15 words) describing what the module does at user-facing level, in the chosen language. Same anti-implementation-tech rules as narration — never name internal infra.
   - The "Module Tour" eyebrow translates to `Tour del Módulo` in ES; pills translate to lowercase Spanish nouns when the submodule name has a natural translation, otherwise keep the English slug (e.g. `engine` → `motor`, `images` → `imágenes`, `functions` → `funciones`, `workflows` → stays `workflows`).
   - **Pills**: emit ONE `<div class="pill">{name}</div>` per submodule into `{{PILLS_HTML}}`, in playback order. The last pill carries the `violet` modifier (`<div class="pill violet">{last}</div>`); the rest are teal. Never group submodules into shared pills.
   - **Outro headline**: `{{OUTRO_HEADLINE_LINE_1}}` + `{{OUTRO_HEADLINE_LINE_2}}` — a two-line module-specific closing thought (the second line renders teal). The footer is fixed by the template (`A Genomcore Project — https://genomcore.com`) and stays English in both renders; do not hand-edit it.
   - Corp-bar tagline (`Open Biomedical Information Management System — a trusted framework for AI-enabled, agentic healthcare`) stays English in both renders — it's a fixed Genomcore lockup, not module copy.
   - Replace `{{TOUR_DURATION}}` with the probed tour-video duration.
   - Replace `{{OUTRO_START}}` with `5 + TOUR_DURATION`.
   - Replace `{{CAPTION_TRACK_JSON}}` with a JS array `[{ t, sub, label, text }, ...]` built by joining script captions with `timing.json`'s real `t` values, in the chosen language. The intro narration covers the title scene and is NOT a caption (caption strip only appears during the tour scene).
   - **Audio tracks**:
     - The first audio is ALWAYS `b00-intro` at composition-absolute `data-start="0"` covering the title scene (already present in the template above `{{AUDIO_TRACKS_HTML}}`).
     - Emit one `<audio id="aud-{beat-id}" src="clips/audio/{lang}/{beat-id}.wav" data-start="{5 + beat.t}" preload="auto"></audio>` per submodule beat into `{{AUDIO_TRACKS_HTML}}`. Every `<audio>` MUST have an `id` or HyperFrames silently drops it from the render.
3. Generate `demo/modules/{module}/hyperframes.{lang}.config.js` from the template (composition path points at `./index.{lang}.html`, output at `../../renders/{module}.{lang}.mp4`).
4. Verify the logo path resolves: `index.{lang}.html` references `../../assets/openbims-logo.svg` and `../../assets/lato/*.woff2`. Both should be readable from inside `modules/{module}/`.
5. **Render via index.html swap** — HyperFrames auto-discovers `./index.html` in the project dir and ignores the `composition` config field. Swap `index.html` → `index.{lang}.html` for the render, then restore:
   ```bash
   cd demo/modules/{module}
   # Snapshot whatever is currently at index.html
   if [ -f index.html ] && [ ! -f index.html.bak ]; then mv index.html index.html.bak; fi
   cp index.{lang}.html index.html
   cp hyperframes.{lang}.config.js hyperframes.config.js   # composition: './index.html' is fine
   npx hyperframes lint
   npx hyperframes render
   # Restore — and rename the timestamped output to the lang-suffixed one
   LATEST=$(ls -t renders/{module}_*.mp4 | head -1)
   mv "$LATEST" "renders/{module}.{lang}.mp4"
   if [ -f index.html.bak ]; then mv index.html.bak index.html; fi
   ```
6. Report: output path (`demo/modules/{module}/renders/{module}.{lang}.mp4`), duration, file size. Extract one screenshot per scene (title / mid-tour / outro) as proof.

### Calibration

If any caption looks misaligned after render, the cause is almost always
that `timing.json` differs from `script.md`'s assumptions. Re-run
`postproduction` after editing the script — do not edit `index.html`
by hand.

---

## Subcommand: all

Run `script` → `mockplay` → `record` → `tts` → `postproduction` in
sequence, stopping at the first failure. The `tts` step uses the default
auto-shorten policy on overflow (no user prompt). After each step,
briefly report what was generated and what to verify before continuing.
Skip a step if its
outputs already exist and `--force` is not passed (default behavior).

Accepts `--lang en|es` (default `en`). The flag is forwarded to `script`,
`tts`, and `postproduction`; `mockplay` and `record` are lang-agnostic and
run once per module regardless of language. To produce both languages,
run `all` once per language — the second run reuses the existing
`mockplay/`, `spec.js`, and `clips/{module}.{webm,mp4}` artifacts and
only adds the per-language `tts.{lang}.txt`, `clips/audio/{lang}/`,
`index.{lang}.html`, and `renders/{module}.{lang}.mp4`.

---

## Templates + assets

- `templates/script.md` — output structure for `script`
- `templates/mockplay.md` — output structure for `mockplay`
- `templates/playwright.config.js` — Playwright runtime config (1920×1080, video=on, 30fps)
- `templates/playwright-spec.js` — boilerplate for the generated spec
- `templates/_helpers.js` — shared Playwright helpers (`installHighlights`, `focusOn`, `moveAndClick`, `smoothScroll`, `typeSlow`, `beat`, `markBeat`)
- `templates/package.json` — minimal demo deps (`@playwright/test`)
- `templates/collect.sh` — webm→mp4 + timing extraction
- `templates/parse-timing.mjs` — converts `[BEAT]` log lines into `clips/timing.json`
- `templates/index.html` — HyperFrames composition (logo + Lato + caption strip)
- `templates/hyperframes.config.js` — render config
- `assets/openbims-logo.svg` — corporate logo
- `assets/lato/lato-latin-{300,400,700,900}-normal.woff2` — Lato weights

When you change a template, create a tracker ticket via `/openbims_workspace task create "..." --epic tooling` so
future runs of completed modules know they may want a re-render.

## Constraints

- **Never** edit `code/*/public/data/` to make a recording work — fix the recipe or the mock-data source.
- **Never** invent features in the script that aren't in the PDD.
- **Never** check `demo/` into git (root `.gitignore` excludes it).
- **Never** run `record` without confirming the console dev server is up.
- **Always** treat `script.md` as the editable source of truth for narrative; everything downstream regenerates from it.
- **Always** parallelize the per-submodule agents in `script` and `mockplay`. The whole point is to keep wall-clock proportional to the module's biggest submodule, not to the count.
