// The payload is narrowed with a guard: `as any` would hide the missing field,
// and `@ts-expect-error` would outlive the fix upstream.
export const isUser = (value: unknown): value is User =>
  typeof value === 'object' && value !== null && 'id' in value;
