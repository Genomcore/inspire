---
id: B2-endorsement-reliability
title: "B2 — an endorsement can be lost on the same day and hides later edits"
created: 2026-10-26
updated: 2026-10-29
reporter: "@dario.blasco"
closed_by: "@djessy.czaplicki"
closed_at: 2026-10-29
epic: roadmap
size: M
importance: High
skills: [workspace]
status: Done
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

- [x] `trust.sh endorse` writes `at` to the second, with a time zone offset. Two
      endorsements on the same day produce two different files.
- [x] The trust report flags "changed since endorsed" from commit times, ignoring commits
      that change only the `endorsed` block. Re-endorsing clears the flag.
- [x] Existing date-only stamps stay valid, and the close note says how the check
      compares them.
- [x] D2 of `docs/adr/adr-artifact-trust.md` is amended to describe the check.
- [x] Part 3 is filed as its own ticket or folded into `B1-operator-profiles`, and the
      close note says which. *Answered 2026-10-28:* folded into `B1-operator-profiles`.

## Notes

**Amended 2026-10-28 (tracker pass): part 3 folds into `B1-operator-profiles`.** Both
questions about part 3 come down to operator identity: who counts as the endorser, and
where several contributors are recorded. The PR approver comes from the git host, which
the INSPIRE Factory reaches, and the Factory also knows who signs in. That ticket's ADR
answers part 3 with the rest of the identity question. This ticket closes on parts 1
and 2.

## Resolution

Parts 1 and 2 shipped. Part 3 is `B1-operator-profiles`'s, as amended above.

- **`at` to the second.** `trust.sh endorse` writes `at` as ISO-8601 with a colon
  offset (`2026-10-29T10:45:52+01:00`), so a second endorsement the same day writes new
  bytes and leaves a commit.
- **`CHANGED SINCE ENDORSED`**, a seventh report group, also counted by `--summary`.
  It names who endorsed and when, and its remedy is to re-endorse.

**History, not clocks.** The ticket asked for commit times compared against `at`. We
settled the comparison by the commit graph instead, because clocks misfire both ways: a
rebase moves commit dates past `at` (a false flag), and a branch edited before the
endorsement but merged after it carries the earlier date (a miss). The check finds `E`,
the commit that recorded the current `endorsed` block (it carries the block and its
parent doesn't). It flags the artifact when a commit in `E..HEAD` (merges excluded) or
the working tree changed it outside the `endorsed` and `produced` blocks. So:

- a commit that only re-endorses, or only re-stamps `produced:`, doesn't count;
- the commit that records the endorsement counts as endorsed, whatever else it changes;
- an endorsement not yet committed is newer than every commit, so it clears the flag at
  once;
- outside a git repository, or for an untracked file, the check is skipped.

**Date-only stamps** stay valid, and need no special comparison: `E` is found by the
block's value, so a stamp written before 0.15.0 is checked exactly like a new one. Its
only weakness is the one part 1 fixes: a same-day re-endorsement wrote no new bytes, so
it left no `E` to find.

`docs/adr/adr-artifact-trust.md` D2 carries the amendment. `trust-stamps.md` describes
the new group, and `test-trust.sh` covers every case above, including a stub guard that
proves the drift assertions fail when the check is disabled.

Not covered: a rename restarts the history the check reads, so an edit made before a
move isn't seen after it. That can only miss a flag, never raise a false one.
