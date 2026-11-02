---
produced:
  skill: feature
  skill_sha: 7aff836
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---
# SMP-01: Browse and filter samples

> Source: [[../../02_modules/samples]]

A lab technician opens the samples registry and sees every sample in one table. The
technician narrows the table by type, by status and by a text fragment of the code.
Filters combine, apply as the technician changes them, and the table states how
many samples match.

**State:** 🟡 Planned
**Priority:** Core

## Actor
A laboratory technician.

## Preconditions
- `P1` — actor(technician) — the technician holds a session in the demo console.

## Main flow
1. `B1` — The technician opens the registry and sees the samples, newest first,
   with code, patient reference, type, collection date and status per row.
2. `B2` — The technician selects a type; the table shows only samples of that type.
3. `B3` — The technician selects a status; the table shows only samples matching
   both filters.
4. `B4` — The technician types part of a code; the table shows only samples whose
   code contains that fragment, still within both filters.
5. `B5` — The technician clears the filters and sees every sample again.

## Alternative flows
### AF-1: More samples than one page
The registry holds more samples than one page shows. The technician loads the next
page from the end of the table and the filters stay applied.

## Error flows
### EF-1: Registry unavailable
The registry does not answer. The table shows a failure message and a retry control;
the filters keep their values.

## Postconditions
- `Q1` — The technician sees the samples that match the current filters and the
  count of matches.

## Acceptance criteria
- [ ] AC-1: With no filter set, the table lists every sample ordered by collection date descending, with the columns code, patient reference, type, collection date and status.
- [ ] AC-2: Selecting a type shows only samples of that type; the count above the table equals the number of rows.
- [ ] AC-3: Type, status and code filters combine with AND; a sample appears only when it satisfies every active filter.
- [ ] AC-4: The code filter matches a case-insensitive substring; the fragment "brc" matches the code "BRC-0042".
- [ ] AC-5: Filters that match no sample show an empty-state message and a count of zero, and no error.
- [ ] AC-6: The table shows 20 samples per page; when more match, a control at the end loads the next 20 with the same filters applied.
- [ ] AC-7: When the registry request fails, the table shows a failure message with a retry control, and the filter values remain unchanged.
- [ ] AC-8: The page writes the active filters into the URL, and opening that URL renders the table with the same filters applied.
