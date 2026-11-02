import { changed, defineCheck, scan, tree, verdict } from '../../../lib/check.ts'

// Checklist 4: every create, update and delete emits the typed audit event from the service.
const MUTATION = /async\s+(create|register|add|update|rename|patch|change|close|delete|remove|toggle)\w*\s*\(/

export default defineCheck({
  kind: 'deterministic',
  run: (ctx) => verdict(
    changed(ctx, /^source\/src\/.*\/application\/.*\.service\.ts$/).filter(([, b]) => MUTATION.test(b) && !/audit/i.test(b)).map(([p]) => `${p}: mutates without an audit event`),
    'unaudited mutation',
  ),
})
