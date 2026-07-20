import { defineConfig, devices } from '@playwright/test';

// Capture size MUST match the composition's stage-frame size in
// templates/index.html (1760×810 by default). Recording at a different size
// forces object-fit:cover to crop or letterbox in the final composition.
const VIDEO_WIDTH = 1760;
const VIDEO_HEIGHT = 810;

export default defineConfig({
  testDir: './modules',
  testMatch: /spec\.js$/,
  fullyParallel: false,
  workers: 1,
  retries: 0,
  reporter: [['list'], ['json', { outputFile: 'test-results.json' }]],
  timeout: 10 * 60 * 1000,
  use: {
    baseURL: process.env.CONSOLE_URL || 'http://localhost:5173',
    viewport: { width: VIDEO_WIDTH, height: VIDEO_HEIGHT },
    // DPR=2 forces Chromium to render at 2× internally, then downsamples
    // into the recorded frame. Net effect: crisper UI — thin borders,
    // chips, icons stop aliasing.
    deviceScaleFactor: 2,
    video: {
      mode: 'on',
      size: { width: VIDEO_WIDTH, height: VIDEO_HEIGHT },
    },
    trace: 'off',
    screenshot: 'off',
    headless: true,
    launchOptions: {
      args: [
        `--window-size=${VIDEO_WIDTH},${VIDEO_HEIGHT}`,
        '--disable-blink-features=AutomationControlled',
        // Higher quality VPx encoding for the recorded video.
        '--enable-features=VaapiVideoEncoder',
        '--force-color-profile=srgb',
      ],
    },
  },
  outputDir: './.raw',
  preserveOutput: 'always',
  projects: [
    {
      name: 'chromium-frame',
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: VIDEO_WIDTH, height: VIDEO_HEIGHT },
      },
    },
  ],
});
