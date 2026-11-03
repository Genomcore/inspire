---
produced:
  skill: feature
  skill_sha: 7aff836
  refs_sha: bd26ed3
  inspire: 0.9.9
  at: "2026-09-18"
---
# LND-05: Compare editions

> Source: [[../../02_modules/landing]]

The visitor compares Community, Cloud and Enterprise on five rows: deploy, core,
extensions, external connectors and support. The table carries no prices. A single
line beneath states that the three editions run the same software and that
Enterprise activates without a migration.

**State:** 🟡 Planned
**Priority:** Important
**Depends on:** [[LND-02]]

## Actor
An IT procurement lead deciding which edition to start with.

## Preconditions
None.

## Main flow
1. `B1` — The visitor reads a table with three edition columns and five rows.
2. `B2` — The visitor reads the line beneath: start in Community and activate
   Enterprise without migrating, because it is the same software.
3. `B3` — The visitor follows the Enterprise column's contact link to Genomcore
   sales.

## Alternative flows
### AF-1: Narrow viewport
On a viewport narrower than 768 px the table renders as three stacked cards, one per
edition, with the same five rows each.

## Error flows
None.

## Postconditions
- `Q1` — The visitor can state what differs between the three editions.

## Acceptance criteria
- [ ] AC-1: The table has three columns headed "Community", "Cloud" and "Enterprise" and five rows headed "Deploy", "Core", "ee extensions", "External connectors" and "Support".
- [ ] AC-2: The Deploy row reads "Docker Compose, one host", "Kubernetes, operated by Genomcore" and "Kubernetes on-prem or cloud, co-managed".
- [ ] AC-6: The Core row reads "AGPL-3.0 complete", "The same", "The same".
- [ ] AC-7: The ee extensions row reads "No", "Yes", "Yes".
- [ ] AC-8: The External connectors row reads "S3, Postgres", "Included", "Oracle, corporate Elastic, ClickHouse".
- [ ] AC-9: The Support row reads "Community + docs", "Included", "Premium, SLA, compliance packs".
- [ ] AC-3: No cell and no surrounding text contains a currency symbol or a numeric price.
- [ ] AC-4: Below 768 px width the page renders three cards instead of the table, one per edition, each listing the same five rows.
- [ ] AC-5: The Enterprise column contains one link to the Genomcore contact page.
