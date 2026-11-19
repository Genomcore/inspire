# Seeds

A **seed** is the starter project INSPIRE recommends for one kind of product. Each
directory here is one seed:

- `<seed>/files/` — the starter, copied as it stands under the project's source root;
- `<seed>/seed.json` — its stack ids (`profiles`), the image INSPIRE Factory runs its
  units in (`image`), and the runtime files the starter needs in its own tree (`copy`).

`.inspire/bin/scaffold.sh <seed>` lays one in a repository that has no code yet. It
refuses a source root that holds code, and it replaces no file of the project's. `/inspire-config stack`
runs it when the operator takes a seed, and `/inspire:init` runs it for the default seed
when the operator keeps the defaults.

Which target gets which seed, and what a seed decides for `.inspire/emanate.yml`, is in
`.claude/skills/inspire-config/references/seeds.md`.

These files are the project's to change: `/inspire:update` keeps an edited one. A seed of
the project's own is a directory beside these, and an update never touches it.

A dependency bot that scans every `package.json` in the repository finds the ones under
`files/`. Exclude `.inspire/seeds/` in its configuration: a starter is copied once, and
its lockfile is updated with an INSPIRE release.
