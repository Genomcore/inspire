# Patterns

Reusable **screen structures**. A screen picks a pattern and fills its slots; it
does not redescribe the structure the pattern already defines. Add a pattern only
when the structure recurs (≥2 screens) — otherwise mark the screen `bespoke`.

| Pattern | Purpose |
|---------|---------|
| [`list`](list.md) | A collection of records — toolbar + tabular/row list + status bar |
| [`detail`](detail.md) | A single record — header + sections/tabs |

These two are starters (generic, brand-agnostic). Add more with
`/inspire_screens extract pattern {name}`; refine an existing one's **Variants**
section rather than forking a near-duplicate.
