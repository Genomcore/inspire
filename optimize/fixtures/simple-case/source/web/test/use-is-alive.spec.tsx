import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { renderHook, waitFor } from '@testing-library/react';
import type { PropsWithChildren } from 'react';

import { ApiClientContext } from '../src/api/client-context';
import { useIsAlive } from '../src/hooks/use-is-alive';
import { mockClient } from './mocks/client';

it('loads liveness through the injected client', async () => {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false } } });
  const wrapper = ({ children }: PropsWithChildren) => (
    <QueryClientProvider client={client}>
      <ApiClientContext.Provider value={mockClient}>{children}</ApiClientContext.Provider>
    </QueryClientProvider>
  );
  const { result, unmount } = renderHook(useIsAlive, { wrapper });
  await waitFor(() => { expect(result.current.status).toBe('alive'); });
  expect(result.current.result?.httpStatus).toBe(200);
  unmount();
  client.clear();
});
