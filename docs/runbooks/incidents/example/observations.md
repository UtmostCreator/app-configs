---
id: INC-EXAMPLE-MEMORY-OBSERVATIONS
title: Fictional document export memory failure — Observations
type: incident-evidence
domain: incident-history
status: illustrative
owner: platform
updated: undated
tags: [fictional-example, observations, php-memory, export]
symptoms: [memory limit, server error, repeated route failures]
---

# Observations

> This is a fictional exercise. Every route, count, relationship and outcome below is synthetic and is not production telemetry.

| ID | Evidence | Summary | Step | Confidence |
| --- | --- | --- | --- | --- |
| OBS-001 | Synthetic server error log | Two fatal records with the same process identifier occur within a short burst; treat them as one candidate request, while allowing for process ID reuse | [RB-04/APP-01](../../diagnostics/04-laravel.md#app-01) | illustrative |
| OBS-002 | Synthetic access log | Repeated failures map to the fictional `/example/export` route; the log has no shared request identifier | [RB-02/TRF-02](../../diagnostics/02-apache-traffic.md#trf-02) | illustrative |
| OBS-003 | Synthetic correlation output | Fatal bursts pair with nearby access failures, but the time-window join cannot prove request identity | [RB-02/TRF-05](../../diagnostics/02-apache-traffic.md#trf-05) | illustrative |
| OBS-004 | Fictional application source | The handler builds a broad result set before applying the requested scope, increasing peak memory | [RB-04/APP-03](../../diagnostics/04-laravel.md#app-03) | illustrative |
| OBS-005 | Isolated synthetic reproduction | A constrained cold run reaches the memory limit; reducing the fixture scope avoids it. No production data or service is used | [RB-04/APP-04](../../diagnostics/04-laravel.md#app-04) | illustrative |

## Limitations

The exercise does not establish a production cause, user impact, data exposure, capacity effect or mitigation. Its purpose is to demonstrate evidence grouping, route correlation, source inspection and bounded reproduction.
