---
id: platform::action::find
module: platform
entity: action
action: find
lifecycle: draft
requires: []
superseded_by: null
---

## Purpose
Looks up an action by id.

## Inputs

| Parameter | Type   | Required | Description |
|-----------|--------|----------|-------------|
| `id`      | string | yes      | Lookup key. |

## Outputs
The matching [[platform.action|platform::action]] entity.

## Entities

### [[platform.action|platform::action]]
**As input:** id · **Effect:** read

| Field | Touch | Type   | Mapping    | Notes        |
|-------|-------|--------|------------|--------------|
| `id`  | read  | string | `input.id` | Lookup key.  |

## Behavior
1. Look up.

## Errors
- `none`
