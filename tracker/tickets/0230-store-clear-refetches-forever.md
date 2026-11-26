---
id: 0230-store-clear-refetches-forever
title: "0230 — a store key cleared on error is fetched again in an endless loop"
created: 2026-11-25
updated: 2026-11-25
reporter: "@djessy.czaplicki"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: High
skills: [code]
status: Open
blocked_by: []
related_to: []
---

## Description

Met on the `wishlist-app` bench case (INSPIRE 0.23.0, Factory 0.25.0, 2026-11-25, run
`run-nFlgdn`). It stopped the `shell` layout, and so held back every screen of the run.

### What happened

The face's store holds the server key `me`, read by the `shell`. The `shell` keeps a reader of
`me` mounted on every route. When the session is missing, the reload of `me` fails as
`unauthenticated`, and the store's outcome for that class is `clear`. The agent built it as
`inspire-code-react` asks: `queryClient.removeQueries(['store', 'me'])`. The mounted
`useStoreMe` sees its query gone, builds it again, fetches, fails, and the query is removed
again. The agent counted 190 calls to `/api/auth/get-session` in 300 ms, could not make the
`shell`'s tests pass, and stopped the unit.

The 2026-11-16 build of the same KB (INSPIRE 0.18.0) never met this: it had no store unit.

### What happens today

`inspire-code-react/SKILL.md` § Store, **On error**: "`clear` removes the query
(`queryClient.removeQueries`)". The rule came with the store in INSPIRE 0.21.0 (`2b6bb147`).
TanStack Query builds a removed query again for an observer that is still mounted, and that
query has no data, so it fetches. `clear` on a key that a mounted component reads is then an
endless fetch loop while the failure lasts. A server key read by the shell, `me` first of all,
is always mounted.

### What this ticket asks for

- `clear` leaves the key empty without starting a fetch while a reader is mounted, and the
  next fetch happens only on the key's own triggers (`start-up`, `first read`,
  ``on change of `k` ``, or a ``refresh store `k` ``).
- The rule is written in `inspire-code-react` § Store, with the API call it uses.
- A test in the skill's testing guidance: a mounted reader of a key whose fetch fails with a
  `clear` outcome makes one request, not more.

### Open questions

- `setQueryData(['store', '{key}'], null)` after `cancelQueries`, or a query function that
  turns the `clear` class into `null` data instead of an error? The second keeps the error out
  of the cache and is how most apps read the current user.
- Does the same loop exist with a navigate outcome that lands on a route the shell still
  frames?

## Acceptance criteria

- [ ] `inspire-code-react` § Store says how `clear` empties a key, and the call it names does
      not refetch while a reader is mounted.
- [ ] A fixture app with a mounted reader of `me` and a failing session makes one session
      request, and shows the signed-out state.

