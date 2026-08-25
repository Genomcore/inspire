## Orchestrator action — `auth::user::signup`

An action that touches multiple entities. Signup is the canonical example: it creates the user row, appends an audit event, and reads from a lookup entity to enforce a domain allow-list. One descriptor, three `### [[module.entity|module::entity]]` sub-sections.

---

```markdown
---
id: auth::user::signup
module: auth
entity: user
action: signup
lifecycle: accepted
requires:
  - "[[auth.password.hash|auth::password::hash]]"
  - "[[auth.user.create|auth::user::create]]"
superseded_by: null
---

## Purpose
Public-facing signup. Layers domain allow-list enforcement and audit logging on top of the bare [[auth.user.create|auth::user::create]] action. The public caller has different threat assumptions — rate limiting, audit, allow-list checks — described in [[auth-public-signup|the public signup feature]]; the admin-side `create` is intentionally minimal.

## Inputs

| Parameter  | Type     | Required | Description                                |
|------------|----------|----------|--------------------------------------------|
| `email`    | email    | yes      | Account login email; must clear allow-list.|
| `password` | password | yes      | Plaintext password; delegated to `create`. |

## Outputs

| Field                         | Type    | Description                                            |
|-------------------------------|---------|--------------------------------------------------------|
| `id`                          | uuid    | The newly created user id.                             |
| `email_verification_required` | boolean | Always `true` at signup — verification is a follow-up. |

## Entities

### [[auth.user|auth::user]]
**As input:** shape · **Effect:** create

| Field          | Touch   | Type      | Mapping                  | Notes                                 |
|----------------|---------|-----------|--------------------------|---------------------------------------|
| `id`           | written | uuid      | `uuid()`                 | PK.                                   |
| `email`        | written | email     | `input.email`            | The principal's identity handle.      |
| `password`     | written | password  | `hash(input.password)`   | Never plaintext.                      |
| `created_at`   | written | timestamp | `now()`                  | Set at insert.                        |
| `signup_ip`    | written | string    | `current_request.ip`     | Audit trail; not exposed in reads.    |

### [[auth.email_allowlist|auth::email_allowlist]]
**As input:** email · **Effect:** read

| Field     | Touch | Type    | Mapping               | Notes                                       |
|-----------|-------|---------|-----------------------|---------------------------------------------|
| `domain`  | read  | string  | `matches input.email` | Match by email's domain (post-`@` part).    |
| `allowed` | read  | boolean | —                     | If `false` → throw `domain_not_allowed`.    |

### [[audit.event|audit::event]]
**As input:** — · **Effect:** append

| Field        | Touch   | Type      | Mapping                | Notes                                  |
|--------------|---------|-----------|------------------------|----------------------------------------|
| `event_type` | written | string    | `"auth.user.signup"`   | Literal; namespaced event id.          |
| `actor_id`   | written | uuid      | `from auth::user.id`   | The just-created user is the actor.    |
| `at`         | written | timestamp | `now()`                |                                        |
| `metadata`   | written | json      | `{ ip: signup_ip }`    | Captured at the request boundary.      |

## Preconditions
- `P1` — absent(auth.user) — No account may already hold the submitted email.
- `P2` — state(auth.email_allowlist, allowed) — The email's domain must be allow-listed, per [[auth-signup-allowlist|the signup allow-list feature]]. Unlike `create`'s `actor(admin)`, this action has no actor precondition at all: it is the public path, and that absence is the design.

## Behavior
1. `B1` — Extract the email domain and look up [[auth.email_allowlist|auth::email_allowlist]] by `domain`, following the rule in [[auth-signup-allowlist|the signup allow-list feature]]. If `allowed = false`, return `domain_not_allowed`.
2. `B2` — Delegate user-row creation to [[auth.user.create|auth::user::create]], which handles `email_exists`, `password_too_weak`, and `email_invalid`.
3. `B3` — Append a `user.signup` event to [[audit.event|audit::event]] with the new user's `id` as actor and the request IP in metadata, per the central audit policy in [[adr-audit-01-centralized-logging]].
4. `B4` — Return the new user's `id` and `email_verification_required: true`. The verification flow is a separate action — [[auth.user.verify_email|auth::user::verify_email]].

## Postconditions
- `Q1` — created(auth.user) — One row exists, with `signup_ip` recorded.
- `Q2` — created(audit.event) — One `user.signup` event is appended.
- `Q3` — returns(id) — The caller receives the new row's identifier.
- `Q4` — No verification email has been sent yet; `email_verification_required` is the caller's cue to start that flow.

## Errors
- `domain_not_allowed` — state(auth.email_allowlist, allowed) — operator-facing message: "Signup from that email domain isn't permitted."
- `email_exists` — unique(email) — propagated as-is from [[auth.user.create|auth::user::create]].
- (Inherits its remaining errors from [[auth.user.create|auth::user::create]] — propagated as-is.)
```

---

## What this example teaches

- **One descriptor, three entities.** Multi-entity actions are common. They keep the cross-entity contract co-located.
- **`from R.field` mapping token.** The audit event's `actor_id` reads from the just-written `auth::user.id`. This is the canonical way to express "use the value written above" without restating it.
- **`Effect: append` for audit logs.** Audit events use `append`, not `create`. Both write rows, but `append` signals that the rows are immutable and never read individually (only aggregated). The convention is enforced by `entity-coherence`: append-only entities don't trigger field-orphan-write warnings even when no read action exists.
- **Inheritance of errors, with one exception spelled out.** `signup` says `(Inherits its remaining errors from [[auth.user.create|auth::user::create]])` rather than restating the whole catalogue — the agent expands that when rendering with `/inspire_domain show`. But `email_exists` is written out explicitly, head included, because this descriptor *writes* the `unique` field itself: an inherited error is still a declared error, and a blanket inheritance note is not a declaration anything can check. Delegating the work does not delegate the contract.
- **A prose-only postcondition next to headed ones.** `Q4` says no verification mail has gone out. No V4 head fits — there is no entity to name and no output to point at — so it stays prose and becomes a claim the suite asserts explicitly. Reaching for a head that only nearly fits would have been worse than none.
- **Allow-list read uses `matches` mapping.** The match is by pattern on the input — the descriptor declares the relationship without specifying the SQL query.
- **Prosaic back-sourcing.** Wikilinks weave into the sentences that make the claims in `## Purpose` and `## Behavior`. No trailing `Back-source:` lines, no bare `[[link]]` at the end of behavior steps.
