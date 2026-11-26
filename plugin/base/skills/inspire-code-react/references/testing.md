# React test-authoring conventions

The fine-grained authoring rules behind `## Test conventions` in
[`SKILL.md`](../SKILL.md). The examples use Vitest's API (`vi.mock`); on a
Jest project the same architecture holds with `jest.mock`.

## Test structure: GIVEN / WHEN / THEN

```typescript
it('should display the user name', () => {
  // GIVEN
  const user = mockUserData;

  // WHEN
  render(<UserCard user={user} />);

  // THEN
  expect(screen.getByText(user.name)).toBeInTheDocument();
});
```

- `// GIVEN`, `// WHEN`, `// THEN` comments — NO other comments allowed in a test.
- Skip GIVEN when there is no setup (e.g. testing defaults).
- Group related assertions in a single test.
- Query by role first: `getByRole` > `getByText` > `getByTestId`. Assert what the
  user sees, never component internals.

## Mock architecture

**All mocks live in the centralized mock layer (`tests/setup/mocks/`).** Never
inline:

```typescript
// Right — async factory delegating to the shared layer
vi.mock('@/services/api', async () => {
  const { fullApiMock } = await import('../../setup/mocks/api');
  return fullApiMock;
});

// Wrong — inline mock
vi.mock('@/services/api', () => ({ get: vi.fn() }));
```

A test overrides only the fields it cares about; the shared mock supplies the rest.

### Adding a new mock

1. New callback: `export const mockXxx = vi.fn()` in `hooks.ts`.
2. New data: add to `data/*.ts` (auto-exported via `data/index.ts`).
3. New API method: add to `api.ts` + a flat export alias.
4. New third-party module: add to `third-party.tsx`.

## Store

A server key whose fetch fails with a `clear` outcome (`SKILL.md` § Store) gets one
test that renders a real reader of the key — the shell, for a key the shell reads —
and makes the fetch fail with that class:

```tsx
it('should request the session once and show the signed-out state when it is missing', async () => {
  // GIVEN
  mockAuthMe.mockRejectedValue(unauthenticatedError);
  const queryClient = new QueryClient();

  // WHEN
  render(
    <QueryClientProvider client={queryClient}>
      <Shell />
    </QueryClientProvider>,
  );

  // THEN
  expect(await screen.findByRole('link', { name: 'Sign in' })).toBeInTheDocument();
  await waitFor(() => expect(queryClient.getQueryState(['store', 'me'])?.status).toBe('success'));
  expect(queryClient.getQueryData(['store', 'me'])).toBeNull();
  expect(mockAuthMe).toHaveBeenCalledTimes(1);
});
```

- `mockAuthMe` is the client function's alias in the shared mock layer, and
  `unauthenticatedError` is a failure the `api/` layer classifies as
  `unauthenticated`, kept in `data/*.ts`.
- The query has to settle as `success` with `null` data before the calls are
  counted. A key cleared with `removeQueries` never settles: the mounted reader keeps
  building the query again, so `waitFor` times out and the test fails instead of
  counting a request too early.
- Render the reader, never the hook alone: the loop needs a mounted observer.
