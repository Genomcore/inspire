# Quality gates

The lint, coverage and escape-hatch rules of this stack in full: which are absolute,
which are ratcheted, which are dropped and why, and how test files are relaxed.

Contents: **Absolute** · **Ratcheted** · **Dropped, with the reason** · **Escape
hatches** · test-file relaxations.

## Quality gates
**Absolute** (oxlint, configured in `.oxlintrc.json` — the agent hits these in its own
loop and fixes them before anything reaches the operator):
- **Type-aware linting on** — `"options": { "typeAware": true }`, with `oxlint-tsgolint`
  installed beside `oxlint`. The `typescript/no-unsafe-*` rules need type information;
  without the option oxlint skips them and reports nothing, which reads as clean.
- **The strict `any` and non-null rules, by name.** oxlint has no counterpart to
  typescript-eslint's `strictTypeChecked` preset, so the part of it this stack relies on
  is enabled rule by rule: `typescript/no-non-null-assertion` · `typescript/no-explicit-any`
  · `typescript/no-unsafe-argument` · `typescript/no-unsafe-assignment` ·
  `typescript/no-unsafe-call` · `typescript/no-unsafe-member-access` ·
  `typescript/no-unsafe-return`. The rest of that preset is not implied: a rule it carried
  is in force only when `.oxlintrc.json` names it, and a rule oxlint does not implement
  has no equivalent here.
- `max-depth` · `max-lines-per-function` · `max-lines`. Two caveats measured rather than
  assumed, both about the rule fitting the file kind: `max-lines-per-function` fires on
  every `describe` block, since a suite callback is a function to the linter — off for
  test files, with the reason written. `max-lines` fires on field-declaration files (a
  DTO with 300 property decorators is wide, not complex) — off for `dto/` and generated
  type modules, in force everywhere else.
