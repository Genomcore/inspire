# `/prototype` — the horizontal prototype

This is the **horizontal prototype**: a wide, shallow, mocked working model of the
**whole product**. It is real, runnable code and it lives here at the repo root
(product side, not under `.inspire_kb/`) — one per project.

It answers *"is this the right thing to build?"* by making the shape of the system
legible end to end, without real backends or production depth.

- **Skill:** `inspire-prototype`.
- **Its insights** co-evolve the vault directly as you build — features, screens,
  ADRs and the design system. It keeps **no learnings file of its own**.
- **Vertical spikes** (narrow, deep) live in **their own external repos**; their
  knowledge is brought home under
  [`.inspire_kb/06_spikes/`](../.inspire_kb/06_spikes) (skill `inspire-spike`).

> Template note: this folder starts empty (just this README). Scaffold the
> horizontal prototype here when the project starts.
