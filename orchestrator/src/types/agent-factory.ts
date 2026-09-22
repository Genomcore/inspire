import type { Agent } from '@/interfaces/agent'

export type AgentFactory = (cwd: string) => Promise<Agent>
