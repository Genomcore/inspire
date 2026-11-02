import { Injectable, Logger } from '@nestjs/common';

export interface AuditEvent {
  name: Uppercase<string>;
  resourceId: string;
  actorId?: string;
}

@Injectable()
export class AuditEmitter {
  private readonly logger = new Logger('Audit');

  emit(event: AuditEvent): void {
    this.logger.log(event);
  }
}
