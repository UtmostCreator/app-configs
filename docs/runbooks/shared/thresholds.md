---
id: RB-SHARED-THRESHOLDS
title: Thresholds and acceptance criteria
type: reference
domain: validation
status: template
owner: platform
updated: 2026-10-21
tags: [thresholds, baseline, acceptance, latency, error-rate, memory]
symptoms: [what is normal, is it recovered]
---

# Thresholds

> [Runbook index](../README.md) · Used by [RB-02/TRF-01](../diagnostics/02-apache-traffic.md#trf-01) and [RB-11/VAL-05](../response/11-validation-review.md#val-05)

Starting values only. Replace them with measured baselines for your service and record the date they were measured.

| Signal | Healthy | Investigate | Incident |
| --- | --- | --- | --- |
| 5xx share of responses | < 0.1% | 0.1% – 1% | > 1% |
| 504 count per 5 min (SSR) | 0 | 1 – 10 | > 10 |
| Requests per minute vs baseline | within 2x | 2x – 5x | > 5x |
| p95 response time | < 1 s | 1 – 3 s | > 3 s |
| Available memory | > 25% | 10 – 25% | < 10% or any kernel OOM |
| Swap in use | ~0 | growing | heavy swapping |
| Apache busy workers vs `MaxRequestWorkers` | < 60% | 60 – 90% | `AH00161` logged |
| Load average per core | < 1 | 1 – 2 | > 2 sustained |

## Capacity model for Apache prefork

`safe_max_workers ≈ (available_memory - reserved_for_os_and_other_services) / average_apache_php_rss`

Use [`worker-capacity.sh`](commands/apache/worker-capacity.sh) to compute it. Never raise `MaxRequestWorkers` above this without a measured reason; see [RB-03/CAP-02](../diagnostics/03-apache-capacity.md#cap-02).

## Baselines

Record a quiet-period and a peak-period baseline (requests/min, status mix, memory, workers) in [service map](service-map.md) or your monitoring tool.
