# `_bundles/` · how the product is exposed

A **bundle** is the unit of exposure: which actions are published together, and
by which package. One file per bundle, `{bundle}.bundle.md`:

```markdown
---
id: api
package: apps/api
profiles: [nestjs]
---

# Bundle: api

## Actions

- [[orders]] (whole module)
- [[billing::invoice::close]]
```

- **Which actions go into which bundle is a specification decision**, made from the
  use cases. One bundle per module is a reasonable start; INSPIRE does not decide it.
- **Exposure stays on the action.** An action's route, dispatch and guard come from
  its own bindings; a bundle never redefines a route.
- **A bundle that only groups actions** is checked by one test: the bundle's
  application starts and exposes every action it lists. Adding an action changes
  that test and nothing else.
- **A bundle that produces its own artifact** (an SDK, a library, a backend for a
  frontend) has code of its own, and its file says what that code does.
- **No version in the specification.** The id is `api`, never `api@v1`.
- A face lists the bundles it uses (`bundles: [api]` in `{face}.face.md`). A screen
  that depends on an action outside its face's bundles is a finding.

**Skill:** `inspire-face` (faces and bundles: add, retire, review).
