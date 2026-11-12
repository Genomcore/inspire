---
id: auth::session::create
module: auth
entity: session
action: create
lifecycle: totally-bogus
requires: ["[auth::session::rotate](../../../_adr/auth-sessions.adr.md)"]
superseded_by: "[also::missing::here](../../also/_domain/missing/missing.here.action.md)"
---

# FEAT-01: Operator sign-in

## Purpose
TODO: write this. Sourced from [adr-does-not-exist-anywhere](../../../_adr/does-not-exist-anywhere.adr.md).

## Rationale
No wikilink in this section at all.

## Fields

| Field   | Type   | Notes                       |
|---------|--------|-----------------------------|
| `token` | string | No action covers this field.|

## Entities

### [auth::session](../_domain/session/session.entity.md)
**Effect:** create

| Field   | Touch   | Type   | Mapping | Notes |
|---------|---------|--------|---------|-------|
| `token` | written | string |         |       |

## Behavior
1. FIXME: mint the token.

## Errors
- `none`
