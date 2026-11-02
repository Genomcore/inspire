import { defineCheck } from '../../../lib/check.ts'

export default defineCheck({
  kind: 'judge',
  rubric: `Checklist 2 (inspire-code-nestjs): no service throws an HTTP exception; every thrown error carries cause; no
controller has try/catch; each new failure the client must tell apart is a domain error in domain/ taking { cause } with
an exception filter that maps it to the problem response. Judge the change. 1.0 all hold. 0.5 an error without cause or
a domain error without filter. 0 HTTP status decided in a service or caught in a controller.`,
})
