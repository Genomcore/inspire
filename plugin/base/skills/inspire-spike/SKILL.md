---
name: inspire-spike
description: "Vertical spikes: register and harvest external functional-prototype repos. A spike is a narrow, deep, throwaway build in its OWN repo that answers 'can we build it as we think?'. Use to register such a repo (name/reference it, set up its learnings hygiene) and to capture its learnings into the vault as a gap analysis against the current project."
---

# /inspire_spike — Vertical spikes (external functional prototypes)

A **vertical spike** is a narrow, deep, **functional** prototype that lives in its
**own external repo** and answers *"can we build it as we think?"*. Unlike the
horizontal prototype ([`/inspire_prototype`](../inspire-prototype/SKILL.md), which is
wide, shallow and in *this* repo), a spike is throwaway code somewhere else — so
this skill never builds it. It **brings the knowledge home** into
[`.inspire_kb/06_spikes/`](../../../.inspire_kb/06_spikes), so it survives even after
the spike repo goes stale.

The code is disposable; the **learnings are the deliverable**. A spike usually
de-risks one hard thing and is deliberately rough on everything else — that
asymmetry is central to `capture` below.

## Invocation

- `/inspire_spike register {name}` — record an external spike repo in the vault
- `/inspire_spike capture {name}` — harvest its learnings as a gap analysis against this project

## Subcommand: register {name}

Give the spike an identity in the vault and set up its learnings hygiene.

1. **Identify + reference.** Create `06_spikes/{name}.md` from
   `06_spikes/_template.md` (kebab-case): the **repo link**, the question it probes,
   its scope, and the feature ids it covers. Add a one-line entry to the index in
   `06_spikes/README.md`.
2. **Inspect the spike repo's learnings hygiene.** Look at its `CLAUDE.md` (or
   equivalent) for a **structured way to record learnings**. If there is one, note
   where the learnings live so `capture` can find them.
3. **If there is none, propose one.** Suggest the operator add a short "Learnings"
   section to the spike repo's `CLAUDE.md` plus a `Learnings.md` file, so insight is
   captured *as the spike runs* rather than reconstructed later. **It's someone
   else's repo** — offer to add it from this session only with **explicit
   permission**, and never write there otherwise.

`register` does not judge the spike; it just wires it in and prepares the harvest.

## Subcommand: capture {name} — a gap analysis

`capture` is **not** "copy the spike's notes in". It's a **gap analysis**: what does
the spike know that this project doesn't yet, and how much of it actually applies
here?

1. **Source the learnings.**
   - If the spike repo has a `Learnings.md` (or the structured section from
     `register`) → import it.
   - Otherwise → read the external codebase around the **relevant feature** of the
     current project and infer what it demonstrates.
2. **Diff spike ↔ vault** across the relevant levels — features (`03_features`),
   contracts (`04_domain`), screens (`05_screens`), decisions (`01_adr`). Where does
   the spike prove, contradict, or extend what our vault says?
3. **Separate the signal from the roughness.** A vertical spike is built to answer
   **one hard question** and is usually crude on the common concerns — no real
   design library, weak or absent auth, not robust. **Do not import its shortcuts as
   if they were decisions.** Infer which pieces are genuinely valuable for *our*
   context (the hard problem it de-risked, the approach that worked); when you lack
   the context to judge, **ask the operator**.
4. **Write the learnings to stand on their own** in `06_spikes/{name}.md` — useful
   even if the external repo disappears — and route the actionable ones to the vault:
   a validated approach → an ADR can advance to `prototyped`
   ([`/inspire_adr promote`](../inspire-adr/SKILL.md)); a proven capability → a
   feature/contract via `/inspire_feature` / `/inspire_domain`.
5. **Record the outcome:** promote to a spec/ADR, feed the horizontal prototype,
   park it, or mark it archived — keep the learnings either way.

## Rules

> **Output language.** Write vault artifacts — vertical-spike notes — in the
> project's declared `output_language` (default English), per
> [`_references/output-language.md`](../_references/output-language.md). Machine-read
> tokens (frontmatter keys/values, wikilink slugs, filenames) stay verbatim.

1. **Never build the spike here.** The code lives in its external repo; this skill
   only registers and harvests. Building is the spike author's job (or `/inspire_code`
   for real implementation).
2. **Writing to the external repo needs explicit permission.** Suggesting a
   `Learnings.md` / `CLAUDE.md` section is fine; adding it requires a clear operator
   yes. Default to read-only on repos that aren't this project.
3. **Learnings must stand alone.** Written so they survive the spike repo going
   stale or archived — never a bare "see the repo".
4. **Capture is a gap analysis, not a copy.** Import the *signal* (what the spike
   de-risked); leave the *roughness* (its throwaway shortcuts) behind. Ask when
   unsure whether a piece applies to this project.
5. **Consult the task tracker** ([`/inspire_task list`](../inspire-task/SKILL.md))
   for tracked spikes; don't re-register what's already indexed.

## Related skills

- `/inspire_prototype` — the horizontal, in-repo visual prototype (discovery); a
  spike often starts life as a question the horizontal couldn't resolve.
- `/inspire_adr` — a spike is the *external functional validation* that lets an ADR
  reach `prototyped` maturity (record the `**Prototype:**` pointer there).
- `/inspire_feature` · `/inspire_domain` — where a captured capability lands as a
  feature or contract.
- `/inspire_code` — the real, in-repo implementation the spike de-risks.
