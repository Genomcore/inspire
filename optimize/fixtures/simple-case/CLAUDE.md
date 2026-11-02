# OpenBIMS benchmark workspace

This is a seeded React + NestJS project for isolated skill evaluations. Implement
the task using the existing infrastructure; dependencies are declared but are
not installed in evaluation copies. Production code lives in `source/`.

- React: `source/web/src`, tests in `source/web/test`. `ApiClientContext` selects
  the API client; tests use `web/test/mocks/client.ts`. `App.tsx` provides the
  QueryClient, and `route-table.ts` owns route paths. `i18n.ts` owns text.
- NestJS: `source/src`, unit tests beside code, e2e tests in `source/test`.
  `CommonModule` provides `AuditEmitter`. `database.ts` configures a Postgres
  DataSource from `DATABASE_URL`, with migrations and synchronization disabled;
  persistence tasks must bind it into their module.
- INSPIRE: the current runtime is installed separately under `.claude` and
  `.inspire`. Product context lives in `inspire_kb/`.

The task is the scope of the evaluation. Existing unrelated code may be imperfect;
do not rewrite it merely to satisfy conventions outside the requested change.
