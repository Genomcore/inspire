---
kind: inspire-code-profile
id: react
layer: frontend
language: typescript
---

## Layering
Presentation stays dumb; logic flows outward through thin layers. **Components** —
render + local UI state only; no business logic, no direct data access. **Hooks** —
orchestrate state and side effects, expose intent to components. **Use-cases /
services** — the business logic, framework-free where possible. **Repository /
infrastructure** — all data access behind an interface, with a mock/real switch so
the UI is testable without a backend. Global state in a dedicated store, not in
prop-drilled component state.

## Test conventions
- **Unit / component** — the component test runner + Testing Library; query by role
  first (`getByRole` > `getByText` > `getByTestId`), assert what the user sees, not
  internals.
- **E2E** — the project's browser test runner against the running app.
- GIVEN/WHEN/THEN. **Mocks are centralized** (a `tests/**/mocks/` layer), never
  inline per-test; a test overrides only the fields it cares about.
- Run: `npm run test` · `npm run test:e2e`.

## Forbidden patterns
- **No business logic or data fetching in components** — push it to a hook /
  use-case.
- **No inline mocks** — register them in the shared mock layer.
- **No hardcoded user-facing strings** — labels, errors, and tooltips go through the
  i18n / constants layer.
- **Sanitize external URLs** before using them in `href`/navigation; never
  `dangerouslySetInnerHTML` with unsanitized input.

## Review focus
- **styling**: uses the design-system tokens (`05_screens/design-system.md`) and the
  shared component layer; no hardcoded colors/spacing, no ad-hoc one-off styles.
- **accessibility**: interactive elements are keyboard-navigable with correct roles,
  labels, and focus management; forms announce errors.
- **security**: forms, auth, and navigation validate input and guard against
  XSS/open-redirect.

## Build & verify
build: `npm run build` · lint: `npm run lint` · types: `npx tsc --noEmit` ·
tests: `npm run test` + `npm run test:e2e`

**Monorepo scoping.** In a workspace, scope every command to the target surface's
package: `pnpm --filter {package} build|lint|test` (or the workspace tool's
equivalent — `npm -w {package} …`, `turbo run test --filter={package}`, `nx test
{package}`). Never run a workspace-wide install or build from a subcommand when a
filtered form exists; a UI surface is verified by its own package going green.

## Routes

> **Seed.** A default this template ships, not a rule INSPIRE enforces — edit it to
> match the project's real routing. See [`README.md`](README.md) § Seeds.

A screen's route is **derived from its `module:` + `screen:` frontmatter**, never
from its file path and never from its `id` string: a collision-minted
`admin.users.list` whose frontmatter says `module: users`, `screen: list` still
routes to `/users/list`, with no doubled surface segment.

- **Route** = `/{module}/{screen}`, both kebab-cased (`user_profile` →
  `user-profile`).
- A screen named `index` renders the module's landing route, `/{module}`.
- **The surface contributes only its shell prefix.** The roster's `**Shell:**`
  value already carries its own leading slash
  (`inspire-surface/references/roster-format.md:76`), so the rendering is a plain
  concatenation, `{shell}{route}`, with no separator in between — a suite-of-one
  renders `{route}` alone, with no prefix. Example: shell `/admin` + route
  `/users/list` → `/admin/users/list`. (A12 states the shape as
  `{shell}/{route}`; that notation reads a slash between the two parts, which is
  already inside `{shell}` — quote A12 verbatim only when citing it, and use the
  concatenation above to render an actual route.)
- A screen whose data binding identifies a single entity appends `/:{param}`, named
  after the identifying input (`/users/detail/:userId`).
- **One route table per surface**, generated from the screen set (`src/routes.tsx`).
  No route string is ever authored twice: the screen file's frontmatter is the only
  place a module and screen name live.
- Navigation targets screens **by id** and resolves through this same rule, so a
  route and a screen can never disagree — and moving a screen between surfaces
  changes no route.

## Bindings

> **Seed**, as above.

How a screen's `## Bindings` keys reach an action. One generated client function per
action, named from the dotted id in camelCase — `auth.user.list` → `authUserList()` —
living in the surface's `api/` layer (the repository layer of `## Layering`). Its
transport is the backend profile's binding table; the two sections are the two ends
of one wire.

- **Query or mutation** is decided by the action's postconditions, not by naming: a
  `created` / `updated` / `deleted` head (vocabulary V4 of
  [`keyed-heads.md`](../../_references/keyed-heads.md)) makes it a mutation;
  anything else is a query.
- **Data keys** → one query hook per key, `use{ActionIdCamelCased}` (`useAuthUserList`),
  with cache key `['{screen-id}', '{key}']` so a screen binding the same action twice
  stays two independent reads.
- **Dispatch keys** → one mutation hook per key, named the same way. The row's
  **On success** / **On error** attributes become its `onSuccess` / `onError`,
  rendering whichever of the three declared forms is present: a navigation
  outcome (`→ [[{screen-id}]]`) resolves through `## Routes` by screen id; a
  state outcome (`` state `{key}` ``) writes the named state key; a refresh
  outcome (`` refresh `{key}` ``) invalidates that data key's cache entry,
  `['{screen-id}', '{key}']` (the same key `## Bindings` mints above), so the
  next read re-fetches.
- **State keys** → a slice of the screen's own store, keyed by the declared key.
  Nothing is lifted to global state unless another screen's bindings name it.
- **Nav keys** → `navigate(routeOf('{target screen id}'))`, never a literal path.
- Components never call the client directly (see `## Forbidden patterns`) — the hook
  is its only caller.

## Persistence

**Not applicable.** A UI surface owns no store: every write leaves through a dispatch
binding to a backend action, and that surface's profile owns the persistence
convention. Browser storage here is UI state — a remembered filter, a draft — never a
source of truth, and never the home of anything a claim asserts.

## Declaration-only tree

The recipe is the language profile's ([`typescript.md`](typescript.md) § Declaration-only
tree). Component and hook signatures survive as `.d.ts`, props types included; JSX
bodies do not. Routes are absent from a packed tree — the test phase derives them
from `## Routes` above rather than reading a router file.
