# Production-code standards beyond the lint gates

Two conventions the toolchain cannot fully enforce, referenced from
`## Forbidden patterns` in [`../../nestjs.md`](../../nestjs.md). The universal
authoring rules (never silence the toolchain, never swallow errors, no anonymous
TODOs, no commented-out code) live in the generic
[`tdd.md`](../../../references/tdd.md) and are not repeated here.

## Audit every meaningful domain mutation

Operational logging (`this.logger.error/warn/log`) and **audit logging are a
different concern**: the audit emitter writes a *typed* event to the project's audit
sink for traceability.

**Rule:** every meaningful domain mutation (create, update, delete) emits a typed
audit event in the **service (application) layer**, on **success**:

- **Success only, by default.** If the write throws, the action did not happen — do
  not emit a success audit for it.
- **Audit the failed attempt too only when the attempt itself is the fact of
  record** — e.g. sending an email/notification: emit success on delivery and error
  on failure under the same event name, so the intent stays traceable. This is the
  exception, not the rule.
- **Meaningful mutations only.** Derived/bookkeeping writes (updating a cache field
  like `lastMessageAt`) and incidental find-or-create side writes are deliberately
  NOT audited. Audit domain-meaningful events, not every DB round-trip.
- **Layer:** the service that owns the mutation — never the controller or the
  repository. (A guard may emit one for a security-relevant rejection, e.g. a failed
  signature check.)
- **Shape:** a stable UPPERCASE event name plus a payload keyed by the domain entity,
  type-checked against a per-API payload union so a new event extends the type.
- **Wrapping:** inline the call for a single event; extract a small private
  `log<Event>()` helper when the emit is conditional, reused, or the method produces
  several outcomes.

This is independent of error handling: a write can emit both an operational error log
and an audit event in the same flow. The test-side half — audit events asserted in
every write test, operational logging never asserted — is in
[`testing.md`](testing.md).

Changing the emitted shape of an audit event already in production is a **consumer
migration, not a refactor**: whatever reads the audit sink (dashboards, alerts, saved
searches) breaks silently on a field-path change. Identify the consumers first, and
update them in the same change — or leave the event alone.

## Encode the invariant in the type when you can — keep the runtime check regardless

Some invariants live **entirely in the type system**. Null-safety is the main one:
with `strictNullChecks`, a `string` parameter simply cannot be null, and
`NonNullable<T>` needs no runtime check because `null`/`undefined` are part of the
*type*. (Never recover non-null-ness with the forbidden `!` operator; narrow with
`if (x)`, `??`, or a type guard, or take `NonNullable<T>` in the signature.)

Constraints TypeScript has no built-in for — non-empty, positive, finite — can still
be modeled so literal misuse fails at compile time:

```typescript
type NonEmptyArray<T> = [T, ...T[]];

// `[]` no longer compiles
async removeLineItems({ orderId, skus }: { orderId: string; skus: NonEmptyArray<string> }): Promise<void>
```

**The catch — and why the runtime check still lives in the service:** the type only
protects values whose shape TypeScript can *prove*. A literal `['a', 'b']` satisfies
`NonEmptyArray<string>`; a `string[]` coming from JSON, a request body, or a DB row
does **not** — and the consumer is forced either to cast
(`as NonEmptyArray<string>`, which **defeats** the guarantee) or to validate. So the
two techniques are complementary:

```typescript
// runtime proof → narrows the variable so it satisfies the typed signature
function assertNonEmpty<T>(items: T[], context: string): asserts items is NonEmptyArray<T> {
  if (items.length === 0) {
    throw new Error(`${context}: items must not be empty`);
  }
}

async removeLineItems({ orderId, skus }: { orderId: string; skus: string[] }): Promise<void> {
  assertNonEmpty(skus, 'removeLineItems'); // skus is now NonEmptyArray<string>
  await this.orderRepository.removeLineItems({ orderId, skus });
}
```

Rule of thumb: **type the invariant to catch literal misuse at compile time, but keep
the runtime assertion in the service**, because external data is the realistic input
and TypeScript cannot prove it. Never reach for `as NonEmptyArray<…>` to silence the
type — that is the `as`-cast escape hatch the quality gates already ratchet; validate
instead. Where the check lives follows the profile's layering rule: the DTO when
there is a controller, the service when there is not, never the repository.
