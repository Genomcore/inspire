---
id: B2-endorsement-reliability
title: "B2 — an endorsement can be lost on the same day and hides later edits"
created: 2026-10-26
updated: 2026-10-28
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: M
importance: High
skills: [workspace]
status: Open
blocked_by: []
related_to: [B1-operator-profiles]
---

## Origin

The INSPIRE maintainers held the second session of a design review on 2026-10-26 while
preparing the training of new INSPIRE operators. This ticket records one of its
decisions. The review's working notes are not public, so this ticket states everything
needed to act on the decision.

**Decision:** change endorsement so it can be trusted. Re-endorsing must always record
something, and an edit made after an endorsement must be visible. Both are settled by
timestamp, to the second.

## Description

### What happens today

`trust.sh endorse` writes `endorsed: {by, at}`, where `at` is a date with no time.
Re-endorsing on the same day writes the same bytes, so git sees no change and there is
nothing to commit. The endorsement looks as if it never happened.

Not noticing later edits is a deliberate decision. Decision D2 of
`docs/adr/adr-artifact-trust.md` says endorsement is "attestation, not content-pinning",
and that this drift is not detected on purpose. The same ADR leaves room for a stronger
check later. This ticket adds one, comparing timestamps instead of hashing content, so it
amends D2.

### What this ticket asks for

1. **Now:** `at` becomes a full timestamp to the second, with its time zone offset.
   Every re-endorsement then changes the file.
2. **Now:** the trust report flags an artifact as "changed since endorsed" when its
   content was committed after `at`. Commits that only change the `endorsed` block don't
   count, because the commit that records an endorsement is always later than `at`.
   Re-endorsing clears the flag. No content hash.
3. **Later:** link endorsement to git: who approved the PR that last touched the file,
   and a list of contributors instead of a single `by`.

Reading commit history here only changes what the report says. It is consistent with the
rule in `docs/adr/adr-upgrade-path.md`, D11, that git state is read only where it changes
what gets reported.

### Open questions

- For part 3, who counts as the endorser: the PR approver or the commit author? The
  review leaned towards the PR approver, which is recorded outside the file.
- Does part 3 belong here or in `B1-operator-profiles`? That ticket ties trust to who
  the last person to touch an artifact was.

## Acceptance criteria

- [ ] `trust.sh endorse` writes `at` to the second, with a time zone offset. Two
      endorsements on the same day produce two different files.
- [ ] The trust report flags "changed since endorsed" from commit times, ignoring commits
      that change only the `endorsed` block. Re-endorsing clears the flag.
- [ ] Existing date-only stamps stay valid, and the close note says how the check
      compares them.
- [ ] D2 of `docs/adr/adr-artifact-trust.md` is amended to describe the check.
- [x] Part 3 is filed as its own ticket or folded into `B1-operator-profiles`, and the
      close note says which. *Answered 2026-10-28:* see Notes.

## Notes

**Amended 2026-10-28 (tracker pass): part 3 is out of scope.** It is recorded with the
long-term direction of `B1-operator-profiles`, which was cancelled on the same day and
keeps both open questions readable in the archive. The PR approver comes from the git
host, and the INSPIRE Factory is the component that reaches the git host and knows who
signs in. So part 3 is unlikely to be built in this repository. This ticket closes on
parts 1 and 2.
