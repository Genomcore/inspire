---
id: FB3-config-run-related
title: "FB3 — /inspire-config writes run_related and puts the review before the tests"
created: 2026-11-12
updated: 2026-11-12
reporter: "@irene.gonzalez"
closed_by: null
closed_at: null
epic: roadmap
size: S
importance: High
skills: []
status: Open
blocked_by: []
related_to: [0143-factory-settings-in-emanate-yml]
---

## Origin

The maintainers of the INSPIRE Factory held the third block of a follow-up review of the Factory
on 2026-11-09. The block covered how a unit's work is checked and repaired, and the memory and
time a run uses. Its ticket in the Factory's tracker is `FB3-whole-suite-per-unit` (Jira
INSPIRE-4). The maintainers settled it on 2026-11-12, and Genomcore/inspire-factory#157
implements it. The review's working notes are not public, so this ticket states the decision in
full.

**Decision:** a unit no longer runs the whole test suite.

- A unit's agent runs only the tests its change touches. When it finishes, the factory runs
  the checks.
- A `run` check may carry `run_related`: the same command with `{files}` where the factory puts
  the files the unit changed since it left the release (`release...HEAD`), as shell-quoted
  absolute paths. The command must pass when no test relates to those files. The factory runs
  `run` instead when the unit changed no file, deleted one, or the command would pass 100,000
  characters.
- When a check has `run_related`, the factory runs every run check's `run` once more on the
  release, after every unit has merged and before the PR. A red suite gets a repair agent up to
  `max_tries`; still red, the run fails like a unit, with no PR and the release kept.
- The recommended phase order puts `review` before the tests: the factory stops at the first
  red phase, so a rejected change is repaired before a full test run is spent.

The work in this repository is the skill that writes `.inspire/emanate.yml`. Its Jira issue is
INSPIRE-8.

## Description

### What happens today

`/inspire-config` knows only `name` and `run` on a run check, says agents run every check
"exactly as written", and puts the `review` phase after `tests`. `derive.md` adds
`--passWithNoTests` "since every unit runs every check".

### What this ticket asks for

- `references/format.md`: `run_related` in the run-check table, with its rules and the reader's
  two errors; the agent no longer runs the checks; when the factory uses `run_related` and when
  it falls back to `run`; the release check; the phase order lint and types, review, tests,
  claims; the worked example with one `run_related` and the review before the tests.
- `references/derive.md`: `run_related` with `--passWithNoTests` on every Jest and Vitest unit
  suite by default, with no question, whenever the factory's reader accepts the key; the review
  phase before `tests`; an existing file gets both in its proposal.
- `references/validate.md`: checks the reader cannot make (`--passWithNoTests` missing, `{files}`
  quoted again, a `run_related` that is not its `run` narrowed, a review after the tests). A
  `run_related` without `{files}` needs no check here: the reader refuses it.
- `SKILL.md` rule 2: `run_related` needs a factory that reads it; validate a draft with it, and
  drop it on an unknown-key refusal.

### Minimum factory version

A factory that predates #157 refuses `run_related` as an unknown key. The PR is not merged and
has no version yet, so the skill names it as "later than 0.15.2" and relies on the reader to
decide. When the Factory tags the release, replace that wording with the exact version in
`SKILL.md` rule 2, `format.md` § Run checks and the note under the worked example.

## Acceptance criteria

- [ ] `format.md`, `derive.md`, `validate.md` and `SKILL.md` describe `run_related`, the release
      check and the review-before-tests order as #157 ships them.
- [ ] On a Jest or Vitest project, `/inspire-config init` writes `run_related` by default, with
      `--passWithNoTests` and the review phase before `tests`, and the factory's reader accepts
      the file.
- [ ] The wording "later than 0.15.2" is replaced with the Factory's tagged version.

## Notes

- Factory: `tracker/tickets/FB3-whole-suite-per-unit.md` in Genomcore/inspire-factory, and
  Genomcore/inspire-factory#157. Its README's `phases` table and `emanate.example.yml` are the
  reference for the key.
- Do not release the skill change before the Factory release: a project that follows it with an
  older factory fails at the reader.
