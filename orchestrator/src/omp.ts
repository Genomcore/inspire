import {
  createAgentSession,
  SessionManager,
} from '@oh-my-pi/pi-coding-agent'

import type { AgentFactory } from './types'

export const createOmpAgent: AgentFactory = async (cwd) => {
  const { session } = await createAgentSession({
    autoApprove: true,
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
