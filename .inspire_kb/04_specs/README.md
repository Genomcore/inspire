# 04 · Specs

The **specification layer** — the precise contract of the system, expressed as
SDD action descriptors and entity documents. This is where "what correct means"
becomes machine-checkable.

- **Skill:** `inspire-object` (define / show / update / refactor / delete /
  promote / demote / review / source / graph).
- **Layout:**
  ```
  04_specs/
    {module}/
      {entity}/
        {module}.{entity}.md              # entity document (Fields, Touched by)
        {module}.{entity}.{action}.md     # action descriptor
  ```
- **Validated** by the guardrail scripts in [`bin/`](../../bin) and enforced at
  git time by [`hooks/`](../../hooks). The spec root is configurable via the
  `SDD_SPEC_ROOT` environment variable (defaults to this folder).

Specs realise features ([`02_features`](../02_features)) and must respect the
decisions in [`01_adr`](../01_adr).
