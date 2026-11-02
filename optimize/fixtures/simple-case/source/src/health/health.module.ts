import { Module } from '@nestjs/common';

import { IsAliveController } from './controllers/is-alive.controller';

@Module({ controllers: [IsAliveController] })
export class HealthModule {}
