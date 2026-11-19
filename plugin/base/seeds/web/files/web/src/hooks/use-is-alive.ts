import { useCallback, useEffect, useState } from 'react';

import { DEFAULT_ENDPOINT, fetchIsAlive, type IsAliveResult } from '../api/is-alive';

export type IsAliveStatus = 'loading' | 'alive' | 'unavailable';

export type IsAliveClient = (signal: AbortSignal) => Promise<IsAliveResult>;

export interface UseIsAlive {
  status: IsAliveStatus;
  result: IsAliveResult | undefined;
  check: () => void;
}

const defaultClient: IsAliveClient = (signal) => fetchIsAlive(DEFAULT_ENDPOINT, { signal });

export function useIsAlive(client: IsAliveClient = defaultClient): UseIsAlive {
  const [result, setResult] = useState<IsAliveResult>();
  const [loading, setLoading] = useState(true);
  const [attempt, setAttempt] = useState(0);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    void (async () => {
      try {
        const next = await client(controller.signal);
        if (controller.signal.aborted) return;
        setResult(next);
        setLoading(false);
      } catch (error) {
        // An aborted check was cancelled by an unmount or a newer check; anything else is a bug worth surfacing.
        if (controller.signal.aborted) return;
        throw error;
      }
    })();
    return () => {
      controller.abort();
    };
  }, [client, attempt]);

  const check = useCallback(() => {
    setAttempt((count) => count + 1);
  }, []);

  const status: IsAliveStatus = loading || result === undefined ? 'loading' : result.state;
  return { status, result, check };
}
