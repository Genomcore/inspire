# Product roots — where code and the prototype live

Two locations on the **product side** are configurable per project, declared in the
spec config, `.inspire/config.json`:

| Field | Points at | Default | Owner skill |
|-------|-----------|---------|-------------|
| `source_root` | the production code INSPIRE realizes | `source` | `inspire-config` |
| `prototype_root` | the horizontal, mock-data prototype | `prototype` | `inspire-prototype` |

A face's or a bundle's `package` (in `{face}.face.md` or `{bundle}.bundle.md`) is a path
**relative to the single `source_root`**: `package: apps/portal` with `source_root: source`
is `source/apps/portal`. There is one `source_root` per project; a face or a bundle never
declares a root of its own.

## The rule

When a skill needs to read, write, run or reference the production code or the
horizontal prototype, **resolve the configured root** — never assume the literal
`source/` or `prototype/`. Read the value from `.inspire/config.json`. When the file
or the key is absent, read the frontmatter of `inspire_kb/00_bootstrap/stack.md`,
where a project installed before INSPIRE 0.20.0 declares it, and fall back to the
default only when neither has it.

Skill prose uses the **default** names (`source/`, `prototype/`) because most projects
keep them and they read cleanly — but the operative location is always what the spec
config declares.

## Special values

- **`source_root: .`** — the repo root *is* the production code. This is the brownfield
  case: INSPIRE is installed into an existing project and governs the code in place, so
  there is no separate `source/` folder. Never create or seed a file at root `.` that
  would collide with the project (e.g. its `README.md`).
- **`prototype_root: none`** — the project has no horizontal prototype (e.g. a brownfield
  product, or one whose visual model lives elsewhere). Skills that build or reference the
  prototype treat it as **absent** rather than scaffolding one.

## Who sets them

`/inspire:init` writes them, with the defaults or with `source_root: .` and
`prototype_root: none` when the repository root already holds code. `/inspire-config
stack` changes them afterwards, as part of the product's **Shape**. `materialize.sh`
creates the product-side folders from them (via `/inspire:init` / `/inspire:update`): a
relative path gets a folder, and `.` / `none` get none. Changing a root later is a
layout change — surface it like any Shape change.
