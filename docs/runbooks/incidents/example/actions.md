---
id: INC-EXAMPLE-MEMORY-ACTIONS
title: Fictional document export memory failure — Actions
type: incident-evidence
domain: incident-history
status: illustrative
owner: platform
updated: undated
tags: [fictional-example, actions, php-memory, export]
symptoms: [memory limit, server error, repeated route failures]
---

# Actions

> This is a fictional exercise. No production action is approved by this example.

| ID | State | Action | Owner | Acceptance |
| --- | --- | --- | --- | --- |
| ACT-001 | proposed | Change the isolated implementation to filter before materialising the full result set | `<owner>` | Synthetic test proves bounded memory across representative fixture sizes |
| ACT-002 | proposed | Add a request identifier shared by application and access logs | `<owner>` | A synthetic request can be joined without relying on a time window |
| ACT-003 | proposed | Measure queueing and resource use under a controlled, isolated workload | `<owner>` | Results include complete inputs, limits and cleanup evidence |

Production changes require the approval and rollback gates in [RB-10](../../response/10-mitigation-recovery.md#mit-02).
