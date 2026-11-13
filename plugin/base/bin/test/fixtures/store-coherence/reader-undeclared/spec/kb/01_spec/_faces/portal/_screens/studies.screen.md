---
id: portal.studies
module: studies
screen: list
lifecycle: accepted
---

# list

**Features:** FEAT-01

## Purpose

A researcher comes here to work on studies.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `current` | store `ghost` | |

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [studies::study::create](../../../_modules/studies/_domain/study/study.create.action.md) | primary action | refresh store `currentStudyId` | — |

### Navigation

| Key | Target | Trigger | Then |
|---|---|---|---|
| `row` | [portal.study-detail](study-detail.screen.md) param `id` | clicking a row | set store `study` from param `id` |

