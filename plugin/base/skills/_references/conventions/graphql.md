---
kind: surface-convention
id: graphql
transport: graphql
---

GraphQL breaks the reflex a REST-trained test author brings: **`200` is not success.**
A response carrying `data: null` and three errors is still `200`. A test that asserts
the status code and stops passes while the feature is entirely broken — which is why
this convention leads with the assertion rule rather than a status table.

## What the transport actually guarantees

Three mechanics before any table. The first two are the GraphQL spec's own semantics —
true on any server. The third is server-specific: this convention was **verified against
`@apollo/server` 5** as its reference implementation, and every Apollo-only mechanism
below is named as such rather than presented as GraphQL.

- Errors raised **during execution** (a resolver, a framework guard) surface in
  `errors[]` with HTTP **`200`**. This is GraphQL's own semantics, not an Apollo choice:
  the document was valid and the server did execute it.
- Errors raised **before execution** — parse failure, schema validation of the document —
  are HTTP **`400`** with no `data`. Apollo attaches this itself
  (`internalErrorClasses.js`: `http: newHTTPGraphQLHead(400)`).
- Any error may **override its own status** via `extensions.http`. Apollo reads it off
  the error, merges it into the HTTP response and deletes it from the extensions the
  client sees (`errorNormalize.js`). So `200` is a default, not a cage.

**On a different GraphQL server** (Yoga, Mercurius, graphql-go, Absinthe, …) the
200-vs-400 split and the `errors[]` semantics hold — they are spec. The Apollo-only
mechanics do not travel: the status-override mechanism (`extensions.http`), the
built-in code enum below, and the attach-a-`stacktrace`-by-default behavior each have
a per-server equivalent that must be looked up and re-verified, never assumed. The
policy rows below stay the same questions; only the mechanism realizing them changes.

**`UNAUTHENTICATED` and `FORBIDDEN` are not Apollo codes.** The built-in enum
(`ApolloServerErrorCode`) is exactly: `INTERNAL_SERVER_ERROR` · `GRAPHQL_PARSE_FAILED` ·
`GRAPHQL_VALIDATION_FAILED` · `PERSISTED_QUERY_NOT_FOUND` ·
`PERSISTED_QUERY_NOT_SUPPORTED` · `BAD_USER_INPUT` · `OPERATION_RESOLUTION_FAILURE` ·
`BAD_REQUEST`. The two auth codes existed as `AuthenticationError` / `ForbiddenError`
classes in Apollo Server 2–3 and were **removed in 4**; today they are a community
convention a project defines for itself. Treat them as project vocabulary, and declare
them below.

## Expected outcomes are data; exceptional failures are errors

Before mapping anything to `errors[]`, ask which side of this line the case falls on.
It is the highest-leverage decision in a GraphQL contract, and the one a REST-trained
author skips because REST has no equivalent.

- **Expected domain outcome** — a natural-key collision, a state machine refusing a
  transition, "no such record". The caller can act on it, and it is part of what the
  operation *means*. Model it **in the schema**, as a result union or a payload type:

  ```graphql
  type Mutation { createThing(input: ThingInput!): CreateThingResult! }
  union CreateThingResult = ThingCreated | ThingConflict
  type ThingConflict { existingVersion: DateTime!, message: String! }
  ```

- **Exceptional failure** — the datastore is unreachable, a bug threw, the credential is
  missing. The caller cannot act on the specifics and the operation did not get to mean
  anything. That belongs in `errors[]`.

Why this is the preferred shape here rather than a stylistic preference: it turns the
error contract into **schema** — typed, introspectable, versioned with the API. A test
then asserts a shape derived from the schema instead of a magic string inside a loosely
typed `extensions` bag, which is the difference between a contract and a convention
someone remembered. The cost is real and worth stating: every operation with expected
errors needs its union, and clients write `... on ThingConflict`.

An error that has to stay in `errors[]` still has two forms — plain `200` with a code,
or the status lifted via `extensions.http = { status: 409 }` (Apollo reads it off the
error, applies it, and strips it from what the client sees). Which one is a policy row,
not a per-action choice.

## Error taxonomy → surface

| Logical error class | Surface response | Notes |
|---|---|---|
| Malformed query, unknown field, type mismatch in the document | `400`, no `data` | Pre-execution. Apollo's own behavior, not a choice. |
| Validation failure on input values (missing required field, bad enum, constraint) | `200` + `errors[].extensions.code: BAD_USER_INPUT` | Apollo built-in code. The body names the offending field, same requirement as REST. |
| Persisted-query miss | `200` + `PERSISTED_QUERY_NOT_FOUND` | Only where the project uses persisted queries. |
| Uniqueness / natural-key collision | `200` + a project code (e.g. `CONFLICT`) | No built-in covers it. |
| Downstream dependency unavailable | `200` + `INTERNAL_SERVER_ERROR` or a project code | |
| Unhandled fault | `200` + `INTERNAL_SERVER_ERROR` | **No `stacktrace` extension.** Apollo attaches one unless explicitly disabled. |

