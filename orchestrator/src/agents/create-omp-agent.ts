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
    cwd,
    sessionManager: SessionManager.inMemory(),
  })
  return {
    prompt: async (message) => {
      await session.prompt(message)
    },
    dispose: async () => {
      await session.dispose()
    },
  }
}
