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
| [`.inspire_kb/`](.inspire_kb/) | The **knowledge-base skeleton** — the navigable graph a project fills in (`00_bootstrap` · `01_adr` · `02_features` · `03_prototypes` · `04_domain` · `05_screens` · `99_tracker`). Each folder documents its own purpose and layout. |
| [`.manual/`](.manual/) | The INSPIRE **microsite / manual** — the canonical explanation of the methodology. Live at **[inspire.openbims.dev](https://inspire.openbims.dev)**; source here (open `.manual/index.html` locally). |
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

For the full story, read the manual at **[inspire.openbims.dev](https://inspire.openbims.dev)** (or open [`.manual/index.html`](.manual/index.html) locally).

---

## Using this as a template

A new specification-driven project adopts INSPIRE's guardrail layer wholesale by
cloning this repo and filling in `.inspire_kb/`. The skills, hooks and validators
speak a generic, stack-agnostic model — features, specs, screens, the horizontal
prototype at `/prototype`, external verticals — and read the spec root from
`SDD_SPEC_ROOT`.

Instantiation is one command (`bash .inspire/install.sh`), and the foundation
([`00_bootstrap`](.inspire_kb/00_bootstrap): stack + theme) ships with a sensible
default. Each project supplies its own content — its modules, features, screens
and specs. Starter `05_screens/patterns/` (`list`, `detail`) come included, and the
design system is seeded from the bootstrap theme at install.

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

*Individual · Navigable · Spec-driven · Prototypical · Iterative · Regenerative · Enforceable*