- **`complexity` is deliberately NOT adopted** (Rule 2's third branch). Measured before
  adopting, its hits are characteristically false positives: a `switch` dispatching a
  dozen query operators to one-line cases scores ~15 cyclomatic while being trivially
  readable. Cyclomatic complexity counts branches, and a dispatch table is all branches and no
  complexity; splitting one to satisfy the rule makes the code worse. Adopt a *cognitive*
  complexity rule instead if the need is real; oxlint ships none today.
- `import/no-cycle` (the `import` plugin), plus the four-layer boundary above as a build
  error instead of a review comment (controllers → application → infrastructure → domain;
  `domain/` imports nothing). oxlint has no `no-restricted-paths`, so the boundary is
  `no-restricted-imports`, set once per layer in an `overrides` entry: `files:
  ["src/*/domain/**"]` refuses an import whose specifier names `application`,
  `infrastructure` or `controllers` (a `patterns` entry with a `regex` such as
  `(^|/)(application|infrastructure|controllers)(/|$)`); `src/*/infrastructure/**`
  refuses `application` and `controllers`; `src/*/application/**` refuses `controllers`.
  Two things to know, both measured:
  - **Resolution is built in.** oxlint resolves imports itself and reads the
    `tsconfig.json` `paths`, so `import/no-cycle` follows relative and `@/` imports with
    no resolver to wire.
  - **The boundary matches the import specifier, not the resolved file.** The glob in
    `files` covers every module on disk, so a new module is inside the boundary from its
    first file; but an import that reaches a layer without naming its directory (a
    barrel re-export, say) passes. Import a layer through its directory name.
- The `vitest` plugin: `vitest/expect-expect` (a test that asserts nothing — the
  characteristic failure of generated tests) · `vitest/no-disabled-tests` ·
  `vitest/no-focused-tests` · `vitest/no-conditional-expect`.
- **A local rule worth authoring: a test may not import a *numeric* constant from the
  code it tests.** This is the lint half of "never build the expected value from the code
  under test": a threshold imported into a test makes the test move with the code, so
  changing `MAX_CONDITION_DEPTH` from 10 to 11 leaves the suite green while an observable
  limit changed — a mutation that survives suites that otherwise look thorough.
  Scoped to **numbers**, and the distinction is the whole reason it has no false
  positives: a number is a threshold whose value a caller observes, so a test must state
  it as a literal; a string / object / array constant is usually a registry or schema
  (the field list a DDL is generated from), where deriving is the point and hard-coding
  forty names would duplicate the source of truth. In oxlint it is a JS plugin
  (`jsPlugins` in `.oxlintrc.json`, ESLint's rule API) — a rule this project-shaped needs
  no package. oxlint gives a JS plugin **no type information**, so the rule decides
  "numeric" from the exported constant's initializer (a numeric literal) rather than from
  the type checker; a constant computed from other constants escapes it. That is why the
  template cannot ship it as a `gates:` entry: a project that adopts it declares the gate
  in its own copy of this profile, and the literal must be the **activation line,
  severity included** (`"local/…": "error"`), never the bare rule name, which also
  appears in the rule's definition and would match with the rule switched off.

  Why lint and not the drill: the drill finds a weak test after the fact and only when
  someone runs it, and it **cannot tell a weak test from a shortcut fix to one** — pinning
  `expect(MAX_CONDITION_DEPTH).toBe(10)` satisfies the drill while testing no behaviour at
  all. Lint refuses it at the moment of writing.

**Ratcheted** (aggregates; baseline kept outside the repo per Rule 3):
- **coverage** — `npm run test -- --coverage` (`@vitest/coverage-v8`);
  `coverage.thresholds` in `vitest.config.ts` is the in-repo
  floor, the history lives in the metrics service. Set the floor to **what is measured
  today**, per metric, and raise it as work lands: the absolute value carries no claim,
  the direction does.
  Read the number honestly, because two things distort it. `coverage.include` counts
  declaration-heavy files (a DTO that is all field decorators, generated types), which
  drags statements down without any behaviour going unchecked; and the **e2e suite runs
  under its own Vitest config, so it contributes nothing to this number** — which is where
  most acceptance criteria are actually covered. A low statements floor beside a high
  branch floor is the expected shape, not a defect to explain away.
  With `## Test conventions` above in force, `application/` and `domain/` should measure
  at or near 100% on their own — a gap there is a missing unit spec, not noise; the drag
  on the aggregate comes from declaration-heavy files, never from untested logic.

**Dropped, with the reason** (Rule 2's third branch — a rule that does not hold here
is written down, never silently missing):
- **mutation score as a ratcheted metric.** Coverage proves a line ran, not that a
  test would fail if its behavior changed — so the gap is real. It is closed per-diff
  by a **mutation drill** — mutate each changed line's behavior and confirm a test fails —
  with the agent as the mutation engine, not by a repo-wide score. Consequence, stated
  plainly: there is **no aggregate number** for test strength in this stack, and the
  drill is bounded to changed files — code that predates the drill is not covered by
  it. What buys the trade is that a diff-scoped drill needs no tool to own, no baseline
  to store, and no CI budget to defend.
- **Property-based testing** (`fast-check`) is the complement for `domain/` — pure
  types and rules with invariants. It tests the code with varied inputs; the drill
  tests the tests. Neither replaces the other.

**Escape hatches** (Rule 4 — the linter allows or refuses each one, never a count):
- `typescript/ban-ts-comment` with `"ts-expect-error": "allow-with-description"` and
  `"ts-ignore": true` — `@ts-expect-error` permitted with a reason, `@ts-ignore` never
  (expect-error expires by itself when the underlying error is fixed).
- `"options": { "reportUnusedDisableDirectives": "error" }` — a stale suppression is an
  error rather than a fossil. oxlint reports it only when this option is set.
- `typescript/no-explicit-any` and `typescript/no-non-null-assertion` (above) refuse
  `as any` and `x!`. A hatch no rule refuses is allowed; there is no count of them.
- **The rest is a local JS plugin**, because oxlint has no `eslint-plugin-eslint-comments`
  and no `no-restricted-syntax`, and the ESLint plugin itself crashes under oxlint's JS
  plugin host. Copy
  [`oxlint-escape-hatches.mjs`](../../inspire-code-typescript/references/oxlint-escape-hatches.mjs)
  into the package, list it in `jsPlugins`, and turn on its three rules at `error`:
  - `escape-hatches/require-reason` — a disable directive names its rules and says why
    after `--` (`require-description` and `no-unlimited-disable`);
  - `escape-hatches/no-restricted-disable`, with the refused rules as its option
    (`["typescript/no-explicit-any", "typescript/no-non-null-assertion"]`) — no inline
    comment re-allows what the config refuses (`no-restricted-disable`). It matches the
    rule name without its plugin prefix, because oxlint honours
    `@typescript-eslint/no-explicit-any` and a bare `no-explicit-any` in a directive too,
    and it refuses any directive that names one of the plugin's own rules;
  - `escape-hatches/no-double-cast` — refuses `as unknown as`, which no oxlint rule does.

  oxlint's JS plugins are **alpha**, so these three rules stand on an experimental host.
  Two disables still get past them, both measured: a bare `/* oxlint-disable */`
  switches off every rule from its line on, the plugin's included, and an
  `oxlint-disable-line` that names the plugin's rules silences their report on its own
  line. Both are visible in the diff, and refusing them needs a check that runs outside
  the linter.
- A refusal a spec file needs (the negative-path cast below) is a config override, never
  a disable.
- On existing code with too many hatches to refuse today, the refusal still goes in at
  `error`, and an `overrides` entry turns the rule off for the files that already break it,
  listed by path. oxlint keeps no bulk-suppression file, so that list is the baseline: a
  new file is refused from its first line, and a file leaves the list when its cleanup
  (a `/inspire-task` ticket) lands.

Test-file relaxations are enumerated **per rule with a written reason**. Two legitimate
cases, and they are different in kind:

- **Untyped response boundaries** — HTTP/GraphQL payloads the types cannot prove. Debt:
  it shrinks as the boundary gets modelled.
- **Negative-path construction** — a test that feeds the wrong type to a validator
  (`null as unknown as string`) needs a cast, because the type system preventing it is
  the whole point of the code under test. **Structural, not debt**: the spec-file
  override that allows it is permanent, and the config says so — an override that
  invites a cleanup which cannot happen trains people to ignore it.

Never a blanket disable of the correctness rules for `**/*.spec.ts`.
