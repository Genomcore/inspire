---
id: users.home
module: users
screen: home
lifecycle: stable
---

# People

**Features:** FEAT-01

## Purpose

An administrator lands here and opens the roster. The screen is delivered, so it
would be the slice's way in — but it still carries the retired section an older
INSPIRE wrote, which derive refuses to read rather than read as empty. Plan can
therefore rule it neither in nor out.

## Bindings

### Data

| Key | Action | Notes |
|---|---|---|
| `summary` | [[auth.user.list\|auth::user::list]] | the headline counts |

### Navigation

| Key | Target | Trigger |
|---|---|---|
| `browse` | [[users.list]] | opening the roster |

### States

| Key | When | Presentation |
|---|---|---|
| `empty` | `summary` returns zero rows | the no-accounts-yet message |

## Instantiation

The retired section: what a pre-0.8 screen file spelled its layout adoption in.
