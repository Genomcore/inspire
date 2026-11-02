import { defineCheck } from '../../../lib/check.ts'

export default defineCheck({
  kind: 'judge',
  rubric: `Checklist 4 (inspire-code-nestjs): every create, update and delete emits the project's typed audit event, with
an UPPERCASE event name, from the application service (never the controller or repository), through the emitter the
project already has or one created in src/common/ at first use. 1.0 every mutation in the change, or none in the change.
0.5 audited but untyped, lowercase or from the wrong layer. 0 a mutation is unaudited.`,
})
