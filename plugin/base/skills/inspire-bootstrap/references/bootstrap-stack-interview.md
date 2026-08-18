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
