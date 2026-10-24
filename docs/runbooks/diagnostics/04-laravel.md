---
id: RB-04
title: Laravel application failures
type: runbook
domain: application
priority: P0
mode: read-only
status: active
owner: platform
updated: undated
tags:
  [
    laravel,
    php,
    exceptions,
    graphql,
    memory,
    queries,
    stack-trace,
    swallowed-errors,
    cached-errors,
    structure,
    memory-limit,
  ]
symptoms:
  [
    Allowed memory size,
    500,
    GraphQL errors,
    slow API,
    stack trace,
    HTTP 200 with errors field,
    failures not logged,
  ]
steps: [APP-01, APP-02, APP-03, APP-04, APP-05]
related: [RB-03, RB-06, RB-08, RB-10]
---

# RB-04 — Laravel application failures

> [Runbook index](../README.md) · Priority P0 · Mode: read-only

Find and group Laravel, PHP and CMS exceptions, then investigate the expensive paths (GraphQL, navigation, structures, content APIs). Read-only.

## Variables

```bash
LARAVEL_LOG=/var/www/<app>/storage/logs/laravel.log
RB=docs/runbooks/shared/commands
```

All steps follow the [shared execution and evidence gates](../shared/recovery-evidence.md#execution-and-evidence-gates). Record unknown results and missing evidence once in the incident record; unknown evidence permits further diagnosis but never satisfies attribution, approval, recovery or closure.

## Steps

[APP-01](#app-01) · [APP-02](#app-02) · [APP-03](#app-03) · [APP-04](#app-04) · [APP-05](#app-05)

## APP-01

**Locate Laravel, PHP and CMS exceptions**

- **Objective:** Get an inventory of exception types and where memory is exhausted. Count only primary failures: errors raised while handling another fatal error are secondary.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# One run: fatal lines -> requests (PID + sub-second burst), first allocation sites, join to the access-log
# 5xx received 0-30 s earlier, templated routes, caller classes, hourly table and route status by day.
sudo python3 -I "$RB"/apache/fatal-correlate.py --error-offset +0000 \
  --error-log /var/log/apache2/error.log.1 \
  --access-log /var/log/apache2/access.log.2.gz --access-log /var/log/apache2/access.log.1
"$RB"/laravel/error-summary.sh "$LARAVEL_LOG" 20
```

Pick rotations from the bundle's log inventory ([fast path FP-1](../shared/fast-path.md#fp-1--one-paste-context-bundle)); add adjacent rotations to bound onset in the same run. Expected output and reading rules: [fast path](../shared/fast-path.md#memory-failures-correlate-fatal-bursts-with-access-failures). Under `mod_php`, memory fatals reach the Apache error log and the error tracker; whether the application log also records them depends on the release's error handling, so a zero count in `laravel.log` is a sink gap, not absence.

### Decision

| Result                             | Next                                         |
| ---------------------------------- | -------------------------------------------- |
| Memory exhaustion errors           | [RB-04/APP-02](#app-02)                      |
| Fatals join one route (`joined` ≈ `requests`) | [RB-04/APP-03](#app-03) with that route; skip window sampling |
| Many fatals unmatched              | Workload is not an Apache request (CLI, queue, other vhost) or coverage differs: [RB-01/EVD-03](../foundations/01-evidence-attribution.md#evd-03) |
| Other exceptions dominate          | [RB-04/APP-02](#app-02)                      |
| No exceptions but failures persist | [RB-03/CAP-04](03-apache-capacity.md#cap-04) |

**Evidence to record:** Exception counts by class and message prefix, first and last occurrence. If exception messages carry request payloads, personal data or tokens, record the group count only and escalate through [RB-07/SEC-01](07-traffic-security.md#sec-01); do not copy the values into notes or exports.

**Return:** [RB-03/CAP-05](03-apache-capacity.md#cap-05) or the calling runbook

### Identify the failing PHP runtime

Distinguish Apache-module requests, PHP-FPM pool requests, queue workers and scheduled CLI jobs using existing process/unit, route, stack and deployment evidence. Their memory limits, INI overrides, timeouts and restart lifecycles can differ. `php -i` and `php --ini` normally describe the CLI SAPI; they do not establish the effective Apache/FPM configuration.

Record the runtime's `PHP_SAPI`, PHP version, loaded/scanned INI files, effective `memory_limit`, pool/vhost/per-directory overrides and request/queue timeouts from **existing restricted runtime telemetry**, tied to a request/worker ID and deployed revision. Inspect corresponding pool/vhost artifacts as supporting evidence, not proof of loaded values. No effective telemetry means unknown; do not create a public `phpinfo()` page. Adding a diagnostic endpoint or booting a framework command goes through the execution/change gates. See [PHP configuration changes](https://www.php.net/manual/en/configuration.changes.php).

Correlate an exception header and multiline trace to its request/trace ID, worker PID, queue job ID or scheduled invocation. A worker can serve many requests; PID/time overlap alone is provisional. Classify secondary exception-handler failures separately. The text error helper uses approximate message-prefix grouping with digits normalised; it can merge distinct failures or split one exception family. Preserve a sanitised representative event and prefer structured exception class, route/operation and error code when those fields already exist.

## APP-02

**Group failures by request context, stack trace and component**

- **Objective:** Identify which component the failures cluster in. A memory error at a given line shows where the limit was hit, not that this line is the root cause: the request may already have accumulated hundreds of MB building collections, pages or structures.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Message signatures per hour (digits normalised) answer "what changed" in one pass:
for h in 00 01 02 03 04 05 06 07 08 09 10 11 12; do
  printf '== %s\n' "$h"
  grep -E "^\[<YYYY-MM-DD> $h:" "$LARAVEL_LOG" | grep -E '\.(ERROR|CRITICAL|ALERT|EMERGENCY):' |
    sed -E 's/^\[[^]]+\] [a-z]+\.[A-Z]+: //' | cut -c1-70 | sed -E 's/[0-9]+/N/g' | sort | uniq -c | sort -nr | head -n 5
done
# Show a stack trace around a line number from above:
sed -n '<N>,<N+25>p' "$LARAVEL_LOG"
```

Prefer the error tracker's stack, release and breadcrumbs for one representative event over reading raw traces on the server.

### Decision

| Result                                                              | Next                                              |
| ------------------------------------------------------------------- | ------------------------------------------------- |
| Failures cluster in GraphQL, navigation, structures or content APIs | [RB-04/APP-03](#app-03)                           |
| Failures cluster in an external call                                | [RB-08/DEP-02](08-service-dependencies.md#dep-02) |
| Failures cluster in cache code                                      | [RB-06/CCH-03](06-cache-invalidation.md#cch-03)   |

**Evidence to record:** Top components and representative stack trace (secrets removed).

**Return:** [RB-03/CAP-05](03-apache-capacity.md#cap-05) or the calling runbook

## APP-03

**Investigate GraphQL, navigation, augmentation, structures and content APIs**

- **Objective:** Find the expensive operations.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
grep -rn "graphql" /var/www/<app>/config | head
# Application debug or query logging must be enabled by an authorised change; do not enable it here.
"$RB"/apache/top-paths.sh /var/log/apache2/access.log 20 | grep -Ei "graphql|api|nav|structure"
```

### Decision

| Result                                                                                                           | Next                                                                                                                              |
| ---------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Navigation or structure traversal is expensive                                                                   | [RB-04/APP-04](#app-04)                                                                                                           |
| GraphQL repeatedly executes identical work                                                                       | [RB-06/CCH-05](06-cache-invalidation.md#cch-05)                                                                                   |
| Backend failures are swallowed or never logged (handler returns an error response without logging the exception) | Observability gap: record it; failures will look like slow requests. [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |
| GraphQL returns HTTP 200 with an `errors` field                                                                  | Treat as failure; check whether such responses are cached ([RB-06/CCH-04](06-cache-invalidation.md#cch-04))                       |
| Heavy work follows a scheduled cache clear                                                                       | [RB-06/CCH-01](06-cache-invalidation.md#cch-01)                                                                                   |
| Backend processing is normal                                                                                     | Return to [RB-03/CAP-05](03-apache-capacity.md#cap-05)                                                                            |
| A fix has been identified                                                                                        | [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01)                                                                      |

**Evidence to record:** Most expensive endpoints and whether work is repeated.

**Return:** [RB-03/CAP-05](03-apache-capacity.md#cap-05) or the calling runbook

## APP-04

**Identify expensive queries, synchronous dependencies and repeated work**

- **Objective:** Quantify repeated work per request.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Use existing observability (APM, slow-query log) rather than enabling new logging in production:
sudo grep -c "Query_time" /var/log/mysql/mysql-slow.log
sudo mysqldumpslow -s t -t 10 /var/log/mysql/mysql-slow.log
```

### Decision

| Result                                | Next                                                   |
| ------------------------------------- | ------------------------------------------------------ |
| N+1 or repeated identical computation | [RB-06/CCH-05](06-cache-invalidation.md#cch-05)        |
| Slow synchronous external dependency  | [RB-08/DEP-02](08-service-dependencies.md#dep-02)      |
| Nothing expensive found               | Return to [RB-03/CAP-05](03-apache-capacity.md#cap-05) |

**Evidence to record:** Top slow queries or repeated operations with counts.

### Reproduce one request locally

When one route owns the failures, reproduce a **single cold request** in an isolated working copy before any load test ([fast path FP-3](../shared/fast-path.md#fp-3--reproduce-one-request-then-stop)). Match the release's package versions (`vendor/composer/installed.json` on the release, `composer show <package>` locally), use disposable cache and data services, and send PHP errors to the terminal so the same run shows the fatal:

```bash
php -d memory_limit=512M -d log_errors=1 -d error_log=/dev/stderr -S 127.0.0.1:8010 -t public public/index.php
curl -sS -m 60 -o /dev/null -w 'http=%{http_code} duration=%{time_total}s bytes=%{size_download}\n' 'http://127.0.0.1:8010/<route>'
```

Add phase checkpoints (`memory_get_usage(true)`, `memory_get_peak_usage(true)`, elapsed) around the handler's stages, compare one warm request, and use a higher limit only to measure the peak. `php -S` serves one request at a time: do not point a concurrency tool at it.

**Return:** [RB-03/CAP-05](03-apache-capacity.md#cap-05) or the calling runbook

## APP-05

**Route caching, dependency and capacity findings**

- **Objective:** Hand off measured findings.
- **Mode:** Read-only
- **Preconditions:** Time window and sources validated ([RB-01](../foundations/01-evidence-attribution.md))

### Commands

```bash
# Decision step only.
```

### Decision

| Result                                 | Next                                                         |
| -------------------------------------- | ------------------------------------------------------------ |
| Caching problem                        | [RB-06/CCH-03](06-cache-invalidation.md#cch-03)              |
| External-service failure               | [RB-08/DEP-02](08-service-dependencies.md#dep-02)            |
| Measured findings explain capacity use | [RB-03/CAP-05](03-apache-capacity.md#cap-05)                 |
| Fix identified                         | [RB-10/MIT-01](../response/10-mitigation-recovery.md#mit-01) |

**Evidence to record:** Chosen route and measurements.

**Return:** [RB-03/CAP-05](03-apache-capacity.md#cap-05) or the calling runbook
