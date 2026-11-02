# `/source` — the production code

Scaffoldped from the inspire-factory `react-nestjs-npm` template: a NestJS API under
`/api` (`src/`) with `GET /api/is-alive`, and a React + Vite web (`web/`) that calls it
and has a 404 page. Everything else is emanated from the knowledge base.

```
npm ci
npm run test && npm run test:e2e
npm run typecheck && npm run lint && npm run build
npm run dev
```

`npm test` runs two Jest projects: `api` (`src/**/*.spec.ts`, node) and `web`
(`web/test/**/*.spec.tsx`, jsdom with Testing Library and `jest-dom` matchers).
Put React component tests under `web/test/`; no extra test packages are needed.
