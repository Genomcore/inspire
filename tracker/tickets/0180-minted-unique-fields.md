---
id: 0180-minted-unique-fields
title: "0180 — a unique field the action mints itself still demands a conflict error"
created: 2026-11-16
updated: 2026-11-16
reporter: "@djessy.czaplicki"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: Mid
skills: [domain]
status: Open
blocked_by: []
related_to: [FB5-exists-precondition-error]
---

## Origin

A governed project on INSPIRE 0.18.0 hit this while getting its domain ready for its first
Factory run. Its 42 draft entities and actions pass `review.sh` at `draft`. When they are
promoted to `accepted`, five `OS-X1` findings become errors. Four of the five are on values
that no caller supplies:

| Action | Field written | Where the value comes from |
|---|---|---|
| `accounts::session::create` | `session.token` | a random secret the auth library issues |
| `accounts::user::create` | `session.token` | the same |
| `accounts::user::create` | `credential.user_id` | `from {user.id}`, the user this action creates |
| `sharing::invite::create` | `invite.token` | 32 random bytes |
| `sharing::invite::create` | `invite.inviter_id` | the caller; one invite per person |

Only `invite.inviter_id` is a business key. Two concurrent first requests from the same person
can collide on it, and the action's contract has to say what happens then.

## Description

### What happens today

- **`OS-X1` exempts only `id`.** `plugin/base/bin/head-referents.sh` requires a
  `unique(<field>)` error head on every action that writes a `unique` field. Its header comment
  exempts `id` because "the action mints the value, so no caller can collide with it", and says
  the check targets "BUSINESS-KEY uniqueness — the email, the slug, the external id a caller
  supplies". The code applies that reasoning to the field named `id` and to nothing else.
- **The Factory refuses the same shape.** `orchestrator/src/contracts/validate-domain.ts`
  repeats the join with the same `field.field === 'id'` exemption, so a unit stops on it.
- **The mapping cannot tell a generated secret from an external value.** In
  `inspire-domain/references/type-mapping.md`, `—` means "a read column for keys, or a field
  supplied externally". A random token written by the action has no token of its own, so its
  mapping is `—`, which a check cannot tell apart from a value supplied from outside.

The workaround is an error head for a conflict that cannot happen, such as
`token_conflict — unique(token)`. It puts an error in the contract that no caller can cause.
The Factory then builds a handler for it and a test that can only trigger it by mocking the
generator.

### What this ticket asks for

- **Exempt written fields whose mapping the action mints itself:** `uuid()`, `now()`,
  `today()`, and `from {R.field}` when `R` is an entity this same action creates. The rule is
  the one the `id` exemption already states, applied by mapping instead of by field name.
- **Add a mapping token for a generated secret,** for example `random({bytes})`, so a token
  field states that the action mints it. The language profiles say how it expands.
- **Keep `current_user` and `input.*` in the check.** A value the caller determines is a
  business key, as `invite.inviter_id` is.
- **Update `keyed-heads.md`'s `OS-X1` row** and the `head-referents.sh` header so both state
  the exemption by mapping.

### Open question

- Is a random secret collision-free enough to exempt, or should the contract still describe the
  retry on a collision? If the answer is to keep the error head, this ticket closes Done for
  the secrets with no code changed, and only the `from {R.field}` case ships.

## Acceptance criteria

- [ ] `head-referents.sh` reports no `OS-X1` for a written `unique` field mapped `uuid()`,
      `now()`, `today()`, the new secret token, or `from {R.field}` with `R` created by the
      same action. Fixtures cover each case.
- [ ] A written `unique` field mapped `input.*`, `current_user` or `—` still reports `OS-X1`,
      and a fixture covers it.
- [ ] `type-mapping.md` defines the secret token, and every shipped language profile renders
      it.
- [ ] `keyed-heads.md`'s `OS-X1` row and the `head-referents.sh` header state the exemption by
      mapping.
- [ ] The open question has a written answer in this ticket's close note.

## Notes

- Related to `FB5-exists-precondition-error`: both are joins between a head and the errors an
  action declares.
- **Factory port, filed when this ships:** `validate-domain.ts` applies the same exemption by
  mapping, so the deriver and `head-referents.sh` refuse the same shapes.
