---
kind: bootstrap-stack
status: active
profiles: [react, nestjs]
wire_conventions: [rest]
---

# Tech stack

The stack this fixture's units are emanated under. It declares test
infrastructure and wire-convention decisions, and `nestjs` carries the probe
recipe for the former — so `preflight` is populated and nothing is a finding.

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
