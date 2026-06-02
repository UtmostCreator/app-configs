# Project orchestrator

Generic tmux + health + GitHub PR helpers for N sibling project repos.

Everything is config-driven — there are no project names in any tracked
script. Real per-host values live in `home/.chezmoidata/projects.yaml`
(gitignored). The committed example at `home/personal.yaml.example`'s
sibling `home/projects.yaml.example` shows the schema with placeholders.

## What it gives you

| Task | Script | What it does |
|------|--------|--------------|
| `mise run projects:tmux` | `scripts/projects/tmux-master.sh` | Master workspace: log pane on top, one shell pane per project, second tmux window with each project's `service.start_cmd` running. |
| `mise run projects:logs` | `scripts/projects/tmux-logs.sh` | N vertical panes, one tailing each project's `service.log` (the original 3-pane log viewer, scaled to whatever fits). |
| `mise run projects:ssh` | `scripts/projects/tmux-ssh.sh` | N tmux panes, one `ssh <alias>` per entry under `ssh_workspace.hosts`. |
| `mise run projects:repo -- <id>` | `scripts/projects/repo-checks.sh` | Per-repo git status snapshot for one project. |
| `mise run projects:health` | `scripts/projects/health/run.sh` | Discover & run every `health/checks.d/*.sh`, pretty-print via `glow`. |
| `mise run projects:health:json` | same, `--json` | Raw aggregate JSON for dashboards. |
| `mise run projects:sync-main` | `scripts/projects/github/sync-main.sh` | Fetch + fast-forward `main` on every project. |
| `mise run projects:pr-watch` | `scripts/projects/github/pr-watch.sh` | Poll GitHub for PR transitions on tracked repos. |

## Setup (once per host)

```bash
# 1. Drop a real config in place (gitignored)
cp home/projects.yaml.example home/.chezmoidata/projects.yaml
$EDITOR home/.chezmoidata/projects.yaml

# 2. Render it into ~/.config/projects/config.yaml
chezmoi apply        # or: mise run sync:apply
```

That's it. Every script below reads `~/.config/projects/config.yaml` via `yq`.

## Schema

`home/.chezmoidata/projects.yaml`:

```yaml
projects:
  <id>:                       # short slug (cms, frontend, api, ...)
    name: "human label"
    dir: "~/work/<id>"        # absolute or tilde path
    repo_url: "git@github.com:org/<id>.git"   # for sync-main + pr-watch
    pane_label: "ID-UPPER"    # tmux pane title
    branch_pattern: ""        # optional regex; empty = no auto-checkout
    service:                  # optional; omit for non-service projects
      pane: "<id>-service"
      start_cmd: "npm run dev"
      log: "~/work/<id>/storage/logs/dev.log"
    health:
      checks: [http, process] # check ids from health/checks.d/
      http_url: "http://<id>.local/up"

tmux:
  master_session: "dev-workspace"
  log_session: "dev-logs"
  layout:
    log_percent: 25
    primary_percent: 50
    secondary_percent: 25
    tertiary_percent: 30

ssh_workspace:
  session: "remote-shells"
  hosts: [test-host, poc-host]

github:
  pr_watch:
    enabled: true
    interval_seconds: 20
    include_repos: [org/<id>]
    events:
      pr_opened:           { enabled: true }
      pr_review_requested: { enabled: true }
      pr_merged:           { enabled: true }
      ci_failed:           { enabled: true }

health:
  retries:
    http_tries: 5
    http_sleep_seconds: 2
```

## Tmux master layout

Order in the YAML controls pane assignment:

```
┌────────────────────────────────────────────────────────┐
│             logs pane (log_percent of height)          │
│         tails each project's service.log               │
├────────────────────────┬───────────────────────────────┤
│ projects[0] PRIMARY    │ projects[1] SECONDARY         │
│   + repo-checks        │                               │
│   + branch_pattern     │                               │
│     auto-checkout      ├───────────────────────────────┤
│                        │ projects[2] TERTIARY          │
├────────────────────────┼───────────────────────────────┤
│ projects[3] BOTTOM_L   │ projects[4] BOTTOM_R          │
└────────────────────────┴───────────────────────────────┘

second window: "services" — one pane per project with service.start_cmd
```

