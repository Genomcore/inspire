---
id: 0143-tracker-status-section
title: "0143 — the tracker README restates the ticket folder by hand, so it drifts"
created: 2026-11-02
updated: 2026-11-18
reporter: "@irene.gonzalez"
closed_by: "@irene.gonzalez"
closed_at: 2026-11-18
epic: follow-up
size: S
importance: Low
skills: []
status: Done
blocked_by: []
related_to: []
---

## Description

`tracker/README.md` § Where things stand lists the open tickets by family, with a count
("**29 open tickets.**") and a dated note of what each pass closed or filed. It maps
`tracker/tickets/` by hand, so every filing, closing or archiving has to edit it too, and
nothing checks that it matches the folder. Four of the six commits that changed the README
after it was created edited this section.

It is already easy to fall behind: `0143-store-side-constraints` was filed without
updating the section, so the README says 29 open tickets while the folder holds 30.

The maintainers' view (`#inspire_mantainers`, 2026-11-02): a list in a markdown file that
only maps a folder causes problems in the long run, so the section should go. A roadmap,
or a view of what the team is considering, does make sense, but a section buried in a
markdown file is not the place for it.

## Acceptance criteria

- [x] `tracker/README.md` no longer has § Where things stand, nor any count or per-ticket
      list of the open set. The folder and each ticket's frontmatter are the only record of
      what is open.
- [x] The rule inside that section, "A question that can be answered in a sitting should be
      answered, not filed", survives the removal: it moves under § Three rules for filing,
      or the section's removal says where it went.
- [x] The "Context and provenance" paragraph no longer calls "this README's status
      section" the current view.

## Notes

- Where a roadmap or a view of what the team is considering should live is not decided
  here. Removing the section does not need it, and whoever wants that view can propose it
  separately.
- The rule moved under § Three rules for filing as "Answer what fits in a sitting", and the
  provenance paragraph moved to the README's introduction. The maintainers' `/digest`
  skill no longer updates the section.
- Closed in the PR that ships the change, so its merge closes the ticket with no second
  PR. Jira: INSPIRE-29.
