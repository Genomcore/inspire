import { changed, defineCheck, scan, tree, verdict } from '../../../lib/check.ts'

// Checklist 3: nothing under domain/ imports @nestjs/*, typeorm, class-validator or class-transformer.
export default defineCheck({
  kind: 'deterministic',
  run: (ctx) => verdict(scan(tree(ctx, /^source\/src\/.*\/domain\/.*\.ts$/, /\.spec\.ts$/), /from\s+['"](@nestjs\/|typeorm|class-validator|class-transformer)/), 'framework import in domain/'),
})
