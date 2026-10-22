---
id: RB-04
title: Laravel application failures
type: runbook
domain: application
priority: P0
mode: read-only
status: active
owner: platform
updated: 2026-10-22
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
"$RB"/laravel/error-summary.sh "$LARAVEL_LOG" 20
"$RB"/apache/error-log-summary.sh /var/log/apache2/error.log   # memory exhaustion grouped by source location
sudo grep -c "Allowed memory size" /var/log/apache2/error.log
```

### Decision

| Result                             | Next                                         |
| ---------------------------------- | -------------------------------------------- |
| Memory exhaustion errors           | [RB-04/APP-02](#app-02)                      |
| Other exceptions dominate          | [RB-04/APP-02](#app-02)                      |
| No exceptions but failures persist | [RB-03/CAP-04](03-apache-capacity.md#cap-04) |

**Evidence to record:** Exception counts by class and message prefix, first and last occurrence.

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
grep -n "ERROR" "$LARAVEL_LOG" | tail -n 20
# Show a stack trace around a line number from above:
sed -n '<N>,<N+25>p' "$LARAVEL_LOG"
```

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
