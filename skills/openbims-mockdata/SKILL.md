---
name: openbims-mockdata
description: "Design, maintain and extend the mock data of the prototype. Invoke when creating/validating tables, enforcing data coherence, or designing new scenarios (use cases the user describes in natural language)."
---

# /openbims_mockdata — Prototype Mock Data

## Purpose

The mock data is a **"Figma interactivo"** — it exists so the browser prototype shows product decisions with realistic content. It is NOT a production database.

This skill has **three pillars**:

1. **Baseline integrity.** The set of JSONL files in `mock-data/tables/` must always load without errors, have consistent foreign keys, and be regenerable (via `git checkout`).
2. **Coherence.** Data must be realistic, no duplicated "example" rows across modules, relationships must be real (the connector an agent uses really exists, the token it references really exists, etc.), and queries from the prototype must actually return something meaningful.
3. **Scenario design.** When the user describes a use case in natural language ("hospital X with EHR agent doing Y"), the skill turns that narrative into coherent JSONL rows that become visible in the prototype **WITHOUT touching UI code**.

## When to use

- Creating or updating mock data tables
- Validating consistency (schemas ↔ JSONL ↔ prototype queries)
- Designing a new scenario the user describes conversationally
- Fixing coherence issues (broken FKs, duplicated entities)
- Syncing mock data to prototype `public/data/`

## CRITICAL CONTEXT

- **DuckDB-WASM** runs entirely in the browser. It auto-detects types from JSONL; ISO date strings become `TIMESTAMP` and come back to JS as numbers (milliseconds). Hooks that parse dates must handle both.
- **JSONL is the source of truth.** Hand-editable. No YAML layer.
- **Tables list** is hardcoded in `code/openbims-console/src/db/client.js` (`discoverTables` function). After adding a new table, update this array, otherwise the table is "skipped" at load.
- **Views** (`mock-data/views/*.sql`) are aggregated and loaded as DuckDB views. Views that reference non-existent tables or columns are silently skipped — they don't prevent the app from loading.

## File locations

```
mock-data/
├── schema/                # DuckDB DDL per module (*.sql)
├── tables/                # One JSONL per table — SOURCE OF TRUTH
├── views/                 # Cross-module views (aggregations, joins)
└── scripts/
    ├── sync-data.sh       # copies tables/ + views.sql → code/*/public/data/
    └── validate.mjs       # (optional) FK validator
```

**Pipeline:** `mock-data/tables/*.jsonl` → `sync-data.sh` → `code/*/public/data/*.jsonl`
**NEVER edit `code/*/public/data/` directly.**

## Invocation modes

- `/openbims_mockdata validate` — run coherence checks against current JSONL
- `/openbims_mockdata add-table {name}` — register a new table in schema + JSONL + client.js manifest
- `/openbims_mockdata scenario` — enter the scenario-design protocol (conversational, see below)
- `/openbims_mockdata sync` — sync tables/ → public/data/ via `sync-data.sh`
- `/openbims_mockdata reset` — restore tables/ to `git checkout HEAD -- mock-data/tables/` (loses unstaged data)

## Coherence rules

### FK integrity

Every foreign key reference in a JSONL row must resolve to a real row in the target table. Common FKs:

- `agent.prompt_id` → `prompts.id`
- `agent.model_id` → `ai_models.id`
- `agent.token_id` → `api_tokens.id`
- `agent_skills.skill_id` → `skills.id`
- `collections.data_source_id` → `data_sources.id`
- `data_sources.connector_id` → `data_connectors.id`
- `bundle_items.artifact_id` → `artifacts.id`
- `artifacts.publisher_id` → `publishers.id`

When you add a row that references `X`, confirm `X` exists. When you delete a row, find and fix orphan references.

### Canonical homes (no duplication)

Each entity lives in ONE canonical place. Do NOT duplicate.

| Entity | Canonical table | Referenced from |
|--------|-----------------|-----------------|
| User | `users` | audit events, sessions, tokens (owner), agents (created_by) |
| API Token | `api_tokens` | agents, workflows, runtimes |
| Prompt | `prompts` (+ `prompt_versions`) | agents (prompt_id), skills (linked_skills) |
| Skill | `skills` | agents via `agent_skills` junction, CORA via `cora_enabled_skills` |
| Guardrail | `guardrails` | agents via `agent_guardrails` junction |
| Model | `ai_models` | agents (model_id), defaults (alias→model_id) |
| Provider | `ai_providers` | ai_models (provider) |
| Connector (data) | `data_connectors` | data_sources (connector_id) |
| Collection | `collections` | records, agents (via perms eventually) |
| Bundle | `bundles` | bundle_items, agents (agent.bundle_id when installed from bundle) |
| Publisher | `publishers` | artifacts, bundles |
| Audit event | `audit_events` (in `audit/` schema) | all modules emit via `@openbims/audit`; no module owns a local store |

