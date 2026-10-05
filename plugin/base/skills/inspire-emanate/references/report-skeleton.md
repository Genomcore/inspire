# Factory run report

Summarize the factory process and its recorded artifacts. This is a reporting
outline, not a second run log or an execution protocol.

- **Invocation:** target checkout, factory checkout, arguments and exit status.
- **Readiness:** INSPIRE's verdict, test roots and outstanding warnings.
- **Result:** factory's completed, failed and blocked units, with their recorded
  errors. If no run started, state the dependency or refusal that stopped it.
- **Work:** links to the actual `.inspire/runs/` directory, release branch,
  retained worktrees and PR if one exists.
- **Next action:** the remedy from the failing check or factory's output.

Do not invent wave budgets, overseer decisions, gate digests or provenance
trailers absent from factory's records. Report missing evidence as missing.
