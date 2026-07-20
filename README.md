# INSPIRE

**A software engineering methodology for the agentic era.**

> **I**ndividual · **N**avigable · **S**pec-driven · **P**rototypical · **I**terative · **R**egenerative · **E**nforceable

When generating code is cheap, the scarce work is no longer writing it — it's
**knowing what to build, and telling whether it's right.** INSPIRE is a way to
build software with AI agents around that shift: intent lives in a navigable
knowledge graph, prototypes create clarity, and coherence is protected
*mechanically* by guardrails rather than by human discipline.

INSPIRE was born inside [OpenBIMS](https://openbims.dev), an open-source
healthcare-AI platform by [Genomcore](https://genomcore.com). This repository
is its **home** — where the methodology is documented and evolved — and a
**template** for bootstrapping new specification-driven projects.

---

## What's here

| Path | What it is |
|---|---|
| [`site/`](site/) | The INSPIRE **microsite** — the canonical explanation of the methodology. Open `site/index.html` in a browser. |
| [`skills/`](skills/) | The agent **skills** — the operating manual each layer of the methodology runs on (module · feature · UI · mock-data · docs · object · workspace · prototype · video). |
| [`hooks/`](hooks/) | Git-time **enforcement hooks** (`pre-commit`, `pre-pr`) that run the review at tool-call time. |
| [`bin/`](bin/) | The **validators** — bash scripts that parse artifacts, evaluate rules, and emit structured findings. See [`bin/README.md`](bin/README.md). |

`skills/`, `hooks/` and `bin/` together are the **guardrail layer**: the
concrete embodiment of INSPIRE's *Enforceable* principle — skills carry the
judgment, hooks + validators catch drift mechanically.

## The methodology in one breath

- **The shift.** Software development was a coordination problem; Agile was built for that. Now one person can orchestrate a swarm of agents, and the bottleneck moves from coordination to **judgment**.
- **The unit of work is a Breath**, not a sprint: one intent, one context — *inhale* (internalize the problem) → *exhale* (materialize it as a pull request). Its size is set by context and impact, not by a clock.
- **The spiral of convergence.** Every Breath turns through *Discover → Specify → Generate → Verify*, each loop reducing uncertainty and moving the product closer to release.
- **Prototypes create clarity.** One *horizontal* prototype (wide, shallow, mocked) asks "is this the right thing?"; many *vertical* spikes (narrow, deep, functional) ask "can we build it as we think?".
- **Knowledge lives in a navigable graph** of plain-text artifacts — the shared context between humans and agents, durable across regenerations of the code.

For the full story, open [`site/index.html`](site/index.html).

---

## Using this as a template

The intent is that a new specification-driven project can adopt INSPIRE's
guardrail layer wholesale. **Important:** this is a *faithful extraction, not
yet generalized* — see the heads-up below.

### Heads-up: still OpenBIMS-flavored

The skills, hooks and validators are copied **verbatim** from OpenBIMS. They
still speak OpenBIMS's domain:

- Skills are named `openbims-*` and reference OpenBIMS concepts (PDD, the SDD
  module layout, the React console prototype, DuckDB mock data, the HTML manual).
- The hooks derive the project root from `.claude/hooks/` and scope the review
  to `spec/sdd/`; the validators expect the OpenBIMS SDD layout
  (`spec/sdd/{module}/{entity}/…`).

So today they are a **reference implementation to adapt**, not a drop-in.
Generalizing them is the evolution work this repository exists to do (see
Roadmap).

### Wiring the guardrails into a project (once adapted)

1. Copy `skills/` → `<project>/.claude/skills/`
2. Copy `hooks/` → `<project>/.claude/hooks/` and `bin/` → `<project>/.claude/bin/`
3. Register the hooks in `<project>/.claude/settings.json`:
   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Bash",
           "hooks": [
             { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/pre-commit.sh" },
             { "type": "command", "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/pre-pr.sh" }
           ]
         }
       ]
     }
   }
   ```
4. Prerequisites for the validators: `bash` 4+, `yq` (Mike Farah's v4), `jq` 1.6+.

---

## Provenance

Extracted from `openbims-pdd` on 2026-07-20. The OpenBIMS-specific alignment
ledger (`methodology/alineacion-datum-openbims.md` — the *Datum ↔ OpenBIMS*
mapping) intentionally **stays in that repository**, since it documents *that*
implementation. What lives here is the methodology itself and its portable
guardrail layer.

## Roadmap

- [ ] Generalize the skills: `openbims-*` → `inspire-*`, domain-neutral.
- [ ] Decouple the validators from hard-coded `spec/sdd/` paths; make the SDD layout configurable.
- [ ] Ship a runnable `.claude/` so a new project works by copy.
- [ ] Extract the horizontal/vertical prototype conventions as reusable scaffolding.
- [ ] Publish the microsite.

---

*Individual · Navigable · Spec-driven · Prototypical · Iterative · Regenerative · Enforceable*
