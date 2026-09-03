# Artifact trust — stamps (shared reference)

## Stamping

Two additive frontmatter blocks record two different things about a KB artifact.
Absence is honest: no block reads as "never endorsed" / "provenance unknown", stamps
accrue as artifacts are touched, nothing migrates. Author neither by hand — an LLM
writing a hash is not a trust primitive, so `.inspire/bin/trust.sh` owns all of it.

```yaml
---
endorsed:              # human-owned — the machine never writes, updates or removes it
  by: "@dario"         # resolved from git config user.email
  at: 2026-09-13       # when they stamped; informational, never a check input
produced:              # machine-owned — overwritten wholesale on every write
  skill: domain        # the skill that performed the write
  skill_sha: 3f9c2a1   # composite hash of its deployed dir — THE staleness comparand
  refs_sha: 91b04e7    # composite hash of the deployed _references/ dir
  inspire: 0.5.0       # runtime version; a human label and retrieval key, never a trigger
  at: 2026-09-13
---
```

After every KB write you make, run `trust.sh stamp <file> --skill <name>` — a skill's
whole provenance duty, and what it writes replaces the block wholesale. Staleness is
**ecosystem divergence, never age**: no check reads a clock, the dates are for humans.

## Endorsement

`trust.sh endorse <file>`, run only after an explicit operator yes, is the only thing
that writes the human-owned block. It answers *who is the last human that put their name
on this?* — a name and a date. Read it honestly: **a human put their name here at that
point in history; the content may have evolved since, and git history is the audit
trail.** Attestation, not content-pinning. A skill may recognize an endorsement moment
and *propose* one — top-rung lifecycle promotions are the native place, those flows being
operator-confirmed ceremonies already — and the human decides. Consent is unenforceable
by machinery: nothing checks that anyone was asked, so the discipline lives in prose.

- Ask per artifact. "Endorse all 23?" is not a real vouch — one keystroke producing 23
  stamps a later reader trusts as if a human had read each one.
- **Disclosure:** before rewriting the body of a file carrying `endorsed:` — presence is
  the whole test — say so in-conversation: "this rewrites content @x endorsed on {date}".

## Scope

| Where | `endorsed` | `produced` |
|---|---|---|
| `01_adr` – `05_screens` artifacts, `design-system.md` included | yes | yes |
| Screens `patterns/` + `components/` entries | yes — an authored layout contract since T2, not rebuilt output | yes |
| An `_index.md` hub at any path — screens' and the catalog's own `patterns/_index.md` / `components/_index.md` among them | no — rebuilt nav content, so endorsing it is drift by construction | yes |
| `00_bootstrap/project.md`, `stack.md` | yes | no — the operator interview generated them, not a skill run |
| `theme.md`, `_template.md`, `README.md` | no | no |
| `06_spikes`, `98_lessons`, `99_tracker` | no | no — meta layers; lessons keep their own version stamping |

Exclusions go **by path and filename, never by frontmatter**: the live `design-system.md`
inherits `status: template` from the copy of `theme.md` that seeded it, so a frontmatter
predicate would excuse a project's real design system. Where a file has no frontmatter at
all — screens by design, most ADRs and features in practice — `stamp` creates the block.

`00_bootstrap` contributes **`project.md` and `stack.md` and nothing else** to what
`report` walks: the rest of that layer is not scanned, so no other file there is counted
or reported whatever it carries in frontmatter. The table above is the scope of the two
blocks, not a promise that every path it names is measured.

## Ownership

Position decides the owning skill — `01_adr` → adr, `02_modules` → module, `03_features`
→ feature, `04_domain` → domain, `05_screens` → screens; short names, exactly what
`--skill` takes. Two paths override position: `05_screens/design-system.md` → bootstrap
(its one artifact outside `00_bootstrap`), `00_bootstrap/surfaces.md` → surface. Hence:
**A skill writing outside its owned layer is misbehaviour — route the write to the owner.**

## Report

`trust.sh report [--summary]` recomputes everything on every run — no ledger, nothing to
rebaseline; `trust.sh skill-sha <dir>` gives one directory's composite hash. Six groups,
keyed by producer transition, since "23 artifacts under a different `inspire-feature`" is
one judgment and not 23:

| Group | What it means |
|---|---|
| `UNENDORSED` | no `endorsed:` block |
| `STALE` | the stamped skill hash differs from the map owner's installed hash |
| `REFS-CHANGED` | the shared references moved — one vault-wide line |
| `PRE-PROVENANCE` | no `produced:` block; a shrinking cohort, never backfilled |
| `OWNER NOT INSTALLED` | the owning skill directory is absent, so provenance is unresolvable — never stale, deleting a skill being legitimate use |
| `MISROUTED` | the stamped skill is not the map owner |

The remedy for a stale artifact is its **owning skill**: invoke that skill's update or
review flow on the artifact. A genuinely misrouted artifact normally appears in both
`MISROUTED` and `STALE` — its `STALE` line compares against a map owner that never wrote
it, so it reflects the routing error rather than generator drift; read the two groups
together. `materialize.sh`'s writes during init and update are **not provenance
events**: an upgrade never stamps. The invariant is exactly *"nothing is stale without
the report saying so **when run**"*, which the pre-PR hook makes unconditional at the
review moment. All of this is signal; none of it gates.
