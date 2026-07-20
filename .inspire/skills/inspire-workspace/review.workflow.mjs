export const meta = {
  name: 'inspire-workspace-review',
  description: 'Pre-PR Global Review (v1, Phase A): parallel module fan-out + completeness gate + sequential cross-cutting synthesis. READ-ONLY — flags issues, never edits.',
  phases: [
    { title: 'Module reviews', detail: 'one /inspire_module review per in-scope module, in parallel' },
    { title: 'Completeness', detail: 'no-silent-caps — every module must return a non-degenerate result' },
    { title: 'Synthesize', detail: 'cross-cutting phases 3–6 over the full repo + consolidated report' },
  ],
}

// ---------------------------------------------------------------------------
// Scope. Phase 1 of the skill (scope identification) runs BEFORE this workflow:
// the caller enumerates the modules under .inspire_kb/02_features/ and passes the
// in-scope slugs as args.modules. If omitted, the module fan-out is skipped and
// only the cross-cutting synthesis runs (over the full repo) — pass args.modules
// for a complete review.
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
    fix_skill: { type: 'string', description: 'the /inspire_* skill that fixes it' },
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

const READ_ONLY = 'STRICTLY READ-ONLY: flag issues only. NEVER edit a file, NEVER run a fix-skill (/inspire_* create/update/delete), NEVER use Edit/Write. Every finding names the fix-skill to invoke later, but you do not invoke it.'

// --- Phase A: module fan-out (parallel + barrier) ---------------------------
phase('Module reviews')
log(`Fan-out: ${modules.length} module reviews (${modules.join(', ')})`)
const moduleResults = await parallel(modules.map((m) => () =>
  agent(
    `In the current repository (the project working directory), perform a consistency review of the "${m}" module by following the \`review\` subcommand procedure documented in \`.claude/skills/inspire-module/SKILL.md\` (steps: features structure, screen spec structure, quality checks, cross-layer coverage features↔screen spec↔prototypes↔specs, drift consolidation, overengineering detection). ${READ_ONLY}\n\n` +
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

// --- Phase C: synthesize (sequential reduce; cross-cutting phases 3–7) -------
phase('Synthesize')
const report = await agent(
  `You are the synthesizer for the pre-PR Global Review, running in the current repository. ${READ_ONLY}\n\n` +
  `PER-MODULE RESULTS (Phase A): ${JSON.stringify(moduleResults)}\n\n` +
  `INCOMPLETE MODULES — emit each as a CRITICAL finding "review-incomplete: {reason}" so the gate fails loudly (never treat a missing/degenerate module as OK): ${JSON.stringify(incomplete)}\n\n` +
  `Now run the cross-cutting checks YOURSELF, sequentially, reading the FULL repo regardless of the module scope above (scope narrows only the fan-out, never these):\n` +
  `- Phase 3 Cross-module consistency: dependency feature-IDs resolve in their target module; ALL [[adr-*]] wikilinks across the feature files resolve to files in .inspire_kb/01_adr/ (incl. phantom/non-existent targets); ADR-PROPAGATION ALIGNMENT — for each ADR read its Status (maturity) + Decision and verify its consequences cohere across the in-repo DESIGN WORKSPACE (features + screen spec + horizontal prototype + specs) at EVERY maturity — a contradiction there is CRITICAL; maturity adds EXTERNAL evidence you check only by pointer, never by inspecting the external artifact (prototyped→a **Prototype:** pointer to an external functional prototype; implemented→a codebase ref), so a design ADR merely lacking external validation is NOT a finding (this is your job, not the module agents' — they do not read ADR Status); no undocumented circular deps.\n` +
  `- Phase 4 Vault structure: .inspire_kb/ tree matches CLAUDE.md, indexes complete, no stray .py/.xlsx/.DS_Store, every module folder has a pure _index.md.\n` +
  `- Phase 5 Prototype component adoption: corpus-wide counts (a component from .inspire_kb/05_screens/components/ is "adopted" by counting its usages across ALL pages of the horizontal prototype at /prototype — never per single module).\n` +
  `- Phase 6 Catalog coherence: patterns/components with 0 references; screens claiming a pattern/component that does not exist.\n\n` +
  `Then emit the consolidated report in the EXACT skeleton from .claude/skills/inspire-workspace/SKILL.md (## Scope / ## Summary / ## By Module / ## Cross-Module / ## Vault Structure / ## Prototype Component Adoption / ## Catalog Coherence / ## OK). Apply the skill's severity rules (rules 1–9): critical = broken refs / missing files / ADR-consequences-not-reflected-within-maturity-reach / review-incomplete; important = stale content, missing coverage, legacy structure; minor = naming/formatting; "verify" if unsure. Tag known items "(tracked: TASK-{id})" by consulting .inspire_kb/06_tracker/tickets/*.md. Every finding names its fix-skill. Return ONLY the final markdown report as your output.`,
  { label: 'synthesize', phase: 'Synthesize' },
)

return report
