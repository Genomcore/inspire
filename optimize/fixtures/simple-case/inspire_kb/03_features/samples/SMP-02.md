---
produced:
  skill: feature
  skill_sha: 7aff836
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---
# SMP-02: Register a sample

> Source: [[../../02_modules/samples]]

From the registry, a lab technician registers a sample the laboratory has just
received: code, patient reference, type and collection date. The registry rejects a
code already in use. On success the new sample appears in the table.

**State:** 🟡 Planned
**Priority:** Core
**Depends on:** [[SMP-01]]

## Actor
A laboratory technician.

## Preconditions
- `P1` — actor(technician) — the technician holds a session in the demo console.

## Main flow
1. `B1` — The technician opens the registration form from the registry.
2. `B2` — The technician enters code, patient reference, type and collection date.
3. `B3` — The technician submits; the registry stores the sample with status
   "received".
4. `B4` — The form closes and the table shows the new sample, matching the current
   filters or not, at the position its collection date gives it.

## Alternative flows
### AF-1: Cancel
The technician closes the form without submitting. Nothing changes.

## Error flows
### EF-1: Code already in use
The registry holds a sample with that code. The form stays open and marks the code
field with the conflict message.

### EF-2: Invalid input
A required field is empty, or the collection date is in the future. The form stays
open and marks each offending field.

## Postconditions
- `Q1` — created(samples.sample) — one sample exists with the entered values and
  status "received".

## Acceptance criteria
- [ ] AC-1: Submitting code, patient reference, type and a collection date not after today creates one sample with status "received" and the entered values.
- [ ] AC-2: After a successful submit, the form closes and the table contains a row for the new sample when it matches the active filters.
- [ ] AC-3: Submitting a code that another sample carries, compared case-insensitively, keeps the form open and marks the code field with the message "A sample with this code already exists".
- [ ] AC-4: Submitting with an empty value in any of code, patient reference, type or collection date keeps the form open and marks each empty field.
- [ ] AC-5: Submitting a collection date later than today keeps the form open and marks the date field.
- [ ] AC-6: A code is 3 to 32 characters of letters, digits and hyphens; anything else marks the code field.
- [ ] AC-7: Closing the form without submitting creates no sample and leaves the table unchanged.
