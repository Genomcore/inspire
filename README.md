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
| [`.inspire/`](.inspire/) | The **guardrail runtime**, staged dormant: `skills/` (the `inspire-*` agent skills), `bin/` (the validators + fixtures), `hooks/` (the git-time hooks), and `install.sh` (instantiation). See [`.inspire/README.md`](.inspire/README.md). |
| [`.inspire_kb/`](.inspire_kb/) | The **knowledge-base skeleton** — the navigable graph a project fills in (`00_bootstrap` · `01_adr` · `02_features` · `03_prototypes` · `04_specs` · `05_screens` · `06_tracker`). Each folder documents its own purpose and layout. |
| [`.manual/`](.manual/) | The INSPIRE **microsite / manual** — the canonical explanation of the methodology. Open `.manual/index.html` in a browser. |
| [`prototype/`](prototype/) | The **horizontal prototype** (product-side, non-dot) — the wide/shallow/mocked working model of the whole product. Its learnings live in `.inspire_kb/03_prototypes/`; verticals live in external repos. |
| [`source/`](source/) | The **production monorepo** (product-side, non-dot) — the root of the actual product code, realized from the KB. Where ADRs reach `implemented`. |

The skills + validators + hooks in `.inspire/` are the **guardrail layer**: the
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
specs, screen specs, the horizontal prototype at `/prototype`, external verticals).

Instantiation is one command (`bash .inspire/install.sh`), and the foundation
([`00_bootstrap`](.inspire_kb/00_bootstrap): stack + theme) ships with a sensible
default. What each project still supplies is its own content — its modules,
features, screens and specs — plus a starter `05_screens/patterns/` +
`design-system.md`. See the Roadmap.

### Wiring the guardrails into a project

Fork/clone this repo, then instantiate the runtime once:

```bash
bash .inspire/install.sh
```

It copies `.inspire/{skills,bin,hooks}` → `.claude/{skills,bin,hooks}` (where
Claude Code discovers and executes them), makes the scripts executable, and wires
the `pre-commit` / `pre-pr` hooks into `.claude/settings.json`. It is idempotent —
re-run it after pulling template updates. Then start filling in `.inspire_kb/`.

Prerequisites for the validators: `bash` 4+, `yq` (Mike Farah's v4), `jq` 1.6+.

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
- [x] Strip OpenBIMS domain prose from all skills — the runtime speaks the generic INSPIRE model.
- [x] Stage the runtime under `.inspire/` and ship `.inspire/install.sh` to instantiate it into `.claude/` on a fork.
- [x] Seed `00_bootstrap` (`stack.md` + `theme.md`) and add the `inspire-bootstrap` skill to configure them.
- [ ] Ship a starter `05_screens/patterns/` + `design-system.md` (the module ID-prefix convention already lives in the module/feature skills).
- [ ] Publish the microsite.

---

*Individual · Navigable · Spec-driven · Prototypical · Iterative · Regenerative · Enforceable*
