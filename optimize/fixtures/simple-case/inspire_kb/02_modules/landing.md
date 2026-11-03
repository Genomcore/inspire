---
kind: module-hub
prefix: LND
produced:
  skill: module
  skill_sha: 915520b
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---

# Landing

> The module **hub** — overview, relationships, and links to everything this module
> owns across the layers. Kept in sync with the per-layer subfolders.

## Overview

The public marketing site for OpenBIMS. It states the positioning in one sentence:
OpenBIMS is the open-source, self-hosted platform for multimodal biomedical data with
integrated AI, built by Genomcore on BIMS v1 and in production in six Spanish regions.
Every section hammers three ideas in this order: the data stays on the customer's
infrastructure, the licence is AGPL-3.0 with no private fork of the core, and the
assistant CORA operates the platform rather than only answering questions.

The site is static and public. It has no login and no backend of its own. Its success
metric is clicks on "Get Started" and clones of the repository, not form submissions.

The primary language is English with a Spanish version for the regional health
services. The tone is direct and technical: short sentences, verbs, no
"revolutionary" and no "transforming healthcare". Visuals reuse the console palette
(teal primary, violet for everything AI/CORA) and real captures of the prototype.

## Relationships

The landing links out to three destinations it does not own: the Getting Started docs
(primary CTA), the GitHub repository, and the Genomcore sales contact for Cloud and
Enterprise. The "live demo" CTA points at the demo console module of this repository
once it exists.

The module classification the landing follows is the current one (11 core modules plus
5 extensions), not the README's count of 12. Correcting the README is an upstream
task in the OpenBIMS repository, not in this module.

Facts the landing may state are limited to what the vault verifies: BIMS v1 lineage,
production in six regions, AGPL-3.0 core, the open-source stack. Logos, testimonials,
patient counts and MDR/IVDR/CE certification are unverified and stay off the page
until business supplies them.

## Use cases

Features live in [`../03_features/landing/`](../03_features/landing) — the glob is the index.

## Screens

_[`../05_screens/landing/`](../05_screens/landing) — the module's screens; the route
map + coverage table live in that folder's `_index.md`._

## Domain

_[`../04_domain/landing/`](../04_domain/landing) — action descriptors + entity
documents for this module._

## Module ADRs

_Decisions scoped to this module (`adr-LND-*` in [`../01_adr/`](../01_adr)):_

None yet.
