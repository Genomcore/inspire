import { expect, test } from 'bun:test'
import { mkdtemp, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'

test('loads the project .env model and rejects unsuccessful OMP turns', async () => {
  const root = await mkdtemp(join(tmpdir(), 'omp-agent-'))
  try {
    await writeFile(join(root, '.env'), 'INSPIRE_MODEL=anthropic/claude-opus-5:high\n')
    const agentModule = new URL('../src/agents/create-omp-agent.ts', import.meta.url).pathname
    // Separate process: the loop tests mock this adapter, while this test exercises it.
    const child = Bun.spawn([process.execPath, '--eval', `
      import { mock } from 'bun:test';
      import assert from 'node:assert/strict';
      let options;
      const messages = [];
      let next = { role: 'assistant', stopReason: 'error', errorMessage: '400 invalid_request_error' };
      let disposed = false;
      mock.module(${JSON.stringify(import.meta.resolve('@oh-my-pi/pi-coding-agent'))}, () => ({
        SessionManager: { inMemory: () => ({}) },
        createAgentSession: async (input) => {
          options = input;
          return { session: {
            messages,
            prompt: async () => { if (next) messages.push(next); },
            dispose: async () => { disposed = true; },
          }};
        },
      }));
      const { createOmpAgent } = await import(${JSON.stringify(agentModule)});
      const agent = await createOmpAgent(process.cwd());
      assert.equal(options.modelPattern, 'anthropic/claude-opus-5:high');
      await assert.rejects(agent.prompt('work'), /400 invalid_request_error/);
      for (const stopReason of ['aborted', 'length', 'toolUse']) {
        next = { role: 'assistant', stopReason };
        await assert.rejects(agent.prompt('work'), /OMP turn failed/);
      }
      next = { role: 'assistant', stopReason: 'stop' };
      await agent.prompt('work');
      next = null;
      await assert.rejects(agent.prompt('work'), /OMP turn failed/);
      await agent.dispose();
      assert.equal(disposed, true);
      delete process.env.INSPIRE_MODEL;
      await createOmpAgent(process.cwd());
      assert.equal('modelPattern' in options, false);
    `], { cwd: root, env: { ...process.env, INSPIRE_MODEL: undefined }, stdout: 'pipe', stderr: 'pipe' })
    const [code, stderr] = await Promise.all([child.exited, new Response(child.stderr).text()])
    expect({ code, stderr }).toEqual({ code: 0, stderr: '' })
  } finally {
    await rm(root, { recursive: true, force: true })
  }
})
