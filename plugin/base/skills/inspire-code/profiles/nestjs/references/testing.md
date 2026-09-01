# NestJS test-authoring conventions

The fine-grained authoring rules behind `## Test conventions` in
[`../../nestjs.md`](../../nestjs.md): how a spec is *written* once the level is chosen.
The level choice itself (unit vs e2e, what each suite covers) lives in the profile;
this file is the style the chosen spec follows.

The helpers named here (`Mother`, `convertToHttpResponse`,
`Expect.throwStrictEqualError`, `Expect.arrayIsEqualIndistinctOrder`) come from no
package: **the first spec that needs one writes it** — a few lines each, semantics
specified below — into the project's shared test support (`test/support/`), and every
later spec reuses it instead of repeating the pattern inline. The names and semantics
are the contract; the implementation is authored once, in the project.

## GIVEN / WHEN / THEN

```typescript
it("should find record by id when record exists", async () => {
  // GIVEN
  const projectId = 123;
  const record = new RecordMother().make({ projectId });
  await recordFixture.insert(record);

  // WHEN
  const result = await recordService.findById(record.id);

  // THEN
  expect(result).toEqual(record);
});
```

- **GIVEN**: setup. Method-under-test arguments at the end, close to WHEN.
- **WHEN**: single statement executing the logic under test.
- **THEN**: all assertions. Variables used only for assertions (`expectedError`,
  `expectedField`, …) are defined HERE — never in GIVEN or WHEN.
- Blank line before `// THEN` and before dependency-call assertions.
- **Group expects by concern** with a blank line between every group. Typical order:
  returned-value assertions → mock/dependency verifications → audit-log
  verifications. Any distinct concern (`expect(result)…` vs
  `expect(mockedService.method)…`) is its own group, even when only two groups are
  present.
- **One group per dependency in the mock-verification block.** Each distinct
  mock/collaborator is its own group, separated by a blank line — never merge
  assertions on different dependencies into one block. The two assertions on the
  *same* mock (`toHaveBeenCalledTimes(n)` + `toHaveBeenCalledWith(...)`, or a single
  `not.toHaveBeenCalled()`) stay together in that group.
- **Keep together** in GIVEN: object creation and its immediate method calls.
  **Separate** with a blank line: different objects.
- **Group each mock stub with the value it consumes.** Declare the value on the line
  directly above its `mockReturnValue`/`mockResolvedValue`, blank line between one
  stub-group and the next. Never let an unrelated stub sit between a value and the
  stub that uses it, and never inline a value that belongs to a different stub.

  ```typescript
  // Wrong — inboundEmail belongs to toInboundEmail, but getEnvelope splits them
  const inboundEmail = buildInboundEmail({ recipients: [recipient] });
  strategy.getEnvelope.mockReturnValue(faker.string.uuid());
  strategy.toInboundEmail.mockResolvedValue(inboundEmail);
  channelConfigService.findByInboundEmail.mockResolvedValue(new ChannelConfigMother().make({ inboundEmail: recipient }));

  // Right — one value per stub, directly above it, blank line between groups
  const envelope = faker.string.uuid();
  strategy.getEnvelope.mockReturnValue(envelope);

  const inboundEmail = buildInboundEmail({ recipients: [recipient] });
  strategy.toInboundEmail.mockResolvedValue(inboundEmail);

  const channelConfig = new ChannelConfigMother().make({ inboundEmail: recipient });
  channelConfigService.findByInboundEmail.mockResolvedValue(channelConfig);
  ```

  Shared inputs used by several stubs (e.g. `recipient`, method-under-test arguments)
  stay grouped at the top of GIVEN, above the stub-groups.

## Mothers (test-data builders)

One Object-Mother per entity, all extending a single abstract `Mother<T>` base class
the project writes once — the abstraction exists so invocation is identical for every
entity. A mother generates **every field randomly** (faker) and `make(overrides)`
merges the fields the test needs fixed:

```typescript
const record = new RecordMother().make({ projectId }); // projectId pinned, rest random
```

Only specify the fields significant to the test; the randomness of the rest is the
point — each run exercises the code with different data, so an accidental dependency
on an unspecified field surfaces as a flaky red instead of hiding behind a constant.
`makeByList(overrides[])` builds collections the same way.

## Fixtures (database setup)

Helpers in `test/fixtures/` for inserting data. Use mothers internally. Each e2e test
prepares its own data.

