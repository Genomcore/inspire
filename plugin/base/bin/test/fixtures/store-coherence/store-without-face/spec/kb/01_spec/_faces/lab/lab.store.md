---
lifecycle: accepted
---

# Store: portal

## STO1: Purpose

What the portal keeps between screens.

## STO2: Server keys

| Key | Action | Load | On error | Notes |
|---|---|---|---|---|
| `me` | [auth::user::me](../../_modules/auth/_domain/user/user.me.action.md) | start-up | → [portal.studies](../portal/_screens/studies.screen.md) | the signed-in user |
| `studies` | [studies::study::list](../../_modules/studies/_domain/study/study.list.action.md) | first read | — | |
| `study` | [studies::study::get](../../_modules/studies/_domain/study/study.get.action.md) | on change of `currentStudyId` | clear | |

## STO3: Client keys

| Key | Type | Initial | Persist | Notes |
|---|---|---|---|---|
| `currentStudyId` | id | — | local | the study being worked on |

## STO4: On error

| Class | Outcome |
|---|---|
| `unauthenticated` | → [portal.studies](../portal/_screens/studies.screen.md) |
| `other` | keep |
