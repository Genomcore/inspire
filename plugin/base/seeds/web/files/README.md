# The production code

The starter of INSPIRE's `web` seed: a NestJS API under `/api` (`src/`) with
`GET /api/is-alive`, and a React + Vite web (`web/`) that calls it and has a 404 page.
Everything else is built from the knowledge base.

```
npm ci
npm run test && npm run test:e2e
npm run typecheck && npm run lint && npm run build
npm run format
npm run dev
```

`npm test` runs two Vitest projects (`vitest.config.ts`): `api` (`src/**/*.spec.ts`,
node, compiled with SWC so Nest decorators and their metadata work) and `web`
(`web/test/**/*.spec.tsx`, jsdom with Testing Library and `jest-dom` matchers).
Put React component tests under `web/test/`; no extra test packages are needed.
`npm run test:e2e` runs `test/**/*.e2e-spec.ts` one file at a time (`vitest.e2e.config.ts`).
Test globals (`describe`, `it`, `expect`) need no import.

Linting is oxlint (`.oxlintrc.json`, type-aware through `oxlint-tsgolint`),
formatting oxfmt (`.oxfmtrc.json`) and type checking tsgo (`@typescript/native-preview`),
which also emits the API build. `oxlint-escape-hatches.mjs` is the local oxlint plugin
that refuses a disable directive without a reason and `as unknown as`; it is this
project's file from now on.
