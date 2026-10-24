---
id: RB-SHARED-SINGLE-FLIGHT
title: Isolated single-flight and cache regression validation
type: reference
domain: validation
status: active
owner: platform
updated: undated
---

# Isolated single-flight and cache regression validation

> [Validation](../response/11-validation-review.md#val-02) · [Correlation contract](recovery-evidence.md#request-correlation)

This is an active experiment in an isolated staging deployment with synthetic data and a mock upstream. It is not a production diagnostic command. The application-specific harness must supply instrumentation and controlled concurrency; a generic `xargs curl` loop cannot establish overlap, key identity, shared locks or actual upstream work.

## Required experiment

1. Pin the deployed revision, cache driver, lock configuration and at least two independently identified application instances. Verify that a shared cache/lock is actually used across these instances. Create a unique test namespace and effective key hash so no other traffic or old value can satisfy this run. Record a unique run ID. Verify the key is absent in this namespace without flushing a shared database.
2. Configure the synthetic upstream to count every received attempt independently of application logs. Hold its first response behind a test-controlled latch. All upstream attempts, including retries, must be recorded; do not sample. Set the test lock TTL above this bounded hold period and verify this precondition. Use a bounded deadline and release the latch in harness cleanup on any failure.
3. Start 100 callers behind a barrier and route them across at least two known application instances. Each must perform a lookup of the same effective key and emit `cache_miss` **before acquiring the rebuild lock**. Release the upstream response only after all 100 distinct request IDs have reported the cold lookup; otherwise record the run as inconclusive. Keep the hold shorter than lock/client timeouts. This deliberately measures contention rather than a sequence of warm hits.
4. Assert exactly one independently observed upstream attempt for this key and generation; one successful completion and cache publication; all 100 callers receive the expected synthetic value; and no caller times out. Reconcile the mock's attempt ledger with application events. Verify the warm key subsequently returns the same value from both instances without another upstream attempt. Confirm no CDN/outer cache bypassed the application layer under test.
5. Stop new admission for the test namespace after all callers finish, drain origin work and retries, and close the mock-origin ledger. Export separate complete, sanitised application and mock-origin JSONL files for the isolated run. Validate it offline with the command below. Preserve the revision, driver, instance IDs, latch/barrier evidence, mock ledger reconciliation, clocks, and cleanup result with the report. Unknown completeness, clock skew beyond ordering precision, or missing upstream instrumentation means unresolved, even if HTTP responses succeed.

```bash
python3 docs/runbooks/shared/commands/verify-single-flight.py cold-key-events.jsonl \
  --origin-ledger mock-origin-events.jsonl \
  --run-id synthetic-run --key-hash synthetic-key --requests 100
```

## Export contract

Every record has `run_id`, `key_hash`, `event` and an offset-bearing ISO `utc` timestamp from synchronised test clocks. The application export accepts only the following event types; unknown types, including `upstream_retry`, make verification unresolved. The verifier expects these additional fields:

| Event | Required fields / count |
| --- | --- |
| `cache_miss` | One per caller: unique `request_id`, `instance_id`; all before upstream completion |
| `upstream_start` | Exactly one: `fetch_id` from the upstream ledger |
| `upstream_finish` | Exactly one: matching `fetch_id`, `ok: true`, `value_hash` |
| `cache_write` | Exactly one after upstream completion: matching `value_hash` |
| `client_result` | One per caller after publication: matching `request_id`, `ok: true`, matching `value_hash` |

The **separate mock-origin export**, emitted by the controlled upstream rather than derived from application logs, uses these records. All carry `source: "mock-origin"`, the same `run_id` and `key_hash`, and offset-bearing `utc` timestamps:

| Event | Required fields / count |
| --- | --- |
| `origin_attempt` | One per received attempt including failed attempts and retries: unique `fetch_id`, receive `utc`, `finished_utc`, `ok`, `value_hash` |
| `origin_ledger_complete` | Exactly one, after all callers finish, admission stops and outstanding origin work drains: `complete: true`, integer `attempt_count` covering every received attempt |

Every attempt must be recorded at receipt and retained even if it never completes; an incomplete attempt cannot qualify for success. The closure count must equal the exported attempt count. Exactly one successful attempt must match the application's fetch ID, value and enclosing interval. Unknown origin event types are unresolved. Exporting only the first attempt, filtering out failed attempts or using application logs to manufacture this ledger invalidates the experiment. Keep exporter implementation/revision and admission/drain evidence with the artifacts; a self-reported closure flag alone cannot establish operational completeness.

Use timestamp precision sufficient to establish this order. The offline verifier checks the ledger's assertions; it cannot prove that instrumentation is truthful or complete. Cross-instance warm reads, invalidation, expiry and failure tests below are separate required observations.

Both input files are capped at 16 MiB and 100,000 nonblank records each before verification. Exceeding either limit fails explicitly; do not truncate or sample to fit. Export only the isolated namespace, or review a purpose-built verifier for a larger experiment. This bounds file input and record count, not Python process memory to 16 MiB.

## Additional regression cases

| Case | Required result |
| --- | --- |
| Warm read on both instances, then scoped invalidation | Both instances see the current generation; both observe invalidation; no unrelated key is removed |
| Upstream failure, including GraphQL HTTP 200 with `errors` | Errors are returned/recorded; failed or empty fallback data is not cached as success; retries are bounded |
| Lock holder dies or lock expires | Recovery occurs within the documented bound; stale owner cannot overwrite a newer generation; policy explicitly bounds duplicate work |
| Entry and revision events for one logical publish | Scoped/coalesced invalidation, no repeated whole-site purge |
| Missing/empty credential; old query-string credential | Rejected under the deployed authentication contract without logging secret values |
| Redirects, navigation, URL maps and legacy assets | Correct payloads/routing; backend work within the agreed budget |

Do not assume one fetch across all instances if the design only provides per-instance single-flight. Record the supported scope and treat a requirement for global coordination as failed until the implementation and multi-instance test demonstrate it.
