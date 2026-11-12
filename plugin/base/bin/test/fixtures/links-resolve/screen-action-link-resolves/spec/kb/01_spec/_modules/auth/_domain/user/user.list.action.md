---
id: auth::user::list
module: auth
entity: user
action: list
lifecycle: accepted
requires: []
superseded_by: null
---

## Purpose
List users — the action a screen binds under `### Data`.

## Rationale
Cites a doc that is not here: [[adr-decoy-the-domain-half-must-stay-silent]].
Under a `05_screens` scope this file is out of scope, so that dangling target
must NOT be reported — it is the bait for the domain half leaking back in.

## Inputs

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `page`    | int  | no       | Page index. |

## Outputs

| Field   | Type | Description |
|---------|------|-------------|
| `users` | list | The page.   |

## Entities

### [[auth.user|auth::user]]
**Effect:** read

| Field | Touch | Type | Mapping | Notes |
|-------|-------|------|---------|-------|
| `id`  | read  | uuid | —       |       |

## Behavior
1. Read the page.

## Errors
- `none`
