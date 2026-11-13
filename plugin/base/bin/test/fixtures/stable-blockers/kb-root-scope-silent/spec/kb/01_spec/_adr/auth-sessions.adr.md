---
id: auth::session::rotate
module: auth
entity: session
action: rotate
lifecycle: stable
requires: ["[auth::session::create](../_modules/auth/_features/FEAT-01-login.feature.md)"]
---

# Session rotation

## Purpose
Rotate a session token. XXX: unfinished.

## Entities

### [auth::session](../_modules/auth/_domain/session/session.entity.md)
**Effect:** update

| Field   | Touch   | Type    | Mapping | Notes |
|---------|---------|---------|---------|-------|
| `token` | written | integer |         |       |

## Behavior
1. Replace the token. See [adr-also-does-not-exist](also-does-not-exist.adr.md).

## Errors
- `none`
