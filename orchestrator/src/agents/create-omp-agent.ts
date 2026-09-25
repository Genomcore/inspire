import {
  createAgentSession,
  SessionManager,
} from '@oh-my-pi/pi-coding-agent'

import type { Agent } from '@/interfaces/agent'
import type { OmpAgentConfig } from '@/interfaces/omp-agent-config'

const defaultConfig: Required<OmpAgentConfig> = {
  autoApprove: true,
  disableExtensionDiscovery: true,
  enableIrc: false,
  enableMCP: false,
  spawns: '',
}

export const createOmpAgent = async (
  cwd: string,
  config: OmpAgentConfig = {},
): Promise<Agent> => {
  const { session } = await createAgentSession({
    ...defaultConfig,
    ...config,
    ...(process.env.INSPIRE_MODEL ? { modelPattern: process.env.INSPIRE_MODEL } : {}),
    cwd,
    sessionManager: SessionManager.inMemory(),
  })
  return {
    prompt: async (message) => {
      const previous = session.messages.findLast((entry) => entry.role === 'assistant')
      await session.prompt(message)
      const reply = session.messages.findLast((entry) => entry.role === 'assistant')
      if (!reply || reply === previous || reply.stopReason !== 'stop') {
        throw new Error(`OMP turn failed in ${cwd}: ${reply?.errorMessage ?? reply?.stopReason ?? 'no assistant response'}`)
      }
    },
    dispose: async () => {
      await session.dispose()
    },
  }
}
