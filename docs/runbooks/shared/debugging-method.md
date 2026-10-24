---
id: RB-SHARED-DEBUGGING
title: Systematic debugging and reliable log analysis
type: reference
domain: evidence
status: active
owner: platform
updated: undated
tags: [debugging, hypotheses, logs, shell, awk, performance, baseline]
symptoms: [inconclusive investigation, misleading counts, missing evidence]
---

# Systematic debugging and reliable log analysis

> [Runbook index](../README.md) · Use alongside [evidence validation](../foundations/01-evidence-attribution.md) and the [evidence schema](evidence-schema.md).

## Choose a question before a command

Write down the customer-visible failure, expected behaviour, affected revision, and UTC interval. Distinguish an observed failure from its proposed cause. An exception location, a busy worker pool, or an earlier deploy gives you a lead; each still needs an explanation connecting it to the failure.

For each hypothesis, record a prediction and a result that would contradict it. Prefer the next observation that separates competing explanations. For example, both expensive requests and increased request volume can saturate workers: compare route mix, latency and arrival rate against the same baseline before choosing a response.

1. Preserve the original evidence and identify its coverage and omissions.
2. State the hypothesis, alternatives and predicted measurement.
3. Make a bounded, read-only observation using the owning runbook.
4. Record the outcome as supported, contradicted or unresolved. A failed command or missing metric is unresolved.
5. Refine the explanation and repeat. Reproduce and reduce a failing case in an isolated environment with sanitised inputs before testing a fix.

Do not replay production writes, clear caches, or inject failures as a diagnostic shortcut. Experiments that change production follow [RB-10](../response/10-mitigation-recovery.md). Recovery after a restart supports a mitigation; it does not establish the original cause. Keep the causal conclusion separate from the recovery result.

## Minimise round trips

Every pasted round should answer a set of questions, not one. Follow the [fast path](fast-path.md): prior art and supplied exports before production, whole interval before windows, one pass producing several aggregates, and a printed header, window, denominator and exit status per block. Redact identifiers rather than meaning: template numeric/UUID/email path segments and classify user agents and peers instead of hashing paths, which can hide useful route classes and cost a round to reverse. Record each round's verdict in the incident's [command review](../incidents/_template/command-review.md).

## Make counts reproducible

Every aggregate should name its source files, host, deployed revision where known, UTC interval (prefer `[start, end)`), source timezone, filters, exclusions, and denominator. Record whether data is sampled, capped, incomplete or still arriving. Do not combine overlapping exports or duplicate log destinations without checking for duplicate events.

- Use the same interval and population for request rate, error share and route rankings. A top-N list is a subset; its displayed rows need not sum to 100%.
- Compare equal-duration baseline and incident windows with similar traffic and route mix. Separate visitor requests from backend retries and SSR fan-out.
- A minute missing from an aggregate is unknown until log coverage is verified. Explicitly fill verified empty minutes with zero before calculating rates over the full interval.
- Check raw, parsed and rejected record counts before trusting a field-based parser. Malformed requests, vhost prefixes, JSON logs and escaped quotes can invalidate `$7`, `$9` or `awk -F'"'` assumptions. `FS` splits text; it does not implement a general quoted-record parser.
- Use `grep -F -- 'literal'` for exact text, `grep -E` for deliberate extended regular expressions, and `awk -v route="$ROUTE"` with equality for exact parsed-field matches. Escape literal dots in regexes. A whole-line match can find a URL inside a referrer rather than the request field.
- Group Laravel exceptions by their timestamped header and preserve the associated multiline trace. Counting matching stack frames inflates event counts. Record a sanitised representative event as well as the grouping rule.

## Distinguish no match from a failed search

Keep stderr visible while validating sources. `2>/dev/null` can hide permission errors and corrupt gzip input. For GNU grep, status 0 means a match, 1 means no match, and 2 means an error. Check the status before running another command. This example counts one literal signature in a readable plain-text log without displaying the matching lines:

```bash
APACHE_ERR=/var/log/apache2/error.log
if grep -F -c -- 'AH00161' "$APACHE_ERR"; then
  : # Count printed; one or more matches.
else
  search_status=$?
  case "$search_status" in
    1) : ;; # Zero printed; no matches in this file.
    *) printf 'Search failed (status %s); result unresolved\n' "$search_status" >&2 ;;
  esac
fi
```

For compressed inputs, check decompression as well as matching. In Bash, enable `set -o pipefail` in a subshell around an evidence pipeline so an upstream failure is visible without changing the caller's shell settings. Capture `PIPESTATUS` immediately if individual stages matter. A downstream `head` can close its pipe early and cause an upstream SIGPIPE; inspect the stages before labelling that a source failure. Do not use `|| true` indiscriminately to turn every failure into a successful empty result.

The [log helpers](commands/README.md) validate filters and report input/selection/rejection counts on stderr. They fail rather than emit a partial aggregate on malformed input. An empty result still needs source coverage checks before making an absence claim. Run them against each selected file explicitly; they do not discover all rotations or all vhosts.

## Align request time, log arrival and correlation

