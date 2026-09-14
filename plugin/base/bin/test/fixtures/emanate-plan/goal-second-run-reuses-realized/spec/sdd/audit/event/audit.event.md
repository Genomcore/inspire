---
id: audit.event
module: audit
entity: event
lifecycle: accepted
---

## Purpose
The append-only record of what happened, described in [[audit-trail]].

## Rationale
The trail is a discrete object because [[adr-audit-01-append-only]] forbids
editing history in place.

## Invariants
- `I1` — An event is never edited after it is written; a correction is a new event.

## Fields

| Field        | Type      | Notes                      |
|--------------|-----------|----------------------------|
| `id`         | uuid      | Primary key.               |
| `kind`       | string    | What happened.             |
| `created_at` | timestamp | The audit-timeline anchor. |

### id
Constraints: `nonnull, unique, immutable`

### kind
Constraints: `nonnull, len(3, 64)`

### created_at
Constraints: `nonnull, immutable, default(now)`

## Touched by

| Action | Touch | Notes |
|--------|-------|-------|
