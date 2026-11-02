// Quality gates from .claude/skills/inspire-code/profiles/nestjs.md § Quality gates.
// Absolutes: strictTypeChecked (the stricter preset, by the profile), size limits, layer
// boundaries via import-x, jest hygiene, justified suppressions. `complexity` is
// deliberately not adopted (see the profile).
import { readdirSync, existsSync } from 'node:fs';
import { config as defineConfig, configs as tsConfigs } from 'typescript-eslint';
import { flatConfigs as importXConfigs } from 'eslint-plugin-import-x';
import jest from 'eslint-plugin-jest';
import { recommended as commentsRecommended } from '@eslint-community/eslint-plugin-eslint-comments/configs';
import { createTypeScriptImportResolver } from 'eslint-import-resolver-typescript';

// Layer order, outermost first. A layer may import the layers after it, never before.
const LAYERS = ['controllers', 'application', 'infrastructure', 'domain'];
const modules = existsSync('./src')
  ? readdirSync('./src', { withFileTypes: true })
      .filter((d) => d.isDirectory() && LAYERS.some((l) => existsSync(`./src/${d.name}/${l}`)))
      .map((d) => d.name)
  : [];
const zones = modules.flatMap((m) =>
  LAYERS.flatMap((target, i) =>
    LAYERS.slice(0, i).map((from) => ({
      target: `./src/${m}/${target}`,
      from: `./src/${m}/${from}`,
      message: `${target}/ must not import ${from}/ (layer boundary)`,
    })),
  ),
);
if (modules.length > 0 && zones.length === 0) throw new Error('layer zones derived to nothing');

export default defineConfig(
  { ignores: ['dist/**', 'coverage/**', 'node_modules/**', 'web/**'] },
  ...tsConfigs.strictTypeChecked,
  ...tsConfigs.stylisticTypeChecked,
  importXConfigs.recommended,
  importXConfigs.typescript,
  commentsRecommended,
  {
    languageOptions: { parserOptions: { projectService: true, tsconfigRootDir: import.meta.dirname } },
    settings: { 'import-x/resolver-next': [createTypeScriptImportResolver({ project: './tsconfig.eslint.json' })] },
    rules: {
      '@typescript-eslint/ban-ts-comment': ['error', { 'ts-expect-error': 'allow-with-description', 'ts-ignore': true }],
      'max-depth': ['error', 3],
      'max-lines-per-function': ['error', { max: 60, skipBlankLines: true, skipComments: true }],
      'max-lines': ['error', { max: 400, skipBlankLines: true, skipComments: true }],
      'import-x/no-cycle': 'error',
      // The rule rejects an empty zone list, so it enters with the first module on disk.
      ...(zones.length > 0 ? { 'import-x/no-restricted-paths': ['error', { zones }] } : {}),
      '@eslint-community/eslint-comments/require-description': 'error',
      '@eslint-community/eslint-comments/no-unused-disable': 'error',
      // A Nest module is a decorated, bodiless class by design.
      '@typescript-eslint/no-extraneous-class': ['error', { allowWithDecorator: true }],
    },
  },
  {
    files: ['**/*.spec.ts', '**/*.e2e-spec.ts'],
    ...jest.configs['flat/recommended'],
    rules: {
      ...jest.configs['flat/recommended'].rules,
      'jest/expect-expect': 'error',
      'jest/no-disabled-tests': 'error',
      'jest/no-focused-tests': 'error',
      'jest/no-conditional-expect': 'error',
      'max-lines-per-function': 'off', // a describe callback is a function to the linter
    },
  },
  { files: ['src/**/dto/**', 'src/migrations/**'], rules: { 'max-lines': 'off' } },
  { files: ['eslint.config.mjs'], ...tsConfigs.disableTypeChecked },
);
