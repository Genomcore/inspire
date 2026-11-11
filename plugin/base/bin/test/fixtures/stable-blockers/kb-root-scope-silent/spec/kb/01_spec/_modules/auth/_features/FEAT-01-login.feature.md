---
id: auth::session::create
module: auth
entity: session
action: create
lifecycle: totally-bogus
requires: ["[[auth.session.rotate|auth::session::rotate]]"]
superseded_by: "[[also.missing.here|also::missing::here]]"
---

# FEAT-01: Operator sign-in

## Purpose
TODO: write this. Sourced from [[adr-does-not-exist-anywhere]].

## Rationale
No wikilink in this section at all.

## Fields

| Field   | Type   | Notes                       |
|---------|--------|-----------------------------|
| `token` | string | No action covers this field.|

## Entities

### [[auth.session|auth::session]]
**Effect:** create

| Field   | Touch   | Type   | Mapping | Notes |
|---------|---------|--------|---------|-------|
| `token` | written | string |         |       |

## Behavior
1. FIXME: mint the token.

## Errors
- `none`
