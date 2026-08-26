# Bootstrap — stack interview
> Part of [inspire-bootstrap](../SKILL.md). Read when the entry's index routes here.

## Subcommand: stack

Define or update `stack.md` — the official application stack, including its
`## Shape`.

1. Read the current `stack.md`.
2. **Establish the shape first — it frames which layers apply.** Ask one simple
   choice at a time (defaults from `stack.md` in brackets); write it to the
   `## Shape` section:
   1. **Platform** — is the product **[1] frontend-only**, **[2] backend-only** (an
      API / service), **[3] a monorepo with frontend + backend**, or **[4] not sure
      yet**? On *not sure*, record the platform as `undecided`, proceed with the
      leanest reasonable assumption, and flag it to revisit once the prototype
      clarifies — never force the choice.
   2. **One surface or several?** — does the product deliver a single surface,
      or several (several UIs, several APIs, shared libs)? Default is one. On
      *several*, delegate **each** declaration to `/inspire_surface add`: that
      skill owns the roster and this one never writes it, and its first `add` is
      the promote ceremony that brings the roster into existence and names the
      surface that already existed. On *one*, nothing is created — a suite-of-one
      is the default and has no roster file
      ([`_references/surface-scope.md`](../../_references/surface-scope.md)).
   3. **If there is a frontend** — **[1] web-only**, **[2] mobile-only**, or
      **[3] web + mobile**? Mobile adds a mobile UI stack (e.g. React Native /
      Expo); web + mobile means both, ideally sharing types/logic.
   4. **If there is a backend** — two questions:
      - **Database:** do we **deploy** a database as part of the platform, or
        **connect to an existing external** one? If connecting, record it as
        external (connection config only, no provisioning); if deploying, it's the
        *Data* layer.
      - **Local dev database:** want one for local development? If yes, **suggest
        running it via Docker** — a container like any other local service — and
        fall back to deploying it directly on the host only when Docker isn't
        available. If no, note that dev runs against a shared/remote DB.
   5. **Product roots** — where production code and the horizontal prototype live.
      Default `source_root: source`, `prototype_root: prototype` (greenfield). For a
      **brownfield** install into an existing repo, set `source_root: .` (the repo root
      *is* the code) and usually `prototype_root: none`. Write both to the `stack.md`
      frontmatter. See [`_references/product-roots.md`](../../_references/product-roots.md).
3. Interview / confirm each **applicable** layer, skipping what the shape excludes
   (no backend/data questions for a frontend-only product, no frontend questions
   for a backend-only service): language; frontend (UI library, build, styling,
   component layer, icons, charts, routing — plus the mobile stack if mobile is in
   scope); backend runtime + framework; data / messaging / scheduling; function
   execution; the prototype's mock-data engine; and shared tooling.
4. Present a diff — the `## Shape` section plus the layers — and apply on approval.
5. **A load-bearing change is an ADR.** Adding a tool is a plain edit here;
   replacing a load-bearing choice (a framework, the runtime, the primary DB) — or
   **changing the shape** (adding a backend, adding mobile, switching from a
   deployed database to an external one) — must be recorded as an ADR in
   [`01_adr`](../../../../inspire_kb/01_adr) — surface that and offer to chain
   `/inspire_adr create`.

### Stack profiles (for `/inspire_code`)

`stack.md` also drives which **stack profiles** `/inspire_code` layers onto its
generic coding-stage checks. After confirming the layers:

1. **Maintain the `profiles:` frontmatter line** — the set of framework ids that
   have (or should have) a profile, derived from the chosen frontend/backend
   frameworks (React → `react`, NestJS → `nestjs`, …). It is `/inspire_code`'s
   deterministic resolution key — the resolution rules live in
   [`profiles/README.md`](../../inspire-code/profiles/README.md) § Resolution.
2. **Offer to scaffold missing profiles.** For any id in `profiles:` with no file at
   `.claude/skills/inspire-code/profiles/{id}.md`, offer to create a lean profile
   from the contract ([`profiles/README.md`](../../inspire-code/profiles/README.md)) so
   the coding stage starts stack-aware. Framework conventions only — org policy
   (branch naming, private registries, CI) stays in the project's `CLAUDE.md`
   (seeded by `/inspire:init`, refined by the `init` flow's CLAUDE.md step in
   [`../SKILL.md`](../SKILL.md) § Subcommand: init, whose long form is
   [`bootstrap-identity.md`](bootstrap-identity.md); that step also creates one if
   the project somehow lacks it).

### Wire conventions (selected with the stack)

A project's wire behavior is decided **once, here** — not per feature, and never by
whoever writes the first test. Resolve it right after the layers:

1. **Select the convention set** from the transport the stack declares (an HTTP API →
   `rest`; a GraphQL surface → `graphql`; a CLI → its own) and write it to `stack.md`'s
   frontmatter as `wire_conventions: [<id>, …]`. The catalogue lives in
   [`_references/conventions/`](../../_references/conventions/README.md); a transport with
   no convention file is an offer to author one, not a reason to proceed on guesses.
2. **Ask the project-policy questions** — and *only* those. Each convention file's
   `## Project policy` table is the question list, already closed-ended with a default
   per row: the existence-leak choice (`403` vs `404`), the validation status, the error
   body shape, and so on. Use `AskUserQuestion`, one pass, with the file's default
   marked as recommended. Do **not** ask what the convention already derives — an
   unknown id returning not-found is not a question.
3. **Record the answers** in `stack.md`'s `## Wire conventions`, one row per decision.
   An unanswered row is written as **not decided yet** with a ticket, never quietly
   defaulted: the convention's default then applies, and saying so is what keeps a later
   test from pinning a different choice as though it were the contract.

Why this belongs at bootstrap and not in the coding stage: the answers are what turn an
acceptance criterion into an executable test. Deferred, every feature re-derives them,
and two features end up with two contracts for the same error.

### Quality gates (installed with the stack)

A project's gates are part of its foundation, not an afterthought: what the operator
stops reading, a machine has to start checking
([`_references/quality-gates.md`](../../_references/quality-gates.md)). Once the layers
and `profiles:` are confirmed:

1. **Install the in-repo gates** listed in each resolved profile's `## Quality gates`
   — the lint rules, the test-runner thresholds, and the CI job that runs them. New
   rules go in **absolute**; a rule the existing code cannot satisfy yet enters scoped
   or ratcheted with a `/inspire_task` ticket for the cleanup. Never dropped silently.
   Seed `.escape-hatches.json` with the stack's suppression patterns from the profile
   and run `.inspire/bin/escape-hatch-ratchet.sh --update` to set the ceilings from
   what the code actually contains. On a greenfield project that is **zero** — the only
   moment it is free. On existing code, measure **before** raising the lint set:
   raising it is what produces new suppressions, so the honest baseline only exists
   beforehand.
2. **Declare the external gate** in `stack.md` — which service keeps the history of
   the aggregate metrics (coverage, duplication, bundle size), since the runtime must
   not store that baseline in the repository it is judging. Record it; the in-repo
   bridge (CI job, reporter config) is installed and validated, the service itself is
   not provisioned here.
3. **Hand the far side to the operator as a ticket** (`/inspire_task create`, not a
   printed checklist — that dies with the session): protect the default branch so a
   failing check blocks a merge, and confirm the external service's own pass condition
   is strict. These sit outside every skill's reach; the ticket keeps a half-installed
   gate visible until a human closes it. Never reported as done.

An existing codebase that predates its gates is not this subcommand's problem: that
is a coding-stage job, brought up to standard from `source/` rather than scaffolded.
