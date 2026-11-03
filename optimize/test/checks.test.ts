import assert from 'node:assert/strict'
import { mkdtempSync, readFileSync, writeFileSync, readdirSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { spawnSync } from 'node:child_process'
import { test } from 'node:test'
import type { Context } from '../lib/check.ts'
import route from '../skills/inspire-code-react/checks/c2-no-literal-routes.ts'
import domain from '../skills/inspire-code-nestjs/checks/c3-domain-pure.ts'

const context = (path: string, text: string, added: boolean): Context => ({
  task: 'Implement the feature', workdir: '/does-not-exist', output: 'done',
  files: { [path]: text }, diff: `diff -- ${path}\n${added ? '+' : ' '}${text}`,
  changes: { [path]: { before: added ? null : text, after: text, patch: '', added: added ? [{ line: 7, text }] : [] } },
})

test('inherited errors in a changed file are ignored, introduced errors fail', async () => {
  for (const [check, path, line] of [
    [route, 'source/web/src/screen.tsx', '<Link to="/bad">'],
    [domain, 'source/src/example/domain/item.ts', "import { Injectable } from '@nestjs/common'"],
  ] as const) {
    assert.equal(check.kind, 'deterministic')
    if (check.kind !== 'deterministic') throw new Error('expected deterministic check')
    assert.deepEqual(await check.run(context(path, line, false)), { score: 1, reason: '' })
    const result = await check.run(context(path, line, true))
    assert.equal(typeof result, 'object')
    assert.match((result as { reason: string }).reason, /:7 /)
  }
})

test('every shipped check loads and deterministic checks need no filesystem', async () => {
  const skills = resolve(import.meta.dirname, '../skills')
  for (const skill of readdirSync(skills)) {
    for (const file of readdirSync(join(skills, skill, 'checks'))) {
      const check = (await import(join(skills, skill, 'checks', file))).default
      assert.ok(['deterministic', 'judge', 'agent'].includes(check.kind))
      if (check.kind === 'deterministic') {
        await check.run({ task: 'task', output: '', workdir: '/does-not-exist', files: {}, changes: {}, diff: '' })
      }
    }
  }
})

test('judge and agent receive only the same diff and have no read tools', () => {
  const dir = mkdtempSync(join(tmpdir(), 'inspire-checks-'))
  try {
    const stub = join(dir, 'claude')
    writeFileSync(stub, `#!/usr/bin/env node
const fs = require('node:fs'); let input = '';
process.stdin.on('data', x => input += x);
process.stdin.on('end', () => {
 fs.appendFileSync(process.env.PROMPT_LOG, JSON.stringify({ input, args: process.argv.slice(2), cwd: process.cwd() }) + '\\n');
 process.stdout.write(JSON.stringify({ structured_output: { score: 1, reason: '' } }));
});`, { mode: 0o755 })
    const ctx = context('example.ts', 'FULL_FILE_SECRET', true)
    ctx.diff = 'SAME_DIFF'
    writeFileSync(join(dir, 'context.json'), JSON.stringify(ctx))
    writeFileSync(join(dir, 'judge.mjs'), "export default { kind: 'judge', rubric: 'Review' }")
    writeFileSync(join(dir, 'agent.mjs'), "export default { kind: 'agent', prompt: 'Review' }")
    const result = spawnSync(process.execPath, [resolve(import.meta.dirname, '../lib/run-checks.ts'), join(dir, 'context.json'), join(dir, 'judge.mjs'), join(dir, 'agent.mjs')], {
      encoding: 'utf8', env: { ...process.env, CLAUDE_CLI_BIN: stub, PROMPT_LOG: join(dir, 'prompts') },
    })
    assert.equal(result.status, 0, result.stderr)
    assert.equal(JSON.parse(result.stdout).passed, true)
    const prompts = readFileSync(join(dir, 'prompts'), 'utf8').trim().split('\n').map(x => JSON.parse(x))
    assert.equal(prompts.length, 2)
    assert.equal(prompts[0].input, prompts[1].input)
    for (const call of prompts) {
      assert.match(call.input, /SAME_DIFF/)
      assert.doesNotMatch(call.input, /FULL_FILE_SECRET/)
      assert.equal(call.args[call.args.indexOf('--tools') + 1], '')
      assert.notEqual(call.cwd, ctx.workdir)
    }
    writeFileSync(join(dir, 'context.json'), JSON.stringify({ ...ctx, changes: {}, diff: '' }))
    const empty = spawnSync(process.execPath, [resolve(import.meta.dirname, '../lib/run-checks.ts'), join(dir, 'context.json'), join(dir, 'judge.mjs'), join(dir, 'agent.mjs')], {
      encoding: 'utf8', env: { ...process.env, CLAUDE_CLI_BIN: stub, PROMPT_LOG: join(dir, 'prompts') },
    })
    assert.equal(empty.status, 0, empty.stderr)
    assert.equal(JSON.parse(empty.stdout).score, 0)
    assert.equal(readFileSync(join(dir, 'prompts'), 'utf8').trim().split('\n').length, 2)

  } finally {
    rmSync(dir, { recursive: true, force: true })
  }
})
