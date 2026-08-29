---
name: inspire-code
description: "Coding-stage lifecycle: realize the knowledge base as production code in source/, and keep it honest. Use when implementing an ADR / action descriptor test-first, reviewing a diff against the KB, debugging a failure to root cause, fixing a broken build, or remediating dependency vulnerabilities."
argument-hint: "<subcommand> [<target>] [args]"
user-invocable: true
---

# /inspire-code — Coding-stage Operations

Every other `inspire-*` skill **specifies**; this one **realizes**. The KB
(`00_bootstrap` → `04_domain`) describes *what* the product does and *why*;
`inspire-code` owns the act of turning that into working code under `source/` and
keeping the two in agreement. An ADR reaches `implemented` maturity precisely when
code that honors it lands in `source/` — this skill is the bridge that gets it
there without drift.

> **Where the code lives is configurable.** `source/` is the default; the operative
> root is `source_root` in `00_bootstrap/stack.md` (a brownfield project sets
> `source_root: .` — the repo root itself). Resolve it rather than assuming `source/` —
> see [`_references/product-roots.md`](../_references/product-roots.md).

This skill is stack-agnostic on purpose. It carries **judgment** (root-cause
discipline, architectural review, test strategy, vulnerability triage), not
mechanical checks — those belong to the project's linters, formatters, and hooks.
The single most important thing it does is refuse to treat code as the source of
truth: the KB is, and every operation here re-anchors to it.

## Surfaces and the monorepo

A suite may realize its capabilities across several **surfaces**, each one a package
inside the single `source_root`. What a surface is, and how a skill resolves which
one a write applies to, are defined in
[`.claude/skills/_references/surface-scope.md`](../_references/surface-scope.md); the
roster fields this skill reads — `Package` and `Profiles`, with their defaults — are
specified in
[`inspire-surface/references/roster-format.md`](../inspire-surface/references/roster-format.md).
Read both before emanating code into a suite that has a roster. **No roster means
suite-of-one**: everything below collapses to "the one package", and the skill
behaves exactly as it did before surfaces existed.

**Resolving the target surface.** The shared scope-resolution rule applies here as
everywhere; what is specific to this skill is that the code's own location pins the
answer. Match the emanation path within `source_root` against the roster's `Package`
values, longest prefix first, matched on whole path segments — `apps/portal` never
matches `apps/portal-admin`. An explicit surface argument still wins, and a path
that falls under no declared package is a question for the operator, not a guess.
Then load that surface's `Profiles`, falling back to the suite's global `profiles:`
in `stack.md` when the surface declares none. With a roster, the **surface** — not
the layer — selects the profile: the surface's `Profiles` field is the selector, and
the by-layer rule applies only when no roster exists. Every subcommand states the
surface and the profile set it resolved.

**Scaffolding is lazy.** `/inspire-surface add` records a `Package` path; it does not
create the directory. The first emanation into a surface whose package is not on disk
scaffolds it — the package, per its profiles' conventions, and the workspace manifest
itself (`pnpm-workspace.yaml`, `turbo.json`, `nx.json` — whichever the stack profile
names) on first need, never before. A project with one materialized package stays
that way until a second surface actually receives code.

**Build and verify per package.** Run the target surface's package-scoped commands,
never the workspace-wide form when a filtered one exists — each profile's
`## Build & verify` gives the concrete shape. `tdd`, `fix-build` and `debug` verify
the package under work; widening to the whole workspace is a step the operator asks
for, because a green build elsewhere is not evidence about this surface.

**Dependency discipline.** Surfaces never import each other. Whatever two surfaces
share moves into a `lib` surface and is imported from there — the ui-kit realizes
`05_screens/components/`, and a contracts/types package is the usual second one. This
is what stops one domain truth from fragmenting into per-surface copies. `review`
checks imports against the roster: an import reaching from one surface's `Package`
into another's is a finding, and its fix is a `lib`, not an exception.

## Scope

**Owns:** implementing features test-first against their acceptance criteria and
realizing action descriptors; judgment-based review of a working diff; the
root-cause debugging loop; build-error remediation; dependency-vulnerability
remediation; and — the INSPIRE-specific part — detecting when code and KB have
drifted apart and routing the fix back to the right specifying skill.

**Does NOT own:** authoring specs (`/inspire-domain`), features (`/inspire-feature`,
`/inspire-module`), screens (`/inspire-screens`), or ADRs (`/inspire-adr`).
When code work reveals that the *spec* is wrong or missing, this skill **stops and
hands back** to the owning skill — it never edits the KB itself. It also does NOT
own mechanical enforcement (lint / format / type-only rules) — that is the
toolchain's job; see each subcommand's note.

## Invocation

```
/inspire-code tdd       <feature-id>        # implement a feature test-first, anchored to its acceptance criteria
/inspire-code review    [<target>]          # judgment review of a diff against the KB + universal quality
/inspire-code debug     <symptom>           # 6-step root-cause framework; loops spec gaps back to the KB
/inspire-code fix-build                      # diagnose + fix compile/build errors, verify
/inspire-code fix-vulns                      # npm vulnerability remediation (fewest overrides, keep build+tests green)
```

