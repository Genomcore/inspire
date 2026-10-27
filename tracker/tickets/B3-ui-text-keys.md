---
id: B3-ui-text-keys
title: "B3 — Screens use text keys, never literals"
created: 2026-10-27
updated: 2026-10-27
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: Mid
skills: [screens, code]
status: Open
blocked_by: []
related_to: [B1-config-replaces-bootstrap]
---

## Origin

The INSPIRE maintainers held the third session of a design review on 2026-10-27 while
preparing the training of new INSPIRE operators. This ticket records one of its
decisions. The review's working notes are not public, so this ticket states everything
needed to act on the decision.

**Decision:** user-facing text on screens comes from dictionary keys, never literals,
even in a single-language product. That way a copy change never forces a test change.
Tests assert keys, and a separate completeness check verifies that every language has
every key. Where the dictionary is stored comes later and blocks nothing: the rule is to
work through keys.

## Description

### What happens today

The spec says nothing about the product's languages. `output_language` sets the
language of the KB, and `_references/output-language.md` explicitly keeps it apart from
"the product's own i18n". Two stack profiles already ask for keys in code: `angular`
("no hardcoded user-facing strings") and `react` (text through "the i18n / constants
layer"). `nestjs` doesn't, and nothing at the spec level or in review makes it a rule.

### What this ticket asks for

- A stack-agnostic rule in the runtime: screens and components refer to text by key.
  Error messages tied to one specific case may be the exception, as discussed.
- Tests assert the key, not the translated text, so a copy change doesn't break a test.
- A completeness test over the translation files: every language has every key. It
  covers missing keys, not wrong translations.
- Where the dictionary lives (a local file, a translation tool, a platform service later)
  is the stack's choice. The rule is only to work through keys, so the store can be
  swapped later.
- The project declares which languages the product supports. This is separate from
  `output_language`.

### Open questions

- Where are product languages declared: the spec config (see
  `B1-config-replaces-bootstrap`), or `project.md`?
- Does a screen spec name the keys it uses, or is that left to the code?
- Should the completeness test be a validator under `.inspire/bin/` (it needs a known
  file format), or a test each stack profile asks for?

## Acceptance criteria

- [ ] The key rule is stated once, stack-agnostically, and every framework profile that
      renders user-facing text follows it, `nestjs` included.
- [ ] The tester doctrine says tests assert keys, not translated text.
- [ ] A completeness check exists, as a validator or as a test every profile requires.
- [ ] The product's supported languages have a declared home, separate from
      `output_language`.
- [ ] The open questions have written answers in this ticket's close note.
