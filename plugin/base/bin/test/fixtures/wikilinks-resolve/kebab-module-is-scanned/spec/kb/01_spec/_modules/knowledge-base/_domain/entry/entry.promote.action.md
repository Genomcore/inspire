---
id: knowledge-base::entry::promote
module: knowledge-base
entity: entry
action: promote
lifecycle: accepted
requires: []
superseded_by: null
---

## Purpose
Promote an entry, citing a document that is not here:
[[this-target-resolves-nowhere]]. The finding must name THIS file — a rule that
cannot discover a kebab-case module reports nothing at all, and silence reads
exactly like a clean run.

## Inputs

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `id`      | uuid | yes      | The entry.  |

## Outputs

| Field | Type | Description |
|-------|------|-------------|
| `id`  | uuid | The entry.  |

## Entities

### [[knowledge-base.entry|knowledge-base::entry]]
**Effect:** update

| Field | Touch   | Type | Mapping | Notes |
|-------|---------|------|---------|-------|
| `id`  | read    | uuid | —       |       |

## Behavior
1. Promote it.

## Errors
- `none`
