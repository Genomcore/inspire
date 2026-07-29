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
| [`plugin/`](plugin/) | The distributable **Claude Code plugin**. `.claude-plugin/plugin.json` carries the release identity (`version` + `released`); `skills/{init,update}/` are the only **live** skills — `/inspire:init` and `/inspire:update`; `base/` is the **inert payload**, materialized into a governed project by init: `base/skills/` → `.claude/skills/inspire-*`, `base/bin/` → `.inspire/bin/` (validators — `base/bin/test/` never materializes), `base/hooks/` → `.claude/inspire/hooks/`, `base/kb/` → `inspire_kb/`, `base/templates/` → a provisional root `CLAUDE.md`, a `.gitignore` block, and the `source/` + `prototype/` README stubs. |
| [`.claude-plugin/marketplace.json`](.claude-plugin/marketplace.json) | Makes this repo its own plugin marketplace, so `/plugin marketplace add Genomcore/inspire` resolves. |
| [`.manual/`](.manual/) | The INSPIRE **microsite / manual** — the canonical explanation of the methodology. Live at **[inspire.openbims.dev](https://inspire.openbims.dev)**; source here. |
| [`docs/adr/`](docs/adr/) | Hand-authored, core-level ADRs about INSPIRE itself — not materialized; a governed project's own decisions live in its `inspire_kb/01_adr/`. |

> `inspire_kb/`, `prototype/` and `source/` don't exist in this template repo —
> they're materialized into a **governed** project by `/inspire:init` (the KB
> skeleton and the product roots, respectively), not shipped here. This list
> covers the repo's top level, not every file `/inspire:init` writes — see
> [`CLAUDE.md`](CLAUDE.md)'s *Structure* section for the fuller breakdown of
> `plugin/base/`.

The skills + validators + hooks under `plugin/base/` are the **guardrail layer**:
the concrete embodiment of INSPIRE's *Enforceable* principle — skills carry the
judgment, hooks + validators catch drift mechanically. `inspire_kb/` is the graph
they operate on.

---

## Get started

A new specification-driven project adopts INSPIRE's guardrail layer wholesale by
installing the plugin and materializing it into a repo. The skills, hooks and
validators speak a generic, stack-agnostic model — features, specs, screens,
prototypes — so they fit any stack.

**1. Install the plugin (once per machine).**

```
/plugin marketplace add Genomcore/inspire
/plugin install inspire@inspire
/reload-plugins
```

This is a per-user maintainer tool, not a runtime dependency — it is never
referenced once a project is materialized. Only whoever runs an init or update
needs it installed; teammates and CI need nothing.

**2. In the repo you want to govern, initialize.**

```
/inspire:init
```

It asks two questions (product roots; whether to declare the marketplace for
teammates), then materializes the skills, validators, hooks and KB skeleton,
marker-merges the `session-start` + `dispatch` hooks into `.claude/settings.json`,
seeds the design system from your bootstrap theme, seeds a provisional root
`CLAUDE.md` and a `.gitignore` block (both left untouched if already present), and
writes `.inspire.lock` recording which release was materialized plus a hash of
every file it wrote (used later for drift detection). It never touches your git
history and never clobbers existing content.

**3. Reload, then bootstrap.**

```
/reload-skills
/inspire_bootstrap init
```

`/reload-skills` picks up the newly materialized `inspire-*` skills — no restart
needed. `/inspire_bootstrap init` then sets the project's output language,
configures the stack + theme and its shape (frontend / backend / monorepo · web /
mobile · database), refines the seeded `CLAUDE.md` and creates your project's own
`README.md`, and optionally wires your git remote. Then start filling in
`inspire_kb/` — your modules, features, screens and specs. The foundation
(`00_bootstrap`) and starter screen patterns ship with sensible defaults; the
`inspire-*` skills guide the rest.

**4. Commit the result.** From here the runtime lives in git like any other
project file — pulling a template update means running `/plugin update inspire`
then `/inspire:update` (which reports drift on the runtime — skills, validators,
hooks — and never overwrites a locally-edited file without your say-so), not
re-forking. `inspire_kb/` is out of scope for update entirely: it is seeded once
at init and is yours from then on.

> **Output language.** Every skill authors its artifacts in the project's declared
> language (`inspire_kb/00_bootstrap/project.md`, default English) —
> independent of the language you converse in and of the product's own UI
> i18n. A `session-start` hook surfaces it into every session.

> **Prerequisites:** `bash` 3.2+ (macOS's built-in bash is fine — no need to
> install a newer one), [`yq`](https://github.com/mikefarah/yq) (Mike Farah's v4),
> `jq` 1.6+.

---

<div align="center">

**INSPIRE doesn't define how code is produced.**
It represents how a well-designed system *breathes* — coherent, alive, and able to
renew itself.

*Individual · Navigable · Spec-driven · Prototypical · Iterative · Regenerative · Enforceable*

Born in [OpenBIMS](https://openbims.dev) · by [Genomcore](https://genomcore.com)

</div>
