export const meta = {
  name: 'inspire-workspace-review',
  description: 'Pre-PR Global Review (v1, Phase A): parallel module fan-out + completeness gate + sequential cross-cutting synthesis. READ-ONLY — flags issues, never edits.',
  phases: [
    { title: 'Module reviews', detail: 'one /inspire-module review per in-scope module, in parallel' },
    { title: 'Completeness', detail: 'no-silent-caps — every module must return a non-degenerate result' },
    { title: 'Synthesize', detail: 'cross-cutting phases 3–6 over the full repo + consolidated report' },
  ],
}

// ---------------------------------------------------------------------------
// Scope. Phase 1 of the skill (scope identification) runs BEFORE this workflow:
// the caller enumerates the modules from the hub glob (inspire_kb/02_modules/*.md
// excluding _*.md and README.md) and passes the in-scope slugs as args.modules.
// If omitted, the module fan-out is skipped and only the cross-cutting synthesis
// runs (over the full repo) — pass args.modules for a complete review.
// IMPORTANT: scope narrows ONLY this module fan-out — the cross-cutting synthesis
// phase always reads the FULL repo (see synthesize prompt).
// ---------------------------------------------------------------------------
const modules = (args && Array.isArray(args.modules) && args.modules.length) ? args.modules : []

const FINDING = {
  type: 'object',
  additionalProperties: false,
  properties: {
    severity: { type: 'string', enum: ['critical', 'important', 'minor', 'verify'] },
    description: { type: 'string' },
    file: { type: 'string' },
    line: { type: 'number' },
    fix_skill: { type: 'string', description: 'the /inspire-* skill that fixes it' },
  },
  required: ['severity', 'description', 'fix_skill'],
}

const MODULE_RESULT = {
  type: 'object',
  additionalProperties: false,
  properties: {
    module: { type: 'string' },
    reviewed: { type: 'boolean', description: 'true only if every sub-check actually ran against real files' },
    files_read: { type: 'number', description: 'count of artifact files actually opened — used to detect degenerate (no-op) reviews' },
    feature_ids: { type: 'array', items: { type: 'string' } },
    entities: { type: 'array', items: { type: 'string' } },
    findings: { type: 'array', items: FINDING },
  },
  required: ['module', 'reviewed', 'files_read', 'findings'],
}

const READ_ONLY = 'STRICTLY READ-ONLY: flag issues only. NEVER edit a file, NEVER run a fix-skill (/inspire-* create/update/delete), NEVER use Edit/Write. Every finding names the fix-skill to invoke later, but you do not invoke it.'

// --- Phase A: module fan-out (parallel + barrier) ---------------------------
phase('Module reviews')
log(`Fan-out: ${modules.length} module reviews (${modules.join(', ')})`)
const moduleResults = await parallel(modules.map((m) => () =>
  agent(
    `In the current repository (the project working directory), perform a consistency review of the "${m}" module by following the \`review\` subcommand procedure documented in \`.claude/skills/inspire-module/references/module-review.md\`. ${READ_ONLY}\n\n` +
    `Return: module="${m}", reviewed=true ONLY if you actually opened and inspected the module's features/screen spec/prototype/specs files (report files_read = how many you opened), the extracted feature_ids and entities (reused downstream), and findings[] (each with severity, description, file, line, fix_skill).`,
    { label: `review:${m}`, phase: 'Module reviews', schema: MODULE_RESULT },
  ),
))

// --- Phase: completeness gate (deterministic, no-silent-caps) ---------------
phase('Completeness')
const incomplete = []
moduleResults.forEach((r, i) => {
  const m = modules[i]
  if (!r) incomplete.push({ module: m, reason: 'agent returned null (dropped/failed/skipped thunk)' })
  else if (r.reviewed !== true) incomplete.push({ module: m, reason: 'reviewed=false' })
  else if (!r.files_read || r.files_read < 1) incomplete.push({ module: m, reason: 'degenerate review: files_read=0 (no files actually inspected)' })
})
const ok = moduleResults.filter(Boolean).length
log(`Module reviews returned: ${ok}/${modules.length}` + (incomplete.length ? ` — ${incomplete.length} INCOMPLETE (will be flagged critical: review-incomplete)` : ' — all complete'))

// --- Phase C: synthesize (sequential reduce; cross-cutting phases + report) -------
phase('Synthesize')
const report = await agent(
  `You are the synthesizer for the pre-PR Global Review, running in the current repository. ${READ_ONLY}\n\n` +
  `PER-MODULE RESULTS (Phase A): ${JSON.stringify(moduleResults)}\n\n` +
  `INCOMPLETE MODULES — emit each as a CRITICAL finding "review-incomplete: {reason}" so the gate fails loudly (never treat a missing/degenerate module as OK): ${JSON.stringify(incomplete)}\n\n` +
  `Now run the cross-cutting checks YOURSELF, sequentially: read \`.claude/skills/inspire-workspace/references/workspace-review.md\` and perform every phase it documents — cross-module consistency, vault structure, prototype component adoption, catalog coherence, and signals — following that file for what each one checks and how it is judged.\n` +
  `Read the FULL repo for every one of them, regardless of the module scope above: scope narrows ONLY this module fan-out — the cross-cutting phases always read the FULL repo. ADR Status/maturity judgment is your job, not the module agents' — they do not read ADR Status.\n\n` +
  `Then emit the consolidated report in the EXACT skeleton from .claude/skills/inspire-workspace/SKILL.md (## Scope / ## Summary / ## By Module / ## Cross-Module / ## Vault Structure / ## Prototype Component Adoption / ## Catalog Coherence / ## Signals / ## OK). Apply the severity and reporting rules in the \`### Review rules\` section of \`.claude/skills/inspire-workspace/SKILL.md\`. Tag known items "(tracked: TASK-{id})" by consulting inspire_kb/99_tracker/tickets/*.md. Every finding names its fix-skill. Return ONLY the final markdown report as your output.`,
  { label: 'synthesize', phase: 'Synthesize' },
)

return report
