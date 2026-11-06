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
- [ ] AC-1: A valid email and password yields a session.
- The operator sees an error when the password is wrong.