`<feature-id>` is a use-case id (e.g. `ai-agents/AIA-08`). `<target>` for `review`
defaults to the working diff (`git diff` / `git diff --cached`); it also accepts a
path, a commit range, or a `<feature-id>` to scope the review to one feature's
realizing code.

## Subcommands

Each subcommand's full flow lives at `references/{name}.md`. **Before executing any
subcommand, read its reference file** — the table below is an index, not the flow.

| Subcommand | What it does |
|---|---|
| [`tdd`](references/tdd.md) | Write production code test-first: red → green → refactor → mutation drill, GIVEN/WHEN/THEN, and the non-negotiable authoring rules. Anchored to the feature's acceptance criteria. |
| [`review`](references/review-dimensions.md) | Judgment review of a diff. Phase 0 checks KB alignment (ADRs, action descriptors, acceptance criteria); phases 1–4 cover architecture, correctness, security, tests. Fans out to dimension agents in thorough mode. |
| [`debug`](references/debug.md) | Reproduce → hypothesize → eliminate → root cause → fix → prevent regression. A root cause that is a spec gap routes back to `/inspire-feature` or `/inspire-domain`. |
| [`fix-build`](references/fix-build.md) | Parse build/compile errors, diagnose root cause, apply the minimal fix, rebuild to verify. |
| [`fix-vulns`](references/fix-vulns.md) | Reach the agreed severity bar with the fewest `overrides` possible, without breaking build or tests. **npm only.** |

## SDD anchoring — the thing that makes this different from a generic linter

`review` and `debug` always re-anchor to the KB before judging code. Concretely:

- **ADRs (`01_adr`).** Does the diff contradict a current ADR — one present and not
  superseded or rejected — within its maturity's reach? An ADR at `implemented`
  maturity is *claimed* to be realized by code — verify the claim.
- **Action descriptors (`04_domain/{module}/{entity}/`).** Does the code satisfy
  the behavioral contract (inputs, outputs, touched entities, invariants, error
  set)? Search for the descriptor whose `## Purpose` back-sources to the feature.
- **Acceptance criteria (`03_features/{module}/{feature-id}.md`).** Is every
  testable criterion covered by a test? Criteria carry stable ids (`AC-n`) — cite
  them literally.

