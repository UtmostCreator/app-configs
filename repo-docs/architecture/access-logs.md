# Apache Access Log Investigation — Decision-Based Runbook

Goal: Identify abnormal traffic, aggressive clients, suspicious requests, expensive endpoints, HTTP errors, and potential causes of server overload.

Execution model: Start at Step 0. Each step explains how to interpret the command results and which step to execute next. Return to earlier steps when new evidence changes the investigation.

> For the maintained incident workflow, start with the [runbook router](../../docs/runbooks/README.md), [evidence validation](../../docs/runbooks/foundations/01-evidence-attribution.md) and [systematic debugging reference](../../docs/runbooks/shared/debugging-method.md). This guide provides an additional Apache walkthrough.

## Workflow overview

Branches can skip forward or return to earlier steps according to the findings.

## Step 0 — Verify log format and select the source

Objective: Confirm that commands will extract the correct fields before interpreting any traffic.

```
LOG=/var/log/apache2/access.log

test -r "$LOG" && echo "Log readable"
head -n 3 "$LOG"
wc -l "$LOG"
```

The following workflow assumes Apache's standard Combined Log Format, which includes client IP, timestamp, request, status code, referrer and user agent. Custom formats must be checked before using positional field extraction.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://httpd.apache.org&sz=32)

Apache HTTP Server Version 2.4

| Result                                | Next action                                                       |
| ------------------------------------- | ----------------------------------------------------------------- |
| Log readable; expected fields present | → Step 1                                                          |
| File missing or permission denied     | Check path, permissions and configured `CustomLog`; repeat Step 0 |
| JSON or custom field ordering         | Adapt the parser; repeat Step 0                                   |
| Very large or rotated logs            | Select the relevant time window; repeat Step 0                    |

## Step 1 — Identify the actual client IP

Objective: Ensure that traffic is attributed to clients rather than a reverse proxy.

### 1.1 Check the most frequent logged IPs

```
awk '{print $1}' "$LOG" \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 30
```

| Result                                  | Next action                                   |
| --------------------------------------- | --------------------------------------------- |
| Public client IPs, correctly attributed | → Step 2                                      |
| Mostly private ALB/proxy IPs            | → Step 1.2                                    |
| One unexpected IP dominates             | Verify proxy attribution first, then → Step 3 |

### 1.2 Check whether X-Forwarded-For is logged

```
grep -m 3 -o 'xff="[^"]*"' "$LOG"
```

If the log is not the proxy-debug log, check the appropriate file:

```
LOG=/var/log/apache2/access_proxy_debug.log
```

For a trusted AWS ALB using its default append configuration, the ALB-appended address is the rightmost XFF entry, not necessarily the first. Earlier entries can be supplied by upstream clients or proxies.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://docs.aws.amazon.com&sz=32)

Elastic Load Balancing

```
awk -F'xff="' '
  NF > 1 {
    split($2, quoted, "\"")
    n = split(quoted[1], ips, ",")
    ip = ips[n]
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", ip)
    print ip
  }
' "$LOG" \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 30
```

Only trust this extraction if the request came through the expected ALB and its XFF handling is verified. With multiple proxy layers, the ALB-appended IP may identify another proxy rather than the original user.

| Result                                     | Next action                                                                             |
| ------------------------------------------ | --------------------------------------------------------------------------------------- |
| Trusted XFF provides distinct client IPs   | Use XFF mode in subsequent steps → Step 2                                               |
| Apache already uses trusted `mod_remoteip` | Use the existing client IP → Step 2                                                     |
| No reliable client IP available            | Continue with proxy-level analysis, but do not attribute traffic to individual visitors |

### 1.3 Set up reusable log parsing

This function ensures subsequent steps use the same client-IP strategy, retain health checks for attribution, and group URLs without query-string differences.

Run it once in your shell.

