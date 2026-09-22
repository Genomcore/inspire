import type { CommandResult, Unit } from './types'

export const buildInitialPrompt = (unit: Unit): string => {
  return `
Implement the ${unit.kind} "${unit.id}" specified at ${unit.path}.

Work only inside this worktree.
Use strict test-driven development.
Repeat this cycle until the unit is complete:
1. Red: write or adjust a test and confirm that it fails for the expected reason.
2. Green: implement only the minimum code required to pass.
3. Blue: refactor for clarity while keeping the suite green.
4. Commit the completed cycle.

Never skip the red execution.
Never weaken or delete a test to obtain green.
Keep the code minimal and readable.
Do not add comments.
Do not add speculative abstractions or unnecessary validation.
Do not modify inspire_kb.
`.trim()
}

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
