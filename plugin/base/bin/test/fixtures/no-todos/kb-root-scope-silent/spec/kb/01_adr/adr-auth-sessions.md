---
id: auth.session.rotate
module: auth
entity: session
action: rotate
lifecycle: stable
requires: ["[[auth.session.create|auth::session::create]]"]
---

# Session rotation

## Purpose
Rotate a session token. XXX: unfinished.

## Entities

### [[auth.session|auth::session]]
**Effect:** update

| Field   | Touch   | Type    | Mapping | Notes |
|---------|---------|---------|---------|-------|
| `token` | written | integer |         |       |

## Behavior
1. Replace the token. See [[adr-also-does-not-exist]].

## Errors
- `none`
