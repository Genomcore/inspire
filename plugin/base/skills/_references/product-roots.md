# Product roots — where code and the prototype live

Two locations on the **product side** are configurable per project, declared in the
frontmatter of
[`00_bootstrap/stack.md`](../../../.inspire_kb/00_bootstrap/stack.md):

| Field | Points at | Default | Owner skill |
|-------|-----------|---------|-------------|
| `source_root` | the production code INSPIRE realizes | `source` | `inspire-code` |
| `prototype_root` | the horizontal, mock-data prototype | `prototype` | `inspire-prototype` |

## The rule

When a skill needs to read, write, run or reference the production code or the
horizontal prototype, **resolve the configured root** — never assume the literal
`source/` or `prototype/`. Read the value from `stack.md`; fall back to the default if
the field is absent.

Skill prose uses the **default** names (`source/`, `prototype/`) because most projects
keep them and they read cleanly — but the operative location is always what `stack.md`
declares.

## Special values

- **`source_root: .`** — the repo root *is* the production code. This is the brownfield
  case: INSPIRE is installed into an existing project and governs the code in place, so
  there is no separate `source/` folder. Never create or seed a file at root `.` that
  would collide with the project (e.g. its `README.md`).
- **`prototype_root: none`** — the project has no horizontal prototype (e.g. a brownfield
  product, or one whose visual model lives elsewhere). Skills that build or reference the
  prototype treat it as **absent** rather than scaffolding one.

## Who sets them

`inspire-bootstrap` owns these fields — the `stack` subcommand, as part of the product's
**Shape**. `materialize.sh` reads them (via `/inspire:init` / `/inspire:update`) when
materializing the product-side folders: it creates the default `source/` / `prototype/`
only when the roots point at those relative paths, and skips creation for `.` / `none`.
Changing a root later is a layout change — surface it like any Shape change.
