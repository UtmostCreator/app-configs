# Adapter Drift Capability

Use this capability when adapter surfaces may diverge from canonical docs.

Primary check:

```bash
php tools/ai/validate-adapter-drift.php
```

Focus:

- canonical doc references present
- adapters remain thin and non-contradictory
- non-agnostic terms are flagged
