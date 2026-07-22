# 06 · Spikes

Vertical spikes answer *"can we build it the way we think?"* — a **narrow, deep,
functional** prototype, each in its **own external repo**, built to de-risk one hard
thing. This KB layer holds only their **knowledge**: repo links, imported learnings,
and gap analysis — **decoupled from the throwaway code** that produced it, so it
survives after the spike repo goes stale or is archived.

> The **horizontal** prototype (wide, shallow, mocked — "is this the right thing?")
> is different: its code lives at [`/prototype`](../../prototype) and it keeps **no
> file here** — its insights co-evolve the vault directly (features, screens, ADRs,
> the design system). See `inspire-prototype`. **This layer is spikes only.**

- **Skill:** `inspire-spike` (`register` + `capture`).
- **Layout:**
  ```
  06_spikes/
    {name}.md        # one per spike: repo link + imported learnings + gap analysis
    _template.md     # copy this for a new spike
    README.md        # this file + the spike index below
  ```

## Adding a spike

1. `/inspire_spike register {name}` copies `_template.md` → `{name}.md` and fills the
   repo link, the question, scope, and covered features.
2. `/inspire_spike capture {name}` harvests its learnings as a **gap analysis**
   against the vault — importing the signal it de-risked, leaving its rough shortcuts
   behind.

Every entry's learnings are written to **stand on their own** and feed back into
[`03_features`](../03_features), [`04_domain`](../04_domain),
[`05_screens`](../05_screens) and [`01_adr`](../01_adr).

## Index

_List each spike here with a one-line summary and its repo link:_

- _e.g._ `realtime-sync` — spike on live collaboration — `github.com/org/spike-realtime-sync`
