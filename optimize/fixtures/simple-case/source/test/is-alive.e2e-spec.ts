import 'reflect-metadata';

import { createServer, type AddressInfo } from 'node:net';

import { INestApplication } from '@nestjs/common';

import { createApp } from '../src/create-app';
import { fetchIsAlive } from '../web/src/api/is-alive';

describe('GET /api/is-alive', () => {
  let app: INestApplication;
  let baseUrl: string;

  beforeAll(async () => {
    app = await createApp();
    await app.listen(0);
    baseUrl = await app.getUrl();
  });

  afterAll(async () => {
    await app.close();
  });

  it('answers 200 with { status: "ok" }', async () => {
    // WHEN
    const response = await fetch(`${baseUrl}/api/is-alive`);

    // THEN
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({ status: 'ok' });
  });

  it('answers 404 as JSON for unknown API routes', async () => {
    // WHEN
    const response = await fetch(`${baseUrl}/api/unknown`);

    // THEN
    expect(response.status).toBe(404);
    expect(response.headers.get('content-type')).toContain('application/json');
  });

  it('is seen as alive by the frontend client', async () => {
    // WHEN
    const result = await fetchIsAlive(`${baseUrl}/api/is-alive`);

    // THEN
    expect(result).toMatchObject({ state: 'alive', httpStatus: 200, body: '{"status":"ok"}' });
    expect(result.failure).toBeUndefined();
    expect(result.latencyMs).toBeGreaterThanOrEqual(0);
  });

  it('is seen as unavailable by the frontend client when the answer is wrong or nothing listens', async () => {
    // GIVEN
    const unreachableUrl = await closedPortUrl();

    // WHEN
    const wrongAnswer = await fetchIsAlive(`${baseUrl}/api/unknown`);
    const noAnswer = await fetchIsAlive(`${unreachableUrl}/api/is-alive`);

    // THEN
    expect(wrongAnswer).toMatchObject({ state: 'unavailable', httpStatus: 404, failure: 'HTTP 404' });

    expect(noAnswer.state).toBe('unavailable');
    expect(noAnswer.httpStatus).toBeUndefined();
    expect(noAnswer.failure).toEqual(expect.any(String));
  });
});

async function closedPortUrl(): Promise<string> {
  const server = createServer();
  await new Promise<void>((resolve) => { server.listen(0, '127.0.0.1', resolve); });
  const { port } = server.address() as AddressInfo;
  await new Promise<void>((resolve, reject) => { server.close((error) => { if (error) reject(error); else resolve(); }); });
  return `http://127.0.0.1:${String(port)}`;
}
