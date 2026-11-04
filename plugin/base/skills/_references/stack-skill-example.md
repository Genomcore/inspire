---
name: inspire-code-_example
description: "<Framework> stack conventions. Use when writing or testing code in a <Framework> package."
stack: _example              # matches the id in stack.md `profiles:`
layer: backend               # frontend | backend | data | tooling — or `language`
language: <language id>      # framework profiles only: the language profile to compose with
---

<!--
Annotated skeleton for a FRAMEWORK stack skill. Copy it to
`.claude/skills/<name>/SKILL.md`, set `name`, `description`, `stack`, `layer` +
`language`, and fill the sections. Keep it lean and declarative —
conventions, not a tutorial. Framework rules only: nothing here should be
domain-specific or org policy (see stack-skills.md). Delete these comments in a
real skill.

A LANGUAGE profile (`layer: language`, no `language:` field) has a different section
set — Rendering · Mapping tokens · Project semantic types · Engine notes ·
Declaration-only tree — and no architecture sections at all. `inspire-code-typescript`
is the shipped worked example; stack-skills.md § File format has its skeleton.
-->

## Layering
<!-- Where each kind of code lives, and the architectural shape. One short paragraph,
     plus the module-boundary answers below — a profile that leaves them out decides
     them ad hoc on the day the second module arrives.
     Feeds the architecture review and the implementation shape. -->
Business logic in <where>; entry/boundary code in <where>; data access behind
<abstraction>. Keep <what> out of <where>.
Module boundaries: a module exposes <what — e.g. its application services> and nothing
below it; generic external-system code (client, value rendering, failure
classification) lives in <shared home> from its FIRST use, exporting only the client;
connection configuration carries no entity knowledge (table/collection names belong to
the owning module).

## Test conventions
<!-- Test tools, what each level means here, how to run them. -->
Unit tests <tool> mock <boundary>; integration/e2e <tool> use the real <thing>.
GIVEN/WHEN/THEN. Run: `<test cmd>` · `<e2e cmd>`.

## Forbidden patterns
<!-- Stack-specific anti-patterns beyond the universal authoring rules. -->
- <anti-pattern> — <do this instead>.

## Review focus
<!-- Extra review dimensions for this stack. Lens + one line. -->
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
<!-- The concrete commands, so nobody has to guess them. -->
build: `<cmd>` · lint: `<cmd>` · types: `<cmd>`

## Bindings
<!-- SEED — project-owned, freely edited. How `{module}::{entity}::{verb}` becomes an
     invocable surface, derived from the id alone: no per-action authoring. Say what
     the five CRUD verbs map to and what any other verb maps to, plus how the
     `actor({role})` precondition becomes a guard. A surface exposing nothing says so.
     On a `layer: backend` profile this section derives three claims per action
     (`{action}/binding/route|dispatch|guard`), see derived-contract.md. -->
`{module}::{entity}::{verb}` → <shape>. Other verbs → <shape>.
Guard: `actor({role})` → <guard>; no actor precondition → <public>.

## Routes
<!-- SEED — UI profiles only; delete otherwise. Screen `module:` + `screen:` → route.
     Never the file path, never the id string. Say what the surface shell contributes.
     The roster's `**Shell:**` value already carries its own leading slash, so the
     shell and route concatenate with no separator: `{shell}{route}`, e.g. `/admin` +
     `/users/list` → `/admin/users/list`; a suite-of-one renders `<route>` alone. -->
`{module}` + `{screen}` → `<route>`; surface shell prefix → `{shell}<route>` (no
separator — the shell's leading slash is already there).

## Persistence
<!-- SEED — the ORM, entity→table and field→column naming, keys, and the migration
     rule (append-shaped: re-emanation appends, never edits history). A surface that
     stores nothing writes "Not applicable" and why. -->
ORM <name>. Entity → `<table>`; field → `<column>`; column types from the language
profile. Migrations in `<dir>`, append-only.

## Declaration-only tree
<!-- Required on a language profile (it owns the recipe); on a framework profile an
     optional addendum naming what the stripping loses here. -->
Recipe: the language profile's. Lost here: <what>, recovered from <which section>.

## References
<!-- Optional. Deep material under the skill's references/, read only when needed. -->
- <file>.md — <what it covers>
