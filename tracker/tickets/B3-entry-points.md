---
id: B3-entry-points
title: "B3 — Entry points: how an action gets called"
created: 2026-10-27
updated: 2026-10-28
reporter: "@dario.blasco"
closed_by: null
closed_at: null
epic: roadmap
size: XL
importance: High
skills: [domain, screens, code]
status: Open
blocked_by: []
related_to: [B3-action-effects, 090-actor-head-without-a-role, B1-kb-structure]
---

## Origin

The INSPIRE maintainers held the third session of a design review on 2026-10-27 while
preparing the training of new INSPIRE operators. This ticket records one of its
decisions. The review's working notes are not public, so this ticket states everything
needed to act on the decision.

**Decision:** an action is a function, not an API endpoint, and most actions are
internal. A new artifact, at the same level as screens, says what calls an action: a
person through a screen, a direct API call, a schedule, an event or trigger, a front-end
listener, a system condition. A trigger is one kind of entry point, not the whole
concept. The working name is "entry point". The final name is still to be chosen.

## Description

### What happens today

Screens are the only declared callers of actions, through `### Dispatches`. Nothing can
declare "every night at 02:00, consolidate the counters" or "when a notification
arrives, do X". So that logic either goes into an action's prose or isn't written down.

Exposure follows the actor. The framework profile derives an authorization guard from
`actor(role)`, and a **public route when there is no actor**. An internal action written
without an actor therefore comes out public. `090-actor-head-without-a-role` already
tracks the authorization half.

### What this ticket asks for

- A new KB artifact type that binds a kind of caller to an action: direct (screen, API,
  CLI) · scheduled · event / trigger · listener / interceptor · system condition.
- Exposure (API, MCP, gRPC, none) belongs to the entry point, not the action. An action
  with no entry point is internal and never gets a public route.
- Screens' `### Dispatches` stay as they are: they are the direct kind, already declared.
- A trigger is **one kind** of entry point, not the whole concept.
- A final name for the artifact, chosen from the candidates below.

### Name candidates

"Clashes" lists terms already in use in INSPIRE or nearby, because a reused word costs a
reader more than an odd one.

| Name | Reads as | Clashes with |
|---|---|---|
| entry point | The review's own word. Neutral, and familiar from hexagonal architecture. | — |
| invoker | The thing that invokes an action, whatever it is. | — |
| caller | Plain and short, but sounds like a person. | actor (overlaps) |
| inbound port | The exact hexagonal term. | — |
| driver | Hexagonal "driving adapter", shortened. | — |
| ingress | The way in. Infrastructure flavour. | Kubernetes Ingress |
| inlet | The way in, with no infrastructure baggage. | — |
| initiator | Whatever starts the action. | — |
| activator | Whatever activates the action. | enable/disable verbs |
| stimulus | Cause and effect: the stimulus and the reaction. | — |
| cue | Short, the signal that starts something. | — |
| occasion | When an action happens. | — |
| invocation | One declared way to invoke. | — |
| launcher | What sets the action off. | — |
| channel | The route by which a call arrives. | messaging channels |
| gateway | The door in front of an action. | API gateway |
| trigger | Familiar from databases, but the review kept it for one kind. | Dispatches' `Trigger` column |
| hook | Short and familiar. | Claude Code and git hooks |
| source | Where the call comes from. | `source/` root |
| surface | Its old meaning: where an action is exposed. | suite surfaces (ui · headless · lib) |

### Open questions

- Where does it live in the KB? It depends on `B1-kb-structure`: beside screens, under
  each module, or inside the domain.
- Is this the old meaning of "surface" (where an action is exposed) coming back? It
  overlaps with part 3 of `B1-kb-structure` (surface or module).
- Does `090-actor-head-without-a-role` fold into this ticket, or stay separate as the
  authorization half?

## Acceptance criteria

- [ ] The artifact has a final name, recorded in this ticket's close note or in an ADR.
- [ ] The artifact type has a format reference, a KB home and a skill that authors it,
      covering every caller kind listed above.
- [ ] Exposure is declared on the entry point. An action with no entry point gets no
      public route, and the framework profiles' route derivation follows that.
- [ ] Screens' `### Dispatches` are read as direct entry points with no format change.
- [ ] The open questions have written answers in this ticket's close note.

## Notes

**Amended 2026-10-28 (tracker pass).**

- *`090-actor-head-without-a-role` stays separate.* It is the authorization half (who
  may invoke), this ticket is exposure (how a call arrives), and that ticket records the
  answer.
- *Factory port.* The INSPIRE Factory derives contracts and routes with its own reader of
  the KB, and its run engine builds the code. A new artifact type, its exposure, and the
  scheduled and event kinds each need matching Factory work, filed in the Factory's
  tracker when this ticket's format lands.
- *Not "entry screen".* `B3-navigation-map` carries a different idea, a screen reached
  without navigation, and calls it an entry screen to keep this ticket's name free.
