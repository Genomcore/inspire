---
kind: surface-convention
id: rest
transport: rest
---

## Error taxonomy → surface

The logical error classes on the left are the vocabulary an action descriptor's
`## Errors` uses. A descriptor never writes the right column — this table is the right
column, once, for every action in the project.

| Logical error class | Surface response | Notes |
|---|---|---|
| Malformed request (unparseable body, wrong content type) | `400` | Before validation — nothing was understood, so no field can be named. |
| Validation failure (missing required field, bad type, value outside an enum, constraint violated) | `400` or `422` — **project policy** | Whichever is chosen, the body **names the offending field**. That part is not optional. |
| Absent credential | `401` | |
| Invalid or expired credential | `401` — **project policy** may split expired out | An expired token is a different remedy (refresh) than a forged one (re-authenticate). |
| Authenticated, but the action is not permitted | `403` | The RBAC denial. |
| Authenticated, permitted, but the target does not exist | `404` | |
| Target exists but the caller may not know that | `403` or `404` — **project policy** | The existence-leak decision. See policy table. |
| Uniqueness / natural-key collision on create | `409` | |
| Optimistic-concurrency loss (stale version) | `409` | |
| State machine refuses the transition (e.g. cancel an already-shipped order) | `409` | Not `400`: the request is well-formed and the caller is allowed; the *state* is the obstacle. |
| Rate limit exceeded | `429` | |
| Downstream dependency unavailable or timed out | `502` / `504` | Never surfaced as `500` — a `500` claims the fault is ours. |
| **Readiness probe** reporting the service cannot serve yet | `503` | A distinct case from the row above, and the distinction is the point: `502`/`504` answers *"your request failed because something downstream did"*, while `503` answers *"do not send me requests yet"*. The caller is an orchestrator, not a user, and it acts on the difference — a `503` withholds traffic or fails a deploy, a `502` does not. The body names **which** dependency is not ready; the probe checks its dependencies for real (a cheap query), because a probe that only proves the process is alive reports a healthy deploy on a service that cannot answer anything. |
| Unhandled fault | `500` | Body carries **no** stacktrace, no internal paths, no framework frames. |

Success side, by verb (the action verb taxonomy in
[`inspire-domain/references/format-action.md`](../../inspire-domain/references/format-action.md)):

| Verb | Success | Notes |
|---|---|---|
| `get` | `200` | |
| `list` | `200` | Always paginated, including when the page is empty — an empty page is `200` with an empty collection, never `404`. |
| `create` | `201` | |
| `edit` / `enable` / `disable` / `move` | `200` | |
| `delete` | `204` | |

## Project policy — asked once, recorded in stack.md

| Decision | Options | Default if the operator has no opinion |
|---|---|---|
| Existence leak: resource exists, caller may not see it | `403` (honest, leaks existence) · `404` (hides existence, indistinguishable from absent) | `404` — it leaks less, and the caller cannot act on the difference anyway. |
| Validation failure status | `400` · `422` | `400` — more widely understood; `422` only buys a distinction most clients ignore. |
| Expired credential | same `401` as absent · distinct code in the error body | distinct code in the body, status stays `401` — the status is for the transport, the code is for the client. |
| Error body shape | `application/problem+json` (RFC 7807) · project schema | `problem+json` — it is a standard, so the test asserts a shape that outlives the project. |
| Create with an existing natural key | `409` · `200` with the existing resource (idempotent) | `409` — silent idempotency hides a caller bug. Only choose `200` where the caller genuinely cannot know. |
| Pagination contract | cursor · offset+limit | cursor — stable under concurrent inserts, which offset is not. |

Recording an answer is **not** optional. An unanswered policy question is
[`quality-gates.md`](../quality-gates.md) Rule 5 in miniature: the gate exists and
nothing enforces it, so the agent silently picks one and the choice becomes whatever
was written first.

## Response shape

- A test asserts the **whole** body, success or error, per
  [`inspire-code/references/tdd.md`](../../inspire-code/references/tdd.md) — never a
  field or two out of an envelope.
- The expected value is built from the domain entity, never from the value under test.
- Loose matchers are for values that are genuinely non-deterministic: generated ids,
  timestamps, cursors. Everything else is an exact value, including the error code and
  the field name inside a validation error.

## Always-present cases

These exist for every action of this transport, whether or not a criterion mentions
them. A feature author forgetting one is normal; a reviewer having to remember them
every time is the defect.

- **Every declared error** in the descriptor's `## Errors` gets a test.
- **Auth, wherever the action is authenticated**: no credential → `401`; valid
  credential without the permission → `403`. Both, not one.
- **`get` / `edit` / `delete` on an unknown id** → `404`.
- **`list` with no matches** → `200` with an empty collection and the pagination
  envelope intact.
- **Required-field omission** → the validation status, with the field named.
- **No stacktrace in any error body**, asserted on the whole `extensions`/error object
  rather than on the presence of one key.

## Deviation

An action that does not follow this convention says so in its descriptor, directly
below `## Errors`:

```markdown
**Wire deviation:** `not_found` returns `403` instead of `404` — this endpoint is
reachable pre-authorization and a `404` would let an unauthenticated caller enumerate
valid ids.
```

A deviation without a reason is a finding, not a deviation.