**Centralized logging rule** (per [[adr-audit-01-centralized-logging]]): no module may define tables of the form `{module}_audit_events`, `{module}_logs`, or equivalent local stores of audit events. Scenarios that need "show activity log for X" populate the central `audit_events` table with `module='X'` and consume it through a module-scoped filter (see `useMarketplaceAuditEvents` for the canonical pattern).

### Naming conventions

- ID prefixes: `agt-` (agents), `skl-` (skills), `pmt-` (prompts), `grd-` (guardrails), `tkn-` (tokens), `col-` (collections), `dcon-` (data connectors), `art-` (marketplace artifacts), `bnd-` (bundles), `pub-` (publishers), `sess-` (sessions), `usr-` or email (users).
- Names: kebab-case for technical IDs; Title Case or natural names for display.
- No mixing: never use "example-001" or "sample". Make it look like a real OpenBIMS instance ("clinical-variant-interp", not "agent-1").

### Realistic content

- Use plausible tenant names (Hospital Clínic Barcelona, MoG Research Lab, Pediatric Oncology Unit).
- Real-world personas for users (dr.garcia, dr.martinez, research.team, compliance.team).
- Medical/clinical terminology where relevant.
- **NO real PII, PHI, patient IDs, or identifiable health data.** Use obviously fake but plausible values.
- Dates: coherent (created_at ≤ updated_at, timestamps plausible, not all on the same day).

### Active vs stale

- If a screen is deleted, delete its entities (and anything referencing them).
- If a feature is removed from the PDD, its mock data should also go.
- Broken FKs must be either repaired or the referencing row deleted.

## Scenario design protocol

When the user describes a use case ("Hospital X wants to see their EHR connected to an agent reviewing patient notes"), follow this protocol. Do NOT start writing rows until step 4.

### Step 1 — Understand (conversational)

Ask the user what's missing:
- Which tenant/org? (real-sounding name)
- What external system is being connected? (FHIR server, SFTP, database, wearables)
- Which agent does the work? (existing agent or a new one)
- What actions should the agent do? (query, summarize, extract, classify, generate)
- What should the user see in the prototype? (list, dashboard, detail view, audit trail)

### Step 2 — Map to entities

Translate the narrative into an entity inventory across modules. Typical pattern for an "agent connected to data" scenario:

- **Marketplace artifact** for the connector (if not already present): publisher, version, category
- **Data connector** row (today still separate from artifact — see drift note below): `dcon-*`
- **Data source** (server instance) that uses the connector: `dsrc-*`
- **Collection** (or Filestore) that reads from the data source: `col-*`
- **Knowledge base** on top of the collection (if RAG is involved): `kb-*`
- **Prompt** for the agent: `pmt-*`
- **Token** with the right permissions: `tkn-*`
- **Agent** referencing all of the above: `agt-*`
- **Agent skills** (prefer reusing Platform Skills; only create `function`/`mcp`/`external-agent` skills if genuinely new)
- **Guardrails** attached to the agent: reuse existing or add new rows
- **Agent sessions** (a couple of them) so "Sessions today" shows activity: `sess-*`
- **Audit events** (10-30 rows) so the audit trail and analytics have content

### Step 3 — Check reuse vs create

For each entity in the inventory, decide:
- **Reuse** if an existing row already covers this need (e.g., the Clinical Token covers most clinical agents)
- **Create** if none fits

Prefer reuse. It's what a real multi-tenant instance would look like.

### Step 4 — Propose to user

Present the plan as a table BEFORE writing any row:

| Entity | Action | ID | Notes |
|--------|--------|-----|-------|
| Marketplace artifact (FHIR R5) | Reuse | `art-fhir-r5` | already published |
| Data connector | Reuse | `dcon-fhir-r5` | linked to artifact (pending unification) |
| Data source | Create | `dsrc-hclinic-ehr` | new FHIR server instance |
| Agent | Create | `agt-hclinic-ehr-reviewer` | new |
| Prompt | Create | `pmt-ehr-review` | new, references skill `skl-fhir-query` |
| Token | Reuse | `tkn-clinical` | shared with other clinical agents |
| Skills | Reuse | `skl-fhir-query`, `skl-umd-query` | |
| Guardrails | Reuse | `grd-pii`, `grd-disclaimer` | |
| Sessions | Create | `sess-*` (×3) | seed activity |
| Audit events | Create | `evt-*` (×15) | last 7 days |

Wait for user approval.

### Step 5 — Write rows

