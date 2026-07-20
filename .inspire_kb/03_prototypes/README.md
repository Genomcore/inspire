# 03 · Prototypes

Prototypes exist to **create knowledge**, not production code. This KB layer is
where that knowledge is captured and made durable — **decoupled from the
throwaway code that produced it**. The prototype code itself lives elsewhere; only
the *learnings* and *pointers* live here.

- **Skill:** `inspire-prototype`.
- **Two shapes, two locations:**

  | Shape | Code lives in | Captured here as |
  |-------|---------------|------------------|
  | **Horizontal** (breadth: wide, shallow, mocked — "is this the right thing?") | [`/prototype`](../../prototype) at the repo root (product side, one per project) | [`horizontal.md`](horizontal.md) — its learnings |
  | **Verticals** (depth: narrow, deep, functional — "can we build it as we think?") | **External repositories**, one per spike | [`verticals/{name}.md`](verticals) — a link to each repo + the learnings imported from it |

## Why this split

- The **horizontal** prototype is a single, long-lived working mock of the whole
  product. It belongs with the product (`/prototype`), runs, and evolves; its
  value to the KB is the *learnings* it produces, so those are mirrored into
  [`horizontal.md`](horizontal.md).
- The **verticals** are many, short-lived, and often built in isolation (their own
  repos, their own stacks). We don't vendor their code in — we **link the repo and
  bring the learnings home** into `verticals/`, so the knowledge survives even
  after the spike repo goes stale or is archived.

The deliverable of any prototype is **what it clarified**. Every entry here ends
with learnings that feed back into [`02_features`](../02_features),
[`04_specs`](../04_specs) and [`05_screens`](../05_screens).
