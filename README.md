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

The convention: **dotfolders are INSPIRE scaffolding**; non-dot dirs are the
product you build on top.

| Path | What it is |
|---|---|
| [`.skills/`](.skills/) | The agent **skills** — the operating manual each layer of the methodology runs on (module · feature · object · prototype · ui · workspace). |
| [`.inspire_kb/`](.inspire_kb/) | The **knowledge-base skeleton** — the navigable graph a project fills in (`00_tech_stack` · `01_adr` · `02_features` · `03_prototypes` · `04_specs` · `05_ui` · `06_tracker`). Each folder documents its own purpose and layout. |
| [`.manual/`](.manual/) | The INSPIRE **microsite / manual** — the canonical explanation of the methodology. Open `.manual/index.html` in a browser. |
| [`prototype/`](prototype/) | The **horizontal prototype** (product-side, non-dot) — the wide/shallow/mocked working model of the whole product. Its learnings live in `.inspire_kb/03_prototypes/`; verticals live in external repos. |
| [`hooks/`](hooks/) | Git-time **enforcement hooks** (`pre-commit`, `pre-pr`) that run the review at tool-call time. |
| [`bin/`](bin/) | The **validators** — bash scripts that parse artifacts, evaluate rules, and emit structured findings. See [`bin/README.md`](bin/README.md). |

`.skills/`, `hooks/` and `bin/` together are the **guardrail layer**: the
concrete embodiment of INSPIRE's *Enforceable* principle — skills carry the
judgment, hooks + validators catch drift mechanically. `.inspire_kb/` is the
graph they operate on.

## The methodology in one breath

- **The shift.** Software development was a coordination problem; Agile was built for that. Now one person can orchestrate a swarm of agents, and the bottleneck moves from coordination to **judgment**.
- **The unit of work is a Breath**, not a sprint: one intent, one context — *inhale* (internalize the problem) → *exhale* (materialize it as a pull request). Its size is set by context and impact, not by a clock.
- **The spiral of convergence.** Every Breath turns through *Discover → Specify → Generate → Verify*, each loop reducing uncertainty and moving the product closer to release.
- **Prototypes create clarity.** One *horizontal* prototype (wide, shallow, mocked) asks "is this the right thing?"; many *vertical* spikes (narrow, deep, functional) ask "can we build it as we think?".
- **Knowledge lives in a navigable graph** of plain-text artifacts — the shared context between humans and agents, durable across regenerations of the code.

For the full story, open [`.manual/index.html`](.manual/index.html).

---

## Using this as a template

The intent is that a new specification-driven project can adopt INSPIRE's
guardrail layer wholesale by cloning this repo and filling in `.inspire_kb/`.
The skills, hooks and validators are renamed (`inspire-*`), rewired to the
`.inspire_kb/` layout, parameterized via `SDD_SPEC_ROOT`, and **stripped of
OpenBIMS domain vocabulary** — they speak the generic INSPIRE model (features,
specs, UISpecs, the horizontal prototype at `/prototype`, external verticals).

What's left before it's a zero-friction drop-in is **wiring**: a runnable
`.claude/` and the project-specific conventions each project supplies (module ID
prefixes, a starter `patterns/` + `design-system.md`, `00_tech_stack`). See the
Roadmap.

### Wiring the guardrails into a project

1. Copy `.skills/` → `<project>/.claude/skills/`
2. Copy `hooks/` → `<project>/.claude/hooks/` and `bin/` → `<project>/.claude/bin/`
3. Copy `.inspire_kb/` → `<project>/.inspire_kb/` and start filling it in.
4. Register the hooks in `<project>/.claude/settings.json`:
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
5. Prerequisites for the validators: `bash` 4+, `yq` (Mike Farah's v4), `jq` 1.6+.

---

## Provenance

Extracted from `openbims-pdd` on 2026-07-20. The OpenBIMS-specific alignment
ledger (`methodology/alineacion-datum-openbims.md` — the *Datum ↔ OpenBIMS*
mapping) intentionally **stays in that repository**, since it documents *that*
implementation. What lives here is the methodology itself and its portable
guardrail layer.

## Roadmap

- [x] Rename the skills `openbims-*` → `inspire-*`.
- [x] Decouple the validators/hooks from hard-coded `spec/sdd/` paths (rewired to `.inspire_kb/`, `SDD_SPEC_ROOT` configurable).
- [x] Establish the `.inspire_kb/` knowledge-base skeleton.
- [x] Define the prototype model and rewrite `inspire-prototype` (horizontal at `/prototype`; verticals as external repos with imported learnings).
- [x] Reconcile `inspire-module` / `inspire-feature` to the flat `02_features/{module}/{use-case}.md` layout.
- [x] Strip OpenBIMS domain prose from all skills — `.skills/` now speaks the generic INSPIRE model.
- [ ] Ship a runnable `.claude/` (or an instantiation script) so a new project works by copy.
- [ ] Provide starter project conventions (module ID prefixes, `patterns/` + `design-system.md`, `00_tech_stack`).
- [ ] Publish the microsite.

---

*Individual · Navigable · Spec-driven · Prototypical · Iterative · Regenerative · Enforceable*
