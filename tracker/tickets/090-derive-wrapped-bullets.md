---
id: 090-derive-wrapped-bullets
title: "090 — derive: a wrapped catalog bullet loses its continuation, and `## Notes` never arrives"
created: 2026-09-09
updated: 2026-09-09
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: follow-up
size: S
importance: High
skills: []
status: Open
blocked_by: []
related_to: []
---

## Description

`plugin/base/bin/lib/derive-catalog.sh` § `derive_catalog_prose` reads a pattern's or a
component's `## Structure` and `## Variants` items with an `awk` that prints a line only
when it **starts with a list marker**:

```
/^[ \t]*[0-9]+\.[ \t]/ { sub(...); print; next }
/^[ \t]*[-*][ \t]/     { sub(...); print; next }
```

A bullet wrapped across two physical lines — ordinary in a vault whose authors keep prose
at 80 columns — therefore reaches the derived contract as its **first line only**, with
no refusal and no warning. In the first field run, `form.md`'s `Coded` variant arrived as
*"fields bound to the study's configured value sets ([[adr-coded-terminology]]),"* and
lost *"each showing the code system alongside the display text."* The contracter, told by
its doctrine that the contract is complete by construction, froze an interface that could
not express the variant; the quality overseer caught it at the boundary; a rework cycle
was spent on a defect the tooling introduced. The orchestrator audited all six contracts
in the run and found the truncation once — which says the input was lucky, not that the
reader is safe. The domain reader is unaffected: `_keyed-heads.sh` joins continuation
lines the way the AC-id reader does, so this is a catalog-side inconsistency.

Beside it, a **`## Notes`** section on a catalog entry is read by nothing. `form.md`'s
notes carried two requirements the run never saw — *"a field bound to a value set states
which system the value came from"* and *"validation names the field that failed"* — and
`derived-contract.md` documents `structure` and `variants` as the carried prose without
saying Notes is excluded. Either the section is contract and derive carries it, or it is
not and the pattern template should stop inviting requirements into it.

## Acceptance criteria

- [ ] `derive_catalog_prose` joins a bullet's continuation lines (indented, no marker)
      into one item, with the same normalization the first line receives. A golden
      fixture under `emanate-derive/` carries a wrapped `## Variants` item and asserts the
      full text in `expected-stdout.json`; a second asserts a wrapped `## Structure` item.
- [ ] `## Notes` is ruled on. **Carried:** it lands as a fourth prose spool (`notes`,
      never claimed, like `structure`), `derived-contract.md` § the catalog kinds names it,
      and a fixture asserts it. **Not carried:** `derived-contract.md` says so in one
      sentence, and the pattern and component templates under `inspire-screens` say that
      Notes is commentary a run never reads, so a requirement placed there is a
      requirement lost.
- [ ] `plugin/test/run.sh golden/emanate-derive` is green, and no other fixture's
      expected output moves — a joined continuation must not change a single-line item.

## Notes

This is the smallest ticket of the batch and the one with the clearest bite: a
truncated requirement costs a rework cycle at the earliest boundary, in a loop whose
whole premise is that the contracter's input is exact.
