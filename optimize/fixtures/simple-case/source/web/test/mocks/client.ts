import type { ApiClient } from '../../src/api/client';

export const mockClient: ApiClient = {
  isAlive: async () => ({
    state: 'alive', endpoint: '/api/is-alive', checkedAt: new Date(0), latencyMs: 1,
    httpStatus: 200, body: '{"status":"ok"}',
  }),
};
