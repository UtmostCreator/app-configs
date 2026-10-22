---
id: RB-06
title: Cache invalidation, stampedes and regeneration
type: runbook
domain: cache
priority: P0
mode: read-only
status: active
owner: platform
updated: 2026-10-22
tags: [cache, redis, stampede, invalidation, purge, cdn, graphql, cache-key, scheduler, flushdb, purge-storm, unique-job, debounce, single-flight, build-time-flag, cached-errors]
symptoms: [load after cache clear, repeated upstream fetches, stale content, purge had no effect, removed: [], many purges, outage right after nightly job]
steps: [CCH-01, CCH-02, CCH-03, CCH-04, CCH-05, CCH-06, CCH-07, CCH-08]
related: [RB-00, RB-07, RB-09, RB-10, RB-11]
---

# RB-06 — Cache invalidation, stampedes and regeneration

> [Runbook index](../README.md) · Priority P0 · Mode: read-only

Map every cache layer independently (application, Redis, CMS, SSR storage, CDN), find clears and invalidations, and test for stampedes and key-correctness problems. Read-only; changes belong to [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01).

## Variables

```bash
APP_DIR=/var/www/<app>
RB=docs/runbooks/shared/commands
```

All steps follow the [shared execution and evidence gates](../shared/recovery-evidence.md#execution-and-evidence-gates). Record unknown results and missing evidence once in the incident record; unknown evidence permits further diagnosis but never satisfies attribution, approval, recovery or closure.

## Steps

[CCH-01](#cch-01) · [CCH-02](#cch-02) · [CCH-03](#cch-03) · [CCH-04](#cch-04) · [CCH-05](#cch-05) · [CCH-06](#cch-06) · [CCH-07](#cch-07) · [CCH-08](#cch-08)

## CCH-01

**Identify scheduled and event-driven cache-clearing operations**

- **Objective:** Find everything that can empty a cache, and when, and what a clear actually removes.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Inspect definitions and existing scheduler logs without booting application providers:
cd "$APP_DIR"
# schedule:list requires an execution review first; run it in an isolated copy if needed.
grep -rnE "cache:clear|Cache::flush|->flush\(|stache:clear|static:clear" app routes bootstrap config | head -30
crontab -l; systemctl list-timers --all --no-pager | head -20
# Which store and Redis database do clears hit? (do not print passwords)
grep -nE "^(CACHE_STORE|CACHE_DRIVER|REDIS_CACHE_DB|REDIS_DB)=" "$APP_DIR/.env"
# Inspect this deployed store implementation; do not assume all stores/commands use FLUSHDB:
grep -n "function flush" -A6 "$APP_DIR/vendor/laravel/framework/src/Illuminate/Cache/RedisStore.php"
redis-cli -n <cache-db> dbsize
```

### Decision

| Result | Next |
| --- | --- |
| Unconditional flush on a Redis store (wipes the whole selected database, not just prefixed keys) | Everything cached there (navigation, content, API caches, possibly locks) rebuilds at once: [RB-06/CCH-05](#cch-05). Causation of an outage stays a hypothesis until [RB-11/VAL-02](../response/11-validation-review.md#val-02) |
| A clear precedes the incident window | [RB-06/CCH-03](#cch-03); record as a causal hypothesis, not a conclusion |
| Clears are event-driven (deploy, publish, webhook) | [RB-06/CCH-06](#cch-06) |
| No clears found | [RB-06/CCH-02](#cch-02) |

**Evidence to record:** Every clear with schedule or trigger, last run time, store and database it flushes, what else lives in that database.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

### Cache operation identity

Before assigning a blast radius to any clear, record the deployed Laravel/CMS version from the lockfile/artifact, concrete cache-store class, invoked command/method and its actual `flush()` implementation. Resolve the selected store, Redis connection alias and database from existing effective telemetry/config artifacts; `.env` names alone may differ from cached/runtime configuration. Record whether queues, sessions, locks or other applications share that database. Missing resolution means unknown blast radius.

[Laravel warns that cache flush ignores prefixes](https://laravel.com/docs/cache). Preserve that warning, but inspect the deployed version and store before equating a command to `FLUSHDB`. CMS file-cache clears, tagged operations, CDN purges, Redis cluster stores and frontend invalidation can have different effects. Map each operation separately; never use a production flush to discover its scope.

## CCH-02

**Map Redis, CMS, SSR storage and CDN caches independently**

- **Objective:** Know which cache each layer uses and whether any is shared. In serverless functions, default application storage is often instance-local, so an invalidation request reaches one instance only.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
redis-cli info keyspace
redis-cli --scan --pattern "<prefix>*" | head -20   # never KEYS * in production
grep -nE "CACHE_DRIVER|CACHE_STORE|REDIS_(HOST|PREFIX)" "$APP_DIR/.env" | sed -E 's/(PASSWORD=).*/\1<redacted>/'
```

### Decision

| Result | Next |
| --- | --- |
| Layers and sharing mapped | [RB-06/CCH-03](#cch-03) |
| Shared or unclear storage between instances | Record as unverified; do not conclude from an empty purge result alone ([RB-06/CCH-06](#cch-06)) |
| A feature flag decides whether caching is on | Check whether it is evaluated at build or at runtime: a runtime-only value may not change a build-time-evaluated config ([RB-09/CFG-03](09-deployment-drift.md#cfg-03)) |

**Evidence to record:** Table: layer, store, key prefix, shared (yes/no/unknown).

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## CCH-03

**Measure cache misses and duplicate upstream fetches**

- **Objective:** Quantify identical upstream requests in the same short interval.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Identical backend requests per minute (same path+query):
awk '{print substr($4,2,17), $7}' /var/log/apache2/access.log | sort | uniq -c | sort -nr | head -20
redis-cli info stats | grep -E "keyspace_(hits|misses)"
```

**Expected output:** Repeated paths identify a candidate workload, not identical operations or proven uncoordinated misses. Query text, variables, locale, auth scope and cache generation can differ. Redis hit/miss counters are cumulative: take two timestamped samples from the same instance and compare deltas, checking for resets. Prove duplicate upstream work using [request correlation](../shared/recovery-evidence.md#request-correlation) or the isolated [single-flight protocol](../shared/single-flight-validation.md). Raw query strings may contain secrets; keep this output restricted and redact before recording.

### Decision

| Result | Next |
| --- | --- |
| Identical requests repeat in bursts | [RB-06/CCH-05](#cch-05) |
| Miss ratio is high with distinct keys | [RB-06/CCH-04](#cch-04) |
| Misses are normal | [RB-06/CCH-06](#cch-06) |

**Evidence to record:** Duplicate-request counts, keyspace hits/misses.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## CCH-04

**Examine GraphQL, redirects and navigation cache-key correctness**

- **Objective:** Check whether keys include everything that changes the response and nothing that varies needlessly, whether invalidation keys match stored keys, and whether error results are cached.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
grep -rnE "Cache::(remember|rememberForever|get|put)\(" app | head -40
# Look for keys built from request-unique values (timestamps, random ids, full query strings).
# Compare the prefix the invalidator computes with the prefix the store uses (read both implementations).
# Look for caching of failed results: a catch that returns an empty list/object and is then stored for the full TTL.
grep -rnE "catch\(\(\) => \[\]\)|\.catch\(" server | head -20
```

### Decision

| Result | Next |
| --- | --- |
| Keys vary unnecessarily (low hit rate) | [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |
| Keys omit a varying input (wrong content) | [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |
| Invalidator and store disagree on key prefix | Invalidation can never match: [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |
| A failed upstream call returns an empty value that is then cached | Errors are cached for the TTL (for example an empty redirects list for an hour): [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |
| A 200 response containing an `errors` field is cached | Cache poisoning risk: [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |
| Keys look correct | [RB-06/CCH-05](#cch-05) |

**Evidence to record:** Cache call sites with key construction reviewed.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## CCH-05

**Investigate stampedes and concurrency coordination**

- **Objective:** Check whether simultaneous misses all recompute or fetch.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
grep -rnE "Cache::lock|atomic|remember\(" app | head -30
# No lock around a cache-aside regeneration means every concurrent miss recomputes.
```

### Decision

| Result | Next |
| --- | --- |
| Cache-aside without coordination on hot keys | Likely amplification mechanism (not proof of the initial trigger): [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01), then [RB-11/VAL-02](../response/11-validation-review.md#val-02) |
| Coordination present | [RB-06/CCH-06](#cch-06) |
| Cannot tell without load testing | [RB-11/VAL-02](../response/11-validation-review.md#val-02) in a non-production environment |

**Evidence to record:** Hot keys, presence or absence of locks/single-flight, concurrency evidence.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## CCH-06

**Verify invalidation coverage, job deduplication and purge responses**

- **Objective:** Confirm that invalidations reach every layer.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Inspect purge responses in application logs (do not print tokens):
grep -E "purge|invalidate|removed" "$APP_DIR/storage/logs/laravel.log" | cut -c1-160 | tail -n 20
# Which queued jobs implement the purge, and what uniqueness do they use?
grep -rnE "ShouldBeUnique(UntilProcessing)?|uniqueFor|DEBOUNCE" app/Jobs | head
```

**Expected output:** A response like `removed: []` only means no matching keys were visible to the handling instance; it does not prove storage is unshared. A job logging "cleared" after an HTTP 200 does not prove anything was removed. `ShouldBeUniqueUntilProcessing` drops its lock when processing starts: it de-duplicates while a job waits (leading edge) but does not enforce a minimum interval between purges.

### Decision

| Result | Next |
| --- | --- |
| Invalidation misses a layer | [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |
| Several events (entry saved, revision saved, navigation saved) each dispatch a whole-site purge | Purge fan-out: [RB-06/CCH-07](#cch-07) |
| Success is logged without checking that anything was removed | Misleading logs: [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |
| Credential used for invalidation is exposed or sent in the URL | [RB-07/SEC-01](07-traffic-security.md#sec-01) |
| Covered and deduplicated | [RB-06/CCH-08](#cch-08) |

**Evidence to record:** Per-layer invalidation result and whether it was verified independently.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## CCH-07

**Count purge storms and correlate with editorial activity and load**

- **Objective:** Decide whether repeated whole-site purges kept load elevated after onset.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Purges per hour/minute from the application log:
grep -E "purge" "$APP_DIR/storage/logs/laravel.log" | cut -c2-17 | uniq -c | tail -n 40
# Editorial saves in the access log at the same times (admin/CMS write routes):
grep -E "POST .*/(cp|api)/" /var/log/apache2/access.log | awk '{print substr($4,2,17)}' | uniq -c | tail -n 40
# Backend request rate afterwards:
"$RB"/apache/request-rate.sh /var/log/apache2/access.log | tail -n 60
```

**Expected output:** The first purge of the day after onset means purges did not start the surge, but a run of purges each followed by a request climb means they re-fuelled it.

### Decision

| Result | Next |
| --- | --- |
| First purge is after onset but purges track the load climb | Amplifier, not trigger: [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) (coalesce, minimum interval, targeted purge) |
| Purges precede onset | Candidate trigger: [RB-09/CFG-04](09-deployment-drift.md#cfg-04) |
| No purge pattern | [RB-06/CCH-08](#cch-08) |

**Evidence to record:** Purge timestamps, editorial saves in the same minutes, backend request-rate curve.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)

## CCH-08

**Route fixes and tests**

- **Objective:** Hand off the fix design and its tests.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Decision step only.
```

### Decision

| Result | Next |
| --- | --- |
| Fix identified | [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |
| Concurrency or invalidation tests needed | [RB-11/VAL-02](../response/11-validation-review.md#val-02) |
| Nothing further | [RB-00/INC-05](../00-incident-intake.md#inc-05) |

**Evidence to record:** Chosen route.

**Return:** [RB-00/INC-04](../00-incident-intake.md#inc-04)
