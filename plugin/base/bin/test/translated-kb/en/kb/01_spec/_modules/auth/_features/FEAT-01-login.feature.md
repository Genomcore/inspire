# FEAT-01: Operator sign-in

A registered operator signs in.

**State:** 🟡 Planned
**Priority:** Core

## UC1: Actor
A registered operator.

## UC2: Preconditions
- `P1` — The account exists and is not suspended.

## UC3: Main flow
1. `B1` — The operator submits credentials.
2. `B2` — The system verifies them.

## UC4: Alternative flows
### AF-1: A remembered device

## UC5: Error flows
### EF-1: A wrong password

## UC6: Postconditions
- `Q1` — A session exists for the operator.

## UC7: Acceptance criteria
- [ ] AC-1: A correct pair yields a session.
