---
kind: inspire-code-profile
id: react
layer: frontend
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
