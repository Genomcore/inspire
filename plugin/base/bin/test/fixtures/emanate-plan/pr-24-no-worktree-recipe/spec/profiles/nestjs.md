---
kind: inspire-code-profile
id: nestjs
layer: backend
language: typescript
---

The framework profile for the service half of the suite.

## Layering

Domain, infrastructure, application, controllers.

## Test infrastructure

The probe recipe. Plan tests for this section's presence and reads no further —
whether the components are healthy is a question only the run asks, and only by
running what is written here.

- Inspect: `docker compose config --services`.
- Status: `docker compose ps` — **healthy**, not merely `Up`.
