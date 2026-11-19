import { Controller, Get } from '@nestjs/common';

@Controller('is-alive')
export class IsAliveController {
  @Get()
  isAlive(): { status: 'ok' } {
    return { status: 'ok' };
  }
}
