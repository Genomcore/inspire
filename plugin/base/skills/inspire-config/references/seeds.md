# Config — targets and seeds
> Part of [inspire-config](../SKILL.md). Read when the entry's index routes here.

A **target** is what the product is delivered as. A **seed** is the default INSPIRE
recommends for a target: the stack ids, the image the factory runs the units in, and
a starter project. The operator says what they want to build; the seed answers
the technical questions behind it, and a technical operator can replace any answer
later.

## Targets

`[product]` The first question of the `stack` flow, asked before any technology is
named. Word it for someone who does not know the technical options:

| Target | Ask it as | Seed |
|---|---|---|
| `desktop-web` | a web application people use on a computer | `web` |
| `responsive-web` | a web application that also works on a phone's browser | `web` |
| `pwa` | a web application people can install on a phone or a computer, and that opens offline | `web` |
| `native-mobile` | an app installed from the App Store or Google Play | none |
| `binary` | a program people run on their own machine, or a command-line tool | none |
| `other` | something else — a service with no screens, a library | none |

Record the answer in `stack.md`'s `## Shape`, on the **Frontend targets** line. A
`responsive-web` or `pwa` target also sets the narrowest supported viewport, which
the `theme` flow asks next time it runs.

## Seeds

| Seed | `profiles` | Image | Image description | Starter |
|---|---|---|---|---|
| `web` | `react`, `nestjs` | `node:24.22.1-trixie` | `Node.js 24.22.1 with npm on Debian trixie, with git and bash.` | one npm package: a NestJS API under `/api` with `GET /api/is-alive` (`src/`, e2e in `test/`), and a React + Vite web that calls it and has a 404 page (`web/src`, `web/test`) |

Each seed is a directory, `.inspire/seeds/<seed>/`: `seed.json` holds the profiles and
the image this table repeats, and `files/` is the starter. A project adds a seed of
its own as a directory beside them.

A seed's `profiles` are stack ids, each served by a stack skill INSPIRE ships
([`stack-skills.md`](../../_references/stack-skills.md)). Its image is a full tag on
the official Debian image, and its description is what a unit's agent is told the
image provides ([`format.md`](format.md) § `image`).

The `stack.md` INSPIRE ships is the `web` seed: its frontmatter carries `seed: web`
and `profiles: [react, nestjs]`, and its sections name that seed's layers. A project
that declines every technical question is on it.

## Choosing the stack

`[technical]` Asked right after the target.

- **The target has a seed.** Offer two answers: the seed, named by its frameworks
  ("React and NestJS — recommended"), and "other". "I don't know — keep the default"
  takes the seed.
  - *The seed:* write `seed: <id>` and the seed's `profiles` to `stack.md`'s
    frontmatter, and confirm the layer sections match it. Ask nothing about the
    image. Then lay the starter (§ The starter project).
  - *Other:* the operator describes the stack in their own words. Remove `seed:`
    from the frontmatter and run the layer-by-layer interview
    ([`stack-interview.md`](stack-interview.md)). A stack id with no shipped skill
    needs one of the project's own, which that interview offers to scaffold. The
    interview ends by scaffolding a minimal application for the described stack
    ([`stack-interview.md`](stack-interview.md) § The starter of a described stack).
- **The target has no seed.** Say so, and that INSPIRE ships no default for it. A
  technical operator describes the stack through the same interview; a functional
  operator leaves it, and the report lists the stack as undecided. `stack.md` then
  records the target and keeps `status: default`, so `review` reports the stack as
  still open. For `native-mobile`, the shipped `ios` and `android` stack skills
  declare no language skill, and the factory's sandbox cannot build iOS.

## The starter project

A repository with no code gets the seed's starter, so the first factory run builds
its units on a tree that already installs, lints, type-checks and passes a test.
Nothing in a run creates one.

1. Run `.inspire/bin/scaffold.sh --dry-run <seed>` and show what it would create.
   The tool refuses when `source_root` is `.` or the source root holds anything but
   a `README.md`: a project with code is never scaffolded. Relay a refusal as it is
   written, and go on without a starter.
2. On the operator's yes, run `.inspire/bin/scaffold.sh <seed>`. It copies
   `.inspire/seeds/<seed>/files/` as it stands and installs nothing. It replaces
   no file of the project's: the one it replaces is the `README.md` stub
   `/inspire:init` seeds in the source root. A `README.md` the project wrote stays,
   and the starter's commands are then in `.inspire/seeds/<seed>/files/README.md`.
3. Tell the operator how to check it — the commands are in the starter's own
   `README.md` — and to commit it. Offer to run them; never run an install unasked.

`/inspire:init` lays the `web` starter itself when the operator keeps the defaults
and the repository has no code. On that project this step finds the starter in place
and has nothing to do. When the operator then chooses another stack, the starter is
the wrong one: say so, list its files, and delete them only on an explicit yes.

## What a seed decides for `emanate.yml`

A project is **on a seed** while `stack.md` names it in `seed:` and its `profiles`
equal the seed's. The `emanate` flow then takes `image.name` and
`image.description` from the table above, marks both *from the seed* in the
proposal, and asks neither. A project that edited its `profiles`, or has no
`seed:`, is on its own stack: the flow proposes an image and asks the operator to
confirm it ([`derive.md`](derive.md) § Ask, Q1 and Q2).

A newer patch of the seed's image is a change to this table in an INSPIRE release.
A project pins its own by editing `image.name` in `.inspire/emanate.yml`: the file
stays the operator's.
