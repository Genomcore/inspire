import type { CommandResult } from '../interfaces/command-result'

export const buildRetryPrompt = (
  result: CommandResult,
  tryNumber: number,
  maxTries: number,
): string => {
  return `
The test suite is still red after attempt ${String(tryNumber)} of ${String(maxTries)}.
Continue the Red, Green, Blue, commit cycle and fix the failure.

stdout:
${result.stdout}

stderr:
${result.stderr}
`.trim()
}
