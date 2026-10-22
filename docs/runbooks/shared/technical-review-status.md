---
id: RB-SHARED-REVIEW-STATUS
title: Technical review corrections and acceptance evidence
type: reference
domain: maintenance
status: active
owner: platform
updated: 2026-10-22
---

# Technical review corrections and acceptance evidence

> [Runbook index](../README.md) · [Local test commands](commands/README.md#local-verification)

Keep RB-00–RB-11 and their specialist ownership. The review's qualitative scores are not recalculated from documentation changes or local fixture tests. Distinguish a corrected procedure from acceptance of the deployed service.

| Work item | Repository correction and local evidence | Deployment-specific acceptance still required |
| --- | --- | --- |
| T-01 Evidence and metric semantics | Offset-normalised access fixtures, summer/winter and DST checks, separate jq traffic/function adapters, failed-CLI tests and multi-row log fixture | Verify real export schema, source units, CLI/platform limits, retention and invocation identity |
| T-02 Approval and rollback | External routes enter planning/approval; each modifying stage repeats the gate; validator rejects bypass links; rsync inverse restores bytes, metadata and symlinks in temporary-directory tests | Named approval/operator/target, frozen change scope, staged configtest/reload and independently verified effective configuration |
| T-03 Recovery and concurrency | Measurement matrix, isolated 100-caller/two-instance protocol, offline ledger verifier rejects duplicate fetches, missing callers and wrong values | Run the application-specific barrier/latch harness, independent origin ledger, warm/invalidation tests, lock-owner failure and upstream-error cache tests |
| T-04 Apache/Linux/PHP coverage | Resource classification, historical metrics, PSS/cgroup/process limits and actual-SAPI guidance; no automatic safe RSS-based cap | Obtain representative busy-worker/pool metrics and effective runtime configuration; load-test any capacity proposal |
| T-05 Failure-aware helpers | Plain/gzip, malformed input, invalid filters, empty/missing files, command failures, IPv4/IPv6 and rotation fixtures | Validate real log-format compatibility and period completeness; check restricted journal access and retention |
| T-06 Maintenance | Shared outcome contract; step objective/decision/evidence assertions; cached anchor validation; reading index links canonical files | Rehearse operational routes with responders and confirm service-specific thresholds/ownership |

## Test boundaries

All automated checks here use local files, synthetic ledgers, jq adapters or mocked commands. The rollback fixture executes the documented filesystem inverse only inside a temporary directory, including equal-size/equal-mtime content changes; it does not reload a service. The single-flight verifier validates a supplied ledger, not the cache implementation. It cannot prove unsampled instrumentation or actual cross-instance coordination. Approval-navigation checks enforce documentation structure, not runtime access control.

The existing shell command entry points are retained. The shared log parser introduced in the earlier correction centralises demonstrated timestamp, quoting and failure-handling defects; it is not a general log-processing framework. Use bounded evidence extracts: counters scale with distinct keys and latency quantiles retain selected samples in memory. Structured exception analysis should use the application's existing structured schema; the text helper remains explicitly approximate.
