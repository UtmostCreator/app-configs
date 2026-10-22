---
id: RB-SHARED-RECOVERY
title: Execution boundaries and recovery evidence
type: reference
domain: validation
status: active
owner: platform
updated: 2026-10-22
---

# Execution boundaries and recovery evidence

> [Runbook index](../README.md) · [Validation](../response/11-validation-review.md) · [Evidence schema](evidence-schema.md)

## Execution and evidence gates

The default diagnostic mode means passive inspection of existing files, journals, metrics and remote read APIs. Saving restricted evidence locally is allowed. An HTTP GET/HEAD can warm caches, trigger SSR, start sessions, or invoke application hooks; its method does not prove it is harmless. Use only a reviewed, bounded health endpoint for an active probe. Record the endpoint, time, timeout and side effects. Application boots (`php artisan`, framework scripts), debugger attachment, new tracing and expensive scans require an execution review. Use an isolated copy where practical; production changes go through [RB-10](../response/10-mitigation-recovery.md).

Do not fetch Git objects into a production checkout during passive inspection. Do not dump all configuration or environment values to obtain a few flags. Use existing deployed artifacts and allowlisted telemetry. `config:show` and scheduler listing boot application code; providers and hooks may perform work. See the [Laravel lifecycle](https://laravel.com/docs/13.x/lifecycle).

At every handoff, record the evidence IDs, scope, coverage, conclusion and next question. `unknown` may move to more diagnosis; it cannot become `pass`. If evidence is unavailable, record the blocked criterion and an owner for the gap. Approval requires recorded authorisation; recovery requires the measurement matrix below. A hypothesis can remain open after recovery, but missing critical recovery measurements cannot be silently waived. An incident owner may record a risk acceptance with compensating evidence and follow-up; that is a qualified recovery decision, not proof the missing signal is healthy.

### Unknown-result outcomes

| Outcome | When to use it | Required action |
| --- | --- | --- |
| `Continue` | Independent evidence supports the next diagnostic step | Preserve limitations; do not add unsupported attribution |
| `Investigate` | A useful measurement is missing | Collect it or use an independent source; missing kernel logs leave OOM unverified |
| `Block` | Production target, authority, rollback, or a required acceptance measurement is unverified | Stop that change/conclusion; a missing upstream count cannot pass single-flight validation |
| `Escalate` | Required evidence or authority cannot be obtained | Assign the gap to the incident owner with impact and options |

Missing user-agent data does not block other diagnosis. Unknown approval or production target always blocks production commands. A qualified incident-owner recovery decision remains explicitly qualified; it cannot certify missing metrics or override the production-authorisation gates.

## Recovery measurement matrix

Before validation, agree on equal baseline and post-change intervals, their UTC bounds, deployment IDs, traffic comparability, acceptance targets, observation duration, and rollback triggers. Use service-specific targets in [thresholds](thresholds.md), not the example values by default. Observe for at least the relevant request timeout, telemetry delay and expected recurrence period; a nightly-job incident needs coverage of that job or an explicitly recorded limitation.

| Required signal | Measurement source / procedure | Acceptance evidence |
| --- | --- | --- |
| Traffic and response error share | Access helpers on the same explicit `START_UTC`/`END_UTC` window; include edge failures before Apache | Total count, denominator, status mix, comparable traffic and complete coverage |
| Latency and timeouts | Existing unfiltered edge/APM request metrics, or `latency-summary.sh` on a verified `duration_us=%D` suffix | p50/p95/p99, sample counts, units, timeout count/share and threshold result; no averaging host percentiles |
| Application success | Existing application/GraphQL error telemetry and representative successful journey evidence | Application-level failures included even for HTTP 200; evidence that required content is correct |
| Worker/pool saturation | Existing interval metrics for BusyWorkers/IdleWorkers and effective cap, plus PHP-FPM queue when used | Sustained headroom, bounded queue and no new worker-limit errors |
| Memory / CPU pressure | Historical interval metrics and kernel/cgroup OOM counters/events, plus current snapshot for ongoing incidents | Available memory, applicable limits, swap/reclaim activity, CPU/run queue, no new OOM in the interval |
| Cache/dependency behaviour | Existing hit/miss and retry counter deltas, parent-linked upstream spans; isolated regression results where relevant | Bounded misses, retries and upstream calls per render; [single-flight test](single-flight-validation.md) passes where required |
| External customer impact | Existing external monitors and critical journey evidence | Customer-visible error/timeout and journey criteria met for the agreed interval |

Example offline access measurements (explicit input file, no application requests):

```bash
RB=docs/runbooks/shared/commands
APACHE_LOG=/var/log/apache2/access.log
export START_UTC=2026-10-13T08:20:00Z END_UTC=2026-10-13T08:25:00Z
"$RB"/apache/request-rate.sh "$APACHE_LOG"
"$RB"/apache/status-distribution.sh "$APACHE_LOG"
# Only if this verified format already contains duration_us=%D:
"$RB"/apache/latency-summary.sh "$APACHE_LOG"
```

The latency helper returns an error if a selected record lacks that duration field. Use APM/edge evidence instead when logging lacks it; missing latency is `unknown`. Empty or malformed inputs cannot establish health. The CLI log count helper counts application log records, not requests or invocations. Use platform invocation metrics or distinct verified invocation IDs for those denominators.

Record one row per signal: baseline value, after value, threshold, source/command, event interval, collection time, coverage, and `pass | fail | unknown`. [VAL-05](../response/11-validation-review.md#val-05) accepts only supported passes or an explicit qualified decision by the incident owner. Do not infer readiness scores from these local checks; production acceptance still requires deployed-service evidence.

## Request correlation

Prefer existing OpenTelemetry instrumentation using [W3C Trace Context](https://www.w3.org/TR/trace-context/) (`traceparent`/`tracestate`) and parent span relationships from browser/edge to SSR to backend. Validate inbound context at trust boundaries and generate server-side context when invalid or outside policy. Do not treat trace headers as authentication. If tracing is unavailable, keep aggregate correlation explicitly provisional; installing a tracing platform is not a prerequisite for using these runbooks. Log a distinct attempt ID for each retry and an invocation/instance ID for serverless execution. Propagate context only across trusted boundaries; a caller-controlled header or user agent is not authentication. Separate tracing identity from independently authenticated service identity.

For cache analysis, record a hash of the effective key including namespace, operation, variables, locale, tenant/auth scope and generation; never raw tokens, bodies or sensitive key material. Count upstream attempts by parent render/operation and this key hash. Record cache hit/miss, lock leader/follower, upstream start/end, value hash and error outcome. Timestamp overlap and matching counts nominate a hypothesis; they do not prove parentage or request amplification. Missing propagation or sampled traces leave exact fan-out unknown.

## Proposed Apache observability change

Standard combined logs have no duration or reliable cross-layer trace relationship. Propose an appended suffix to the existing format so existing fields retain their positions:

```apache
# Proposal only: merge into the site's existing LogFormat through RB-10.
# Append these fields; do not paste this comment as a complete LogFormat:
# duration_us=%D request_id=%L end_epoch_us=%{end:usec}t peer=%{c}a
```

Keep the existing `%t` as receipt time and `%>s` as final status. `%L` links to an error-log request ID when present; it may be `-` and is not a distributed trace ID. Verify compatible `ErrorLogFormat` and application propagation separately. Keep trusted client and peer addresses distinct, review query-string privacy, verify parser compatibility, test `configtest` and representative requests in staging, and prepare rollback/retention controls before production. Field meanings are defined in [Apache mod_log_config](https://httpd.apache.org/docs/2.4/mod/mod_log_config.html) and [ErrorLogFormat](https://httpd.apache.org/docs/2.4/mod/core.html#errorlogformat).
