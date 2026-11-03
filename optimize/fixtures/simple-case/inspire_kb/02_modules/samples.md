---
kind: module-hub
prefix: SMP
produced:
  skill: module
  skill_sha: 915520b
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---

# Samples

> The module **hub** — overview, relationships, and links to everything this module
> owns across the layers. Kept in sync with the per-layer subfolders.

## Overview

The demo console of this repository: a registry of biological samples a laboratory
receives. A lab technician sees the samples in one table, narrows it by type, status
and code, and registers a new sample from the same screen. The module exists to
exercise one full vertical slice, screen to database, through INSPIRE.

Each sample carries a code the laboratory assigns, a patient reference, a type
(blood, saliva, tissue), the collection date and a processing status (received,
processing, analyzed).

## Relationships

The landing module links here through its "See live demo" call to action. The
module depends on no other module and shares no entity.

## Use cases

Features live in [`../03_features/samples/`](../03_features/samples) — the glob is the index.

## Screens

_[`../05_screens/samples/`](../05_screens/samples) — the module's screens; the route
map + coverage table live in that folder's `_index.md`._

## Domain

_[`../04_domain/samples/`](../04_domain/samples) — action descriptors + entity
documents for this module._

## Module ADRs

_Decisions scoped to this module (`adr-SMP-*` in [`../01_adr/`](../01_adr)):_

None yet.
