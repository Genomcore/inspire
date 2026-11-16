---
kind: bootstrap-stack
profiles: [nestjs, postgres, clickhouse]
datastores:
  metadata: postgres
  analytics: clickhouse
default_datastore: metadata
---

# Tech stack
