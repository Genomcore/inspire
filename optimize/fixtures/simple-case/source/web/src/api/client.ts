import { fetchIsAlive, type IsAliveResult } from './is-alive';

export interface ApiClient {
  isAlive(signal?: AbortSignal): Promise<IsAliveResult>;
}

export const httpClient: ApiClient = {
  isAlive: (signal) => fetchIsAlive(undefined, { signal }),
};
