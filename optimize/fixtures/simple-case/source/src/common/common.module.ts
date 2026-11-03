import { Global, Module } from '@nestjs/common';

import { AuditEmitter } from './audit';

@Global()
@Module({ providers: [AuditEmitter], exports: [AuditEmitter] })
export class CommonModule {}
