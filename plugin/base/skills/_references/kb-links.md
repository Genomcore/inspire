# Linking KB files (shared reference)

Every link from one KB file to another is a relative Markdown link to the target file.
This reference is the one place that says how to write it; a skill points here instead
of restating it. A wikilink (`[[id]]`) is never written: `links-resolve` reports it as an
error.

## The form

`[text](path)`, where `path` is the target file's path relative to the file that holds
the link, extension included.

- **Path.** Start from the directory of the linking file, climb with `../` to the
  directory both files share, then descend to the target. The path names the file
  itself, whatever its typed extension.
- **Text.** The target's id: `[auth::session::start](../session/session.start.action.md)`.
  Use prose when the sentence needs it: `[the audit decision](../../_adr/audit.adr.md)`.
  No tool reads an id from the text, so text never decides what a link refers to.
- **Anchor.** A section of the target follows the path: `(../auth.feature.md#email-rules)`.
- **Embed.** The image form, `![text](path)`, embeds the target and is checked like a link.
- **Table cell.** The form is the same; a link carries no pipe, so nothing needs escaping.
- **Frontmatter.** The link is quoted, and its path is relative to the file that holds
  the frontmatter: `requires: ["[m::e::a](../e/e.a.action.md)"]`.
- **Code span or fence.** A link there is an example; no tool reads it.

Worked paths, from a file in `inspire_kb/01_spec/_modules/auth/_domain/user/`:

| Target | Path |
|---|---|
| a sibling action, `user.create.action.md` | `user.create.action.md` |
| another entity's action in the module | `../session/session.start.action.md` |
| a feature, `_modules/auth/_features/signup.feature.md` | `../../_features/signup.feature.md` |
| the module hub | `../../auth.module.md` |
| a global ADR, `01_spec/_adr/audit.adr.md` | `../../../../_adr/audit.adr.md` |
| a screen, `_faces/admin/_screens/user-list.screen.md` | `../../../../_faces/admin/_screens/user-list.screen.md` |

The id is the target's frontmatter `id:` where it has one (`session-sweep.process.md`
with `id: auth.session-sweep` is `auth.session-sweep`), else its file name without the
typed extension (`audit.adr.md` is `adr-audit`).

## Writing a link

1. Find the target file by its typed extension, never by guessing a directory.
2. When it does not exist, create it first from its template, in its type's first state
   (`lifecycle: draft`, `**State:** 🟡 Planned`, `**Status:** design`). A missing target
   is always a broken link, never a concept nobody wrote down.
3. Compute the path from the linking file and write the link.
4. Moving or renaming a file rewrites every link to it in the same change: search
   `inspire_kb/` for the old file name and update each path.

Run [write-checks](write-checks.md) on the file afterwards; `links-resolve` reports a
path that names no file.
