---
produced:
  skill: feature
  skill_sha: 7aff836
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---
# LND-03: Tour the modules

> Source: [[../../02_modules/landing]]

The visitor walks through the platform one module per row: a name, one or two
sentences, and a real capture of the prototype console. The tour follows the current
classification of eleven core modules plus five extensions; the landing shows the
nine modules the brief names and groups Apps and Extensions in one row.

**State:** 🟡 Planned
**Priority:** Important
**Depends on:** [[LND-02]]

## Actor
A bioinformatician or platform engineer checking whether the platform covers their
workloads.

## Preconditions
- `P1` — A prototype capture exists for each module row.

## Main flow
1. `B1` — The visitor reaches the tour and reads the module rows in this order:
   Datastore, Filesystem, Runtime, Automation, AI Agents, Auth, Audit, Messaging,
   Apps & Extensions.
2. `B2` — For each row the visitor reads the name, the description and sees the
   capture.
3. `B3` — The visitor opens a capture at full size and closes it again.

## Alternative flows
### AF-1: Capture missing
A row has no capture yet. The row renders the name and description with a neutral
placeholder box of the same aspect ratio, and the page reports no broken image.

## Error flows
None.

## Postconditions
- `Q1` — The visitor has seen every module row with its description.

## Acceptance criteria
- [ ] AC-1: The tour renders exactly nine rows, in the order Datastore, Filesystem, Runtime, Automation, AI Agents, Auth, Audit, Messaging, Apps & Extensions.
- [ ] AC-2: Every row has a name, a description of one or two sentences, and an image element with a non-empty alt text naming the module.
- [ ] AC-3: Clicking a capture opens it at its natural size in an overlay; pressing Escape or clicking outside closes the overlay.
- [ ] AC-4: A row whose capture file is absent renders a placeholder with the same aspect ratio and triggers no browser image error.
- [ ] AC-5: The row for Apps & Extensions names Genomics Studio as a first-party app.
