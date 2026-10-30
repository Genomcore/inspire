# Checking what you write (shared reference)

An authoring skill checks each KB file it writes before it moves on, because a finding
is cheapest to fix while the file is still in front of you. The writing contract
([writing-style](writing-style.md)) says how to write; this check says where the file
does not follow it yet.

## The check

After you write a file, run:

```
.inspire/bin/review.sh <file>
```

A file is a scope of its own: every rule that applies to it runs, and findings are
reported on that file only. Rules that need the rest of the vault to judge it, such as
the `requires` graph or which actions touch an entity's fields, still read the whole
domain tree. Findings arrive on stderr, one JSON line each.

## What to do with the findings

- **An error** is fixed before you go on. Errors block the pull request, so leaving one
  only moves the work later.
- **A warning about the file's own text** (prose style, a missing or empty section,
  frontmatter, a wikilink) is fixed now. Rewrite the sentence; do not argue with the
  rule in the file.
- **A warning that waits on another artifact** (a field no action touches yet, a
  criterion with no test yet, a dependency that is still a draft) is not fixed by
  inventing that artifact. Tell the operator what it waits on, and move on.
- **A warning the operator chooses to keep** stays. Say so in one line when you report
  the write; do not raise it again in the same session.

Run the check again after a fix, then stamp the file
([trust-stamps](trust-stamps.md#stamping)), so the stamp records the version you
checked.

## At commit time

The same review runs again after each `git commit` made in a Claude Code session, on
every KB file the commit contains. It never blocks the commit: its findings are
reported back to the agent, and errors still block the pull request. A finding that
appears there means a file was committed without this check, or was edited after it.

No check runs on each file edit. A hook on every edit slows each write down, and fixing
a finding is itself an edit, so the hook fires again and can loop.
