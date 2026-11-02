---
id: samples::sample::list
module: samples
entity: sample
action: list
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
Return one page of samples, newest collection first, narrowed by the optional type, status and code filters that [[SMP-01]] describes. This is the only read the registry table uses.

## Inputs

Every parameter is optional.

| Parameter | Type | Description |
|---|---|---|
| `type` | enum<blood,saliva,tissue> | Keep only samples of this type. |
| `status` | enum<received,processing,analyzed> | Keep only samples in this status. |
| `code` | string | Keep only samples whose code contains this fragment, compared case-insensitively. |
| `limit` | integer | Page size. |
| `cursor` | string | Opaque cursor from a previous page's `next_cursor`. |

### code
Constraints: `len(1, 32)`

### limit
Constraints: `min(1), max(200), default(50)`

## Outputs

| Field | Type | Description |
|---|---|---|
| `items` | json | An array of [[samples.sample|samples::sample]] entities, ordered by `collected_at` descending then `created_at` descending. |
| `total` | integer | The number of samples matching the filters across every page. |
| `next_cursor` | string | Cursor for the next page; null on the last page. |

## Entities

### [[samples.sample|samples::sample]]
**As input:** filter fields · **Effect:** read-whole

| Field | Touch | Type | Mapping | Notes |
|---|---|---|---|---|
| `type` | read | enum<blood,saliva,tissue> | `input.type` | Exact match when supplied. |
| `status` | read | enum<received,processing,analyzed> | `input.status` | Exact match when supplied. |
| `code` | read | string | `input.code` | Case-insensitive substring when supplied. |

## Preconditions
- `P1` — actor(technician) — Only a technician of the demo console lists samples, as the actor of [[SMP-01]].

## Behavior
1. `B1` — Combine every supplied filter with AND, as [[SMP-01]] requires; an absent filter constrains nothing.
2. `B2` — Order the matches by `collected_at` descending, then `created_at` descending.
3. `B3` — Return at most `limit` matches from the position `cursor` names, with `total` counted over every match and `next_cursor` set when more remain.

## Postconditions
- `Q1` — returns(items) — The caller receives the page of matching samples; an empty page is a valid result.
- `Q2` — returns(total) — The caller receives the count of matches across every page.
- `Q3` — unchanged(samples.sample) — Listing writes nothing.

## Errors
- `cursor_invalid` — operator-facing message: "The page cursor is not valid."
