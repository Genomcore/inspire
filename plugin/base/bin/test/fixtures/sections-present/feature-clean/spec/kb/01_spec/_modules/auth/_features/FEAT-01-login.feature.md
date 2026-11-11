---
# surfaces: [console]   # blast radius
---

# FEAT-01: Operator sign-in

> Source: [[../../02_modules/auth]]

An operator signs in with an email and a password and receives a session.

**State:** 🟡 Planned
<!-- State ladder: 🟡 Planned → 🔵 In progress → 🟢 Implemented. -->
**Priority:** Core

## Actor
Operator

## Preconditions
The operator has an account.

## Main flow
1. The operator submits email and password.
2. The system issues a session.

## Alternative flows
### AF-1: Already signed in

## Error flows
### EF-1: Wrong password

## Postconditions
A session exists for the operator.

## Acceptance criteria
<!-- ids are stable: never renumber; a new criterion takes the next free id; never reuse a deleted id; gaps are legal -->
- [x] AC-1: A valid email and password yields a session.
- [ ] AC-3: A wrong password returns a generic error, and this wrapped
  continuation line is not itself a criterion.
  - the indented sub-bullet elaborating AC-3 is not a criterion either
- [X] AC-7: A session expires after 30 minutes of inactivity.
