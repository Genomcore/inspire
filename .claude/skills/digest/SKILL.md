---
name: digest
description: Turn a meeting transcript into tracker tickets for this repo — read the transcript, check each decision against the code and the open tickets, publish a card page the attendees comment on, apply their comments, then open the tracker PR from the agreed cards. Use for /digest <transcript link>, and whenever someone wants the decisions of a meeting, design review or call filed as tickets, even if they do not name the skill.
argument-hint: <transcript link or file>
---

# Digest a meeting into the tracker

The pipeline has three stops, and each waits for a person:

1. **Cards.** The transcript becomes a card page: one card per proposed ticket or ticket change.
2. **Comments.** The attendees comment on the cards, and each comment changes the page.
3. **PR.** When the person says the cards are agreed, the PR copies them into `tracker/tickets/`.

Do not skip ahead. The page exists so the room agrees on the text before it reaches a public
tracker. A PR opened before that agreement gets rewritten in review.

## 0. Orient

- **Home repo** is the repo this session runs in. **Sibling repo** is the other INSPIRE repo,
  if it is checked out next to this one. Tell them apart by remote: `Genomcore/inspire` is the
  spec, `Genomcore/inspire-factory` is the Factory.
- `git fetch` both, and read code and tickets from `origin/main` (`git show origin/main:<path>`,
  `git grep <pattern> origin/main`). A local checkout often lags, and a card grounded in stale
  code is wrong.
- Read `tracker/README.md` in both repos. It is the rulebook: ticket families and their prefixes,
  the frontmatter format, the three filing rules, and how work crosses between the two trackers.
  This skill does not restate those rules, so what the README says wins.

Then ask the person, in one message, only what the transcript and the README cannot answer:

- the ticket family for this meeting. If the README defines one that fits (such as the next
  `B<n>` of a design review), propose it. If none fits, propose a prefix and say why;
- decisions taken outside the meeting that belong on the cards;
- a design record or document the cards must be checked against. A concern it already covers
  is not filed.

## 1. Read the transcript

A Google Docs link is read with the Google Drive connector (`read_file_content`, with comments).
Anything else is a local file or pasted text. If the connector is missing, ask for an export.
Save the text in the scratchpad and read **all** of it, because decisions often land in the
last ten minutes.

For each topic, note what the room reached:

- **Decided**: the room agreed on what to do.
- **Direction stated**: a direction is set and the details are open.
- **Raised, unresolved**: a problem with no answer. It can open a design session.
- **Idea only**: mentioned, nobody owns it.

Keep the timestamps and the speakers' words in the meeting's language. They become the
evidence quotes on each card.

## 2. Ground every decision

For each decision, establish:

- **What the repo does today**, from code and docs at `origin/main`, with file paths. This is
  the part of a card readers trust most, so state the behaviour and the gap, not a summary.
- **Which open tickets it touches**, in both trackers. Under filing rule 1, a decision on an
  open ticket's surface amends that ticket and does not open a new one.
- **Whether it is a ticket at all.** Rule 2 drops a null-urgency idea. A question the room
  answered is recorded where it applies and is not filed.
- **Which tracker owns it.** Work native to the sibling repo gets its own card in a second
  section of the page and its own PR there. Work in the sibling repo that follows from a
  ticket here is filed there only when this ticket ships. Its card says "filed later".

Record a decision at the scope the room gave it. Do not narrow it to the part that looks
easiest to build.

For a wide code sweep, an Explore subagent per area keeps file dumps out of this context.

## 3. Publish the card page

Start from `assets/card-page.html`. It holds the page's styles (light and dark), the layout, and
one card of each kind. Replace every `{{…}}` and repeat the card pattern once per proposal:

- `new`: a new ticket. Use the id it will have (`<prefix>-<readable-slug>`).
- `amend`: a change to an open ticket. Use that ticket's id.
- `hold`: filed later, covered by the design record, or not filed. Say why.

Each card has the decision in full, what the repo does today, what the ticket asks for, its open
questions, the existing tickets it touches, a suggested size, importance and skills, and the
quotes. At the top is "Effect on open tickets". Add a "Against <design record>" table if one was
given. At the bottom are "Discussed, not a ticket" and "What happens next".

The page is private and goes to the attendees, so names and quotes belong on it. Publish it as
an HTML artifact, not a Claude Doc: people read the cards and comment on them in place. Give the
person the link to share, and watch the page for comments.

## 4. Apply the comments

For each comment thread:

1. Make the change on the page and republish to the same URL.
2. Answer in the thread with what changed, or answer the question if the thread asks one.
3. Resolve the thread.

The thread is where the commenter looks, so the answer goes there and not only to the
session. A comment that changes the decision itself also changes the card's quotes or
"Decided" line. Carry on until the person says the cards are agreed.

## 5. Open the PR

Only when the person says so ("create the PR from the agreed cards"):

- Work in a worktree, `.claude/worktrees/<slug>`, on the branch `docs/tracker-<slug>` cut from
  `origin/main`, so the repo root stays on `main`.
- Write one file per new card, `tracker/tickets/<prefix>-<slug>.md`, in the README's format.
  Apply each `amend` card to its ticket and bump its `updated:` date. Update the README's
  "Where things stand" section: the open count and the entries for this meeting.
- Every new ticket opens with `## Origin`: the meeting's date and what it was about, and the
  decision in full. A reader acts on the ticket with nothing outside the repository.
- Copy the agreed text from the page. Do not reword it in the PR.

**The trackers are read outside the team (the spec repo is public).** A ticket carries no
names, clients or internal project names, and no link to the card page, the transcript or any
other private record, including its decision numbers. Write in English, in the present tense,
and describe the work, not how the meeting reached it.

Before pushing, run `git show --stat HEAD`. Only `tracker/` files are in the commit: no runtime,
manifest or version change, and no notes or scratch files.

Commit as `docs(tracker): file <what> as <prefix> tickets`. The PR body has these parts, and
ends after the last one:

- **Summary**: one paragraph on the meeting and what it turns into, then "Tracker files only:
  no runtime, manifest or version change."
- A table: `Ticket | Change | What it records`, one row per file, the README included.
- **Not filed**: each topic left out, with the reason.
- **<Sibling repo>**: what the PR there files, and what is filed later and when.
- **Open points for review**: the open questions reviewers should weigh.

If cards target the sibling repo, open its PR the same way in its own worktree, with its own
README's format.

Reply with the PR link or links. The card page stays as the record of how the tickets were
agreed.
