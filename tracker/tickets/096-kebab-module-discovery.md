---
id: 096-kebab-module-discovery
title: "096 — a kebab-case module slug is invisible to the domain finders, and the failure mode is silence"
created: 2026-09-10
updated: 2026-09-10
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: Very High
skills: []
status: Open
blocked_by: []
related_to: [096-wikilink-alias-target]
---

## Description

Reported against 0.9.1 by a governed project running the runtime over its own vault.

`sdd_find_actions` and `sdd_find_entities` in `plugin/base/bin/_lib.sh` recognise a domain
artifact by the dotted segment count of its leaf filename, and both match those segments
with `[A-Za-z0-9_]` — no hyphen. INSPIRE's own guidance says a multi-word module slug is
kebab-case, so the runtime asks for a shape it then cannot see.

**Nothing reports it.** The file is not discovered, so no rule reads it, and a rule that
reads nothing emits nothing. In the reporting vault that hid 6 action descriptors and 3
entity documents of one module behind a clean `review.sh` run.

Everything downstream is built on those two lists, so the module is missing from all of it
at once:

- **Every rule** — `field-coverage`, `keys-present`, `constraints-mechanics`,
  `head-referents`, `sections-present` and the rest iterate the two finders.
- **The id index** — `sdd_build_id_index` reads `sdd_find_actions`, so no id of that module
  is indexed and every wikilink pointing at one is reported as dangling.
- **The emanation planner** — `lib/plan-scan.sh` calls the same helpers, so the module can
  never enter a frontier.
- **Derive, even when the unit is named outright** — `emanate-derive.sh` validates the path
  through `kind_holds`, which calls the same helpers, and refuses a well-formed descriptor.

The consuming project's measured counts on 0.9.1 were 36 of 42 actions and 20 of 23
entities discovered, all nine misses in the one kebab-case module.

## Acceptance criteria

- [ ] Both finders discover a leaf filename whose module segment is kebab-case, and the
      segment count still separates an entity document from an action descriptor.
- [ ] `plugin/base/bin/` is audited for the same character class used on a slug elsewhere,
      and each site is either fixed or recorded as deliberately snake-only.
- [ ] The regression asserts the artifact is **discovered** — a fixture that asserts an
      absence of findings passes while the module is skipped, which is the defect.
