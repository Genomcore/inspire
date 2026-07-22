---
kind: inspire-code-profile
id: nestjs
layer: backend
---

## Layering
Domain-driven, four layers. **domain/** — pure TypeScript interfaces, types, enums;
no framework imports. **infrastructure/** — persistence entities, repositories
(data access + a `toDomain()` mapper), and adapters for external systems; HTTP calls
to other services are wrapped in a repository too. **application/** — services hold
the business logic; one primary service per aggregate, dedicated services for
complex flows (no God objects). **controllers/** — DTOs (request DTOs implement the
domain interface; response DTOs map in their constructor) + the controller. Business
logic never lives in a controller.

## Test conventions
- **Unit** (`*.spec.ts`) — services with their dependencies mocked (a typed
  auto-mock helper, not hand-rolled objects); assert the returned value **and** each
  collaborator call.
- **E2E** (`*.e2e-spec.ts`) — controllers and DB repositories against a **real
  database**; mock only outbound external HTTP (intercept and assert the request was
  made). E2E never overrides providers.
- HTTP repositories (call an API, not a DB) are unit-tested — the contract is the
  parsing/mapping, not the transport.
- GIVEN/WHEN/THEN; use test-data builders so each test sets only the significant
  fields. Assert full response bodies and full persisted documents, built from the
  domain entity — never compared against the value under test.
- Run: `npm run test` (unit) · `npm run test:e2e` (e2e).

## Forbidden patterns
- Services throw a **generic `Error` with `cause`**, never HTTP exceptions —
  translating to HTTP is the controller/filter's job.
- **Repositories never validate input** — validation lives in the DTO (with a
  controller) or the service (without one).
- DI by concrete class when there is one implementation; an abstract class as the
  contract when there are several. Never interface + string token + `@Inject`.
- No ORM/DB technology in class names (`EmailTemplateRepository`, not
  `…MongooseRepository`).

## Review focus
- **api-contract**: request/response DTOs validate at the boundary
  (`class-validator`) and the OpenAPI/Swagger surface (`@ApiProperty`,
  `@ApiOperation`, `@ApiResponse`) matches the actual shape.
- **security**: OWASP checks on new endpoints, guards, and auth logic —
  authorization (not only authentication), input validation, no sensitive data in
  logs or error responses.

## Build & verify
build: `npm run build` · lint: `npm run lint` · types: `npx tsc --noEmit` ·
tests: `npm run test` + `npm run test:e2e`