Fewer than 5 projects → the layout collapses (only the panes that have a project assigned are created).

## Adding / removing a project

Adding:

```bash
$EDITOR home/.chezmoidata/projects.yaml
# add a `<new-id>:` block under `projects:` with at minimum: name, dir, repo_url, pane_label
chezmoi apply         # re-renders ~/.config/projects/config.yaml
mise run projects:tmux --force   # restart workspace
```

Removing:

```bash
$EDITOR home/.chezmoidata/projects.yaml
# delete the `<id>:` block
chezmoi apply
mise run projects:tmux --force
```

The scripts have no hard-coded project ids — everything follows from the YAML.

## Writing a new health check

Each check is a self-contained 5–15 line script under
`scripts/projects/health/checks.d/`:

```bash
#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/projects/health/lib.sh
source "$SCRIPT_DIR/../lib.sh"

# Run for every project that lists "<check-id>" under health.checks
for id in $(proj_health_for_each_project disk-space); do
  dir="$(proj_expand_path "$(proj_field "$id" dir)")"
  PROJ_CHECK_NAME="${id}-disk"
  if [[ "$(df -P "$dir" | awk 'NR==2 {print $5}' | tr -d %)" -lt 90 ]]; then
    proj_emit ok "$id" "disk under 90%"
  else
    proj_emit fail "$id" "disk over 90%" "df -h $dir"
  fi
done
```

Add the check id (e.g. `disk-space`) under `health.checks` on any
project in your `projects.yaml` to enable it. No registry, no wiring.

## Anonymisation contract

The committed source tree contains zero real project names, ssh
hostnames, repo URLs, or owner identities. The only project-shaped
strings in code are:

- check ids in `health/checks.d/*.sh` (these are intentional category
  names — `http`, `process`, `tmux` — not project names)
- tmux session defaults (`dev-workspace`, `dev-logs`, `remote-shells`)
  which are overridable via `tmux.*` in your YAML

If you find a project name leaked into a tracked script, that is a bug
— please file a follow-up row in `repo-docs/migration-followups.md`.

## What this replaces (relative to a personal scripts directory)

Originally:

- `cms-open-workspace.sh` (316 lines, hard-coded 5 project names)
- `log-workspace.sh` (93 lines, hard-coded 3 log paths)
- `test-env.sh` (66 lines, hard-coded `webtest`/`webpoc`)
- `cms-verify-workspace.sh` (1058 lines, hand-rolled ANSI rendering, parallel arrays)
- `cms-health-monitor.sh` (368 lines, second TUI for the same data)
- `cms-health-pretty.sh` (65 lines, markdown emitter)
- `cms-fix.sh` (34 lines, fzf-driven fix picker)
- `gh-pr-watch.sh` (668 lines, multi-format YAML-driven watcher)
- `gh-pr-watch-{bat,live,log-view,pretty}.sh` + `gh-pr-status.sh` + `gh-pr-open.sh` + `gh-pr-open-from-log.sh`

What remains here:

- `tmux-master.sh` (~190 lines, generic over N projects)
- `tmux-logs.sh` (~110 lines, generic over N projects)
- `tmux-ssh.sh` (~70 lines, generic over N hosts)
- `repo-checks.sh` (~55 lines, generic)
- `health/run.sh` + `render.sh` + 3 checks (~50 + 50 + ~50 lines total)
- `github/sync-main.sh` (~40 lines)
- `github/pr-watch.sh` (~110 lines, single output format, single config schema)

~1.7k → ~640 lines, single source of truth, every project name removed.

What was deliberately not ported:

- Cisco-VPN dnsmasq workarounds (macOS-specific; tied to a single corporate VPN — drop entirely)
- The standalone frontend debug helper (overlapped with `tmux-master.sh`)
- The multiple PR-watch formatters (`bat`, `live`, `log-view`, `pretty`) — single format, configurable via `github.pr_watch.events`
- The `--quiet` / `--json` / text-render forking in the old health monitor — replaced by `run.sh --json` piping to `render.sh`
