# ADR catalog — INSPIRE core

Core-level decisions about INSPIRE itself. Project-level ADRs live in a fork's
`inspire_kb/01_adr/` and are authored with `/inspire_adr`.

Ids are slug-only (`adr-{slug}.md`) — see
[adr-decision-record-ids](adr-decision-record-ids.md) for why. This index carries the
chronology a numeric prefix used to imply. Newest first.

| Date | ADR | Status |
|------|-----|--------|
| 2026-08-05 | [adr-suites-and-surfaces](adr-suites-and-surfaces.md) | Accepted — shipped in 0.5.0 |
| 2026-08-04 | [adr-upgrade-path](adr-upgrade-path.md) | Accepted — shipped in 0.4.0 |
| 2026-07-29 | [adr-plugin-delivery](adr-plugin-delivery.md) | Accepted |
| 2026-07-29 | [adr-decision-record-ids](adr-decision-record-ids.md) | Accepted |
| 2026-07-22 | [adr-runtime-lifecycle-and-lessons](adr-runtime-lifecycle-and-lessons.md) | Accepted (design); D1 superseded by `adr-plugin-delivery`; gap 3's migration-path half closed by `adr-upgrade-path` (D6/D7 still the target) |