```
# Select one:
CLIENT_MODE=peer
# CLIENT_MODE=alb-xff

apache_rows() {
  awk -F'"' -v mode="$CLIENT_MODE" '
    BEGIN { OFS="\t" }

    # Keep health checks until peer, route and expected behaviour are verified.
    # A user agent alone is not trusted attribution.

    {
      split($1, prefix, /[[:space:]]+/)
      ip = prefix[1]

      if (mode == "alb-xff") {
        pos = index($0, "xff=\"")
        if (!pos) next

        value = substr($0, pos + 5)
        split(value, quoted, "\"")

        n = split(quoted[1], ips, ",")
        ip = ips[n]
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", ip)
      }

      split($2, request, /[[:space:]]+/)
      uri = request[2]
      path = uri
      sub(/\?.*$/, "", path)

      suffix = $3
      sub(/^[[:space:]]+/, "", suffix)
      split(suffix, response, /[[:space:]]+/)
      status = response[1]

      if (ip != "" && uri != "" &&
          status ~ /^[1-5][0-9][0-9]$/) {
        print ip, path, status, request[1], $6, uri
      }
    }
  ' "$LOG"
}
```

Run a smoke test:

```
apache_rows | head -n 5
```

The resulting tab-separated columns are:

| Field | Meaning                        |
| ----- | ------------------------------ |
| `$1`  | Client IP                      |
| `$2`  | URL path, without query string |
| `$3`  | HTTP status                    |
| `$4`  | HTTP method                    |
| `$5`  | User agent                     |
| `$6`  | Original request URI           |

Decision: If fields are correct, proceed to Step 2. If not, return to Step 0 and adjust the parser.

## Step 2 — Identify the HTTP status distribution

Objective: Determine whether the problem involves errors or excessive successful requests.

```
apache_rows \
  | cut -f3 \
  | sort \
  | uniq -c \
  | sort -nr
```

Example:

```
120340 200
 14321 404
  2311 301
   821 500
   125 503
```

| Finding              | Interpretation                              | Next step              |
| -------------------- | ------------------------------------------- | ---------------------- |
| 200/2xx dominates    | Successful traffic, possibly expensive      | → Step 3               |
| Many 301/302         | Redirects; check for loops                  | → Step 5               |
| Many 401/403         | Access attempts or authentication failures  | → Step 5               |
| Many 404             | Missing resources, broken links or scanning | → Step 5               |
| Many 429             | Rate limiting is being triggered            | → Step 7               |
| Many 500/502/503/504 | Application or infrastructure failures      | → Step 5, then Step 10 |

Do not treat a raw count as abnormal without considering the log's duration and normal traffic baseline.

## Step 3 — Identify the most active client IPs

Objective: Determine whether traffic is concentrated in a small number of clients.

```
apache_rows \
  | cut -f1 \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 30
```

Example:

```
34521 203.0.113.10
 9211 198.51.100.20
  821 192.0.2.30
```

| Finding                              | Next step                      |
| ------------------------------------ | ------------------------------ |
| One IP dominates                     | → Step 7, investigate that IP  |
| Several IPs dominate                 | → Step 7, investigate each     |
| Requests distributed across many IPs | → Step 4                       |
| Mostly proxy IPs                     | → Step 1; validate attribution |
| No obvious concentration             | → Step 4                       |

Important: A large request count alone does not prove abusive behaviour. NAT gateways, legitimate integrations and shared proxies can generate significant traffic.

## Step 4 — Find the most requested URLs

Objective: Identify which application resources receive the most traffic.

```
apache_rows \
  | cut -f2 \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 50
```

Example:

```
23411 /
12421 /graphql
 6221 /robots.txt
 5112 /api/search
 3211 /wp-login.php
```

| Finding                        | Next step                           |
| ------------------------------ | ----------------------------------- |
| `/` dominates                  | → Step 5; then Step 7               |
| `/graphql`, `/api/*` dominate  | → Step 6                            |
| `/wp-login.php`, `/.env`, etc. | → Step 5; investigate scanning      |
| Static assets dominate         | → Step 5; assess status and caching |
| Unexpected URLs appear         | → Step 5                            |

## Step 5 — Correlate URLs with HTTP status codes

Objective: Distinguish genuine application traffic from failing requests.

```
apache_rows \
  | cut -f2,3 \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 50
```

Example:

```
12034 / 404
 8421 /wp-login.php 404
 6221 /robots.txt 200
 5211 /graphql 200
 1202 /graphql 500
```

| Finding                       | Interpretation                                       | Next step |
| ----------------------------- | ---------------------------------------------------- | --------- |
| `/wp-login.php 404`           | Possible automated scanning                          | → Step 7  |
| `/.env 403`                   | Possible sensitive-file probing                      | → Step 7  |
| `/graphql 500`                | Application errors                                   | → Step 10 |
| `/graphql 200` at high volume | Potential expensive processing                       | → Step 6  |
| `/ 404` unexpectedly          | Possible application routing issue                   | → Step 10 |
| Many redirects                | Possible configuration or application redirect issue | → Step 10 |