```typescript
await recordFixture.insert(new RecordMother().make({ projectId }));
```

**Reading back is also a fixture.** DB reads live in `test/fixtures/` too —
`getRecordsInDb(app)` — never an inline model/table query in the test. Split the query
from the mapping across two statements. Full shape:
[`db-assertions.md`](db-assertions.md).

A setup fixture takes a single object of **partial** overrides
(`{ record, owner, members }`), defaults each, and builds collections via the mother's
`makeByList(overrides[])` — never a positional list of fully-built entities.

## Mocking

**Never** hand-roll mock objects — use a typed auto-mock library
(`jest-mock-extended`):

```typescript
// Never
const mockProvider: EmailProvider = {
  sendEmail: jest.fn().mockResolvedValue(undefined),
};

// Always
let emailProvider: MockProxy<EmailProvider>;
beforeEach(() => {
  emailProvider = mock<EmailProvider>();
});
```

- Verify mock calls in EVERY test: `toHaveBeenCalledTimes(n)` +
  `toHaveBeenNthCalledWith(n, …args)`. A dependency the path under test must NOT
  reach is asserted too, with `not.toHaveBeenCalled()` — silence is not an assertion,
  and it is what lets a later change start calling it unnoticed.
- **Audit events are asserted in every write test — operational logging never is.**
  Where the project has a typed audit emitter (see the audit rule in
  [`coding-standards.md`](coding-standards.md)), every create/update/delete test
  asserts the success event (level + event name + payload), and attempt-audited flows
  (e.g. sending an email) assert the failure event too. Operational logging
  (`error`/`warn`/`log`) is a debugging aid, not a contract — do not assert it.
- E2E external HTTP via `nock`; `nock.cleanAll()` in `afterEach`.
- E2E tests **never override providers** — real providers + nock.

## Nock helpers (e2e)

Static helper class per external API in `test/mocks/<api-name>.http-mock.ts`; methods
return `nock.Scope` so tests call `.done()`. Naming `<action>With<Outcome>Response`;
single `args` object. Full template: [`nock-helpers.md`](nock-helpers.md).

## Assertions

### Errors — `toStrictEqual` with cause

Always validate class + message + cause. `toThrow('msg')` is incomplete (ignores
cause and class drift).

```typescript
// Async
await expect(promise).rejects.toStrictEqual(
  new Error("Failed to send email", { cause: error }),
);

// Sync — via the project's throw-capture helper
Expect.throwStrictEqualError({ callback, expectedError });
```

Custom exception classes, nested causes, and anti-patterns:
[`error-assertions.md`](error-assertions.md).

### HTTP — assert the FULL body, not properties piecemeal

```typescript
// Wrong — partial
expect(response.body.statusCode).toEqual(HttpStatus.BAD_REQUEST);
expect(response.body.message).toMatch(/^foo/);

// Right — complete shape
expect(response.body).toEqual({
  statusCode: HttpStatus.BAD_REQUEST,
  message: "Validation failed",
  error: "Bad Request",
});
```

`statusCode` (HTTP-level) can be asserted separately as `response.statusCode`, but
anything checked on `response.body` MUST cover the full body.

### DB state — assert the FULL document, from the domain entity

After a mutation, re-read the affected collection(s) via the read fixture and assert
the **whole document**, never isolated fields. Re-read **every** collection the
request could touch, including the ones that must stay **unchanged** (assert they are
intact); an empty collection is asserted too (`[]`). Order-sensitive:
`toEqual([...])`. Order-indifferent: `Expect.arrayIsEqualIndistinctOrder(expected,
actual)` — the written-once helper for comparing two arrays when order does not
matter (`arrayContaining` + a length check; matchers go in the **first** argument,
where it applies them). Worked examples: [`db-assertions.md`](db-assertions.md).

### Build the expected from the domain entity, never from the value under test

The object passed to `toEqual` must NOT be derived from `response.body` (nor from
variables extracted out of it) — comparing the response against itself proves
nothing. Build the expected from the inserted **domain entity**:

- HTTP body: a `convertToHttpResponse(entity)` / `convertArrayToHttpResponse(entities)`
  helper (serializes dates, recurses, rewrites an `anyDate()` matcher to `anyString()`).
- DB document: a `map<Entity>DomainToModel(entity)` mapper. Mappers named `*DomainTo*`
  take **domain interfaces** as input.
- Per-test changes are overrides on the domain object
  (`{ ...record, status: Status.CLOSED, updatedAt: anyDate() }`), never edits to the
  produced object.
