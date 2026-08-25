# FEAT-01: Login

> Source: [[../../02_modules/auth]]

A registered user signs in.

**State:** 🟡 Planned
**Priority:** Core

## Actor
Registered user

## Preconditions
- `P1` — The account exists and is not suspended.

## Main flow
1. The user submits credentials.
2. The system verifies them.

## Alternative flows
### AF-1: Remembered device

## Error flows
### EF-1: Wrong password

## Postconditions
- `Q1` — A session exists for the user.

## Acceptance criteria
- [ ] AC-1: A correct pair yields a session.
