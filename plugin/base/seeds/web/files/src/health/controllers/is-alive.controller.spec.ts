import { IsAliveController } from './is-alive.controller';

describe('IsAliveController', () => {
  it('reports the service alive without touching any dependency', () => {
    // GIVEN
    const controller = new IsAliveController();

    // WHEN
    const result = controller.isAlive();

    // THEN
    expect(result).toEqual({ status: 'ok' });
  });
});
