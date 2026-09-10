---
id: 096-kebab-module-discovery
title: "096 — a kebab-case module slug is invisible to the domain finders, and the failure mode is silence"
created: 2026-09-10
updated: 2026-09-10
reporter: "@dario.blasco"
closed_by: "@dario.blasco"
closed_at: 2026-09-10
epic: follow-up
size: S
importance: Very High
skills: []
status: Done
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

- [x] Both finders discover a leaf filename whose module segment is kebab-case, and the
      segment count still separates an entity document from an action descriptor. — the
      hyphen is in all three segments of both patterns; the finders identify an artifact by
      segment count and slug shape is another rule's question, so the class is uniform.
- [x] `plugin/base/bin/` is audited for the same character class used on a slug elsewhere,
      and each site is either fixed or recorded as deliberately snake-only. — one other
      site, `prose-style.sh`'s R4 id stripper, fixed with it. `declared-errors-tested.sh`
      already carried the hyphen; `_keyed-heads.sh` and `_lib.sh`'s table-cell patterns read
      field names, which are snake by contract, and are left alone.
- [x] The regression asserts the artifact is **discovered** — a fixture that asserts an
      absence of findings passes while the module is skipped, which is the defect. —
      `lib-tests.sh` asserts both finders return the kebab file;
      `wikilinks-resolve/kebab-module-is-indexed` asserts a link to one resolves and
      `kebab-module-is-scanned` asserts a finding names one. All three fail against 0.9.5.