**Authentication and authorization are deliberately absent from this table** — what a
caller observes depends on *where the check runs*, which no convention can decide:

| Where the check runs | What the caller observes |
|---|---|
| HTTP middleware, before the GraphQL handler | a real `401` / `403`, **no GraphQL body** — nothing executed |
| A framework guard or the resolver itself | a GraphQL error, HTTP `200` by default, liftable to `401` with `extensions.http` |

Both are defensible; picking one by accident is not. It is the first row of the policy
table, and until it is answered a test asserting either shape is pinning a guess.

"Target does not exist" is absent for the same reason — there is no `404` in GraphQL, so
it is a policy row too, not a derivation.

## Project policy — asked once, recorded in stack.md

| Decision | Options | Default if the operator has no opinion |
|---|---|---|
| Expected domain errors | schema result unions (errors as data) · `errors[]` with a code | schema unions for expected outcomes, `errors[]` only for exceptional failures — the error contract becomes typed schema instead of a string convention. |
| Errors that stay in `errors[]` | plain `200` + code · status lifted via `extensions.http` | lifted — a client can then handle transport failures uniformly, and the code is still in the body for the specific case. |
| Where the auth check runs | HTTP middleware (real `401`/`403`, no GraphQL body) · in-execution guard (`200` + a project code, optionally lifted via `extensions.http`) | in-execution guard, status lifted to `401`/`403` — a single client can then treat transport failures uniformly, and the GraphQL body still carries the code. |
| Absent resource on a single-item query | `null` in `data`, no error · a project `NOT_FOUND` in `errors` | `null` with no error — "not found" is a valid answer to a query, not a failure. Reserve errors for what prevented answering. |
| Auth error code vocabulary | `UNAUTHENTICATED` / `FORBIDDEN` (the pre-Apollo-4 names, now project-owned) · project-specific names | the pre-4 names — every GraphQL client developer already knows them, and Apollo removing the classes did not remove the shared vocabulary. |
| Nullability of list fields | non-null list of non-null items (`[T!]!`) · nullable | `[T!]!` — a nullable list makes every consumer write a branch that is never exercised. |
| Expired credential | same code as absent · distinct code | distinct code — the client's remedy differs (refresh vs re-login). |
| Partial success on a multi-field query | allowed (`data` + `errors` together) · all-or-nothing | allowed — it is the protocol's own semantics; fighting it costs more than it returns. **But every test must then assert both halves.** |
| Domain error codes | reuse a built-in where it fits · a project enum | built-ins where they genuinely fit (`BAD_USER_INPUT` for input validation), a project enum for everything domain-specific — the built-in list has no collision, conflict or not-found code, so most domain errors need one. |

## Response shape

- Assert the **entire** response object — `data` **and** `errors` — not one or the
  other. A test that asserts only `data` cannot tell a successful query from a
  partially failed one; a test that asserts only `errors` cannot tell a rejection from
  a rejection that also returned garbage.
- Assert the **whole `extensions` object** on an error, not the presence of `code`.
  Asserting `code === 'BAD_USER_INPUT'` passes happily next to a leaked `stacktrace`;
  asserting the whole object fails the moment one is attached. That regression ships
  quietly — nothing else in the pipeline notices a leaked stacktrace.
- On a success path, assert `errors` is **absent**. Omitting that assertion is how a
  feature ships with an error nobody looked at.
- Loose matchers only for generated ids, timestamps and cursors.

## Always-present cases

- **Every declared error** in the descriptor's `## Errors` gets a test — and it asserts
  the form that error takes here: a typed schema member (`... on ThingConflict`) for an
  expected outcome, an `errors[]` entry for an exceptional failure. A test asserting the
  wrong one passes against an implementation that contradicts the schema.
- **Success asserts the absence of `errors`**, not just the shape of `data`.
- **No `stacktrace` extension** in any error response, asserted on the whole
  `extensions` object, in whatever environment the tests run.
- **Auth, wherever the operation is authenticated**: one test for no credential, one for
  a valid credential without the permission. Both, not one. What they assert comes from
  the *where the auth check runs* policy row — a real `401`/`403` with no GraphQL body,
  or a `200` carrying the project's code. Asserting the wrong one is not a stylistic
  slip: it locks in a design nobody chose.
- **Malformed document** → `400` with no `data`, distinguishing a schema-level
  rejection from a runtime one.
- **Empty result on a list query** → the empty collection with the pagination envelope
  intact, and `errors` absent.

## Deviation

Declared in the descriptor below `## Errors`, same form as the REST convention:

```markdown
**Wire deviation:** `variant_not_found` is returned in `errors` with code
`NOT_FOUND` rather than as a `null` field — the caller distinguishes "no such variant"
from "variant with no current version", and a bare `null` collapses the two.
```

A deviation without a reason is a finding, not a deviation.
