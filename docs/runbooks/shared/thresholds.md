---
id: RB-SHARED-THRESHOLDS
title: Thresholds and acceptance criteria
type: reference
domain: validation
status: template
owner: platform
updated: 2026-10-22
tags: [thresholds, baseline, acceptance, latency, error-rate, memory]
symptoms: [what is normal, is it recovered]
---

# Thresholds

> [Runbook index](../README.md) · Used by [RB-02/TRF-01](../diagnostics/02-apache-traffic.md#trf-01) and [RB-11/VAL-05](../response/11-validation-review.md#val-05)

Templates only; none of these values establishes recovery without complete measurements in the [recovery matrix](recovery-evidence.md#recovery-measurement-matrix). Set an observation duration and rollback trigger for each signal. Starting values only. Replace them with measured baselines for your service and record the date they were measured.

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

A prefork planning model is:

`child_budget = effective_memory_ceiling - other_services_peak - OS_headroom - Apache_shared_and_master_overhead`

`candidate_children <= child_budget / measured_loaded_child_private_memory`

This is a candidate for load testing, not an automatic safe limit. Determine the effective ceiling from host capacity and applicable service/container/ancestor cgroup limits, using the lowest applicable bound. Do not subtract already-consumed memory twice. Host `MemAvailable` is current headroom, not a replacement for a whole-service budget.

Measure a range of loaded child private memory/PSS over representative expensive requests and concurrency. Include the master/shared allocation once, account for variance and growth, and verify actual total memory at load. RSS includes shared mappings; averaging master, idle and busy process RSS can both hide peaks and double-count shared pages. PSS apportions shared mappings and requires care as process counts change. Reserve measured peak budgets for PHP-FPM, databases, Redis and other services; inspect cgroup `memory.events` and OOM evidence.

[`worker-capacity.sh`](commands/apache/worker-capacity.sh) reports current observations only. It cannot certify a worker cap. For event/worker MPM, `MaxRequestWorkers` limits threads; model thread/process overhead and the independent PHP-FPM pool. Verify the effective running MPM/config, test under representative load, set rollback limits, and apply changes through [RB-10](../response/10-mitigation-recovery.md). Missing measurements mean no defensible numeric recommendation.

See [Apache MaxRequestWorkers](https://httpd.apache.org/docs/2.4/mod/mpm_common.html#maxrequestworkers) and the [Linux cgroup memory controller](https://www.kernel.org/doc/html/latest/admin-guide/cgroup-v2.html#memory).

## Baselines

Record a quiet-period and a peak-period baseline (requests/min, status mix, memory, workers) in [service map](service-map.md) or your monitoring tool.
