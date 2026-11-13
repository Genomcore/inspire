---
id: auth.user
module: auth
entity: user
lifecycle: accepted
---

## Purpose
User entity.

## Rationale
A link is written `[text](path.md)`, as in `[adr-example](../_adr/example.adr.md)`;
the old form was `[[adr-example]]`, and ``a span holding `[x](y.md)` inside`` is still
one span. The one real link here resolves: [auth::user](user.entity.md).

```markdown
[adr-in-a-fence](../_adr/fenced.adr.md) and [[adr-in-a-fence]]
```

~~~~
```
[[still-fenced]] [inner](inner.md)
```
~~~~

## Invariants
None beyond Fields constraints.

## Fields

| Field | Type | Notes        |
|-------|------|--------------|
| `id`  | uuid | Primary key. |
