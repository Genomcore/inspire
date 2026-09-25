export interface Agent {
  prompt: (message: string) => Promise<void>
  dispose: () => void | Promise<void>
}
