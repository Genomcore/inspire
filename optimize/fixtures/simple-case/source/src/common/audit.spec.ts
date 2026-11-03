import { Logger } from '@nestjs/common';

import { AuditEmitter } from './audit';

it('records the typed audit event', () => {
  const log = jest.spyOn(Logger.prototype, 'log').mockImplementation(() => undefined);
  try {
    const event = { name: 'EXAMPLE_CREATED', resourceId: 'example' } as const;
    new AuditEmitter().emit(event);
    expect(log).toHaveBeenCalledWith(event);
  } finally {
    log.mockRestore();
  }
});
