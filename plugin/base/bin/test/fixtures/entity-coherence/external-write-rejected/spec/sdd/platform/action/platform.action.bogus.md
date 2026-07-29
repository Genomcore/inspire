---
id: platform::action::bogus
module: platform
entity: action
action: bogus
lifecycle: draft
requires: []
superseded_by: null
---

## Purpose
Bogus write on an external entity — should be rejected.

## Inputs

| Parameter     | Type   | Required | Description |
|---------------|--------|----------|-------------|
| `id`          | string | yes      | Target id.  |
| `description` | string | yes      | New value.  |

## Entities

### [[platform.action|platform::action]]
**As input:** id · **Effect:** update

| Field         | Touch   | Type   | Mapping             | Notes |
|---------------|---------|--------|---------------------|-------|
| `id`          | read    | string | `input.id`          | Key.  |
| `description` | written | string | `input.description` |       |

## Behavior
1. Should never exist.

## Errors
- `none`