If many 404 responses concern static assets, investigate missing files or deployment paths rather than assuming malicious traffic.

## Step 6 — Find expensive dynamic endpoint candidates

Objective: Exclude ordinary static resources and isolate routes that may perform application work.

```
apache_rows \
  | awk -F '\t' '
      tolower($2) !~ /\.(css|js|png|jpe?g|gif|svg|ico|webp|woff2?|ttf|map)$/ {
        print $2, $3
      }
    ' \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 50
```

| Finding                            | Next step             |
| ---------------------------------- | --------------------- |
| One dynamic endpoint dominates     | → Step 7              |
| Several dynamic endpoints dominate | → Step 7 for each     |
| High 5xx counts                    | → Step 10             |
| No suspicious dynamic activity     | → Step 8, then Step 9 |

This identifies candidates, not necessarily expensive requests. CPU, latency, database queries and caching metrics are needed to establish actual resource cost. Dynamic-looking paths can also serve cached content.

## Step 7 — Investigate a specific endpoint or IP

Objective: Connect the suspicious resource to its clients, methods and HTTP responses.

### 7.1 Top IPs requesting a particular endpoint

Set the endpoint:

```
ROUTE=/graphql
```

```
apache_rows \
  | awk -F '\t' -v route="$ROUTE" \
      '$2 == route {print $1}' \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 30
```

To include status and HTTP method:

```
apache_rows \
  | awk -F '\t' -v route="$ROUTE" \
      '$2 == route {print $1, $3, $4}' \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 50
```

### 7.2 Examine everything requested by one IP

```
IP=203.0.113.10
```

```
apache_rows \
  | awk -F '\t' -v ip="$IP" \
      '$1 == ip {print $2, $3}' \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 100
```

| Finding                             | Next step                        |
| ----------------------------------- | -------------------------------- |
| One IP repeatedly hits the same URL | → Step 8                         |
| One IP probes many unrelated URLs   | → Step 8                         |
| One IP generates many 5xx responses | → Step 10                        |
| Many IPs attack the same endpoint   | → Step 8, then Step 9            |
| Traffic appears legitimate          | → Step 9 to evaluate live impact |

For `/graphql`, path-only analysis cannot distinguish different GraphQL operations. Operation names, query complexity, request duration and application telemetry are necessary for deeper investigation.

## Step 8 — Identify user agents

Objective: Identify possible automated clients, crawlers and unusual traffic patterns.

```
apache_rows \
  | cut -f5 \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 50
```

To examine the user agents associated with one IP:

```
apache_rows \
  | awk -F '\t' -v ip="$IP" \
      '$1 == ip {print $5}' \
  | sort \
  | uniq -c \
  | sort -nr
```

| Finding                               | Next step                                 |
| ------------------------------------- | ----------------------------------------- |
| `curl`, `python-requests`, scripts    | → Step 7; investigate requested resources |
| Claimed search crawler                | Verify crawler identity; then → Step 9    |
| Blank or unusual user agent           | → Step 7                                  |
| Normal browser user agents            | → Step 9                                  |
| High-volume requests from many agents | → Step 9                                  |

User agents are client-controlled and can be spoofed. Do not use them as standalone proof of identity or malicious activity.

## Step 9 — Check live TCP connections

Objective: Determine whether historical request patterns correspond to current network activity.

### 9.1 Established connections by local port

```
sudo ss -Hnt state established \
  '( sport = :80 or sport = :443 )' \
  | awk '{
      port = $4
      sub(/^.*:/, "", port)
      print port
    }' \
  | sort \
  | uniq -c \
  | sort -nr
```

Example:

```
142 443
 21 80
```

### 9.2 Established connections by remote IP and local port

```
sudo ss -Hnt state established \
  '( sport = :80 or sport = :443 )' \
  | awk '{
      local = $4
      remote = $5
      sub(/^.*:/, "", local)
      sub(/:[^:]+$/, "", remote)
      gsub(/^\[|\]$/, "", remote)
      print remote, "->", local
    }' \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 50
```

The `ss` utility supports established-connection and local source-port filters.&#x20;

