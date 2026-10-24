---
id: RB-SHARED-REVIEW-STATUS
title: Technical review corrections and acceptance evidence
type: reference
domain: maintenance
status: active
owner: platform
updated: undated
---

# Technical review corrections and acceptance evidence

> [Runbook index](../README.md) · [Local test commands](commands/README.md#local-verification)

Track the later defect corrections and outstanding staging evidence in the [qualification register](qualification-status.md).

Keep RB-00–RB-11 and their specialist ownership. The review's qualitative scores are not recalculated from documentation changes or local fixture tests. Distinguish a corrected procedure from acceptance of the deployed service.

| Work item | Repository correction and local evidence | Deployment-specific acceptance still required |
| --- | --- | --- |
| T-01 Evidence and metric semantics | Offset-normalised access fixtures, summer/winter and DST checks, separate jq traffic/function adapters, failed-CLI tests and multi-row log fixture | Verify real export schema, source units, CLI/platform limits, retention and invocation identity |
| T-02 Approval and rollback | External routes enter planning/approval; each modifying stage repeats the gate; validator rejects bypass links; scoped rollback helpers and temporary-directory tests cover filesystem restoration; required metadata and service acceptance remain explicit | Named approval/operator/target, frozen change scope, staged configtest/reload and independently verified effective configuration |
| T-03 Recovery and concurrency | Measurement matrix, isolated 100-caller/two-instance protocol, offline ledger verifier rejects duplicate fetches, missing callers and wrong values | Run the application-specific barrier/latch harness, independent origin ledger, warm/invalidation tests, lock-owner failure and upstream-error cache tests |
| T-04 Apache/Linux/PHP coverage | Resource classification, historical metrics, PSS/cgroup/process limits and actual-SAPI guidance; no automatic safe RSS-based cap | Obtain representative busy-worker/pool metrics and effective runtime configuration; load-test any capacity proposal |
| T-05 Failure-aware helpers | Plain/gzip, malformed input, invalid filters, empty/missing files, command failures, IPv4/IPv6 and rotation fixtures | Validate real log-format compatibility and period completeness; check restricted journal access and retention |
| T-06 Maintenance | Shared outcome contract; step objective/decision/evidence assertions; cached anchor validation; reading index links canonical files | Rehearse operational routes with responders and confirm service-specific thresholds/ownership |

## Test boundaries

All automated checks here use local files, synthetic ledgers, jq adapters or mocked commands. The rollback fixture executes the documented filesystem inverse only inside a temporary directory, including equal-size/equal-mtime content changes; it does not reload a service. The single-flight verifier validates a supplied ledger, not the cache implementation. It cannot prove unsampled instrumentation or actual cross-instance coordination. Approval-navigation checks enforce documentation structure, not runtime access control.

The existing shell command entry points are retained. The shared log parser introduced in the earlier correction centralises demonstrated timestamp, quoting and failure-handling defects; it is not a general log-processing framework. Use bounded evidence extracts: counters scale with distinct keys and latency quantiles retain selected samples in memory. Structured exception analysis should use the application's existing structured schema; the text helper remains explicitly approximate.

## Local correction verification

The runnable runbook and project-health fixture suites passed, with one optional POSIX ACL round-trip skipped because the workspace filesystem rejected it. File bytes, mode, numeric ownership, symlink targets, modification time and user extended-attribute restoration passed. Bash syntax, Markdown links/frontmatter, privacy lint and `git diff --check` passed in the stated scope.

The untracked `investigation-v1.md` was a raw embedded-file bundle, not a canonical runbook. It has been replaced by a neutral pointer to the reviewed source files. Direct discovery over that bundle is unsupported; link validation applies to canonical runbook files only.

Reproduce the isolated runbook checks without modifying the original bundle:

```bash
set -euo pipefail
REVIEW_STAGE=$(mktemp -d)
tar -C docs --exclude='runbooks/investigation-v1.md' --exclude='__pycache__' \
  -cf - runbooks projects | tar -C "$REVIEW_STAGE" -xf -
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s "$REVIEW_STAGE/runbooks/shared/commands/tests" -v
bash "$REVIEW_STAGE/runbooks/shared/commands/validate-runbook-links.sh"
bash "$REVIEW_STAGE/runbooks/shared/commands/check-anonymized.sh"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover \
  -s ops/projects/health -p 'test_health.py' -v
git diff --check
```

The new capture-limit/privacy tests were also run against temporary copies of their original `HEAD` implementations: they failed before correction and pass after correction. Netlify URL/type regressions likewise failed against the original adapters. All service, journal and HTTP failure tests use mocks or files; no production health probe, installation, service reload or multi-instance staging experiment was performed.
