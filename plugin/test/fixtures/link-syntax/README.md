# Link-syntax corpus

The cases on which every tool that finds KB links agrees with the spec reader,
`sdd_links` in `plugin/base/bin/_lib.sh` (adr-markdown-links D2, D4). The reader is
the reference: a tool that reads a case differently is wrong on that case.
`plugin/test/links/01-link-syntax-corpus.sh` holds the spec side to it.

- `cases/<name>.md` — one input. `cases/<name>.json` — what the reader finds in it.
- `resolve/repo/` — a repository root holding a KB, `inspire_kb/`.
  `resolve/expected.json` — the files whose links are checked, and where each link
  resolves.
- `expect.sh` — writes either kind of expected file from the reader.

## A case

```json
{
  "links": [{ "line": 1, "form": "md", "target": "x.md#sec", "text": "a" }],
  "code": [
    { "kind": "fence", "from": 3, "to": 5 },
    { "kind": "span", "from": 7, "to": 8, "text": "`a\nb`" }
  ]
}
```

- `line` — the 1-based line the link starts on.
- `form` — `md` for `[text](path)`, `embed` for `![text](path)` whose path names a
  `.md` file, `wiki` for `[[target|text]]` and `![[target|text]]`.
- `target` — as written. For a Markdown link: the destination without its `<…>` and
  its title, anchor kept. For a wikilink: the part before the first `|`, without the
  backslash a table cell puts before that pipe; when that part is empty, the whole
  text between the brackets.
- `text` — as written between the brackets, with `\|` read as `|`; the target when it
  is empty.
- `links` is in document order. A link inside a Markdown link's text comes right
  after that link.
- `code` lists the ranges the reader skips, in document order. A fence runs from its
  opening line to its closing line, or to the last line when it is never closed. A
  span runs from the line of its opening backticks to the line of its closing ones;
  `text` is the span as written, backticks included, with its line endings.

Not listed: an external URL (`scheme://`, `mailto:`, `tel:`, `data:`), an in-file
anchor (`#x`), and an image of anything but a `.md` file.

## The resolution tree

```json
{
  "files": ["inspire_kb/01_spec/README.md"],
  "links": [{ "file": "inspire_kb/README.md", "line": 3, "form": "md",
              "target": "../source/app/main.ts", "text": "main",
              "resolved": "source/app/main.ts" }]
}
```

- `files` — every `.md` file under `inspire_kb/` but `*.template.md` and those under
  `_migration/`, relative to the repository root, sorted byte by byte.
- `resolved` — the existing file or directory the link names, relative to the
  repository root, or `null`. A path joins the linking file's directory, out of the
  KB too; a path that starts with `/` joins the repository root. `%XX` and a
  backslash before punctuation are decoded first; an anchor or a query is dropped. A
  wikilink resolves to `null`.
- The tree is read from a copy outside any git work tree, so the repository root is
  the directory above the KB.

## Rules beyond CommonMark

- Frontmatter opens when the first line is `---` and closes at the next `---`. Each
  of its lines is read alone: a span there pairs within the line.
- A wikilink is a match of `\[\[[^][]+\]\]` outside code, in a Markdown link's text
  too. A wikilink that starts at the same bracket as a Markdown link is read as the
  wikilink.

The reader models top-level blocks only, so the corpus holds no case of: a fence
inside a list item or a block quote indented by more than 3 spaces, an indented code
block, an HTML block, a reference-style link, or a link split across lines.