**Anchor check.** If a spec this work builds from carries no `endorsed:`
block, tell the operator — "building from a spec no human endorsed" — and
continue ([trust-stamps](../_references/trust-stamps.md#endorsement)). Warn,
never refuse.

When code and KB disagree, the fix has a home: **code wrong → fix here; spec wrong
or missing → hand back** to `/inspire-domain` / `/inspire-feature`. Never
silently "correct" the KB to match the code, and never bend the code around a spec
you believe is wrong — surface the disagreement.

## Stack profiles (on-demand)

This skill is stack-agnostic; a **stack profile** layers a framework's concrete
conventions onto its generic dimensions. At the start of any subcommand, resolve the
active profile set per [`profiles/README.md`](profiles/README.md) § Resolution. That
contract is also where the load rules live — which files a resolved set reads from
[`profiles/`](profiles/), that profiles compose, and that a declared framework with no
profile file runs purely generic instead of blocking — so read it there rather than
from here. When the suite has a surface roster, the target surface's `Profiles` field
is the selector instead; see *Surfaces and the monorepo* above.

What this skill adds is where a profile's sections land in its own flow:
`## Layering` → review Phase 1 / implementation shape; `## Test conventions` → `tdd`
+ review Phase 4; `## Forbidden patterns` → review + authoring rules;
`## Review focus` → extra review dimensions; `## Build & verify` → the real
build/test commands. When a framework the project declared has no profile, say so in
the run's opening statement and offer `/inspire-bootstrap` to scaffold one.

## Rules

> **Output language.** Write every artifact you produce in the project's declared
> `output_language` (default English) — see
> [`_references/output-language.md`](../_references/output-language.md). Applies
> whatever language the conversation is in, and independently of the product's own
> i18n; machine-read tokens (frontmatter keys/values, wikilink slugs, filenames)
> stay verbatim. Review reports and debug write-ups addressed to the operator are
> prose — write them in `output_language` too.

> **Writing contract.** Review reports, debug write-ups and any KB text you propose
> follow [`_references/writing-style.md`](../_references/writing-style.md).

> **Lesson capture.** At a natural pause, when the operator's feedback should
> change how this skill behaves, offer `/inspire-lesson note` — never auto-write
> a lesson. Protocol and ticket-vs-lesson routing:
> [`_references/lesson-capture.md`](../_references/lesson-capture.md).

1. **`review`, `debug` (analysis phase) are read-only until a fix is agreed.**
   `review` never edits code — it reports, ranks, and names the fix. Its one bounded
   exception is the mutation drill (review Phase 4), which applies and immediately
   reverts one mutation at a time and must leave the tree exactly as it found it.
   `fix-build`, `fix-vulns`, and `tdd` do edit, but only source/test files, never
   the KB.
2. **The KB is the source of truth, not the code.** Every disagreement between the
   two is surfaced, not silently reconciled. KB edits are routed to the owning
   skill (see SDD anchoring).
3. **Mechanical checks are not this skill's job — closing the gap is.** Formatting,
   unused imports, `any`/return-type rules, line length, naming, import order,
   floating promises, cyclomatic complexity, module size, import cycles, tests that
   assert nothing — the project's linter/formatter/type-checker and hooks enforce
   these. A check the toolchain *could* run but doesn't is a **finding**, not an
   observation: report it naming the gate that should own it, per
   [`_references/quality-gates.md`](../_references/quality-gates.md) and the active
   profile's `## Quality gates`. Reviewing by hand every time what a machine could
   check once is itself the defect.
4. **Root cause before fix.** `debug` and `fix-build` never patch a symptom. Fix
   the cause, then check whether the same pattern exists elsewhere.
5. **Never silence the toolchain and never swallow errors.** See
   [`references/tdd.md`](references/tdd.md) — these authoring rules hold across
   every subcommand that writes code, not just `tdd`.
6. **Infrastructure before the first test.** E2E comes first, so the database / broker /
   cache it runs against has to exist before the cycle starts. A component the tests need
   is declared in `stack.md`'s `## Test infrastructure` (an ADR when load-bearing), then
   added to the compose file, then brought up **by the operator** — never started
   silently, never assumed. A connection error is not a red test; it is a test that never
   ran. See [`references/tdd.md`](references/tdd.md).
7. **No production code without its test, and no test trusted until it has failed.**
   `tdd` writes the failing test first; `review` flags new logic that arrived without
   one. Green is not the end of the cycle — the **mutation drill** closes it
   ([`references/tdd.md`](references/tdd.md), step 7): break the settled code on
   purpose and confirm the tests notice. A survivor is a test gap, not a code bug.
8. **Commits and pushes stay operator-only.** No subcommand runs `git commit` /
   `git push` as a side effect. When the operator does ask, follow the shared git
   discipline in
   [`_references/git-conventions.md`](../_references/git-conventions.md) (the
   project's `CLAUDE.md` overrides it).
9. **The feature's `State:` advance is offered from here, written elsewhere.**
   `tdd` offers — never auto-writes — the ladder's two moves at its cycle's edges:
   🟡 → 🔵 when implementation starts, 🔵 → 🟢 when every criterion is claimed and
   green ([`references/tdd.md`](references/tdd.md) § The state ladder advances from
   here). On acceptance the write chains into `/inspire-feature update`, so Rule 1's
   "never the KB" holds. The lifecycle gates key their severity to that line —
   leaving it at 🟡 while implementing is running with the gates disarmed.
10. **Consult the task tracker** at the start of multi-step subcommands
   (`/inspire-task list`). Surface known items as `(tracked: TASK-{id})`
   rather than re-reporting them as new. If a session surfaces friction worth
   capturing, offer a skill-feedback ticket (`epic: skill-feedback`,
   `skills: [code]`).

## References

- [`references/tdd.md`](references/tdd.md) — test-first loop, GIVEN/WHEN/THEN, and
  non-negotiable authoring rules (toolchain, error handling, dead code, TODOs).
- [`references/review-dimensions.md`](references/review-dimensions.md) — the review
  phases + the fan-out dimensions and what each one checks.
- [`references/fix-build.md`](references/fix-build.md) — build-error taxonomy + process.
- [`references/fix-vulns.md`](references/fix-vulns.md) — npm vulnerability workflow.
- [`references/debug.md`](references/debug.md) — the 6-step root-cause framework.
- [`profiles/README.md`](profiles/README.md) — the stack-profile contract; the
  lean default profiles (`react`, `nestjs`) live beside it.
- [`_references/findings-format.md`](../_references/findings-format.md) — shared
  finding rendering format, used when `review` surfaces SDD-layer findings.
- [`_references/quality-gates.md`](../_references/quality-gates.md) — which layer
  owns a rule (lint vs metric gate vs human), absolutes vs ratchets, and why a
  threshold must live outside the author's write reach.
- [`_references/conventions/README.md`](../_references/conventions/README.md) — the
  wire conventions resolved from `00_bootstrap/stack.md`: what a caller observes for
  each logical error, so `tdd` can derive its test list instead of inventing the half
  the descriptor deliberately leaves out.

## Related skills

- `/inspire-feature`, `/inspire-domain` — the specifying skills this one hands back
  to when a code problem turns out to be a spec problem.
- `/inspire-module` — its `review` audits the KB before a PR; `inspire-code review`
  audits the *code* that realizes it. Run both before landing a change.
- `/inspire-surface` — owns the roster this skill resolves packages and profiles
  from; the only skill that adds or retires a surface.
- `/inspire-adr` — ADR lifecycle; an ADR reaches `implemented` maturity via this
  skill's work. `/inspire-task` — the tracker; consult it and file skill-feedback.
- `/inspire-workspace` — the pre-PR global review and vault structure.
