<div align="center">

# INSPIRE

### Software that breathes.

**A software engineering methodology for the agentic era.**

> **I**ndividual · **N**avigable · **S**pec-driven · **P**rototypical · **I**terative · **R**egenerative · **E**nforceable

[**Read the manual → inspire.openbims.dev**](https://inspire.openbims.dev) · [OpenBIMS](https://openbims.dev) · [Genomcore](https://genomcore.com)

</div>

---

## Why INSPIRE

For decades, building software was a **coordination** problem — getting teams of
humans aligned around implementation. Agile was built for that world.

That world is ending. When generating code is cheap, the scarce work is no longer
writing it — it's **knowing what to build, and telling whether it's right.** A
single person can now orchestrate a swarm of AI agents, and the bottleneck moves
from coordination to **judgment**.

INSPIRE is a way to build software around that shift:

- **Intent lives in a navigable knowledge graph** — plain-text artifacts that stay
  durable across every regeneration of the code.
- **Prototypes create clarity** — a wide, shallow horizontal prototype and narrow,
  deep vertical spikes reduce uncertainty *before* you commit.
- **Coherence is enforced mechanically** — guardrails, skills and automated checks
  catch drift by design, not by human discipline.

It was born inside [OpenBIMS](https://openbims.dev), an open-source healthcare-AI
platform by [Genomcore](https://genomcore.com). This repository is both its
**home** — where the methodology is documented and evolved — and a ready-to-use
**template** for bootstrapping your own specification-driven projects.

> 📖 **The full story lives in the manual:** **[inspire.openbims.dev](https://inspire.openbims.dev)**
> (source in [`.manual/`](.manual/) — open [`.manual/index.html`](.manual/index.html) locally).

---

## The methodology in one breath

- **The unit of work is a Breath, not a sprint.** One intent, one context —
  *inhale* (internalize the problem) → *exhale* (materialize it as a pull request).
  Its size is set by context and impact, not by a clock.
- **Every Breath turns the spiral of convergence** — *Discover → Specify → Generate
  → Verify* — each loop reducing uncertainty and moving the product closer to release.
- **Prototypes are instruments for learning, not early products.** One *horizontal*
  prototype (wide, shallow, mocked) asks "is this the right thing?"; many *vertical*
  spikes (narrow, deep, functional) ask "can we build it as we think?".
- **The specification is the DNA of the system.** Code is its current expression; when
  it drifts, agents regenerate it while preserving the original intent.

*Stop sprinting. Start breathing.*

---

## What's in this repo

The convention: **dotfolders are INSPIRE scaffolding**; non-dot dirs are the
product you build on top.

| Path | What it is |
|---|---|
| [`.inspire/`](.inspire/) | The **guardrail runtime**, staged dormant: `skills/` (the `inspire-*` agent skills — the judgment half), `bin/` (the validators + fixtures — the mechanical half), `hooks/` (the git-time + session-start hooks), `templates/` (product-side files materialized at install) and `install.sh` (instantiation). See [`.inspire/README.md`](.inspire/README.md). |
| [`.inspire_kb/`](.inspire_kb/) | The **knowledge-base skeleton** — the navigable graph a project fills in (`00_bootstrap` · `01_adr` · `03_features` · `06_spikes` · `04_domain` · `05_screens` · `98_skill_learnings` · `99_tracker`). Each folder documents its own purpose and layout. |
| [`.manual/`](.manual/) | The INSPIRE **microsite / manual** — the canonical explanation of the methodology. Live at **[inspire.openbims.dev](https://inspire.openbims.dev)**; source here. |
| `prototype/` | The **horizontal prototype** (product-side) — the wide/shallow/mocked working model of the whole product. *Created at install, not shipped here.* |
| `source/` | The **production monorepo** (product-side) — the root of the actual product code, realized from the KB. Where ADRs reach `implemented`. *Created at install, not shipped here.* |

> The two product-side dirs (`prototype/`, `source/`) don't exist in this template
> repo — they're your product, not INSPIRE. `install.sh` creates them on
> instantiation, and also removes this methodology `README.md` so your fork starts
> with its own (written by `/inspire_bootstrap init`).

The skills + validators + hooks in `.inspire/` are the **guardrail layer**: the
concrete embodiment of INSPIRE's *Enforceable* principle — skills carry the
judgment, hooks + validators catch drift mechanically. `.inspire_kb/` is the graph
they operate on.

---

## Get started

A new specification-driven project adopts INSPIRE's guardrail layer wholesale by
cloning this repo and filling in `.inspire_kb/`. The skills, hooks and validators
speak a generic, stack-agnostic model — features, specs, screens, prototypes — so
they fit any stack.

**1. Fork or clone this repository.**

```bash
git clone https://github.com/genomcore/inspire.git my-project
cd my-project
```

**2. Instantiate the runtime (once per fork).**

```bash
bash .inspire/install.sh
```

This copies `.inspire/{skills,bin,hooks}` → `.claude/{skills,bin,hooks}` (where
Claude Code discovers and executes them), makes the scripts executable, wires the
`session-start` + `pre-commit` / `pre-pr` hooks into `.claude/settings.json`,
creates the product-side `prototype/` + `source/` folders, seeds the design system
from your bootstrap theme, writes a root `.inspire.lock` recording which INSPIRE
release was instantiated, and removes this methodology `README.md`. It is
**idempotent** — `.inspire/` stays the versioned source of truth, so re-run it
after pulling template updates (your own `prototype/`, `source/` and `README.md`
are left untouched).

**3. Run `/inspire_bootstrap init`.** It sets the project's output language,
configures the stack + theme and its shape (frontend / backend / monorepo · web /
mobile · database), creates your project's own `README.md`, and optionally wires
your git remote. Then start filling in `.inspire_kb/` — your modules, features,
screens and specs. The foundation ([`00_bootstrap`](.inspire_kb/00_bootstrap)) and
starter screen patterns ship with sensible defaults; the `inspire-*` skills guide
the rest.

> **Output language.** Every skill authors its artifacts in the project's declared
> language ([`00_bootstrap/project.md`](.inspire_kb/00_bootstrap/project.md),
> default English) — independent of the language you converse in and of the
> product's own UI i18n. A `session-start` hook surfaces it into every session.

> **Prerequisites for the validators:** `bash` 4+, [`yq`](https://github.com/mikefarah/yq)
> (Mike Farah's v4), `jq` 1.6+.

---

<div align="center">

**INSPIRE doesn't define how code is produced.**
It represents how a well-designed system *breathes* — coherent, alive, and able to
renew itself.

*Individual · Navigable · Spec-driven · Prototypical · Iterative · Regenerative · Enforceable*

Born in [OpenBIMS](https://openbims.dev) · by [Genomcore](https://genomcore.com)

</div>