Only after approval:
- Append new rows to the right JSONL files (don't rewrite existing data)
- Respect FK order: create parent rows before children
- Use realistic timestamps (not all same second)
- Assign stable IDs (slugs + counters, not UUIDs)

### Step 6 — Validate + sync

1. Run validator (`validate` invocation) to catch broken FKs and orphan refs
2. If a new table was added, also update:
   - `mock-data/schema/{NN}_{module}.sql` (CREATE TABLE)
   - `code/openbims-console/src/db/client.js` (table manifest inside `discoverTables`)
3. Run `bash code/openbims-console/scripts/sync-data.sh` to copy to `public/data/`
4. Tell the user what to expect in the prototype and where (exact routes)

### Step 7 — Document

If the scenario introduces significant new data, create a tracker ticket via `/openbims_workspace task create "..." --epic {module} --size {S|M|L|XL}` for cross-session context.

## Validation checks

Run these every time after editing:

### Table/schema consistency
- Every CREATE TABLE in `schema/*.sql` has a corresponding `tables/*.jsonl` (or is documented as schema-only)
- Every JSONL file has a CREATE TABLE
- Every table listed in `code/openbims-console/src/db/client.js` exists on disk
- Every table on disk is listed in `client.js` (otherwise it's skipped)

### FK integrity
- For each declared FK, scan the JSONL of the child and assert every FK value exists in the parent JSONL
- Flag junction tables with rows referencing deleted parents

### Coherence
- No duplicate IDs within a single table
- No duplicate canonical entities across tables (e.g., PostgreSQL connector appearing in both `data_connectors` and as a separate entry in `artifacts` without cross-link — this IS current drift, flag as `tracked`)
- Timestamps are plausible (not in the year 1970, not in the future for `created_at`, `updated_at` ≥ `created_at`)
- Status values are in the declared set (e.g., `status` is one of the documented enum values)

### Centralized logging (per [[adr-audit-01-centralized-logging]])
- Run: `grep -rniE "CREATE TABLE.*_(audit_events|activity_log|audit_log|logs_table)" mock-data/schema/`.
- Any match outside `audit/` schema is a violation. Flag as `critical`.
- No currently tracked drift — legacy `marketplace_audit_events` was removed (2026-04-23); marketplace events flow into the central `audit_events` table with `module='Marketplace'`.

### Runtime verification
- After sync, launch the dev server and verify:
  - No "Loaded X tables (N skipped)" with N > 0 (all tables should load)
  - No "Table does not exist" warnings in console
  - No "Binder Error" or "Parser Error" in views
  - Affected screens render without React errors

## Known drift (tracked, do NOT flag as new)

See `tracker/tickets/` (use `/openbims_workspace task list --epic {module}` or open the Kanban). Today's tracked drift:

- **Connector ≠ Marketplace artifact.** `data_connectors`, `filesystem_connectors`, `messaging_connectors`, etc. have their own IDs (`dcon-postgresql`), separate from `artifacts` of the Marketplace. In a real instance, they'd be the same entity (an installed connector IS a Marketplace artifact). Unification is deferred; when designing scenarios, treat them as one logically even though they're two rows. Note the intended artifact_id in the connector row's `marketplace_artifact_id` field if you create new ones.

## Rules

1. **JSONL is source of truth.** Do not edit `code/*/public/data/*` directly — it gets overwritten by `sync-data.sh`.
2. **Validate before sync.** Never push to `public/data/` with broken FKs.
3. **Scenarios are additive.** A new scenario adds rows; it does NOT delete or modify existing baseline rows unless the user explicitly asks.
4. **Propose before writing.** For any non-trivial change (new entity, new scenario), present the plan first.
5. **No PII.** Realistic but fake. No real patient data, no real SSNs, no real addresses.
6. **Sync + verify.** After any change, sync and open the affected prototype routes to confirm visibility.
7. **New tables need three updates.** Adding a new table requires: (a) CREATE TABLE in schema/, (b) JSONL in tables/, (c) entry in `client.js` `discoverTables` array. Omitting (c) silently skips the table.
8. **Document drift.** Known incoherences that aren't blocking get a tracker ticket via `/openbims_workspace task create` with a fix plan in the body, never stay implicit.

## Output format when applying a scenario

At the end of a scenario application, report:

```markdown
## Scenario applied: {name}

**New rows:**
- prompts.jsonl: +1 (pmt-ehr-review)
- agents.jsonl: +1 (agt-hclinic-ehr-reviewer)
- agent_sessions.jsonl: +3
- agent_audit_events.jsonl: +15
- data_sources.jsonl: +1 (dsrc-hclinic-ehr)

**Reused:**
- Marketplace artifact: art-fhir-r5
- Token: tkn-clinical
- Skills: skl-fhir-query, skl-umd-query, skl-pubmed
- Guardrails: grd-pii, grd-disclaimer

**Sync:** ✅ `public/data/` updated

**Visible in the prototype:**
- `/ai-agents/agents` — new "hclinic-ehr-reviewer" row
- `/ai-agents/agt-hclinic-ehr-reviewer` — full detail with 3 skills, 2 guardrails, new sessions
- `/ai-agents` (dashboard) — top agents table includes the new agent
- `/ai-agents/audit` — 15 new events referencing this agent

**No UI changes were made.**
```
