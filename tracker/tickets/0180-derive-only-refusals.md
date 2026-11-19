---
id: 0180-derive-only-refusals
title: "0180 — a spec the Factory refuses can pass every INSPIRE rule"
created: 2026-11-17
updated: 2026-11-17
reporter: "@djessy.czaplicki"
closed_by: null
closed_at: null
epic: follow-up
size: M
importance: High
skills: [domain, screens]
status: Open
blocked_by: []
related_to: [B3-overridable-types, 0180-component-without-props, FB2-kb-contradiction-check, 0180-minted-unique-fields]
---

## Origin

A governed project's first full INSPIRE Factory run (Factory 0.18.0, 2026-11-16) built 54
units and refused six at derive, before any agent started. The six refusals blocked seven more
units. Every refused spec had passed `review.sh` and been promoted to `accepted`. Five were
`DR-T1` (an unknown type) and one was `DR-C2` (a component with no props); those two gaps are
filed in `B3-overridable-types` and `0180-component-without-props`. The same project had
already met `OS-X1` before the run, because that rule exists in `head-referents.sh` and in the
Factory, and `review.sh` reported it. The difference is where the rule lives.

## Description

### What happens today

`derived-contract.md` § Refusal splits the refusal classes in two:

- **`OS-*`** classes each have one implementation, the review rule that owns it. Derive runs
  those rules, so an author sees the same finding at authoring time.
- **`DR-*`** classes are derive-only. The contract says `DR-T*`, `DR-R*`, `DR-B*`, `DR-C*`,
  `DR-N*` and `DR-P*` "are derive-only: no rule owns them, because they are questions only a
  reader that has to *render* the unit needs answered". `DR-S*` and `DR-D1` number shapes the
  screen and section rules already report.

The split keeps one copy of each check. Its cost is that a derive-only class is found by a run,
after the run has scaffolded and built every unit that does not depend on the refused one.
Nothing records, for each class, whether an INSPIRE rule reports the same shape. The new
`DR-D3` (`0143-entity-datastore`) ships with its rule, `entity-datastore.sh`; nothing says
whether that is the pattern for every new class.

### What this ticket asks for

- **An audit of every `DR-*` class** in `derived-contract.md`'s table: for each one, the
  review rule that reports the same shape, or none.
- **For each class with none, a decision:** add the check to a review rule, or keep it
  derive-only with a written reason (for example, the shape can only be judged while
  rendering). `DR-T*` and `DR-C2` are decided in their own tickets.
- **The table records the answer**, as a column naming the review rule, so a reader sees which
  classes an author can meet before a run.
- **A rule for new classes:** a new `DR-*` class ships with its review rule, or with its reason
  for staying derive-only.

If the audit finds that every remaining derive-only class should stay derive-only, this ticket
closes Done with the column and the rule written, and no new check.

## Acceptance criteria

- [ ] `derived-contract.md`'s `DR-*` table names, for each class, the review rule that reports
      the same shape, or the reason it stays derive-only.
- [ ] Each class moved to a review rule has a fixture that shows the finding.
- [ ] `derived-contract.md` states the rule for a new `DR-*` class.

## Notes

- Factory note: a class that moves to a review rule changes nothing the Factory reads, since
  derive already refuses it. If the Factory's deriver then consults that rule, as it does for
  `OS-*`, the Factory work is filed in its tracker when this ships.
