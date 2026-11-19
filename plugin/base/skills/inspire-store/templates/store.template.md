---
lifecycle: draft
---

# Store: {Face display name}

## STO1: Purpose

{One paragraph: what this face keeps between screens, and why no single screen can hold it.}

## STO2: Server keys

| Key | Action | Load | On error | Notes |
|---|---|---|---|---|
| `{key}` | [{module}::{entity}::{action}](../../_modules/{module}/_domain/{entity}/{entity}.{action}.action.md) | {start-up · first read · on change of `{key}`} | {— · keep · clear · → [{face}.{slug}](_screens/{slug}.screen.md)} | {what it holds} |

## STO3: Client keys

| Key | Type | Initial | Persist | Notes |
|---|---|---|---|---|
| `{key}` | {semantic type} | {value, or —} | {none · session · local} | {what it holds} |

## STO4: On error

| Class | Outcome |
|---|---|
| `{unauthenticated · forbidden · not-found · unavailable · other}` | {keep · clear · → [{face}.{slug}](_screens/{slug}.screen.md)} |
