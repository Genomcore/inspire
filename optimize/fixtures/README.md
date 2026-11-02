# Evaluation bases

Each `fixture:` in `complaints.yaml` points to a directory overlaid on a freshly
materialized INSPIRE project. Several bases can coexist; skills can share a base,
and task-specific directories can overlay it. No generator or preparation agent
is involved. Check in source and lockfiles, not installed dependencies or runtime.

`simple-case/` originates from the local simple-case scaffold used by the React
and NestJS benchmarks. It now includes an injectable API client, a test mock,
TanStack Query, centralized route paths, a typed audit emitter, Postgres data
source configuration, and Swagger dependencies. The existing liveness and
not-found screens remain; project/user/support features and the language switch
are deliberately left to the tasks. Existing imperfections are useful regression
coverage for checks that must not blame an agent for its starting state.

Validate changes to this base with the commands in `../README.md`. Changing a
base changes the benchmark: start a fresh optimization run afterward.
