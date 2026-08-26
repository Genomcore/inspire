INSPIRE agents — .claude/agents/
================================

This directory is an INSPIRE payload class, materialized here by /inspire:init
and kept up to date by /inspire:update the same way .claude/skills/ is: a file
INSPIRE shipped and you never touched takes the new version; a file you edited
is never clobbered (yours is kept; only when both you and INSPIRE changed it are
you asked, and doing nothing keeps yours); a file you
wrote yourself is kept by construction, because INSPIRE only ever writes the
paths it ships.

Claude Code reads EVERY *.md file under .claude/agents/ as an agent definition,
which is why this file is a .txt and not a .md: a README with no agent
frontmatter would be parsed as a broken agent. The same rule applies to anything
you add here — a note, a draft, a snippet: give it a non-.md extension, or give
it valid agent frontmatter.

Your own agents are welcome here. INSPIRE only ever writes the files it ships
(this README and its agent shells); nothing else in this directory is ever
written, moved or deleted by an upgrade.
