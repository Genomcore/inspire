---
id: samples::sample::create
module: samples
entity: sample
action: create
lifecycle: accepted
requires: []
superseded_by: null
produced:
  skill: domain
  skill_sha: 4328a5f
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---

## Purpose
Register one sample the laboratory has received, as [[SMP-02]] describes. The registry is the single writer of [[samples.sample|samples::sample]] rows.

## Inputs

Every parameter is required.

| Parameter | Type | Description |
|---|---|---|
| `code` | string | The laboratory's sample code. |
| `patient_ref` | string | Opaque patient reference. |
| `type` | enum<blood,saliva,tissue> | The kind of biological material. |
| `collected_at` | date | The calendar day of collection. |

### code
Constraints: `len(3, 32), pattern(/^[A-Za-z0-9-]+$/)`

The bounds are the entity's own, stated in [[samples.sample|samples::sample]]; [[SMP-02]] fixes them at three to thirty-two characters of letters, digits and hyphens.

### patient_ref
Constraints: `len(1, 64)`

### collected_at
Constraints: `max(today)`

A collection day cannot be in the future, per [[SMP-02]].

## Outputs

A [[samples.sample|samples::sample]] entity.

## Entities

### [[samples.sample|samples::sample]]
**As input:** shape · **Effect:** create

| Field | Touch | Type | Mapping | Notes |
|---|---|---|---|---|
| `id` | written | uuid | `uuid()` | Generated at write. |
| `code` | written | string | `input.code` | Kept as entered. |
| `patient_ref` | written | string | `input.patient_ref` | |
| `type` | written | enum<blood,saliva,tissue> | `input.type` | |
| `collected_at` | written | date | `input.collected_at` | |
| `status` | written | enum<received,processing,analyzed> | `received` | Every new sample starts here. |
| `created_at` | written | timestamp | `now()` | |

## Preconditions
- `P1` — actor(technician) — Only a technician of the demo console registers samples, as the actor of [[SMP-02]].
- `P2` — absent(samples.sample) — No sample may already carry the submitted code, compared case-insensitively, per [[SMP-02]].

## Behavior
1. `B1` — Validate each input against its constraints; report every failing field at once, as [[SMP-02]] requires.
2. `B2` — Compare the submitted code case-insensitively against every stored code; a match raises `code_exists`.
3. `B3` — Insert the row with `status` set to `received` and `created_at` set to the current instant.

## Postconditions
- `Q1` — created(samples.sample) — Exactly one row exists for the submitted code, with the entered values and `status` `received`.
- `Q2` — The caller receives the created sample, including its `id`.

## Errors
- `code_exists` — unique(code) — operator-facing message: "A sample with this code already exists."
- `code_invalid` — pattern(code) — operator-facing message: "A code is 3 to 32 letters, digits or hyphens."
- `collected_at_in_future` — max(collected_at) — operator-facing message: "The collection date cannot be later than today."
