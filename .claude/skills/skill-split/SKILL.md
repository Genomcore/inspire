---
name: skill-split
description: Split an oversized SKILL.md into a lean SKILL.md plus up to three reference files it links to, moving whole sections verbatim. Run only when the operator types /skill-split.
disable-model-invocation: true
argument-hint: "[skill-dir] [max-files]"
---

# Split an oversized skill

A `SKILL.md` loads in full every time the skill fires, and after compaction Claude
Code keeps only its first 5000 tokens. This command keeps in `SKILL.md` what every
run needs and moves what only some runs need to `references/`, behind a link that
says when to read it. It moves text; it never rewrites it.

Arguments: `$ARGUMENTS`, as `<skill-dir> [max-files]`. The skill directory is
required (for example `plugin/base/skills/inspire-code-nestjs`); `max-files`
defaults to 3.

## 1. Measure

```bash
bash plugin/scripts/skill-size.sh <skill-dir>
```

If it prints no `WARN` or `ERROR` for `<skill-dir>/SKILL.md`, report the size and
stop: the skill is not too big. An `ERROR` on the description is not fixed by a
split; report it and stop.

Then map the sections and read the whole `SKILL.md`:

```bash
bash plugin/scripts/skill-size.sh --sections <skill-dir>/SKILL.md
```

Each row is start line, line count, estimated tokens, heading.

## 2. Plan

Keep in `SKILL.md`, because every run needs it:

- the frontmatter and the opening that says what the skill does;
- the procedure or subcommand routing an agent follows on every run;
- rules that apply to every run, and the final checklist (`Before you finish` or
  similar);
- the shared blocks every INSPIRE skill carries (Output language, Writing contract,
  Lesson capture), unchanged.

Move whole `##` sections that only some runs need: one subcommand's detailed
procedure, a format specification, a catalogue or long table, worked examples,
escape hatches, troubleshooting. Group them into at most `max-files` files, each one
topic, named by that topic in kebab-case (`references/test-conventions.md`, never
`part-2.md`). Reuse the skill's `references/` directory if it has one, and do not
reuse a file name already there.

Aim for `SKILL.md` under 400 lines and 4000 tokens, which leaves room to grow below
the 500-line and 5000-token limits. Move the fewest sections that get there.

Show the plan as a table — section, lines, tokens, destination file, and the
condition under which an agent must read that file — and wait for the operator's
approval before writing anything.

## 3. Move

For each destination file:

1. Start it with a `#` title and one sentence saying what it covers. If it will
   exceed 100 lines, follow with a `Contents` list of its `##` headings.
2. Paste each section verbatim, heading included. Do not reword, summarise or
   reorder inside a section.
3. Fix every relative link in the moved text for the new location: the file now
   sits one directory deeper, so `../_references/x.md` becomes
   `../../_references/x.md`, and `references/y.md` becomes `y.md`. A path the
   skills tree holds is written as a Markdown link, never as a backtick path
   (`plugin/test/skills/01-skill-links.sh` fails on the latter).

In `SKILL.md`, replace each moved section with its heading and one line:

```markdown
## Quality gates

Read [references/quality-gates.md](references/quality-gates.md) before running or
changing a quality gate.
```

The condition is concrete: name the subcommand, step or situation. Where a step of
the procedure is what needs the moved text, put the pointer in that step as well.

Then find links into the moved sections from anywhere in the tree and repoint
them:

```bash
grep -rn '<skill-name>/SKILL.md#' plugin/ docs/ .claude/
```

## 4. Verify

All three must pass before you report done:

```bash
bash plugin/scripts/skill-size.sh <skill-dir>   # no WARN for SKILL.md
bash plugin/test/run.sh skill-links             # every link resolves
```

and no line was lost: every non-blank line of the old `SKILL.md` must appear in
some file of the skill. The only lines this may print are the ones whose links you
changed:

```bash
d=<skill-dir>
comm -23 <(git show HEAD:"$d/SKILL.md" | grep -v '^[[:space:]]*$' | sort -u) \
         <(cat "$d"/SKILL.md "$d"/references/*.md | sort -u)
```

## 5. Report

Before and after for `SKILL.md` (lines and tokens), the files created with their
read-when condition, and the verify output. Under `plugin/`, the split changes the
runtime: before opening the PR, run `/release-entry` (version bump, `CHANGELOG.md`
entry, manifest). A project whose operator edited this skill will see a conflict
on upgrade; mention that in the changelog entry.
