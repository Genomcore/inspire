# Semantic types — the project's own

_The types this project adds to the universal semantic vocabulary. The universal
vocabulary itself — what `email`, `uuid`, `timestamp` and the rest mean — lives in
[type-mapping](../../.claude/skills/inspire-domain/references/type-mapping.md) and is
not edited here. This file ships **empty**: a project that has needed no type of its
own declares none, which is the honest state of most projects._

| Type | Base type | Means / predicate | Rendering |
|------|-----------|-------------------|-----------|

**Type** — the name as it appears in a descriptor's `Type` column. Lowercase,
underscore-separated, never an alias of a universal type (`text`, `int` and friends
are rejected: see type-mapping).

**Base type** — **mandatory**, one of the universal types. It is what makes a project
type safe to declare: a language profile that carries no explicit row for the type
renders it exactly as its base type, in every target. Pick the universal type whose
predicate this one narrows.

**Means / predicate** — one line: what a value of this type is, and what makes it
valid. Narrower than the base type's predicate, never wider.

**Rendering** — `—` when the base type's rendering is right (the common case), or the
id of the language profile that carries an explicit row for this type
(`.claude/skills/inspire-code/profiles/{id}.md`). Adding the row and naming the
profile here are one act; a type naming a profile that has no row for it is a
readiness error, exactly as a type with no base type is.

> Declaring a type here is a **plain edit** — it neither needs an ADR nor changes the
> runtime. Adding a type every project would recognize is the opposite: that belongs
> in the universal vocabulary, as a change to INSPIRE itself.
