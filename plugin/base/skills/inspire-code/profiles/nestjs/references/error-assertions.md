# Error assertions

Always assert error message AND cause. `toThrow('msg')` is incomplete — it ignores
`cause` and lets the error class drift silently.

## Async — `rejects.toStrictEqual`

```typescript
// Incomplete
await expect(promise).rejects.toThrow('Failed to send email');

// Complete
await expect(promise).rejects.toStrictEqual(
  new Error('Failed to send email', { cause: error }),
);
```

`toStrictEqual` validates the error class, message, and cause. Use the same
constructor (and constructor args) the production code uses.

## Sync — a throw-capture helper

For synchronous code, a throw-capture helper written once into the shared test
support:

```typescript
const callback = (): void => field.validateOrThrow(args);
const expectedError = new ValidationException('Field', errors);

Expect.throwStrictEqualError({ callback, expectedError });
```

Internally it wraps the call, captures the thrown error, and runs `toStrictEqual`
against `expectedError` — a few lines a project writes once, so the incomplete
`try`/`catch` form below never needs to appear in a spec.

## Custom exception classes

When the production error is a domain-specific class:

```typescript
await expect(promise).rejects.toStrictEqual(
  new RecordNotFoundException({ id: recordId, projectId }),
);
```

The constructor args must match exactly — no `expect.objectContaining`, no
`expect.any`.

## Nested causes

Match the full cause chain:

```typescript
const dbError = new Error('connection refused');
const wrappedError = new RepositoryException('find failed', { cause: dbError });

await expect(promise).rejects.toStrictEqual(
  new ServiceException('cannot fetch record', { cause: wrappedError }),
);
```

## Anti-patterns

- `rejects.toThrow(/regex/)` — fragile, ignores cause and class.
- `rejects.toMatchObject({...})` — silently allows missing/extra fields.
- `try { ... } catch (err) { expect(err.message).toBe(...) }` — verbose and skips
  class/cause checks. Use `toStrictEqual`.
