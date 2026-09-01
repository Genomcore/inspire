---
kind: surface-convention
id: _example                # a real convention's id matches its stack.md `wire_conventions:` entry
transport: <rest | graphql | cli | mcp | grpc | …>
---

<!-- Copy this file to `{id}.md` and fill it in. Keep it declarative: this is data a
     skill reads, not prose a human is asked to interpret. If a row cannot be stated
     as "this input → that observable response", it is not a convention yet. -->

## Error taxonomy → surface
<!-- The DERIVED half: the mapping any competent engineer would produce identically.
     A descriptor never restates these — that is the point. Cover at minimum:
     malformed request · validation failure · absent credential · invalid credential ·
     permitted-but-forbidden · not found · collision · rate limit · downstream failure ·
     unhandled fault. -->
| Logical error class | Surface response | Notes |
|---|---|---|
| <class> | <what the caller observes> | <why, when it is not obvious> |

<!-- Then the success side, keyed by the action verb taxonomy (get / list / create /
     edit / delete / …), since the verb is what a descriptor already declares. -->

## Project policy — asked once, recorded in stack.md
<!-- The NON-derivable half: decisions where two competent engineers disagree, so no
     default is honest. CLOSED questions only — options enumerated, plus the default to
     apply when the operator has no opinion. An open question here yields prose no test
     can be written against, which defeats the file. -->
| Decision | Options | Default if the operator has no opinion |
|---|---|---|
| <decision> | <a> · <b> | <choice> — <one line on why> |

## Response shape
<!-- What a test asserts, in full. Name the envelope, and name explicitly which fields
     are non-deterministic and may use loose matchers — everything unnamed is exact. -->

## Always-present cases
<!-- The tests that exist for EVERY action on this transport, criterion or no criterion.
     This is the section that stops "nothing left to interpretation" from depending on
     whoever wrote the feature file remembering the auth cases. -->

## Deviation
<!-- The exact form an action uses to declare it does not follow this convention,
     with an example. A deviation without a written reason is a finding. -->
