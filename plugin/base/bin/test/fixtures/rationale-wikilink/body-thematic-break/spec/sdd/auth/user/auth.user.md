---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
The user account entity.

---

The thematic break above sits in the body, before the rationale-bearing
section. `sdd_body_section` must keep reading past it — this rule's logic is
unchanged, but its parser input is not, and an accepted entity whose back-source
is merely *below* a `---` used to be reported as having none.

## Rationale
Grounded in [[adr-plt-01-identity-model]] and [[pdd-auth-identity-system]].

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |
