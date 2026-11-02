---
id: samples.list
module: samples
screen: list
lifecycle: accepted
produced:
  skill: screens
  skill_sha: e7152c6
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---

# Samples

**Features:** SMP-01, SMP-02
**Pattern:** [[../patterns/list]]

## Purpose

A laboratory technician comes here to find a sample among those the laboratory has
received and to register a new one. The table of samples leads, newest collection
first, with the three filters above it; the registration form opens from the primary
action without leaving the table.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `main` | [[samples.sample.list\|samples::sample::list]] | the table feed; the screen passes the three filter values and a page size of 20 |

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [[samples.sample.create\|samples::sample::create]] | submitting the registration form | refresh `main` | state `form-error` |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `main` returns zero rows | the empty-collection message, the count at zero, the filters kept |
| `error` | `main` rejects | the failure message and a retry control; the filters keep their values |
| `more` | `main` returns a `next_cursor` | a load-more control at the end of the table |
| `form-open` | the technician presses the primary action, before `create` runs | the registration form with code, patient reference, type and collection date |
| `form-error` | `create` rejects | the form stays open with each offending field marked; `code_exists` marks the code field with its message |

## Module-specific deviations

- The toolbar holds three filters: a type select, a status select and a code text
  field. Changing any of them refreshes `main` at once and writes the values into the
  URL query, which the screen reads back on load.
- The status bar shows the `total` of `main` as "N samples".
- The registration form opens in a dialog over the table; closing it without
  submitting changes nothing.

## Current prototype

- **Target:** `prototype/` root, `/samples/list`, run with `npm run dev` inside `prototype/`
- **Drift:**
  - data wiring — the prototype filters and inserts in memory; nothing calls `samples::sample::list` or `::create`
