---
id: samples.sample
module: samples
entity: sample
lifecycle: accepted
produced:
  skill: domain
  skill_sha: 4328a5f
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---

## Purpose
The `samples::sample` entity is one biological sample the laboratory has received, as the registry in [[SMP-01]] lists it and [[SMP-02]] registers it. Every row is one physical sample with the code the laboratory wrote on it.

## Rationale
The registry exists to exercise one vertical slice of the demo console, so the entity carries only what [[SMP-01]] filters on and [[SMP-02]] enters: a laboratory `code`, a `patient_ref`, a `type`, the `collected_at` day and a processing `status`. `code` is the laboratory's own identifier and is unique across the registry, because two samples with one code cannot be told apart at the bench. `patient_ref` is an opaque reference the laboratory supplies; the demo console holds no patient entity. `type` and `status` are closed sets so the filters in [[SMP-01]] are exact matches. `collected_at` is a calendar day, since a laboratory records the day of collection and not an instant. `created_at` anchors the row to the moment of registration and orders the table when two samples share a collection day.

## Invariants
- `I1` — `status` starts at `received` on registration, as [[SMP-02]] states; no action in this module moves it further.

## Fields

| Field | Type | Notes |
|---|---|---|
| `id` | uuid | Primary key. |
| `code` | string | The laboratory's own sample code. |
| `patient_ref` | string | Opaque patient reference the laboratory supplies. |
| `type` | enum<blood,saliva,tissue> | The kind of biological material. |
| `collected_at` | date | The calendar day of collection. |
| `status` | enum<received,processing,analyzed> | Processing stage. |
| `created_at` | timestamp | Registration instant; secondary sort key. |

### id
Constraints: `nonnull, unique, immutable`

### code
Constraints: `nonnull, unique, immutable, len(3, 32), pattern(/^[A-Za-z0-9-]+$/)`

Uniqueness compares case-insensitively, as [[SMP-02]] requires; the store keeps the code as entered.

### patient_ref
Constraints: `nonnull, len(1, 64)`

### type
Constraints: `nonnull, immutable`

### collected_at
Constraints: `nonnull, immutable`

A day later than today is rejected at registration by [[samples.sample.create|samples::sample::create]].

### status
Constraints: `nonnull, default(received)`

### created_at
Constraints: `nonnull, immutable, default(now)`

## Touched by

| Action | Touch | Notes |
|---|---|---|
| [[samples.sample.create|samples::sample::create]] | write | Inserts the row with `status` `received`. |
| [[samples.sample.list|samples::sample::list]] | list | Filters by `type`, `status` and a `code` fragment; returns whole rows. |
