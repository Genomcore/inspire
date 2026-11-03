import { useQuery } from '@tanstack/react-query';

import { useApiClient } from '../api/client-context';
import type { IsAliveResult } from '../api/is-alive';

export type IsAliveStatus = 'loading' | 'alive' | 'unavailable';

export interface UseIsAlive {
  status: IsAliveStatus;
  result: IsAliveResult | undefined;
  check: () => void;
}

export function useIsAlive(): UseIsAlive {
  const client = useApiClient();
  const query = useQuery({
    queryKey: ['system.is-alive', 'response'],
    queryFn: ({ signal }) => client.isAlive(signal),
    retry: false,
  });
  return {
    status: query.isPending ? 'loading' : query.data?.state ?? 'unavailable',
    result: query.data,
    check: () => { void query.refetch(); },
  };
}