[image](https://www.google.com/s2/favicons?domain=https://www.man7.org&sz=32)

Linux manual page

| Finding                            | Next step                                |
| ---------------------------------- | ---------------------------------------- |
| Many connections from one client   | → Step 7; correlate historical requests  |
| Many connections from ALB IPs      | Expected behind ALB; inspect ALB metrics |
| No unusual connections             | → Step 10; check historical spikes       |
| High connection counts plus errors | → Step 10 immediately                    |

If the ALB forwards to port `8080` or another target port, replace the port filters accordingly.

Limitation: One TCP connection can carry multiple HTTP requests, especially with keep-alive or HTTP/2. Connection counts do not equal request rates.

## Step 10 — Establish when the problem occurred and correlate errors

Objective: Check whether the identified patterns coincide with a traffic spike or application failure.

### 10.1 Requests per minute

```
awk -F'[][]' '
  NF > 1 {
    print substr($2, 1, 17)
  }
' "$LOG" \
  | sort \
  | uniq -c \
  | tail -n 30
```

Example:

```
  120 21/Oct/2026:19:30
  145 21/Oct/2026:19:31
  920 21/Oct/2026:19:32
 1520 21/Oct/2026:19:33
```

Sort before `uniq -c` so nonadjacent records from the same minute are counted together. Apache logs can arrive out of timestamp order: default `%t` is receipt time, while writing happens later. This display sorts `DD/Mon/YYYY` lexically, so `tail` is not a reliable latest-window selector across date boundaries. Select a validated interval first or parse timestamps into UTC before chronological sorting.

### 10.2 Identify endpoints generating server errors

```
apache_rows \
  | awk -F '\t' '
      $3 ~ /^5/ {print $2, $3}
    ' \
  | sort \
  | uniq -c \
  | sort -nr \
  | head -n 30
```

### 10.3 Inspect Apache's error log

```
sudo tail -n 150 /var/log/apache2/error.log
```

For live investigation:

```
sudo tail -f /var/log/apache2/error.log
```

| Finding                                     | Next step                                                              |
| ------------------------------------------- | ---------------------------------------------------------------------- |
| Request spike and 5xx increase at same time | Investigate server resources, application and dependencies             |
| Traffic spike without application failures  | → Step 7; determine source and cost                                    |
| 5xx without traffic increase                | Investigate application, upstream services and deployments             |
| No spike or errors                          | → Step 11; compare with baseline and close or refine the investigation |

## Step 11 — Determine likely cause and choose the response

| Evidence                                 | Possible cause                              | Initial action                                          |
| ---------------------------------------- | ------------------------------------------- | ------------------------------------------------------- |
| One IP, many URLs, repeated 404          | Automated scanner                           | Consider WAF/rate limits after verifying                |
| One IP, repeated expensive 200 responses | Aggressive client or integration            | Verify client, cacheability and rate                    |
| Many IPs, same expensive route           | Distributed traffic or bot activity         | Check ALB/WAF/CDN metrics                               |
| 500 errors increasing                    | Application failure                         | Investigate application logs and recent changes         |
| 502/503/504 increasing                   | Upstream failure or capacity issue          | Check target health, timeouts, workers and dependencies |
| Static assets dominate                   | Normal asset loading or inefficient caching | Check cache headers and CDN                             |
| High traffic with stable performance     | Possibly normal demand                      | Compare historical baseline                             |

Do not block an IP or change rate limits solely from one command result. Correlate at least the client identity, requested resources, request frequency, and application impact.

## Quick decision index

| If you discover…                          | Go to                           |
| ----------------------------------------- | ------------------------------- |
| IP attribution looks incorrect            | Step 1                          |
| Many HTTP errors                          | Step 5                          |
| One suspicious IP                         | Step 7                          |
| One suspicious resource                   | Step 7                          |
| Potentially expensive dynamic URLs        | Step 6                          |
| A suspicious user agent                   | Step 7                          |
| Possible concurrent connection overload   | Step 9                          |
| Application errors or resource exhaustion | Step 10                         |
| Investigation inconclusive                | Step 10, then revisit Steps 3–8 |

Corrections incorporated from the original commands: accurate parsing of the quoted Apache request and user-agent fields; trusted-proxy-aware XFF selection; query-string normalisation; correctly escaped static-asset filtering; verification of ALB health checks before exclusion; and support for IPv6 in live-connection analysis.

Scope: Read-only diagnostics on the configured Apache log. Results cover the selected file and its time range, not automatically all rotated logs, other Apache virtual hosts, CDN requests, or requests rejected before reaching Apache.
