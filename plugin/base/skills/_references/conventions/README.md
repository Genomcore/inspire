# Wire conventions — the contract

A **wire convention** is the declared answer to "what does this action look like
from outside, and what does a caller get when things go wrong". It exists so an
acceptance criterion can become an executable test **without anybody inventing the
missing half**.

The problem it solves is concrete. An action descriptor declares logical errors —
`missing_required_field`, with an operator-facing message — and, by design, nothing
about the wire: [`inspire-domain/references/format-action.md`](../../inspire-domain/references/format-action.md)
`## Pure-contract scope` puts route and transport out of the descriptor's reach. Left
there, whoever writes the e2e test picks a status code out of the air, and picks a
different one next month. Both tests pass. Neither is the contract.

So the runtime ships the conventions, the project **selects** which apply, and from
that point they are **restrictive**: derived silently where they hold, and overridable
only in the open.

## Resolution

Same mechanism as the stack profiles ([`inspire-code/profiles/README.md`](../../inspire-code/profiles/README.md)),
resolved from [`00_bootstrap/stack.md`](../../../../inspire_kb/00_bootstrap/stack.md):

1. **Deterministic** — if `stack.md`'s frontmatter declares
   `wire_conventions: [<id>, …]`, use that set. `/inspire_bootstrap stack`
   maintains this line.
2. **Inference fallback** — otherwise infer from the declared transport (a GraphQL ADR
   or a `## API` section naming GraphQL → `graphql`; an HTTP/REST API → `rest`).

Then read **only** `conventions/{id}.md` for each resolved id. Conventions are
**composable and orthogonal to the stack profile**: REST on NestJS and GraphQL on
NestJS are the same profile with different conventions, which is why these are not
folded into `profiles/`.

**No convention resolved is not a free pass.** It means the wire behavior is
unspecified, and the honest move is to say so and offer to run
`/inspire_bootstrap stack` — not to guess a status code and write a test that pins
the guess.

## Two halves, and the line between them

Every convention file separates what it can decide from what it cannot. The line is
the whole point: it is what lets a project specify only what is genuinely its own.

- **Derived** — the mapping a competent engineer would produce the same way every
  time. Unknown id on a fetch → not-found. Absent or expired credential →
  unauthenticated. These are **not written into descriptors**. The descriptor names
  the logical error; the convention supplies the rest.
- **Project policy** — decisions where two competent engineers legitimately disagree,
  so no default can be honest. `403` vs `404` when the resource exists but the caller
  may not see it is a privacy decision, not a technical one. These are **asked once at
  bootstrap** and recorded in `stack.md`'s `## Wire conventions`. Never re-asked per
  feature; never left to the agent.

## File format

```markdown
---
kind: surface-convention
id: <slug>                  # matches the id in stack.md `wire_conventions:`
transport: <rest | graphql | cli | …>
---

## Error taxonomy → surface
<!-- The derived half. One row per logical error class. The Logical column is the
     vocabulary a descriptor's `## Errors` uses; the Surface column is what the test
     asserts. -->
| Logical error class | Surface response | Notes |

## Project policy — asked once, recorded in stack.md
<!-- Closed questions only, each with its options and what choosing costs. An open
     prose question here produces prose nobody can test against. -->
| Decision | Options | Default if the operator has no opinion |

## Response shape
<!-- What a test asserts in full: success envelope, error envelope, which fields are
     non-deterministic and may use loose matchers. -->

## Always-present cases
<!-- The tests that exist for every action of this transport whether or not a
     criterion mentions them — the ones a feature author forgets and a reviewer
     should never have to remember. -->

## Deviation
<!-- How an action declares it does NOT follow the convention. -->
```

## Deviations are declared, never assumed

An action that does not follow the resolved convention says so in its descriptor,
under `## Errors`, as an explicit surface note per the convention's `## Deviation`
section. Silence means the convention holds — which is what makes the convention
restrictive rather than decorative, and what makes a missing status code a **finding**
instead of an interpretation.

## Who reads this

| Consumer | Uses it for |
|---|---|
| `/inspire_bootstrap stack` | asking the project-policy questions once, recording the answers |
| `/inspire_code tdd` | deriving the full test list before writing the first failing test |
| `/inspire_code review` | a case the convention requires and no test covers is a finding |
| `/inspire_feature` | the acceptance-criteria gate: a declared error with no criterion |
| `/inspire_domain` | whether a descriptor needs a deviation note at all |
