---
name: claim
description: Claim a tracker ticket for the operator in the INSPIRE Jira project — find the ticket in this repo's tracker (or the sibling repo's), check Jira and GitHub for anyone already on it, then create or update the Jira issue with the operator as assignee, the repo's label and status In Progress. Use for /claim <ticket>, and whenever someone says they are picking up, taking or starting work on a tracker ticket, or asks to register a ticket in Jira, even if they do not name the skill.
argument-hint: <ticket id, file name or path>
---

# Claim a tracker ticket in Jira

The tracker file holds the ticket's text. The Jira issue holds who works on it and in what
status. This skill writes only to Jira: it changes no file in the repo, creates no branch and
closes nothing.

It uses the Atlassian connector. Its tools are named by operation (`atlassianUserInfo`,
`searchJiraIssuesUsingJql`, `createJiraIssue`, `editJiraIssue`, the issue-transitions list,
`transitionJiraIssue`, the issue-comment tool), with a prefix that depends on how the connector
was added. Pass `genomcore.atlassian.net` as the cloud id. Without the connector, stop and tell
the operator to connect Atlassian in their Claude settings.

With no argument, ask which ticket.

## 1. Resolve the ticket

- **Home repo** is the repo this session runs in. **Sibling repo** is the other INSPIRE repo,
  if it is checked out in the directory that holds the home repo's main checkout: two levels
  up from `git rev-parse --path-format=absolute --git-common-dir`, which also holds from a
  worktree. Tell them apart by remote:

  | Remote | Label |
  |---|---|
  | `Genomcore/inspire` | `inspire-specs` |
  | `Genomcore/inspire-factory` | `inspire-factory` |

- `git fetch origin` and read the ticket from `origin/main`
  (`git show origin/main:tracker/tickets/<id>.md`), because a local checkout often lags.
- The argument matches a ticket when it equals the id, the file name or the path. Otherwise it
  matches the one file in `git ls-tree --name-only origin/main tracker/tickets/` whose name
  contains it. Several matches: list them and ask. No match in the home repo: look in the
  sibling repo the same way, and the label follows the repo the ticket is in. No match in
  either: stop and say so.
- The ticket's `status:` must be `Open`. A `Done` or `Cancelled` ticket is not claimed: stop
  and say so.
- Keep the id, the title, the repo, the `### What this ticket asks for` subsection (or, when
  the ticket has none, the first paragraph of `## Description`) and `## Acceptance criteria`.

## 2. Check who is on it

**Jira.** Get the operator's account id with `atlassianUserInfo`. Search:

```
project = INSPIRE AND (summary ~ "\"<id>\"" OR text ~ "\"tracker/tickets/<id>.md\"")
```

with the fields `summary`, `status`, `assignee`, `labels` and `updated`. Jira's phrase search
also matches prefixes (`"FB2-small"` finds `FB2-small-change-scope`), so keep only an issue
whose summary holds the id as a whole word (`[<id>]`, or `<id>` followed by a space or the end)
or whose description names `tracker/tickets/<id>.md`. Drop an issue labelled with the other
repo's label.

**GitHub.** Look for work that has started without a Jira issue:

- `gh pr list -R <owner/repo> --state open --search "<id>" --json number,title,author,headRefName,url`
- the remote branches whose name contains the ticket's slug (the id without its family prefix:
  `small-change-scope` for `FB2-small-change-scope`), each with
  `git log -1 --format='%an, %ar' origin/<branch>`.

A PR or branch whose author is the operator is not a conflict.

**Decide.**

| What the checks find | What to do |
|---|---|
| No issue, no PR or branch by someone else | Create the issue (step 3). |
| No issue, a PR or branch by someone else | Stop. Report the PR or branch and its author, and ask whether to claim anyway. |
| One issue, unassigned, status not done | Claim it (step 3). |
| One issue, assigned to the operator | Already claimed. Move it to In Progress if it is in To Do, and report it. |
| One issue, assigned to someone else, status not done | Stop. Report the assignee, the status and the last update. Take it over only when the operator says so in words. |
| One issue in a done status (Done, Released) | Stop. Jira says the work is done and the tracker says Open; report both. |
| Several issues | Stop and list them. |

## 3. Claim

**A new issue.** `createJiraIssue` with:

- project `INSPIRE`, issue type `Task` (`Bug` when the operator says the ticket is a defect);
- summary `[<id>] <title>`, the title without its family prefix and with its first letter in
  capitals (`FB2 — a fix to a few routes…` becomes `A fix to a few routes…`);
- assignee: the operator's account id; labels: the repo's label;
- description, in Markdown, copied from the ticket without rewording:

  ```
  Tracker ticket: [`tracker/tickets/<id>.md`](https://github.com/<owner/repo>/blob/main/tracker/tickets/<id>.md) in <owner/repo>.

  **What is achieved**

  <the subsection kept in step 1>

  **Acceptance criteria**

  <the section kept in step 1>
  ```

**An existing unassigned issue.** `editJiraIssue`: the operator as assignee, and the repo's
label added to its labels (send the full list). The summary and description stay as they are.

**A take-over the operator asked for.** The same edit, then a comment on the issue:
`Taken over with /claim.`

**Then**, in every case, list the issue's transitions and run the one whose target status is
`In Progress`. If none leads there, leave the status as it is and say so.

## 4. Report

One line per issue: key and link, status, assignee and label. Add any PR or branch found in
step 2 under it.
