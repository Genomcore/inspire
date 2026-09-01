---
kind: inspire-code-profile
id: _example                 # a real profile's id matches its stack.md `profiles:` entry
layer: backend               # frontend | backend | data | tooling
---

<!--
Annotated skeleton. Copy it to `profiles/<id>.md`, set `id` + `layer`, and fill the
sections. Keep it lean and declarative — conventions, not a tutorial. Framework
rules only: nothing here should be domain-specific or org policy (see README.md).
Delete these comments in a real profile.
-->

## Layering
<!-- Where each kind of code lives, and the architectural shape. One short paragraph,
     plus the module-boundary answers below — a profile that leaves them out decides
     them ad hoc on the day the second module arrives.
     Feeds review Phase 1 (architecture) and the implementation shape in `tdd`. -->
Business logic in <where>; entry/boundary code in <where>; data access behind
<abstraction>. Keep <what> out of <where>.
Module boundaries: a module exposes <what — e.g. its application services> and nothing
below it; generic external-system code (client, value rendering, failure
classification) lives in <shared home> from its FIRST use, exporting only the client;
connection configuration carries no entity knowledge (table/collection names belong to
the owning module).

## Test conventions
<!-- Test tools, what each level means here, how to run them. Feeds `tdd` + review Phase 4. -->
Unit tests <tool> mock <boundary>; integration/e2e <tool> use the real <thing>.
GIVEN/WHEN/THEN. Run: `<test cmd>` · `<e2e cmd>`.

## Forbidden patterns
<!-- Stack-specific anti-patterns beyond the universal authoring rules in tdd.md. -->
- <anti-pattern> — <do this instead>.

## Review focus
<!-- Extra dimensions `review` adds to its fan-out for this stack. Lens + one line. -->
- <lens>: <what it hunts for>.

## Quality gates
<!-- How this stack mechanically enforces _references/quality-gates.md. Split the
     list: absolutes belong to the linter (local, binary — the agent self-corrects);
     aggregates get a ratchet whose baseline lives outside the repo. Tools and rules
     only, never an org's server or pipeline. -->
**Absolute** (linter): `<rule>` · `<rule>` — <what each one refuses>.
**Ratcheted** (aggregates): <metric> via `<package>` — <why it can't be absolute yet>.
**Escape hatches**: `<suppression syntax this stack allows>` — the rule that refuses an
undescribed one, and the counted set whose ceiling may only fall.
**Dropped, with the reason**: <rule that does not hold for this stack> — <why, and what
covers the gap instead>. A rule left out silently reads as a rule nobody thought of.

## Build & verify
<!-- The concrete commands. `fix-build`, `review`, `debug` use these, not guesses. -->
build: `<cmd>` · lint: `<cmd>` · types: `<cmd>`

## References
<!-- Optional. Deep material under profiles/<id>/references/, read only when needed. -->
- <file>.md — <what it covers>
