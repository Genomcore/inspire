---
kind: inspire-code-profile
id: angular
layer: frontend
language: typescript
---

## Layering
Presentation stays dumb; logic flows outward through services. **Smart
components** (containers) — orchestrate state, dispatch/select, navigate; no
rendering detail. **Dumb components** (presentational) — inputs in, outputs
out, `OnPush`, no store or HTTP access. **Services** — business logic and data
access via `inject()`; HTTP behind a service layer (or repository abstraction),
never called from a component. **State** — signals for local and service
state (`signal`/`computed`/`linkedSignal`); a global store (NgRx, where the
project adopts it) for cross-feature state; derived data computed in
selectors/`computed`, never stored. `OnPush` everywhere; new references, never
mutation.

Module boundaries: features live under `@features/*` behind lazy-loaded
routes and expose their routes plus public services — another feature never
imports their internals. Cross-cutting singletons (auth, interceptors, guards,
the API client) go to `@core/*` at first use; presentational components,
pipes, and directives with no feature knowledge go to `@shared/*`. The
project's selector and SCSS class prefixes are declared once (per
`angular.json` / lint config) and used everywhere.

## Test conventions
- **Unit / component** — Jasmine + TestBed (Karma runner); unit specs colocated
  (`*.spec.ts`). Signal inputs set via `fixture.componentRef.setInput()`; HTTP
  via `provideHttpClientTesting()` + `HttpTestingController` with
  `httpMock.verify()` in `afterEach`; dependencies mocked with typed
  `jasmine.createSpyObj`, signal-based services mocked with real signals. CDK
  component harnesses for Material-heavy components.
- **Component (Cypress)** — where the project adopts Cypress component testing:
  `*.cy.ts` alongside the component, mounted with `@cypress/angular`, covering
  interactions, visual states, and emitted events; business logic stays in
  service specs.
- **E2E** — Playwright against the running app (`e2e/*.spec.ts`), asserting
  what the user observes.
- GIVEN/WHEN/THEN. Shared test data: 1-2 lines inline, larger sets in
  `*.spec.data.ts` next to the spec — never duplicated across specs. Expected
  user-facing text asserted against the centralized constants / i18n keys, not
  hardcoded; expected values traced, never guessed.
- Run: `npm run test` · `npm run test:e2e` (and `npm run cy:test-components`
  where Cypress is adopted).

## Forbidden patterns
- **No business logic, store access, or HTTP in dumb components** — inputs and
  outputs only; push logic to a service or the container.
- **No state mutation under OnPush** — always new references; `markForCheck()`
  after async callbacks that update local state (or signals, which need
  neither).
- **No subscription without cleanup** — `takeUntilDestroyed` / `takeUntil` /
  async pipe; a bare `.subscribe()` in a component is a leak.
- **No custom structural directives for control flow** — native
  `@if`/`@for`/`@switch`; new templates use the new control-flow syntax.
- **No `@for` without a meaningful `track`** — track a unique id, never the
  object reference.
- **No function calls in template bindings** — pure pipes or `computed`.
- **No hardcoded user-facing strings** — everything through the i18n layer.
- DI: an abstract class as the contract when there are several
  implementations — never interface + string token + `@Inject`.
- **No hardcoded colors/spacing** — design tokens only; `::ng-deep` only
  scoped under `:host`.
- **No barrel Material imports** — import each `Mat*Module` specifically.
- **No derived data stored in state** — compute it in selectors / `computed`.

## Review focus
- **styling**: uses the design tokens and BEM naming with the project's class
  prefix (`05_screens/design-system.md`); no ad-hoc values, no unscoped
  `::ng-deep`.
- **accessibility**: correct roles, labels, and aria attributes; keyboard
  operability; aria-labels match the values they describe; forms announce
  errors.
- **performance**: OnPush + signals, `track` in loops, `@defer` for heavy or
  below-fold subtrees, memoized selectors, no leaked subscriptions.
- **state**: state lives at the right level (signal vs service vs store);
  effects use the right flattening operator (`switchMap` for cancel-previous,
  `exhaustMap` for submit, `concatMap` for ordered writes).
- **ssr-safety** (when the project uses `@angular/ssr`): no direct
  `window`/`document` outside `afterNextRender`/platform guards; no
  server/client content mismatches.

## Quality gates
Prose only for now — this stack ships no machine-checkable `gates:` block yet;
a project derives one from an iteration that exercises each rule (Rule 2 of
[`quality-gates.md`](../../_references/quality-gates.md) forbids transcribing
untested gates). The candidates this profile's conventions already imply:
- **angular-eslint** with the template accessibility rules enabled — the
  a11y review lens above is only trustworthy when the mechanical half runs.
- **typescript-eslint `strictTypeChecked`** and `ban-ts-comment` at
  `allow-with-description` — shared-toolchain candidates, same reasoning as
  the backend profile.
- **Bundle budgets** in `angular.json` (`initial`, `anyComponentStyle`) —
  the build-time ratchet this stack gets for free; a budget bump is a diff.
- **Coverage** via `ng test --code-coverage`, floor set to what is measured
  today and only raised.
Escape hatches and their ratchet follow the shared rules in
`quality-gates.md`; nothing Angular-specific replaces them.

## Build & verify
build: `ng build` (`-c production` for release) · lint: `ng lint` ·
types: `npx tsc --noEmit` · tests: `npm run test` + `npm run test:e2e` ·
bundle: `ng build -c production --stats-json` + esbuild-visualizer.

**Workspace scoping.** In a multi-project workspace, scope every command to
the target project: `ng build {project}` · `ng test {project}` · `ng serve
{project}` (or the workspace tool's equivalent — `nx test {project}`, `pnpm
--filter {package} …`). Never run a workspace-wide build from a subcommand
when a scoped form exists; a UI surface is verified by its own project going
green.

## References
Deep material under [`angular/references/`](angular/references/), read on demand:
- [components.md](angular/references/components.md) — component declaration, smart/dumb, OnPush, control flow, Material/ag-Grid patterns, communication, component tests.
- [di.md](angular/references/di.md) — `inject()`, provider scopes, tokens, abstract-class contracts, DestroyRef cleanup, testing with DI.
- [directives.md](angular/references/directives.md) — attribute/structural/host directives, composition API, observer-based directives.
- [forms.md](angular/references/forms.md) — typed reactive forms, validation, FormArray, ControlValueAccessor custom controls.
- [http.md](angular/references/http.md) — HttpClient, `resource()`/`httpResource()`, interceptors, caching, pagination, HTTP tests.
- [ngrx.md](angular/references/ngrx.md) — actions/reducers/selectors/effects, ComponentStore, persistence, NgRx tests. Only when the project uses NgRx.
- [performance.md](angular/references/performance.md) — change detection, lazy loading, `@defer`, virtual scroll, leak prevention, the runtime checklist.
- [routing.md](angular/references/routing.md) — lazy routes, functional guards, resolvers, signal route params, preloading.
- [signals.md](angular/references/signals.md) — `signal`/`computed`/`linkedSignal`/`effect`, RxJS interop, the signal store pattern.
- [ssr.md](angular/references/ssr.md) — render modes, hydration, browser-only code, TransferState, SEO. Only when the project uses `@angular/ssr`.
- [styles.md](angular/references/styles.md) — the two-layer token system, BEM conventions, Material overrides, responsive patterns.
- [testing.md](angular/references/testing.md) — TestBed patterns, signals/OnPush testing, harnesses, router/forms/directive/pipe tests, Playwright, Cypress conventions.
- [tooling.md](angular/references/tooling.md) — CLI generation, builds, budgets, workspaces, path aliases, proxies, CI examples.