Apache's default `%t` is request receipt time. A line becomes available later, so long-running requests can arrive in the file with timestamps earlier than the most recent line. Buffered logging or shipping adds further delay. A live onset window can therefore be incomplete; requery after the relevant timeout and shipping delay, recording the observation time. `%{end:...}t` selects end time when configured. `%D` measures duration in microseconds. These field meanings are defined by [Apache mod_log_config](https://httpd.apache.org/docs/2.4/mod/mod_log_config.html).

An upstream timeout does not guarantee that Apache records a 5xx: backend work can finish later with a different status, or a worker can die before logging. Correlate edge/CDN, Apache, PHP and application evidence. Prefer an existing request/trace ID; Apache `%L` can join access and error records when populated. Without a shared ID, time/route/status overlap supports a candidate relationship, not a proven one-to-one match. Record clock skew and timestamp precision.

The helpers' `WINDOW` is a Python regex on the source timestamp text, not a UTC conversion. Apache access helpers also support paired `START_UTC`/`END_UTC`, normalising explicit source offsets into UTC before selection. Their request-rate output sorts ISO UTC minute keys chronologically. Error-log timelines still require timezone validation: timestamp strings such as `DD/Mon/YYYY` do not sort chronologically across month/year boundaries. Recount buckets with an associative array or sort identical bucket keys before `uniq -c`; file order is insufficient.

## Measure latency and resource pressure

For each relevant resource, check utilisation, saturation and errors, and record unavailable metrics as unknown. High utilisation alone does not explain a queue or a customer failure.

| Resource | Utilisation | Saturation | Errors / failures |
| --- | --- | --- | --- |
| CPU | CPU busy time over an interval | Runnable work waiting for CPU | Throttling evidence; distinguish it from application errors |
| Memory | Available memory and applicable container/service limits | Reclaim, swap activity, memory pressure | Kernel or cgroup OOM events; PHP allocation failures separately |
| Apache / PHP pool | Busy workers relative to the effective limit | Existing queue/backlog metrics, waiting requests | Worker-limit warnings, timeouts, process deaths |
| Storage / dependency | Busy time or active connections relative to limits | I/O wait time or dependency pool queues | I/O failures, dependency errors and retries |

Use existing historical metrics for a past incident. A current snapshot cannot reconstruct past pressure. Follow [RB-03](../diagnostics/03-apache-capacity.md) for capacity and [RB-08](../diagnostics/08-service-dependencies.md) for dependencies.

When duration is already recorded, compare p50, p95 and p99 with sample count, units, route, status and timeout share. Keep fast errors separate from successful requests. Avoid averaging per-host percentiles; calculate from pooled samples or compatible histogram buckets. A small sample cannot reliably describe its tail. Completed-request latency omits work still in flight and may omit killed requests, so compare it with edge timeouts and pool pressure.

Standard combined logs contain no duration. Do not assume `$NF` is `%D`; it can be part of a quoted user agent. Record missing latency as an observability gap and use existing APM or edge timing. Logging changes require [RB-10](../response/10-mitigation-recovery.md).

## Reading notes

The following sections were consulted in the Markdown editions in the user's CLI library. These are adaptations to this repository's workflow, not copied book excerpts. Titles and sections are used instead of machine-specific paths so this reference remains portable.

| Source | Sections consulted | Application here |
| --- | --- | --- |
| Andreas Zeller, *Why Programs Fail*, 2nd ed. (2009) | Chapter 6, especially §6.2, The Scientific Method | Hypothesis, prediction, discriminating observation and unresolved outcomes |
| Brendan Gregg, *Systems Performance*, 2nd ed. (2020) | §2.5.9, The USE Method | Resource checklist and explicit unknown metrics |
| Beyer et al., *The Site Reliability Workbook* (2018) | Monitoring discussion of counters and latency percentiles | Interval-based rates, latency tails and sample limitations |
| Sobell and Helmke, *A Practical Guide to Linux Commands, Editors, and Shell Programming*, 4th ed. (2017) | Pipeline syntax and exit status | Visible stderr, pipeline failures and stage inspection |
| Aho, Kernighan and Weinberger, *The AWK Programming Language*, 2nd ed. (2024) | Associative arrays; field separators and quoted CSV discussion | Bucket aggregation and parser boundaries |
| Friedl, *Mastering Regular Expressions*, 2nd ed. (2002) | Character classes and metacharacter context | Deliberate literal versus regex matching |
| Barrett, *Efficient Linux at the Command Line* (2022) | Numeric sorting examples | Numeric ranking versus chronological timestamp sorting |

## Historical evidence and current observations

Label every collection as `historical-event`, `current-state` or `reproduction`. Record event time, collection time, source interval, host/boot/container identity, deployed revision and completeness. Current `systemctl show`, `/proc`, process RSS, Redis counters and configuration files do not establish their values during a past incident. Link historical metrics, configuration/deploy artifacts and journals where available; leave the historical value unknown if they are absent. Relative `since` windows need collection time, and a command that succeeds still needs retention and permission checks.

See [recovery evidence](recovery-evidence.md) for pass/unknown/fail gates and [single-flight validation](single-flight-validation.md) for an isolated experiment that measures actual upstream work.

