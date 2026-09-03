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

What INSPIRE ships here
-----------------------

Five shells, one per role of the code-emanation loop. A shell is an identity, a
permission envelope (its tools: list) and a pointer at its doctrine; the doctrine
itself lives once, in
.claude/skills/inspire-code/references/roles/, and roles/README.md is the one
page that explains the whole model.

  inspire-contracter.md        emits interfaces, validators, bindings, schemas
  inspire-tester.md            writes the frozen suite from the unit's claims
  inspire-implementer.md       writes the bodies that turn that suite green
  inspire-security-overseer.md read-only security oracle at each handoff
  inspire-quality-overseer.md  read-only quality oracle at each handoff

The three personas carry a full working set including Bash and Agent. The two
overseers carry Read, Grep and Glob and nothing else: an overseer writes nothing,
and Bash can write.

The overseer roster is additive-only
------------------------------------

An overseer is any agent file in this directory whose name ends in
-overseer.md. There is no roster file and no extra frontmatter key. Add your own
— compliance, accessibility, a lens your domain needs — by dropping one more
*-overseer.md here and a doctrine doc beside the shipped ones; the loop picks it
up at every handoff.

What makes such a file a valid overseer, and why the two shipped ones cannot be
removed, is defined once — in roles/README.md, section "The roster is
additive-only". Read the rule there rather than from here; emanation enforces
that definition, and a second wording of it in this file could only drift.

Your own agents are welcome here. INSPIRE only ever writes the files it ships
(this README and its agent shells); nothing else in this directory is ever
written, moved or deleted by an upgrade.
