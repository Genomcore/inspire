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
| `rows` | [studies::study::list](../../../_modules/studies/_domain/study/study.list.action.md) | the table |
| `current` | store `studies` | the cached list |

### Dispatches

| Key | Action | Trigger | On success | On error |
|---|---|---|---|---|
| `create` | [studies::study::create](../../../_modules/studies/_domain/study/study.create.action.md) | primary action | → [portal.study-detail](study-detail.screen.md) param `id`; state `error` | set store `studies` |

### Navigation

| Key | Target | Trigger | Then |
|---|---|---|---|
| `row` | [portal.study-detail](study-detail.screen.md) param `id` | clicking a row | remember the study |
| `other` | [portal.study-detail](study-detail.screen.md) param `id` | clicking the title | set store `currentStudyId` from param `slug` |

### States

| Key | When | Presentation |
|---|---|---|
| `error` | `create` rejects | the failure message |

