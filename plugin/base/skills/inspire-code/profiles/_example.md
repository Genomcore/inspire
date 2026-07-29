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
<!-- Where each kind of code lives, and the architectural shape. One short paragraph.
     Feeds review Phase 1 (architecture) and the implementation shape in `tdd`. -->
Business logic in <where>; entry/boundary code in <where>; data access behind
<abstraction>. Keep <what> out of <where>.

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

## Build & verify
<!-- The concrete commands. `fix-build`, `review`, `debug` use these, not guesses. -->
build: `<cmd>` · lint: `<cmd>` · types: `<cmd>`

## References
<!-- Optional. Deep material under profiles/<id>/references/, read only when needed. -->
- <file>.md — <what it covers>
