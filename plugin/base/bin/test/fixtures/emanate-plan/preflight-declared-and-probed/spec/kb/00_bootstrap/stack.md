---
kind: bootstrap-stack
status: active
profiles: [react, nestjs]
wire_conventions: [rest]
---

# Tech stack

The stack this fixture's units are emanated under. It declares test
infrastructure, a worktree recipe and wire-convention decisions, and `nestjs`
carries the probe recipe for the first — so `preflight` is populated and nothing
is a finding.

## Language

- **TypeScript**, end to end.

## Wire conventions

| Decision | Answer |
|---|---|
| Existence leak | `404` |
| Validation failure status | not decided yet |

## Test infrastructure

| Component | Purpose |
|---|---|
| `postgres` | the e2e database |
| `redis` | the cache the session store runs on |

## Worktree recipe

| Step | Command |
|---|---|
| environment | `set -a; . ops/emanate.env; set +a` |
| dependencies | `cp -Rc ../../node_modules node_modules` |
| generated artifacts | `npm run -w api prisma:generate` |
