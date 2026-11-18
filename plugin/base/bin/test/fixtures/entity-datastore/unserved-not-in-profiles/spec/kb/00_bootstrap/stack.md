---
kind: bootstrap-stack
profiles: [nestjs, postgres]
datastores:
  metadata: postgres
  analytics: clickhouse
default_datastore: metadata
---

# Tech stack
