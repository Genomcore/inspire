# Subcommand: graph

Print the action→action `requires` graph for the scope, including supersession edges. Read-only.

## Format

```
auth::user::create
  └── requires: auth::password::hash  [stable]
auth::user::update
  └── requires: auth::user::create    [accepted]
  └── requires: auth::password::hash  [stable]
auth::user::delete  [superseded → auth::user::archive]
```

Supersession edges are rendered with a different marker (`→ superseded_by`). Cycles — if any exist — are highlighted with `CYCLE` so they are visible before hitting `acyclic-deps`.

**Bonus output:** a "ready queue" — actions at `lifecycle: accepted` whose every `requires` target is already `stable`, i.e. candidates for promotion to `stable` next.
