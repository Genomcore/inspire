---
name: inspire-code-react
description: "React stack conventions: layering, tests, forbidden patterns, quality gates, build commands and seed conventions. Use when writing or testing code in a React package."
stack: react
layer: frontend
language: typescript
---

Rules here use MUST, MUST NOT, SHOULD and MAY (RFC 2119). MUST and MUST NOT are
required: code that breaks one is wrong. SHOULD is the default; depart from it only
with the reason written in the code or the commit. MAY is optional. A **Seed**
section is the project's own convention: code MUST follow it exactly as written
until the project edits it.

## Layering
Presentation stays dumb; logic flows outward through thin layers. **Components** —
render + local UI state only; no business logic, no direct data access. **Hooks** —
orchestrate state and side effects, expose intent to components. **Use-cases /
services** — the business logic, framework-free where possible. **Repository /
infrastructure** — all data access behind an interface, with a mock/real switch so
the UI is testable without a backend. Global state in a dedicated store, not in
prop-drilled component state.

- Components MUST NOT access data; a hook MUST be the only caller of the `api/` client.

Module boundaries: not yet formulated for this stack — deliberately deferred to a
frontend iteration that exercises them, rather than transcribed untested from the
backend rules. The contract in [_references/stack-skills.md](../_references/stack-skills.md) still applies; this line is the deferral,
not the answer.

## Test conventions
- **Unit / component** — the component test runner + Testing Library; queries SHOULD
  go by role first (`getByRole` > `getByText` > `getByTestId`), assert what the user sees, not
  internals.
- **E2E** — the project's browser test runner against the running app.
- GIVEN/WHEN/THEN. **Mocks MUST be centralized** in a `tests/**/mocks/` layer and
  MUST NOT be defined inline per test; a test overrides only the fields it cares about.
- Run: `npm run test` · `npm run test:e2e`.
- The authoring detail — the GIVEN/WHEN/THEN comment discipline and the centralized
  mock architecture with its extension steps — lives in
  [`references/testing.md`](references/testing.md); read it before
  writing or modifying any spec or mock.

## Forbidden patterns
- **No business logic or data fetching in components** — push it to a hook /
  use-case.
- Tests MUST NOT define mocks inline — register them in the shared mock layer.
- User-facing strings MUST NOT be hardcoded — labels, errors and tooltips go through
  the i18n / constants layer.
- External URLs MUST be sanitized before use in `href`/navigation, and
  `dangerouslySetInnerHTML` MUST NOT receive unsanitized input.
- Code MUST NOT read anything from a screen id's shape — no `id.split('.')`, no prefix
  match: a screen's module, face and route come from the route table (§ Routes).

## Review focus
- **styling**: uses the design-system tokens (`01_spec/_design-system/design-system.tokens.json`, plus the face's own `{face}.tokens.json` when it has one; meanings in `01_spec/_design-system/design-system.md`; a token `{color.primary}` is the CSS custom property `--color-primary`) and the
  shared component layer; no hardcoded colors/spacing, no ad-hoc one-off styles.
- **accessibility**: interactive elements MUST be keyboard-navigable with correct roles,
  labels and focus management, and forms MUST announce errors.
- **security**: forms, auth and navigation MUST validate input and guard against
  XSS/open-redirect.

## Quality gates
Not yet formulated for this stack — the backend profile's gates were measured on a
real NestJS codebase, and this stack has had no equivalent iteration; transcribing
them here untested is exactly what [`quality-gates.md`](../_references/quality-gates.md)
Rule 2 forbids dressing up as adoption. The rules themselves still bind: a project on
this stack derives its own `## Quality gates` (and the `gates:` frontmatter that lets
`.inspire/bin/profile-gates-installed.sh` verify them) from a frontend iteration that
exercises each rule before writing it down. The shared-toolchain candidates are
obvious — the type-aware `typescript/no-unsafe-*` rules and `typescript/ban-ts-comment`
in `.oxlintrc.json`, the escape-hatch ratchet — and the React-only ground (oxlint's
`react/rules-of-hooks` and `react/exhaustive-deps`, its `jsx-a11y` plugin, a bundle-size
budget) is where the measuring has to happen. This section is the deferral, not the answer.

## Build & verify
build: `npm run build` · lint: `npm run lint` (`oxlint`) · format: `npx oxfmt --check` ·
types: `npx tsgo --noEmit` · tests: `npm run test` (`vitest run`) + `npm run test:e2e`

The default toolchain is **oxlint** with `oxlint-tsgolint` for the type-aware rules,
**oxfmt** for formatting, **tsgo** (`@typescript/native-preview`) for type checking and
**Vitest** for unit and component tests, transforming through SWC
(`@vitejs/plugin-react-swc`). A project whose `stack.md` names other tools uses its own
commands.

**Monorepo scoping.** In a workspace, scope every command to the target face's or
bundle's package (its `package` field): `pnpm --filter {package} build|lint|test` (or the workspace tool's
equivalent — `npm -w {package} …`, `turbo run test --filter={package}`, `nx test
{package}`). Never run a workspace-wide install or build from a subcommand when a
filtered form exists; a face is verified by its own package going green.

