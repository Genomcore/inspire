import react from '@vitejs/plugin-react';
import swc from 'unplugin-swc';
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    coverage: { thresholds: { lines: 0, functions: 0, branches: 0, statements: 0 } },
    projects: [
      {
        plugins: [swc.vite()],
        test: { name: 'api', environment: 'node', globals: true, include: ['src/**/*.spec.ts'] },
      },
      {
        plugins: [react()],
        test: {
          name: 'web',
          environment: 'jsdom',
          globals: true,
          include: ['web/test/**/*.spec.tsx'],
          setupFiles: ['web/test/setup.ts'],
        },
      },
    ],
  },
});
