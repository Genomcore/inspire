# ADR — The visor serves the KB as a local site

- **Status:** Accepted — 2026-11-13
- **Amends:** [adr-plugin-delivery](adr-plugin-delivery.md) **D1** (the plugin also carries
  commands a project runs as shipped) and **D4b** (placement follows whether a project may
  change a file, not where the file operates). Builds on
  [adr-markdown-links](adr-markdown-links.md) **D1**, **D2** and **D4**, and
  [adr-upgrade-path](adr-upgrade-path.md) **D6**.
- **Scope:** Where INSPIRE places a file (plugin or project), and the visor: a command that
  serves a project's `inspire_kb/` as a website on the operator's machine. Not hosting, not
  publishing, not previews of pull requests.

---

## Context

A KB is plain Markdown with relative links (adr-markdown-links D1), so any Markdown site
generator can render it. Quartz renders a folder of Markdown as a site with search,
backlinks, link previews and a graph of the links. Run over a real KB, it resolves every
link outside `_migration/` and builds about 500 files in seconds.

`adr-plugin-delivery` D4b places a skill by where it operates: on the installation (plugin)
or on the project (materialized). A command that reads the KB operates on the project, yet
nothing in it needs to differ from one project to another. What a project needs to change
is the site's configuration.

## Decisions

### D1 — A file lives in the project when a project may change it, and in the plugin otherwise

A file a project may change, through an edit or a lesson, is materialized, and
`/inspire:update` keeps the project's changes (adr-upgrade-path D6). A file every project
runs as shipped stays in the plugin. This replaces D4b's criterion and reproduces its
placement: lessons target the methodology skills, and `init`, `update` and `migrate` never
differ between projects.

### D2 — `/inspire:visor` is a plugin command

The command runs from the plugin, because no project changes how the visor starts, checks
and serves. Under D1 the plugin carries it with `init`, `update` and `migrate`, and the
plugin is referenced at runtime for this command.

### D3 — The site's configuration is materialized under `.inspire/visor/`

`.inspire/visor/` holds the Quartz configuration, the Quartz version and the Quartz plugins
the visor uses. It is committed and runtime-managed, so a project's edits, its own Quartz
plugins included, survive an update. Quartz itself and the built site are installed under
`.inspire/visor/` and gitignored through the INSPIRE block of `.gitignore`.

### D4 — The visor reads `inspire_kb/` in place and writes nothing in it

Quartz reads the KB directory directly, and no file inside `inspire_kb/` is created,
changed or deleted. The site shows no content the KB does not hold: the pages Quartz
generates render what the KB declares (its directories, its own tags and aliases), and the
site root redirects to the KB's `README.md`.

### D5 — The visor serves the whole KB except templates and `_migration/`

Tracker tickets, lessons and spikes link into the specification, so leaving them out
breaks links. Templates (`*.template.md`) and `_migration/` are left out, as
adr-markdown-links D2 leaves them out of link checking.

### D6 — The visor is a local preview with live reload

It builds the site on the operator's machine and serves it on a local port. It rebuilds
when a KB file changes.

### D7 — The visor refuses a KB older than INSPIRE 0.17.0

It reads `inspire_version` from `.inspire.lock` and refuses a missing lock, a lock without
the field, or a version below 0.17.0, naming both versions and `/inspire:migrate`. From
0.17.0 a KB holds only relative Markdown links (adr-markdown-links D5), and the visor
resolves links by relative path only.

### D8 — The visor renders Markdown as CommonMark does

A single line break inside a paragraph renders as a space. The reader the validators share
is the CommonMark reference (adr-markdown-links D4), so the site shows a file the way the
tools read it.

### D9 — A file with invalid frontmatter is left out of the site and listed

Before building, the visor parses every file's frontmatter. A file that does not parse is
left out of the build, and the visor prints its path and the parse error. The site comes
up without it.

### D10 — The project chooses the Quartz version

The version is set in `.inspire/visor/`, and an INSPIRE release ships a default. Each
Quartz plugin the visor uses declares the Quartz versions it works with, and the visor
refuses a version outside that range, naming both.

### D11 — The visor runs Quartz on the host's Node, or in a container when the host has none

It uses `node` from `PATH` when its version is 22 or later. Otherwise it runs Quartz in a
container of a pinned Node image, with the project mounted. With neither, it refuses and
names what is missing.

### D12 — The KB's facts reach the site through Quartz's content index only

A Quartz plugin of the visor adds each file's unit kind, `module` and `lifecycle` to its
entry in the content index. The unit kind is the file's typed extension (adr-kb-structure
D3), and `module` and `lifecycle` come from frontmatter. The plugin reads no file body.

### D13 — The graph colours each node by its unit kind and shows a legend

The visor ships its own graph plugin in place of Quartz's, because Quartz's graph has no
setting for node colours. Its palette maps unit kinds to colours, a kind not in the palette
is grey, and a legend in the graph panel lists the kinds on screen. Unit kinds are an open
set, so a new kind needs only a palette entry.

## Consequences

- The plugin's skill descriptions gain one entry, `visor`, resident in every project the
  operator opens (adr-plugin-delivery D4b, second reason).
- A teammate needs the plugin to run the visor; reading the KB without it stays possible in
  any Markdown reader (adr-plugin-delivery D2).
- The visor's graph plugin is maintained in this repository. A Quartz release that changes
  the graph component's contract needs a matching change here.
- The test estate covers the visor's checks (version floor, Quartz version range, invalid
  frontmatter) and runs one real build of a small fixture when Node 22 or later is present;
  without Node the build test records a SKIP.
- The manual gets a page for `/inspire:visor` in the same release, in the inspire-docs
  repository.
