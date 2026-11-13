# FEAT-01: Operator sign-in

An operator signs in.

## Actor
Operator

## Preconditions
The operator has an account.

## Main flow
1. The operator submits email and password.

## Alternative flows
### AF-1: Already signed in

## Error flows
### EF-1: Wrong password

## Postconditions
A session exists for the operator.

## Acceptance criteria
- [ ] AC-1: A valid email and password yields a [session](../../../_adr/sessions.adr.md).
- [ ] AC-2: A wrong password returns a [generic error](a.md)[again](b.md).
- [x] AC-2: A session expires after 30 minutes of inactivity.
