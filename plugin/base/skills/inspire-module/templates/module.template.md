---
kind: module-hub
prefix: MYM              # the module's feature / use-case ID prefix
---

# {Module Name}

> The module **hub** — overview, relationships, and links to this module's features,
> its entities and actions, the screens that use them, and its ADRs. Kept in sync with
> what the module's directory holds.

## MOD1: Overview

{What this module is and does, in a few sentences.}

## MOD2: Relationships

{How it relates to other modules — dependencies, shared entities, upstream/downstream.}

## MOD3: Use cases

_One link per `*.feature.md` in this module's `_features/`:_

- [[{use-case}]] — {one line: what the use case lets the actor do}

## MOD4: Screens

_The screens that use this module's actions. They live in the faces that show them
(`_faces/{face}/_screens/`); the route map is each face's `_index.md`._

- [[{face}.{slug}]] — {face}: {what the screen does}

## MOD5: Domain

_The entity documents and action descriptors in this module's `_domain/`:_

- [[{module}.{entity}|{module}::{entity}]] — {one line}
  - [[{module}.{entity}.{action}|{module}::{entity}::{action}]]

## MOD6: Module ADRs

_Decisions that bind this module only, in its `_adr/`:_

- [[adr-{slug}]] — {relation}
