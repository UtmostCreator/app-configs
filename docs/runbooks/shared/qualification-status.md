---
id: RB-SHARED-QUALIFICATION
title: Investigation correction and operational qualification status
type: reference
domain: validation
status: active
owner: platform
updated: undated
---

# Investigation correction and operational qualification status

> [Review evidence](technical-review-status.md) · [Recovery measurement contract](recovery-evidence.md#recovery-measurement-matrix) · [Validation](../response/11-validation-review.md)

Repository corrections and local fixtures do not qualify a deployment. This register separates implemented procedures from evidence that an operator must still collect. No production requests, service reloads, stress experiments or representative export validation were performed as part of these corrections. Reconcile this register with the local test output before recording a local acceptance result; a listed procedure is not evidence that it ran.

| Review item | Repository work / local evidence | Operational evidence still required |
| --- | --- | --- |
| P0-01 Reviewed active requests | Intake defaults to existing monitoring; probes require endpoint review and bounded timeouts; applicability gates cover validation | Confirm deployed endpoint side effects, approved budget and actual curl exit/status semantics; unavailable endpoint stays unavailable |
| P0-02 End-to-end recovery | Recovery matrix and VAL-01/VAL-05 require bounded comparable windows, coverage and unknown-result handling | Complete baseline/post-change matrix using real sources; follow the acceptance checklist below |
| P0-03 Isolated multi-instance single-flight | Separate origin-ledger contract and offline verifier; synthetic 100-caller/two-instance positive and negative cases in `test_single_flight_origin.py` | Real barrier/latch harness, complete independent origin ledger and bounded lock-owner failure experiment; follow checklist below |
| P0-04 Staging rollback rehearsal | Scoped rollback procedure and local filesystem checks; these do not reload Apache | Representative staged configtest, metadata comparisons, reload, effective configuration and recovery observations |
| P1-01 Traffic URL normalisation | Traffic adapter extracts/redacts route evidence and rejects invalid inputs; adapter fixtures | Representative sanitised Netlify traffic exports and route/redaction review |
| P1-02 Attempt reconciliation | Unknown application/origin events, retries, incomplete closure, wrong IDs/values and ledger count mismatches cannot pass offline verification | Independently audited exporter completeness and admission/drain evidence |
| P1-03 Incident-specific regressions | VAL-02 records applicable/not-applicable/unresolved with rationale; local documentation assertion | Operator selects relevant tests against actual incident and change scope |
| P1-04 Netlify identity/schema | Explicit duration units and invocation identity; legacy function-type uncertainty retained; schema fixtures | Real export version, duration units, sampling/retention and independently validated invocation identity |
| P1-05 Rollback scope and drift | Scoped manifests and drift checks replace broad configuration-tree restoration | Confirm authorised paths, concurrent writers, metadata support and service-specific rollback boundary |
| P1-06 Apache/PHP compatibility | Existing format, effective SAPI and unknown worker-capacity gates | Deployed LogFormat, PHP SAPI/configuration, worker limits and propagated application/edge IDs |
| P2-01 Anonymisation coverage | Extend lightweight lint to executable and fixture/configuration formats; synthetic token cases | Review real evidence before sharing; pattern lint does not establish absence of secrets |
| P2-02 Incident windows | Historical diagnostics use recorded bounds; VAL-01 no longer supplies stale dates | Verify each real source's timezone, clock uncertainty, retention and coverage |
| P2-03 Bootstrap prerequisites | Intake/evidence bootstrap can establish provisional bounds without requiring completed attribution | Operator walkthrough from an incomplete incident report |
| P2-04 Aggregation limits | Single-flight files capped at 16 MiB/100,000 records each; log helpers enforce decompressed-byte, line, record, key and duration limits with negative fixtures | Representative input sizes and observed resource use; do not truncate required evidence to fit |
| P2-05 Negative cases | Local fixtures cover partial callers, extra attempts, missing telemetry/schema fields, unknown types and mismatched correlation | Sanitised representative failures and deployment-specific missing-source cases |
| P3-01 Shared wording | Shared contracts retain evidence/decision rules | Optional operator feedback on navigation; no readiness claim |
| P3-02 Command examples | Recorded window variables replace recovery dates; explicit placeholders remain | Walkthrough using the actual shell, service paths and permissions |
| P3-03 Incident examples | Existing diagnostic routes remain canonical | Optional anonymised Apache OOM, Netlify timeout and stampede walkthroughs after evidence is available |

## Recovery qualification acceptance record

For P0-02, retain a completed matrix rather than a healthy snapshot:

1. Record separate baseline and post-change UTC start/end bounds, the change time, deployed revision and source clocks. Post-change samples must actually belong to the current change's observation interval; an old example interval cannot qualify.
2. Agree comparable interval lengths and traffic cohorts. Record any exceptions, traffic mix changes, source sampling, clock uncertainty and retention gaps. Include failures before the origin where applicable.
3. For every critical signal retain the raw source reference, aggregation command/units, numerator/denominator, complete interval coverage, threshold and pass/fail/unknown result. A missing latency field, partial rotation set or unavailable historical metrics remains unknown.
4. Check both bounds against each source's actual coverage. A current memory snapshot cannot fill an earlier interval. A sample spanning only part of the post-change window cannot establish recovery for the whole window.
5. Record observation long enough for relevant timeout, telemetry delay and recurrence. Any unsupported critical signal prevents a fully verified result. Explicit incident-owner risk acceptance may support a **qualified decision**, with owner, gaps, compensating evidence and follow-up; it does not change unknown measurements to pass.

Wrong-window and incomplete-window operational cases remain unqualified until this record is completed with representative source evidence. Local parser/window fixtures exercise selection and failure handling; they do not implement a universal recovery-decision engine.

## Staging concurrency qualification acceptance record

For P0-03, use the [single-flight protocol](single-flight-validation.md). Preserve deployed revision, cache/lock configuration, two independent instance identities, effective-key hash, namespace isolation, all 100 cold misses before origin release, response-value assertions, independent unsampled origin attempts including retries, and admission/drain closure evidence. The successful cold-key run must record exactly one origin attempt and one publication. Offline verifier PASS applies only to the supplied cold-run ledger.

Run warm reads, scoped invalidation, failure/expiry and **lock-owner death** separately. For owner death, record the killed owner, TTL/deadline, follower progress, generation/fencing behaviour, absence of stale overwrite, permitted duplicate-work policy and cleanup. A normal cold-key PASS cannot qualify owner-death recovery or prove cross-instance locking by itself.

## Staging rollback qualification acceptance record

For P0-04/P1-05, record the authorised files and required bytes, ownership, modes, symlinks, ACLs and extended attributes before the change. Demonstrate local filesystem support; unsupported required metadata blocks qualification. Preserve the post-change expected manifest so unrelated drift blocks restoration. Restore only the authorised scope, compare required metadata and bytes, validate Apache configuration, reload successfully, and verify the effective service configuration and reviewed health evidence. Compare out-of-scope state before and after. Temporary-directory restoration is local filesystem evidence only; service reload and effective configuration remain pending until rehearsed on a representative deployment.