## Routes

> **Seed.** The project's routing convention: code MUST follow it exactly as written.
> The project MAY edit it to match its real routing. See [`stack-skills.md`](../_references/stack-skills.md) § Seeds.

A screen's route is **derived from its `module:` + `screen:` frontmatter**, never
from its file path and never from its `id` string: a screen `admin.user-list`
whose frontmatter says `module: users`, `screen: list` routes to `/users/list`
inside its face's shell, with no face segment of its own.

- **Route** = `/{module}/{screen}`, both kebab-cased (`user_profile` →
  `user-profile`).
- A screen named `index` renders the module's landing route, `/{module}`.
- **The face contributes only its shell prefix.** The `shell` in `{face}.face.md`
  already carries its own leading slash
  ([inspire-face/references/face-format.md](../inspire-face/references/face-format.md)), so the rendering is a plain
  concatenation, `{shell}{route}`, with no separator in between — a face with no
  `shell` renders `{route}` alone, with no prefix. Example: shell `/admin` + route
  `/users/list` → `/admin/users/list`. (The notation `{shell}/{module}/{screen}`
  reads a slash between shell and route, which is already inside `{shell}` — use
  the concatenation above to render an actual route.)
- A screen whose data binding identifies a single entity appends `/:{param}`, named
  after the identifying input (`/users/detail/:userId`).
- There MUST be **one route table per face**, generated from the face's screens
  (`src/routes.tsx`). No route string is ever authored twice: the screen file's
  frontmatter is the only place a module and screen name live.
- Code MUST resolve every route through a `routeOf('{screen id}')` helper built from that
  table; a literal path string MUST NOT appear outside the route table.
- The route table also carries each screen's `module` and `face`, from the same
  frontmatter. Code that needs either one (the shell's active entry, a breadcrumb, a
  per-module guard) reads it through `moduleOf('{screen id}')` / `faceOf('{screen id}')`
  helpers built from that table, never from the id string: a screen id's first segment
  is its face, not its module, and a migration can rewrite an id while the frontmatter
  stays.
- Navigation targets screens **by id** and resolves through this same rule, so a
  route and a screen can never disagree. Moving a screen to another face changes its
  id and its shell prefix, and nothing else of its route.

## Bindings

> **Seed**, as above.

How a screen's `## Bindings` keys reach an action. There MUST be one client function per
action, named from the dotted id in camelCase — `auth.user.list` → `authUserList()` —
living in the face's `api/` layer (the repository layer of `## Layering`). Its
transport is the backend profile's binding table; the two sections are the two ends
of one wire.

- **Query or mutation** is decided by the action's postconditions, not by naming: a
  `created` / `updated` / `deleted` head (vocabulary V4 of
  [`keyed-heads.md`](../_references/keyed-heads.md)) makes it a mutation;
  anything else is a query.
- **Data keys** → MUST be one query hook per key, `use{ActionIdCamelCased}`
  (`useAuthUserList`), built on TanStack Query (`@tanstack/react-query`, added with the
  first data key if the project lacks it) unless the project names another query
  cache, with cache key `['{screen-id}', '{key}']` so a screen binding the same action twice
  stays two independent reads.
- **Dispatch keys** → MUST be one mutation hook per key, named the same way. The row's
  **On success** / **On error** attributes become its `onSuccess` / `onError`,
  rendering whichever of the three declared forms is present: a navigation
  outcome (`→ [{screen-id}]({path})`) resolves through `## Routes` by screen id; a
  state outcome (`` state `{key}` ``) writes the named state key; a refresh
  outcome (`` refresh `{key}` ``) invalidates that data key's cache entry,
  `['{screen-id}', '{key}']` (the same key `## Bindings` mints above), so the
  next read re-fetches.
- **State keys** → a slice of the screen's own store, keyed by the declared key.
  Nothing is lifted to global state unless another screen's bindings name it.
- **Nav keys** → MUST use `navigate(routeOf('{target screen id}'))`, never a literal path.
- Components MUST NOT call the client directly (see `## Forbidden patterns`) — the hook
  is its only caller.

## Persistence

**Not applicable.** A face owns no store: every write leaves through a dispatch
binding to a backend action, and that action's profile owns the persistence
convention. Browser storage here is UI state — a remembered filter, a draft — never a
source of truth, and never the home of anything a claim asserts.

## Declaration-only tree

The recipe is the language profile's ([`inspire-code-typescript`](../inspire-code-typescript/SKILL.md) § Declaration-only
tree). Component and hook signatures survive as `.d.ts`, props types included; JSX
bodies do not. Routes are absent from a packed tree — the test phase derives them
from `## Routes` above rather than reading a router file.

## References

- [`references/testing.md`](references/testing.md) — the spec-authoring
  detail: GIVEN/WHEN/THEN comment discipline, the centralized mock architecture and
  how to extend it. Read before writing or modifying any spec or mock.