- Server-generated values use the typed matcher helpers `anyString()`, `anyDate()`,
  `anyObjectId()` — the only sanctioned use of `expect.any` (see "Avoid weak
  matchers").

### Use enums, never string literals

In expected objects and arguments use the enum, not its raw value:
`type: ContactType.INTERNAL` (not `'internal'`). String literals drift silently when
the enum changes.

### Always capture and assert the awaited result

Never write a bare `await service.method(...)` line. Capture into
`const result = await ...` and assert it — even when the return type is
`Promise<void>` (`expect(result).toBeUndefined()`). If the method later starts
returning data, the test fails loudly instead of silently ignoring the new value. For
error paths, `await expect(promise).rejects.toStrictEqual(error)` already asserts the
result — that form is fine as-is.

### Avoid weak matchers

Prefer **exact values** over asymmetric matchers. Each weakening hides drift:

- `expect.anything()`, `expect.any(String)`, `expect.any(Number)` — accept any value
  of that type. Only for values truly opaque to the test.
- `expect.stringMatching(regex)` — only the matched portion is checked; the rest is
  invisible. Only when the variable portion is environment-dependent.
- `expect.objectContaining(...)`, `expect.arrayContaining(...)` — silently allow
  extra keys/items. Avoid; they invalidate the "full shape" rule.

Default rule: if you can capture the value deterministically (fixed clock, fixed
UUID, controlled fixture), do so and assert the literal. Reach for asymmetric
matchers only after proving the value cannot be pinned.

## Test helpers

**Repeated complex assertions become `expect<Feature><Outcome>` helpers.** When the
same multi-statement assertion block recurs across tests, extract it — never
copy-paste it:

- Naming: `expect` + feature + outcome — `expectRecordToBeUpdated`,
  `expectRecordsCreated`. Pair positive and negative outcomes
  (`expectRecordToBeUpdated` / `expectRecordToBeNotUpdated`) so the "nothing
  happened" branch is as cheap to assert as the happy path.
- Signature: a single destructured `args` object (same rule as fixtures and nock
  helpers).
- The helper is assertion-only — expects, no branching, no data setup. It still obeys
  every assertion rule above; extracting a weak assertion just centralizes the
  weakness.
- Placement: bottom of the `describe`. **Each spec file defines its own** — assertion
  helpers are never shared across spec files.

**The same applies to repeated complex GIVEN setups.** A multi-stub mock arrangement
or compound object build that recurs extracts into a per-spec `build<X>` / `given<X>`
helper (`buildCreateInput`, `givenDbError`) — same rules: single partial-overrides
`args` object, bottom of the `describe`, never shared across spec files. Two
guardrails:

- **Significant fields stay visible at the call site.** The helper defaults the
  noise; the fields the test discriminates on are passed as overrides in the `it()`.
- **A stub helper returns the values it stubbed**, so THEN can still assert exact
  arguments.

Compound *data insertion* is not a per-spec helper — that is a setup fixture in
`test/fixtures/`, shared, per the Fixtures section.

Auxiliary functions inside spec files are **arrow consts** (never `function`
declarations), **defined at the bottom of the `describe`**, after the last `it()`.

## General rules

- One test = one scenario. A single WHEN statement and one asserted outcome per
  `it()`. Never bundle several endpoint/method calls into one test — split them.
- One `describe` per endpoint (e2e) or per method (unit) — **never group tests by a
  cross-cutting concern** (`authorization`, `validation`, `pagination`, …). A test
  that checks authorization on `GET /x` belongs in the `GET /x` block. Cases that
  span N endpoints get split across their N endpoint blocks.
- Each test creates its own data inside `it()` — **no shared variables outside
  tests**.
- After mutations (POST, PUT, DELETE): verify DB state, not just the HTTP response —
  full document, all affected collections.
- Filter tests include both matching AND non-matching data.
- Generic `find`/`updateMany`/`deleteMany` surfaces: **one test per filter field**
  (matching + non-matching data in the same test), plus ONE combined-filters test,
  plus pagination (`offset`+`limit`) and each `sortBy` enum value once — never the
  combinatorial product of filters. When a legacy method-per-query repository
  converges to a generic surface, its per-method scenarios are rewritten as filter
  cases — the scenarios survive, the method names do not.
- Never use methods of the class under test for setup or verification.
- Use `test.each()` for parameterized tests across the same logic with multiple
  inputs.
