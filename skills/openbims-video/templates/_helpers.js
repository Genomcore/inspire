// Playwright runtime helpers used by every generated spec.js.
// - Native cursor + click ring + focus ring (CSS injected per page).
// - Smooth scroll, slow type, beats.
// - `markBeat(id, submodule)` emits a console event the collector parses
//   into clips/timing.json so HyperFrames captions land on real timestamps.

const HIGHLIGHT_CSS = `
  @keyframes obims-click-pulse {
    0%   { transform: translate(-50%, -50%) scale(0.4); opacity: 0.9; }
    60%  { transform: translate(-50%, -50%) scale(1.6); opacity: 0.4; }
    100% { transform: translate(-50%, -50%) scale(2.2); opacity: 0; }
  }
  .__obims_click_ring__ {
    position: fixed;
    pointer-events: none;
    z-index: 2147483647;
    width: 56px;
    height: 56px;
    border-radius: 50%;
    border: 3px solid rgba(20, 184, 166, 0.95);
    box-shadow: 0 0 18px rgba(20, 184, 166, 0.55);
    animation: obims-click-pulse 650ms ease-out forwards;
  }
  .__obims_focus_ring__ {
    position: fixed;
    pointer-events: none;
    z-index: 2147483646;
    border: 3px solid rgba(20, 184, 166, 0.85);
    border-radius: 8px;
    box-shadow: 0 0 0 4px rgba(20, 184, 166, 0.18);
    transition: all 220ms ease-out;
  }
`;

export async function installHighlights(page) {
  await page.addStyleTag({ content: HIGHLIGHT_CSS });
  await page.evaluate(() => {
    if (window.__obimsHighlightsInstalled) return;
    window.__obimsHighlightsInstalled = true;
    document.addEventListener('click', (e) => {
      const ring = document.createElement('div');
      ring.className = '__obims_click_ring__';
      ring.style.left = `${e.clientX}px`;
      ring.style.top = `${e.clientY}px`;
      document.body.appendChild(ring);
      setTimeout(() => ring.remove(), 700);
    }, true);
  });
}

export async function focusOn(page, locator, { padding = 6, holdMs = 0 } = {}) {
  const box = await locator.boundingBox();
  if (!box) return;
  await page.evaluate(
    ({ x, y, w, h, p }) => {
      let ring = document.querySelector('.__obims_focus_ring__');
      if (!ring) {
        ring = document.createElement('div');
        ring.className = '__obims_focus_ring__';
        document.body.appendChild(ring);
      }
      ring.style.left = `${x - p}px`;
      ring.style.top = `${y - p}px`;
      ring.style.width = `${w + p * 2}px`;
      ring.style.height = `${h + p * 2}px`;
      ring.style.opacity = '1';
    },
    { x: box.x, y: box.y, w: box.width, h: box.height, p: padding }
  );
  if (holdMs > 0) await page.waitForTimeout(holdMs);
}

export async function clearFocus(page) {
  await page.evaluate(() => {
    const ring = document.querySelector('.__obims_focus_ring__');
    if (ring) ring.style.opacity = '0';
  });
}

export async function moveAndClick(page, locator, { hover = 250, settle = 350 } = {}) {
  const box = await locator.boundingBox();
  if (!box) throw new Error('Element has no bounding box');
  const x = box.x + box.width / 2;
  const y = box.y + box.height / 2;
  await page.mouse.move(x, y, { steps: 18 });
  await page.waitForTimeout(hover);
  await page.mouse.click(x, y);
  await page.waitForTimeout(settle);
}

export async function smoothScroll(page, deltaY, { steps = 12, stepMs = 35 } = {}) {
  const perStep = deltaY / steps;
  for (let i = 0; i < steps; i++) {
    await page.mouse.wheel(0, perStep);
    await page.waitForTimeout(stepMs);
  }
}

export async function typeSlow(page, locator, text, { delay = 55 } = {}) {
  await locator.click();
  await locator.fill('');
  await page.keyboard.type(text, { delay });
}

export async function beat(page, ms = 800) {
  await page.waitForTimeout(ms);
}

// Beat marker — emitted to the page console; collector greps for the prefix.
// Uses Date.now() (wall-clock) so timestamps stay monotonic across page
// navigations — performance.now() resets after page.goto.
export async function markBeat(page, id, submodule = '') {
  await page.evaluate(
    ({ id, sub }) => console.log(`[BEAT] ${id} ${sub} ${Date.now()}`),
    { id, sub: submodule }
  );
}
