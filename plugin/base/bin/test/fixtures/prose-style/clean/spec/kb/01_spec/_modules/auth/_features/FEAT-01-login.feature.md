# FEAT-01: Operator sign-in

## Actor

An operator of the tenant.

## Preconditions

The operator holds an account.

## Main flow

1. The operator submits an email and a password.
2. The system issues a session.

## Alternative flows

### AF-1: Already signed in

## Error flows

### EF-1: A wrong password

## Postconditions

A session exists for the operator.

## Acceptance criteria

- [ ] AC-1: A valid email with a valid password yields a session.
