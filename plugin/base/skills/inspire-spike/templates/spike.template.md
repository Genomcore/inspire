---
kind: spike
repo: https://github.com/org/spike-name    # external repository (source of truth for the code)
status: active                             # active | archived | superseded
covers: [ ]                                # feature ids / use cases this spike probes
---

# {Spike name}

> A narrow, deep, functional spike. **The code lives in the external repo above** —
> this file links it and captures what it taught us.

## SPK1: Question

_What are we trying to find out? (Usually: "can we build it the way we think?")_

## SPK2: Scope

_The one flow / capability this spike takes end-to-end, and the stack it used._

## SPK3: Learnings

_Brought home from the spike. Written to stand on their own — useful even if the
external repo is later archived._

- **{insight}** → affects [{use-case}](../01_spec/_modules/{module}/_features/{use-case}.feature.md) / [{module}::{entity}::{action}](../01_spec/_modules/{module}/_domain/{entity}/{entity}.{action}.action.md) / [{face}.{slug}](../01_spec/_faces/{face}/_screens/{slug}.screen.md) / [adr-{slug}](../01_spec/_adr/{slug}.adr.md)

## SPK4: Outcome

_What happens next: promote to a spec, feed the horizontal prototype, park it, or
discard. If archived, say so and why._
