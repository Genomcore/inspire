---
kind: bootstrap-stack
profiles: [nestjs, postgres, clickhouse]
datastores:
  metadata: postgres
  analytics: clickhouse
default_datastore: warehouse
---

# Tech stack
