export const DEFAULT_ENDPOINT = '/api/is-alive';

export type IsAliveState = 'alive' | 'unavailable';

export interface IsAliveResult {
  state: IsAliveState;
  endpoint: string;
  checkedAt: Date;
  latencyMs: number;
  httpStatus?: number;
  body?: string;
  failure?: string;
}

export interface FetchIsAliveOptions {
  fetchImpl?: typeof fetch;
  signal?: AbortSignal;
}

export async function fetchIsAlive(endpoint = DEFAULT_ENDPOINT, { fetchImpl = fetch, signal }: FetchIsAliveOptions = {}): Promise<IsAliveResult> {
  const startedAt = performance.now();
  const checkedAt = new Date();
  try {
    const response = await fetchImpl(endpoint, { signal, headers: { accept: 'application/json' } });
    const body = await response.text();
    const latencyMs = Math.round(performance.now() - startedAt);
    if (response.ok && isOkPayload(body)) {
      return { state: 'alive', endpoint, checkedAt, latencyMs, httpStatus: response.status, body };
    }
    const failure = response.ok ? 'The response is not a liveness payload' : `HTTP ${String(response.status)}`;
    return { state: 'unavailable', endpoint, checkedAt, latencyMs, httpStatus: response.status, body, failure };
  } catch (error) {
    if (signal?.aborted) throw error;
    const latencyMs = Math.round(performance.now() - startedAt);
    const failure = error instanceof Error ? error.message : String(error);
    return { state: 'unavailable', endpoint, checkedAt, latencyMs, failure };
  }
}

function isOkPayload(body: string): boolean {
  try {
    const payload: unknown = JSON.parse(body);
    return typeof payload === 'object' && payload !== null && 'status' in payload && payload.status === 'ok';
  } catch {
    // A body that is not JSON cannot be the liveness payload; the caller reports it as unavailable.
    return false;
  }
}
