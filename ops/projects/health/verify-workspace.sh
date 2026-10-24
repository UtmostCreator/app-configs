#!/usr/bin/env bash
# verify-workspace.sh
#
# Checks that every backend workspace service is healthy.
# Emits  SUCCESS  or  NEEDS RESTART  for each check, with the exact
# command to fix anything that is failing.
#
# Auto-runs in the ws-shell pane when `ws` opens.
# Re-run manually at any time:  ws-verify

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../workspace/config.sh"

JSON_MODE=0
QUIET_MODE=0
for arg in "$@"; do
    case "$arg" in
        --json)
            JSON_MODE=1
            ;;
        --quiet)
            QUIET_MODE=1
            ;;
        *)
            ;;
    esac
done

RENDER_TEXT=1
if [[ "$JSON_MODE" == "1" || "$QUIET_MODE" == "1" ]]; then
    RENDER_TEXT=0
fi

# Fast mode is used by the real-time monitor to avoid long retry windows that
# can make status appear stale after services are stopped/started.
FAST_MODE="${WS_VERIFY_FAST:-0}"
if [[ "$FAST_MODE" == "1" ]]; then
    RETRY_MAX_CAP="2"
    RETRY_WAIT_CAP="1"
    WS_HTTP_TRIES="${WS_HTTP_TRIES:-3}"
    WS_HTTP_SLEEP="${WS_HTTP_SLEEP:-1}"
    INTEGRATION_HTTP_TRIES="${INTEGRATION_HTTP_TRIES:-3}"
    INTEGRATION_HTTP_SLEEP="${INTEGRATION_HTTP_SLEEP:-1}"
    FRONTEND_HTTP_TRIES="${FRONTEND_HTTP_TRIES:-4}"
    FRONTEND_HTTP_SLEEP="${FRONTEND_HTTP_SLEEP:-1}"
    FRONTEND_PROCESS_TRIES="${FRONTEND_PROCESS_TRIES:-6}"
    FRONTEND_PROCESS_SLEEP="${FRONTEND_PROCESS_SLEEP:-1}"
else
    RETRY_MAX_CAP=""
    RETRY_WAIT_CAP=""
    WS_HTTP_TRIES="${WS_HTTP_TRIES:-15}"
    WS_HTTP_SLEEP="${WS_HTTP_SLEEP:-3}"
    INTEGRATION_HTTP_TRIES="${INTEGRATION_HTTP_TRIES:-10}"
    INTEGRATION_HTTP_SLEEP="${INTEGRATION_HTTP_SLEEP:-3}"
    FRONTEND_HTTP_TRIES="${FRONTEND_HTTP_TRIES:-15}"
    FRONTEND_HTTP_SLEEP="${FRONTEND_HTTP_SLEEP:-3}"
    FRONTEND_PROCESS_TRIES="${FRONTEND_PROCESS_TRIES:-15}"
    FRONTEND_PROCESS_SLEEP="${FRONTEND_PROCESS_SLEEP:-2}"
fi

# ── Colours (degrade gracefully outside a terminal) ──────────────────────────
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    DIM='\033[2m'
    RESET='\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; DIM=''; RESET=''
fi

# ── State ────────────────────────────────────────────────────────────────────
PASS_COUNT=0
FAIL_COUNT=0
FAIL_MESSAGES=()
CURRENT_SECTION=""
SECTION_NAMES=()
SECTION_PASS_COUNTS=()
SECTION_FAIL_COUNTS=()
ROOT_ISSUES=()
FIX_PLAN=()
ENDPOINT_NAMES=("Integration endpoint" "backend login endpoint" "Frontend endpoint")
ENDPOINT_STATES=("unknown" "unknown" "unknown")
ENDPOINT_NOTES=("" "" "")
CHECK_ROWS=()

# ── Helpers ───────────────────────────────────────────────────────────────────
_frontend_auth_header() {
    local creds=""
    local pair=""
    local encoded=""

    if [[ -n "${BASIC_AUTH_CREDS:-}" ]]; then
        creds="$BASIC_AUTH_CREDS"
    fi

    pair="${creds%% *}"
    [[ -n "$pair" ]] || return 0

    encoded="$(printf '%s' "$pair" | base64 | tr -d '\n')"
    printf 'Authorization: Basic %s\n' "$encoded"
}

_frontend_http_healthy() {
    [[ "$_FE_HTTP" == "200" ]] \
        || { [[ -z "$_FE_AUTH_HEADER" ]] && [[ "$_FE_HTTP" == "401" ]]; }
}

_frontend_http_code() {
    local url="$1" timeout="$2"

    if [[ -n "$_FE_AUTH_HEADER" ]]; then
        curl -H "$_FE_AUTH_HEADER" -sSo /dev/null -w '%{http_code}' --max-time "$timeout" "$url" 2>/dev/null || true
    else
        curl -sSo /dev/null -w '%{http_code}' --max-time "$timeout" "$url" 2>/dev/null || true
    fi
}

_ok() {
    local label="$1" detail="${2:-}"
    if [[ "$RENDER_TEXT" == "1" ]]; then
        printf "  ${GREEN}✓ SUCCESS${RESET}  %-40s ${DIM}%s${RESET}\n" "$label" "$detail"
    fi
    (( PASS_COUNT++ )) || true
    _incr_section_count "pass"
    _set_endpoint_state "$label" "success" "$detail"
    _record_check "ok" "info" "$label" "$detail" "" "$CURRENT_SECTION" "healthy" ""
}

_fail() {
    local label="$1" detail="${2:-}" fix="${3:-}"
    if [[ "$RENDER_TEXT" == "1" ]]; then
        printf "  ${RED}✗ NEEDS RESTART${RESET}  %-34s ${DIM}%s${RESET}\n" "$label" "$detail"
        [[ -n "$fix" ]] && printf "    ${YELLOW}→ run: %s${RESET}\n" "$fix"
    fi
    (( FAIL_COUNT++ )) || true
    FAIL_MESSAGES+=("${label}  →  ${fix:-no fix suggested}")
    _incr_section_count "fail"
    _set_endpoint_state "$label" "fail" "$detail"
    [[ -n "$fix" ]] && _add_unique FIX_PLAN "$fix"
    _classify_root_issue "$label" "$detail"
    _record_check "fail" "$(_infer_severity "$label" "$detail")" "$label" "$detail" "$fix" "$CURRENT_SECTION" "$(_infer_kind "$label" "$detail")" "$(_infer_blocked_by "$label" "$detail")"
}

_section() {
    CURRENT_SECTION="$1"
    _ensure_section_entry "$CURRENT_SECTION"
    if [[ "$RENDER_TEXT" == "1" ]]; then
        printf "\n${BOLD}${CYAN}─── %s${RESET}\n" "$1"
    fi
}

_infer_severity() {
    local label="$1" detail="$2"
    case "$label|$detail" in
        *"endpoint"*"HTTP 500"*|*"Frontend HTTP"*"HTTP 500"*) printf 'warn' ;;
        *"Herd app"*|*"nginx"*|*"dnsmasq"*|*"tmux session"*|*"pane:"*|*"HTTP"*|*"endpoint"*) printf 'critical' ;;
        *) printf 'critical' ;;
    esac
}

_infer_kind() {
    local label="$1" detail="$2"
    case "$label|$detail" in
        *"Herd app"*|*"nginx"*|*"port 80"*|*"port 443"*|*"dnsmasq"*|*"tmux session"*|*"pane:"*|*"log watcher"*)
            printf 'root'
            ;;
        *"backend app HTTP"*|*"Integration HTTP"*|*"Integration endpoint"*|*"backend login endpoint"*)
            if [[ " ${ROOT_ISSUES[*]} " == *"Herd stack is not running"* || " ${ROOT_ISSUES[*]} " == *"DNS resolver stack is degraded"* ]]; then
                printf 'blocked'
            else
                printf 'independent'
            fi
            ;;
        *"Frontend HTTP"*|*"Frontend endpoint"*)
            printf 'independent'
            ;;
        *)
            printf 'independent'
            ;;
    esac
}

_infer_blocked_by() {
    local label="$1" detail="$2"
    if [[ "$(_infer_kind "$label" "$detail")" != "blocked" ]]; then
        printf ''
        return 0
    fi
    if [[ " ${ROOT_ISSUES[*]} " == *"Herd stack is not running"* ]]; then
        printf 'herd/nginx'
    elif [[ " ${ROOT_ISSUES[*]} " == *"DNS resolver stack is degraded"* ]]; then
        printf 'dnsmasq'
    else
        printf 'upstream dependency'
    fi
}

_record_check() {
    local status="$1" severity="$2" name="$3" message="$4" fix="$5" group="$6" kind="$7" blocked_by="$8"
    local row
    row="$(jq -cn \
        --arg status "$status" \
        --arg severity "$severity" \
        --arg name "$name" \
        --arg message "$message" \
        --arg fix "$fix" \
        --arg group "$group" \
        --arg kind "$kind" \
        --arg blocked_by "$blocked_by" \
        '{status:$status,severity:$severity,name:$name,message:$message,fix:$fix,group:$group,kind:$kind,blocked_by:$blocked_by}')"
    CHECK_ROWS+=("$row")
}

_add_unique() {
    local arr_name="$1"
    local value="$2"
    local existing
    eval "for existing in \"\${${arr_name}[@]-}\"; do
        [[ \"\$existing\" == \"\$value\" ]] && return 0
    done"
    eval "${arr_name}+=(\"\$value\")"
}

_section_index() {
    local name="$1"
    local i
    for (( i=0; i<${#SECTION_NAMES[@]}; i++ )); do
        [[ "${SECTION_NAMES[$i]}" == "$name" ]] && { printf '%s\n' "$i"; return 0; }
    done
    printf '%s\n' "-1"
}

_ensure_section_entry() {
    local name="$1"
    local idx
    idx="$(_section_index "$name")"
    if [[ "$idx" == "-1" ]]; then
        SECTION_NAMES+=("$name")
        SECTION_PASS_COUNTS+=("0")
        SECTION_FAIL_COUNTS+=("0")
    fi
}

_incr_section_count() {
    local kind="$1"
    local idx
    [[ -z "$CURRENT_SECTION" ]] && return 0
    idx="$(_section_index "$CURRENT_SECTION")"
    [[ "$idx" == "-1" ]] && return 0
    if [[ "$kind" == "pass" ]]; then
        SECTION_PASS_COUNTS[$idx]=$(( SECTION_PASS_COUNTS[$idx] + 1 ))
    else
        SECTION_FAIL_COUNTS[$idx]=$(( SECTION_FAIL_COUNTS[$idx] + 1 ))
    fi
}

_set_endpoint_state() {
    local label="$1" state="$2" note="$3"
    local i
    for (( i=0; i<${#ENDPOINT_NAMES[@]}; i++ )); do
        if [[ "${ENDPOINT_NAMES[$i]}" == "$label" ]]; then
            if [[ "$state" == "success" && "$note" == *"HTTP 500"* ]]; then
                ENDPOINT_STATES[$i]="warn"
            else
                ENDPOINT_STATES[$i]="$state"
            fi
            ENDPOINT_NOTES[$i]="$note"
            return 0
        fi
    done
}

_classify_root_issue() {
    local label="$1" detail="$2"
    case "$label|$detail" in
        *"Herd app"*|*"nginx"*|*"port 80"*|*"port 443"*)
            _add_unique ROOT_ISSUES "Herd stack is not running"
            ;;
        *"dnsmasq"*|*"DNS"*)
            _add_unique ROOT_ISSUES "DNS resolver stack is degraded"
            ;;
        *"backend app HTTP"*|*"Integration HTTP"*|*"Frontend HTTP"*|*"endpoint"*)
            _add_unique ROOT_ISSUES "Application HTTP endpoints are degraded"
            ;;
        *"tmux session"*|*"pane:"*|*"log watcher"*)
            _add_unique ROOT_ISSUES "tmux workspace is incomplete"
            ;;
        *)
            _add_unique ROOT_ISSUES "Multiple health checks are failing"
            ;;
    esac
}

_resolve_host_ip() {
    local hostname="$1"
    local ip=""

    ip="$(dscacheutil -q host -a name "$hostname" 2>/dev/null | awk '/^ip_address: /{print $2; exit}')"
    if [[ -n "$ip" ]]; then
        printf '%s\n' "$ip"
        return 0
    fi

    ip="$(grep -E "^[[:space:]]*127\.0\.0\.1([[:space:]]|$).*\b${hostname//./\.}\b" /etc/hosts 2>/dev/null | awk 'NR==1{print $1}')"
    if [[ -n "$ip" ]]; then
        printf '%s\n' "$ip"
        return 0
    fi

    return 1
}

_host_is_pinned() {
    local hostname="$1"
    grep -Eq "^[[:space:]]*127\.0\.0\.1([[:space:]]|$).*\b${hostname//./\.}\b" /etc/hosts 2>/dev/null
}

_port53_owner() {
    # Names a non-dnsmasq process bound to 127.0.0.1:53 (e.g. a VPN or local resolver).
    lsof -nP -iUDP@127.0.0.1:53 2>/dev/null | awk '
        NR > 1 && $1 !~ /dnsmasq/ { print $1; found=1; exit }
        END { if (!found) exit 1 }
    '
}

_dns_fix_hint() {
    local owner
    owner="$(_port53_owner 2>/dev/null || true)"

    if [[ -n "$owner" ]]; then
        printf 'stop %s (holds port 53), then: herd restart && ws-verify\n' "$owner"
        return 0
    fi

    printf 'open -a Herd && herd start\n'
}

# Returns the port= value from Herd's user dnsmasq.conf.
# Defaults to "53" when the port= line is absent (Herd's out-of-box default).
_dnsmasq_conf_port() {
    grep -E "^port=" "$HERD_DNSMASQ_CONF" 2>/dev/null \
        | cut -d= -f2 | tr -d '[:space:]' \
        || echo "53"
}

# Returns the port directive from /etc/resolver/test.
# Defaults to "53" when absent (macOS default: query port 53).
_resolver_test_port() {
    grep -E "^port " "$WS_RESOLVER_TEST_FILE" 2>/dev/null | awk '{print $2}' || echo "$WS_DNSMASQ_DEFAULT_PORT"
}

# retry <max> <sleep_secs> <cmd …>
_retry() {
    local max="$1" wait="$2"; shift 2
    local i

    if [[ -n "$RETRY_MAX_CAP" && "$max" -gt "$RETRY_MAX_CAP" ]]; then
        max="$RETRY_MAX_CAP"
    fi
    if [[ -n "$RETRY_WAIT_CAP" && "$wait" -gt "$RETRY_WAIT_CAP" ]]; then
        wait="$RETRY_WAIT_CAP"
    fi

    for (( i=1; i<=max; i++ )); do
        if "$@" &>/dev/null; then return 0; fi
        (( i < max )) && sleep "$wait"
    done
    return 1
}

_herd_app_running() {
    pgrep -qf '/Applications/Herd.app/Contents/MacOS/Herd|Herd\.app/Contents/MacOS/Herd' 2>/dev/null
}

# Pipe-friendly helpers used with _retry (can't pipe inside "$@")
_nginx_on_port() { lsof -nP -iTCP:"$1" -sTCP:LISTEN 2>/dev/null | grep -q "nginx"; }
_dnsmasq_running() { pgrep -q dnsmasq 2>/dev/null; }
_redis_container_running() {
    [[ "$(docker inspect -f '{{.State.Status}}' "$WS_REDIS_CONTAINER_NAME" 2>/dev/null || echo missing)" == "running" ]]
}
_http_responds_within() {
    local url="$1"
    local timeout_secs="$2"
    local code
    code="$(curl -ksSo /dev/null -w '%{http_code}' --max-time "$timeout_secs" "$url" 2>/dev/null || true)"
    [[ -n "$code" && "$code" != "000" ]]
}

_frontend_process_pid() {
    pgrep -f "netlify dev.*--port ${WS_FRONTEND_PORT}|ws-frontend-debug\\.sh run|web-frontend/node_modules/.bin/nuxt dev|web-frontend/node_modules/.bin/nuxi dev|node .*web-frontend.*nuxi.* dev|npm run dev -- --host ${_FE_HOST_REGEX} --port ${WS_FRONTEND_TARGET_PORT}" | head -1 || true
}

_frontend_listener_pid() {
    lsof -nP -iTCP:"$WS_FRONTEND_PORT" -sTCP:LISTEN -t 2>/dev/null | head -1 || true
}

_frontend_listener_matches_frontend() {
    local pid="$1"
    local command

    [[ -n "$pid" ]] || return 1
    command="$(ps -p "$pid" -o command= 2>/dev/null || true)"
    [[ -n "$command" ]] || return 1

    [[ "$command" == *"$WS_FRONTEND_APP_DIR"* \
        || "$command" == *"netlify dev"* \
        || "$command" == *"frontend dev"* \
        || "$command" == *"nuxi dev"* ]]
}

_frontend_ready_signal() {
    local pid

    pid="$(_frontend_process_pid)"
    [[ -n "$pid" ]] && return 0

    pid="$(_frontend_listener_pid)"
    [[ -n "$pid" ]] && _frontend_listener_matches_frontend "$pid"
}

# ── Config ────────────────────────────────────────────────────────────────────
SESSION="$WS_TMUX_SESSION"
WS_APP_URL="https://backend.test"
INTEGRATION_ENV_FILE="$HOME/Herd/integration/.env"
INTEGRATION_APP_URL="https://integration.test"
_FE_HOST_REGEX="${WS_FRONTEND_HOST//./\\.}"

if [[ -f "$INTEGRATION_ENV_FILE" ]]; then
    _INTEGRATION_ENV_URL="$(awk -F= '/^APP_URL=/{print $2; exit}' "$INTEGRATION_ENV_FILE" 2>/dev/null | tr -d '"')"
    [[ -n "$_INTEGRATION_ENV_URL" ]] && INTEGRATION_APP_URL="$_INTEGRATION_ENV_URL"
fi

INTEGRATION_HOST="${INTEGRATION_APP_URL#https://}"
INTEGRATION_HOST="${INTEGRATION_HOST#http://}"
INTEGRATION_HOST="${INTEGRATION_HOST%%/*}"

# ── Herd dnsmasq config ────────────────────────────────────────────────────────
# Herd's bundled dnsmasq provides wildcard *.test DNS (address=/.test/127.0.0.1).
# Hostnames pinned in /etc/hosts resolve regardless of dnsmasq state:
#   echo '127.0.0.1 newsite.test' | sudo tee -a /etc/hosts
#   sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder
HERD_DNSMASQ_CONF="$WS_HERD_DNSMASQ_CONF"
DNSMASQ_DEFAULT_PORT="$WS_DNSMASQ_DEFAULT_PORT" # Herd default

# ── Header ────────────────────────────────────────────────────────────────────
if [[ "$RENDER_TEXT" == "1" ]]; then
    printf "\n${BOLD}╔══════════════════════════════════════════════╗${RESET}\n"
    printf "${BOLD}║  Workspace Health Check                       ║${RESET}\n"
    printf "${BOLD}║  %-45s║${RESET}\n" "$(date '+%a %d %b %Y  %H:%M:%S')"
    printf "${BOLD}╚══════════════════════════════════════════════╝${RESET}\n"
fi

# =============================================================================
# 1. tmux workspace integrity
# =============================================================================
_section "tmux workspace"

_pane_alive() {
    local title="$1"
    local dead
    dead="$(tmux list-panes -a \
        -F '#{session_name}	#{pane_title}	#{@ws_workspace_role}	#{pane_dead}' 2>/dev/null \
        | awk -F'\t' -v s="$SESSION" -v t="$title" \
            '$1==s && ($2==t || $3==t) { print $4; exit }')"
    [[ "$dead" == "0" ]]
}

_first_alive_pane() {
    local title dead
    for title in "$@"; do
        dead="$(tmux list-panes -a \
            -F '#{session_name}|#{pane_title}|#{@ws_workspace_role}|#{pane_dead}' 2>/dev/null \
            | awk -F'|' -v s="$SESSION" -v t="$title" \
                '$1==s && ($2==t || $3==t) { print $4; exit }')"
        if [[ "$dead" == "0" ]]; then
            printf '%s\n' "$title"
            return 0
        fi
    done
    return 1
}

if tmux has-session -t "$SESSION" 2>/dev/null; then
    _ok "tmux session" "ws-dev is running"
else
    _fail "tmux session" "session not found" "ws"
fi

_LOG_PANE="$(_first_alive_pane "APP-logs" "APP-LOGS" "ws-logs" "APP-LOG" "ws-log" || true)"
if [[ -n "$_LOG_PANE" ]]; then
    _ok "pane: ${_LOG_PANE}" "alive"
else
    _fail "pane: APP-logs" "dead or missing" "tmux kill-session -t ws-dev && ws"
fi

_HERD_PANE="$(_first_alive_pane "backend-HERD" "ws-backend" || true)"
if [[ -n "$_HERD_PANE" ]]; then
    _ok "pane: ${_HERD_PANE}" "alive"
else
    _fail "pane: ws-backend" "dead or missing" "tmux kill-session -t ws-dev && ws"
fi

_NUXT_PANE="$(_first_alive_pane "backend-FRONTEND" "ws-frontend" || true)"
if [[ -n "$_NUXT_PANE" ]]; then
    _ok "pane: ${_NUXT_PANE}" "alive"
else
    _fail "pane: ws-frontend" "dead or missing" "tmux kill-session -t ws-dev && ws"
fi

# =============================================================================
# 2. Herd — nginx · PHP-FPM · DNS
# =============================================================================
_section "Herd — nginx · PHP-FPM · DNS"

# Herd desktop process (explicitly report app state so closing Herd is visible
# even when managed services are still running for a short period).
if _herd_app_running; then
    _ok "Herd app" "running"
else
    _fail "Herd app" "not running" "open -a Herd"
fi

# nginx process (retry: herd start spawns nginx asynchronously)
if _retry 8 2 pgrep -qf "nginx: master"; then
    _ok "nginx" "master process running"
else
    _fail "nginx" "no master process" "ws-stop-stack && ws-stack"
fi

# nginx port 80
if _retry 8 2 _nginx_on_port 80; then
    _ok "nginx port 80" "127.0.0.1:80 listening"
else
    _fail "nginx port 80" "nothing on port 80" "ws-stop-stack && ws-stack"
fi

# nginx port 443
if _retry 8 2 _nginx_on_port 443; then
    _ok "nginx port 443" "127.0.0.1:443 listening"
else
    _fail "nginx port 443" "nothing on port 443" "ws-stop-stack && ws-stack"
fi

# PHP-FPM
if pgrep -qf "php-fpm: master"; then
    _ok "PHP-FPM" "master process running"
else
    _fail "PHP-FPM" "no master process" "ws-stop-stack && ws-stack"
fi

# ── dnsmasq (Herd wildcard DNS) ──────────────────────────────────────────────
# Herd's bundled dnsmasq provides wildcard *.test DNS (address=/.test/127.0.0.1).
#
# FAIL — dnsmasq not running:
#   open -a Herd && herd start && ws-verify
# ─────────────────────────────────────────────────────────────────────────────
_CONF_PORT="$(_dnsmasq_conf_port)"
# Wait up to 16s for dnsmasq — herd start launches it asynchronously
_retry 8 2 _dnsmasq_running || true
_DNSMASQ_RUNNING="$(pgrep -q dnsmasq 2>/dev/null && echo yes || echo no)"

if [[ "$_DNSMASQ_RUNNING" == "no" ]]; then
    _fail "dnsmasq" "not running" "open -a Herd && herd start && ws-verify"
else
    _ok "dnsmasq" "running · port ${_CONF_PORT}"
fi

# DNS — check both direct site resolution and wildcard .test DNS health.
if _RESOLVED="$(_resolve_host_ip backend.test 2>/dev/null)"; then
    _ok "backend.test DNS" "backend.test → ${_RESOLVED}"
else
    _PORT53_OWNER="$(_port53_owner 2>/dev/null || true)"
    if [[ -n "$_PORT53_OWNER" ]]; then
        _fail "backend.test DNS" \
            "hostname unresolved — port 53 held by ${_PORT53_OWNER}" \
            "$(_dns_fix_hint backend.test)"
    else
        _fail "backend.test DNS" "backend.test does not resolve — dnsmasq not running" \
            "$(_dns_fix_hint backend.test)"
    fi
fi

if _INTEGRATION_DNS_TEST="$(_resolve_host_ip "$INTEGRATION_HOST" 2>/dev/null)"; then
    _ok "Wildcard .test DNS" "${INTEGRATION_HOST} → ${_INTEGRATION_DNS_TEST}"
else
    _PORT53_OWNER="$(_port53_owner 2>/dev/null || true)"
    if [[ -n "$_PORT53_OWNER" ]]; then
        _fail "Wildcard .test DNS" \
            "parked .test domains unavailable — port 53 held by ${_PORT53_OWNER}" \
            "$(_dns_fix_hint "$INTEGRATION_HOST")"
    elif _host_is_pinned backend.test; then
        _fail "Wildcard .test DNS" \
            "backend.test resolves via /etc/hosts, but parked .test domains like ${INTEGRATION_HOST} do not" \
            "$(_dns_fix_hint "$INTEGRATION_HOST")"
    else
        _fail "Wildcard .test DNS" \
            "parked .test domains do not resolve" \
            "$(_dns_fix_hint "$INTEGRATION_HOST")"
    fi
fi

# =============================================================================
# 3. Docker · Colima · Redis
# =============================================================================
_section "Docker · Colima · Redis"

if ! command -v docker >/dev/null 2>&1; then
    if command -v brew >/dev/null 2>&1 && brew list --versions docker >/dev/null 2>&1; then
        _fail "Docker CLI" "docker command not found" "brew link docker"
    else
        _fail "Docker CLI" "docker command not found" "brew install docker"
    fi
else
    _ok "Docker CLI" "$(command -v docker)"
    if _retry 20 3 docker info; then
        _ok "Docker / Colima" "daemon responding"
    else
        _fail "Docker / Colima" "daemon unreachable" "colima stop && colima start --cpu 2 --memory 2 --vm-type vz"
    fi

    _REDIS_STATUS="$(docker inspect -f '{{.State.Status}}' "$WS_REDIS_CONTAINER_NAME" 2>/dev/null || printf 'missing')"
    if [[ "$_REDIS_STATUS" != "running" ]]; then
        # Container may still be starting after Colima came up — retry up to 30s
        _retry 10 3 _redis_container_running || true
        _REDIS_STATUS="$(docker inspect -f '{{.State.Status}}' "$WS_REDIS_CONTAINER_NAME" 2>/dev/null || printf 'missing')"
    fi
    if [[ "$_REDIS_STATUS" == "running" ]]; then
        _REDIS_ID="$(docker inspect -f '{{.Id}}' "$WS_REDIS_CONTAINER_NAME" 2>/dev/null | cut -c1-12)"
        _ok "Redis container" "running (${_REDIS_ID})"
    else
        _fail "Redis container" "status: ${_REDIS_STATUS}" "ws-stop-stack && ws-stack"
    fi
    if _retry 3 1 lsof -nP -iTCP:"$WS_REDIS_PORT" -sTCP:LISTEN; then
        _ok "Redis port $WS_REDIS_PORT" "listening"
    else
        _fail "Redis port $WS_REDIS_PORT" "nothing on port $WS_REDIS_PORT" "ws-stop-stack && ws-stack"
    fi
fi

# =============================================================================
# 4. backend dev server (Vite · backend)
# =============================================================================
_section "backend dev server (Vite · backend)"

# Node process inside backend working directory (retried — npm spawns node after a moment)
if _retry 10 2 pgrep -qf "Herd/backend/node_modules"; then
    _ok "backend node process" "found under backend/node_modules"
else
    _fail "backend node process" "no node process in backend" "ws-stop-stack && ws-stack"
fi

# Vite port 5173 (retried — Vite takes a moment to bind after npm run dev)
if [[ "$RENDER_TEXT" == "1" ]]; then
    printf "  ${DIM}Waiting for Vite on port 5173 …${RESET}\n"
fi
if _retry 10 2 lsof -nP -iTCP:5173 -sTCP:LISTEN; then
    _ok "Vite dev server" "port 5173 listening"
else
    _fail "Vite dev server" "nothing on port 5173" "ws-stop-stack && ws-stack"
fi

# backend app URL (full HTTP check — retry covers PHP/nginx warmup)
# Accepts any HTTP response code other than 000 (connection failure).
# A 404 means nginx+PHP are serving the app; using curl -f would cause a false
# negative on branches where the app has no content at the root URL.
if [[ "$RENDER_TEXT" == "1" ]]; then
    printf "  ${DIM}Waiting for ${WS_APP_URL} …${RESET}\n"
fi
_BACKEND_HTTP=""
for (( _ws_i=1; _ws_i<=WS_HTTP_TRIES; _ws_i++ )); do
    _BACKEND_HTTP="$(curl -ksSo /dev/null -w '%{http_code}' --max-time 5 "${WS_APP_URL}" 2>/dev/null || true)"
    [[ -n "$_BACKEND_HTTP" && "$_BACKEND_HTTP" != "000" ]] && break
    (( _ws_i < WS_HTTP_TRIES )) && sleep "$WS_HTTP_SLEEP"
done
if [[ -n "$_BACKEND_HTTP" && "$_BACKEND_HTTP" != "000" ]]; then
    _ok "backend app HTTP" "${WS_APP_URL} → HTTP ${_BACKEND_HTTP}"
else
    _fail "backend app HTTP" "${WS_APP_URL} not responding" "ws-stop-stack && ws-stack"
fi

# =============================================================================
# 5. Frontend (Frontend)
# =============================================================================
_section "Integration"

if _INTEGRATION_RESOLVED="$(_resolve_host_ip "$INTEGRATION_HOST" 2>/dev/null)"; then
    _ok "Integration DNS" "${INTEGRATION_HOST} → ${_INTEGRATION_RESOLVED}"
else
    _INTEGRATION_PORT53_OWNER="$(_port53_owner 2>/dev/null || true)"
    if [[ -n "$_INTEGRATION_PORT53_OWNER" ]]; then
        _fail "Integration DNS" \
            "${INTEGRATION_HOST} does not resolve — wildcard .test DNS blocked by ${_INTEGRATION_PORT53_OWNER}" \
            "$(_dns_fix_hint "$INTEGRATION_HOST")"
    else
        _fail "Integration DNS" "${INTEGRATION_HOST} does not resolve" "$(_dns_fix_hint "$INTEGRATION_HOST")"
    fi
fi

# Test against /login/system — the first real page Integration serves.
# A 200 means the app is fully up; a 302 redirect to /login/system is also healthy.
_INTEGRATION_CHECK_URL="${INTEGRATION_APP_URL}/login/system"
if [[ "$RENDER_TEXT" == "1" ]]; then
    printf "  ${DIM}Waiting for ${_INTEGRATION_CHECK_URL} …${RESET}\n"
fi
_INTEGRATION_HTTP=""
for (( _integration_i=1; _integration_i<=INTEGRATION_HTTP_TRIES; _integration_i++ )); do
    _INTEGRATION_HTTP="$(curl -kso /dev/null -w '%{http_code}' --max-time 5 "${_INTEGRATION_CHECK_URL}" 2>/dev/null || true)"
    case "$_INTEGRATION_HTTP" in
        200|301|302)
            break
            ;;
    esac
    (( _integration_i < INTEGRATION_HTTP_TRIES )) && sleep "$INTEGRATION_HTTP_SLEEP"
done

case "$_INTEGRATION_HTTP" in
    200|301|302)
        _ok "Integration HTTP" "${_INTEGRATION_CHECK_URL} → HTTP ${_INTEGRATION_HTTP}"
        ;;
    *)
    _fail "Integration HTTP" "${_INTEGRATION_CHECK_URL} not responding" "$(_dns_fix_hint "$INTEGRATION_HOST")"
        ;;
esac

# =============================================================================
# 6. Frontend (Frontend)
# =============================================================================
_section "Frontend (Frontend)"

_FRONTEND_PID="$(_frontend_process_pid)"
_FRONTEND_MATCH_NOTE=""

if [[ -z "$_FRONTEND_PID" ]]; then
    # Frontend startup can lag behind tmux pane creation and netlify handoff.
    _retry "$FRONTEND_PROCESS_TRIES" "$FRONTEND_PROCESS_SLEEP" _frontend_ready_signal >/dev/null
    _FRONTEND_PID="$(_frontend_process_pid)"
fi

if [[ -z "$_FRONTEND_PID" ]]; then
    _FRONTEND_LISTENER_PID="$(_frontend_listener_pid)"
    if _frontend_listener_matches_frontend "$_FRONTEND_LISTENER_PID"; then
        _FRONTEND_PID="$_FRONTEND_LISTENER_PID"
        _FRONTEND_MATCH_NOTE=" (matched via port listener)"
    fi
fi

if [[ -n "$_FRONTEND_PID" ]]; then
    _ok "frontend dev process" "PID ${_FRONTEND_PID}${_FRONTEND_MATCH_NOTE}"
else
    _fail "frontend dev process" "no process found" "ws-stop-frontend && ws-frontend"
fi

# Detect the actual port the frontend / Frontend process is listening on.
# Falls back to the expected default if process detection finds nothing.
# Tests the root path on the detected port and requires HTTP 200.
_FE_DEFAULT_PORT="$WS_FRONTEND_PORT"
_FE_PID_LIST=()
if [[ -n "$_FRONTEND_PID" ]]; then
    _FE_PID_LIST+=("$_FRONTEND_PID")
    while IFS= read -r _child; do
        [[ -n "$_child" ]] && _FE_PID_LIST+=("$_child")
    done < <(pgrep -P "$_FRONTEND_PID" 2>/dev/null || true)
fi
while IFS= read -r _helper_pid; do
    [[ -n "$_helper_pid" ]] && _FE_PID_LIST+=("$_helper_pid")
done < <(pgrep -f 'ws-frontend-debug\.sh run' 2>/dev/null || true)
while IFS= read -r _netlify_pid; do
    [[ -n "$_netlify_pid" ]] && _FE_PID_LIST+=("$_netlify_pid")
done < <(pgrep -f "netlify dev.*--port ${WS_FRONTEND_PORT}" 2>/dev/null || true)
while IFS= read -r _npm_pid; do
    [[ -n "$_npm_pid" ]] && _FE_PID_LIST+=("$_npm_pid")
done < <(pgrep -f "npm run dev -- --host ${_FE_HOST_REGEX} --port ${WS_FRONTEND_TARGET_PORT}" 2>/dev/null || true)
while IFS= read -r _frontend_pid; do
    [[ -n "$_frontend_pid" ]] && _FE_PID_LIST+=("$_frontend_pid")
done < <(pgrep -f 'web-frontend/node_modules/.bin/nuxt' 2>/dev/null || true)
while IFS= read -r _nuxi_pid; do
    [[ -n "$_nuxi_pid" ]] && _FE_PID_LIST+=("$_nuxi_pid")
done < <(pgrep -f 'web-frontend/node_modules/.bin/nuxi|node .*web-frontend.*nuxi.* dev' 2>/dev/null || true)

_FE_AUTH_HEADER="$(_frontend_auth_header)"

_FE_DETECTED_PORT=""
_FE_DETECTED_PORTS=""
# Prefer the port owned by the top-level frontend process when it holds one.
if [[ -n "$_FRONTEND_PID" ]]; then
    _FE_DETECTED_PORTS="$(
        lsof -nP -a -p "$_FRONTEND_PID" -iTCP -sTCP:LISTEN 2>/dev/null \
            | awk 'NR>1 {
                n=split($9,a,":");
                port=a[n]+0
                if (port>1024) print port
              }' \
            | sort -un
    )"
    if printf '%s\n' "$_FE_DETECTED_PORTS" | grep -qx "$_FE_DEFAULT_PORT"; then
        _FE_DETECTED_PORT="$_FE_DEFAULT_PORT"
    elif [[ -n "$_FE_DETECTED_PORTS" ]]; then
        _FE_DETECTED_PORT="$(printf '%s\n' "$_FE_DETECTED_PORTS" | head -1)"
    fi
fi
# If the top-level process itself holds no port yet, fall back to scanning the full process group.
if [[ -z "$_FE_DETECTED_PORT" && ${#_FE_PID_LIST[@]} -gt 0 ]]; then
    _PID_STR="$(printf '%s,' "${_FE_PID_LIST[@]}")"
    _PID_STR="${_PID_STR%,}"
    _FE_DETECTED_PORTS="$(
        lsof -nP -a -p "$_PID_STR" -iTCP -sTCP:LISTEN 2>/dev/null \
            | awk 'NR>1 {
                n=split($9,a,":");
                port=a[n]+0
                if (port>1024) print port
              }' \
            | sort -un
    )"
    if printf '%s\n' "$_FE_DETECTED_PORTS" | grep -qx "$_FE_DEFAULT_PORT"; then
        _FE_DETECTED_PORT="$_FE_DEFAULT_PORT"
    elif [[ -n "$_FE_DETECTED_PORTS" ]]; then
        _FE_DETECTED_PORT="$(printf '%s\n' "$_FE_DETECTED_PORTS" | head -1)"
    fi
fi

_FE_PORT="$_FE_DEFAULT_PORT"
_FE_URL="http://localhost:${_FE_PORT}/"
_FE_PORT_NOTE=""
if [[ -n "$_FE_DETECTED_PORT" && "$_FE_DETECTED_PORT" != "$_FE_DEFAULT_PORT" ]]; then
    _FE_PORT_NOTE=" (detected internal listener ${_FE_DETECTED_PORT}; health check uses public frontend port ${_FE_DEFAULT_PORT})"
elif [[ -z "$_FE_DETECTED_PORT" ]]; then
    _FE_PORT_NOTE=" (process detection found no internal listener, using public frontend port ${_FE_DEFAULT_PORT})"
fi

if [[ "$RENDER_TEXT" == "1" ]]; then
    printf "  ${DIM}Checking ${_FE_URL}${_FE_PORT_NOTE} …${RESET}\n"
fi
_FE_HTTP=""
for (( _fe_i=1; _fe_i<=FRONTEND_HTTP_TRIES; _fe_i++ )); do
    _FE_HTTP="$(_frontend_http_code "$_FE_URL" 5)"
    _frontend_http_healthy && break
    (( _fe_i < FRONTEND_HTTP_TRIES )) && sleep "$FRONTEND_HTTP_SLEEP"
done

if _frontend_http_healthy; then
    if [[ "$_FE_HTTP" == "401" ]]; then
        _ok "Frontend HTTP" "${_FE_URL} → HTTP 401 (Basic Auth challenge responding)${_FE_PORT_NOTE}"
    else
        _ok "Frontend HTTP" "${_FE_URL} → HTTP 200${_FE_PORT_NOTE}"
    fi
else
    _fail "Frontend HTTP" \
        "${_FE_URL} → HTTP ${_FE_HTTP:-no response} (expected 200)${_FE_PORT_NOTE}" \
        "ws-stop-frontend && ws-frontend"
fi

# =============================================================================
# 7. Endpoint response checks (10s)
# =============================================================================
_section "Endpoint response checks (10s)"

_EP_TIMEOUT="10"
_EP_INTEGRATION_URL="https://integration.test/login/system"
_EP_BACKEND_LOGIN_URL="https://backend.test/cp/auth/login"
_EP_FRONTEND_URL="http://localhost:${WS_FRONTEND_PORT}/"

_EP_CODE="$(curl -ksSo /dev/null -w '%{http_code}' --max-time "$_EP_TIMEOUT" "$_EP_INTEGRATION_URL" 2>/dev/null || true)"
if [[ "$_EP_CODE" == "200" ]]; then
    _ok "Integration endpoint" "${_EP_INTEGRATION_URL} → HTTP 200"
else
    _fail "Integration endpoint" "${_EP_INTEGRATION_URL} → HTTP ${_EP_CODE:-000} (expected 200)" "ws-verify"
fi

if _http_responds_within "$_EP_BACKEND_LOGIN_URL" "$_EP_TIMEOUT"; then
    _EP_CODE="$(curl -ksSo /dev/null -w '%{http_code}' --max-time "$_EP_TIMEOUT" "$_EP_BACKEND_LOGIN_URL" 2>/dev/null || true)"
    _ok "backend login endpoint" "${_EP_BACKEND_LOGIN_URL} → HTTP ${_EP_CODE}"
else
    _fail "backend login endpoint" "no response within ${_EP_TIMEOUT}s" "ws-verify"
fi

_FE_HTTP="$(_frontend_http_code "$_EP_FRONTEND_URL" "$_EP_TIMEOUT")"
if _frontend_http_healthy; then
    if [[ "$_FE_HTTP" == "401" ]]; then
        _ok "Frontend endpoint" "${_EP_FRONTEND_URL} → HTTP 401 (Basic Auth challenge responding)"
    else
        _ok "Frontend endpoint" "${_EP_FRONTEND_URL} → HTTP 200"
    fi
else
    _fail "Frontend endpoint" "${_EP_FRONTEND_URL} → HTTP ${_FE_HTTP:-000} (expected 200)" "ws-stop-frontend && ws-frontend"
fi

# =============================================================================
# 8. Frontend cache token
# =============================================================================
_section "Frontend cache token"

_BACKEND_ENV="$WS_BACKEND_APP_DIR/.env"
_FE_ENV="$WS_FRONTEND_APP_DIR/.env"

_BACKEND_CACHE_TOKEN="$(awk -F= '/^NUXT_CACHE_TOKEN=/{print $2}' "$_BACKEND_ENV" 2>/dev/null | tr -d '[:space:]')"
_FE_CACHE_TOKEN="$(awk -F= '/^CACHE_INVALIDATION_TOKEN=/{print $2}' "$_FE_ENV" 2>/dev/null | tr -d '[:space:]')"

if [[ -z "$_BACKEND_CACHE_TOKEN" ]]; then
    _fail "NUXT_CACHE_TOKEN (backend)" \
        "missing or empty in backend/.env — saves will fail with 4xx" \
        "echo 'NUXT_CACHE_TOKEN=local-dev-token' >> $WS_BACKEND_APP_DIR/.env"
else
    _ok "NUXT_CACHE_TOKEN (backend)" "set"
fi

if [[ -z "$_FE_CACHE_TOKEN" ]]; then
    _fail "CACHE_INVALIDATION_TOKEN (web-frontend)" \
        "missing or empty in web-frontend/.env — Frontend will reject all cache-clear requests" \
        "echo 'CACHE_INVALIDATION_TOKEN=local-dev-token' >> $WS_FRONTEND_APP_DIR/.env"
else
    _ok "CACHE_INVALIDATION_TOKEN (web-frontend)" "set"
fi

if [[ -n "$_BACKEND_CACHE_TOKEN" && -n "$_FE_CACHE_TOKEN" ]]; then
    if [[ "$_BACKEND_CACHE_TOKEN" == "$_FE_CACHE_TOKEN" ]]; then
        _ok "cache tokens match" "backend ↔ web-frontend tokens are identical"
    else
        _fail "cache tokens match" \
            "backend NUXT_CACHE_TOKEN ≠ web-frontend CACHE_INVALIDATION_TOKEN — saves will get 401" \
            "Set the same value in both .env files then restart both servers"
    fi
fi

# =============================================================================
# 9. Log watcher
# =============================================================================
_section "Log watcher"

_LOG_PANE="$(_first_alive_pane "APP-logs" "APP-LOGS" "ws-logs" "APP-LOG" "ws-log" || true)"
if [[ -n "$_LOG_PANE" ]]; then
    _ok "log watcher" "${_LOG_PANE} pane alive"
else
    _fail "log watcher" "APP-logs pane is dead" "ws-stop-logs && ws-logs"
fi

# =============================================================================
# Summary
# =============================================================================
_OVERALL_STATUS="UP AND RUNNING"
_OVERALL_ICON="✅"
_OVERALL_COLOR="$GREEN"
if [[ $FAIL_COUNT -gt 0 ]]; then
    _OVERALL_STATUS="HALTED"
    _OVERALL_ICON="❌"
    _OVERALL_COLOR="$RED"
fi

_CAUSE="none"
if [[ ${#ROOT_ISSUES[@]} -gt 0 ]]; then
    _CAUSE="${ROOT_ISSUES[0]}"
fi

_AFFECTED=""
for (( _i=0; _i<${#SECTION_NAMES[@]}; _i++ )); do
    if [[ "${SECTION_FAIL_COUNTS[$_i]}" -gt 0 ]]; then
        if [[ -n "$_AFFECTED" ]]; then
            _AFFECTED+=" · "
        fi
        _AFFECTED+="${SECTION_NAMES[$_i]}"
    fi
done
[[ -z "$_AFFECTED" ]] && _AFFECTED="none"

_ROOT_ISSUES_JSON="$(if [[ ${#ROOT_ISSUES[@]} -eq 0 ]]; then printf '[]'; else printf '%s\n' "${ROOT_ISSUES[@]}" | sed '/^$/d' | jq -R . | jq -s '.'; fi)"
_FIX_PLAN_JSON="$(if [[ ${#FIX_PLAN[@]} -eq 0 ]]; then printf '[]'; else printf '%s\n' "${FIX_PLAN[@]}" | sed '/^$/d' | jq -R . | jq -s '.'; fi)"
_AFFECTED_JSON="$(if [[ "$_AFFECTED" == "none" ]]; then printf '[]'; else printf '%s\n' "$_AFFECTED" | tr '·' '\n' | sed 's/^ *//;s/ *$//' | sed '/^$/d' | jq -R . | jq -s '.'; fi)"
_SECTIONS_JSON="$({
    for (( _i=0; _i<${#SECTION_NAMES[@]}; _i++ )); do
        jq -cn \
            --arg name "${SECTION_NAMES[$_i]}" \
            --argjson pass "${SECTION_PASS_COUNTS[$_i]}" \
            --argjson fail "${SECTION_FAIL_COUNTS[$_i]}" \
            '{name:$name,pass:$pass,fail:$fail,status:(if $fail > 0 then "fail" else "ok" end)}'
    done
} | jq -s '.')"
_ENDPOINTS_JSON="$({
    for (( _i=0; _i<${#ENDPOINT_NAMES[@]}; _i++ )); do
        jq -cn \
            --arg name "${ENDPOINT_NAMES[$_i]}" \
            --arg status "${ENDPOINT_STATES[$_i]}" \
            --arg notes "${ENDPOINT_NOTES[$_i]}" \
            '{name:$name,status:$status,notes:$notes}'
    done
} | jq -s '.')"
_CHECKS_JSON="$(printf '%s\n' "${CHECK_ROWS[@]}" | jq -s '.')"

if [[ "$JSON_MODE" == "1" ]]; then
    jq -n \
        --arg generated_at "$(date -u +%FT%TZ)" \
        --arg overall_status "$_OVERALL_STATUS" \
        --arg overall_icon "$_OVERALL_ICON" \
        --arg cause "$_CAUSE" \
        --argjson pass_count "$PASS_COUNT" \
        --argjson fail_count "$FAIL_COUNT" \
        --argjson root_issues "$_ROOT_ISSUES_JSON" \
        --argjson fix_plan "$_FIX_PLAN_JSON" \
        --argjson affected "$_AFFECTED_JSON" \
        --argjson sections "$_SECTIONS_JSON" \
        --argjson endpoints "$_ENDPOINTS_JSON" \
        --argjson checks "$_CHECKS_JSON" \
        '{
            generated_at:$generated_at,
            overall:{status:(if $overall_status == "UP AND RUNNING" then "ok" else "fail" end),label:$overall_status,icon:$overall_icon,cause:$cause,pass_count:$pass_count,fail_count:$fail_count,affected:$affected},
            root_issues:$root_issues,
            fix_plan:$fix_plan,
            sections:$sections,
            endpoints:$endpoints,
            checks:$checks
        }'
    exit $([[ $FAIL_COUNT -eq 0 ]] && printf 0 || printf 1)
fi

printf "\n${BOLD}STATUS:${RESET} ${_OVERALL_COLOR}${_OVERALL_ICON} ${_OVERALL_STATUS}${RESET}\n"
printf "${BOLD}CAUSE:${RESET} %s\n" "$_CAUSE"
printf "${BOLD}AFFECTED:${RESET} %s\n" "$_AFFECTED"

printf "\n${BOLD}────────────────────────────────${RESET}\n"
printf "${BOLD}🔥 ROOT ISSUES${RESET}\n"
printf "${BOLD}────────────────────────────────${RESET}\n"
if [[ ${#ROOT_ISSUES[@]} -eq 0 ]]; then
    printf "1. none\n"
else
    for (( _i=0; _i<${#ROOT_ISSUES[@]}; _i++ )); do
        printf "%d. %s\n" $(( _i + 1 )) "${ROOT_ISSUES[$_i]}"
    done
fi

printf "\n${BOLD}────────────────────────────────${RESET}\n"
printf "${BOLD}🛠 FIX PLAN${RESET}\n"
printf "${BOLD}────────────────────────────────${RESET}\n"
if [[ ${#FIX_PLAN[@]} -eq 0 ]]; then
    printf "1. none\n"
else
    for (( _i=0; _i<${#FIX_PLAN[@]}; _i++ )); do
        printf "%d. %s\n" $(( _i + 1 )) "${FIX_PLAN[$_i]}"
    done
fi

printf "\n${BOLD}────────────────────────────────${RESET}\n"
printf "${BOLD}SYSTEMS${RESET}\n"
printf "${BOLD}────────────────────────────────${RESET}\n"
for (( _i=0; _i<${#SECTION_NAMES[@]}; _i++ )); do
    _PASS="${SECTION_PASS_COUNTS[$_i]}"
    _FAIL="${SECTION_FAIL_COUNTS[$_i]}"
    _TOTAL=$(( _PASS + _FAIL ))
    if [[ "$_FAIL" -eq 0 ]]; then
        printf "%-22s ✅ OK   (%s checks)\n" "${SECTION_NAMES[$_i]}" "$_TOTAL"
    else
        printf "%-22s ❌ FAIL (%s fail, %s pass)\n" "${SECTION_NAMES[$_i]}" "$_FAIL" "$_PASS"
    fi
done

printf "\n${BOLD}────────────────────────────────${RESET}\n"
printf "${BOLD}ENDPOINTS${RESET}\n"
printf "${BOLD}────────────────────────────────${RESET}\n"
printf "%-12s %-7s %s\n" "Service" "Status" "Notes"
for (( _i=0; _i<${#ENDPOINT_NAMES[@]}; _i++ )); do
    _NAME="${ENDPOINT_NAMES[$_i]}"
    _STATE="${ENDPOINT_STATES[$_i]}"
    _NOTE="${ENDPOINT_NOTES[$_i]}"
    case "$_STATE" in
        success)
            printf "%-12s %-7s %s\n" "${_NAME%% endpoint}" "✅ OK" "${_NOTE:-n/a}"
            ;;
        warn)
            printf "%-12s %-7s %s\n" "${_NAME%% endpoint}" "⚠️ WARN" "${_NOTE:-n/a}"
            ;;
        fail)
            printf "%-12s %-7s %s\n" "${_NAME%% endpoint}" "❌ FAIL" "${_NOTE:-n/a}"
            ;;
        *)
            printf "%-12s %-7s %s\n" "${_NAME%% endpoint}" "⏳ WAIT" "not evaluated"
            ;;
    esac
done

printf "\n${BOLD}══════════════════════════════════════════════${RESET}\n"
if [[ $FAIL_COUNT -eq 0 ]]; then
    printf "${GREEN}${BOLD}  ✅  ALL CHECKS PASSED${RESET}   (%d checks)\n" "$PASS_COUNT"
else
    printf "${RED}${BOLD}  ❌  %d CHECK(S) NEED ATTENTION${RESET}   (%d passed)\n" \
        "$FAIL_COUNT" "$PASS_COUNT"
    printf "\n${BOLD}Issues:${RESET}\n"
    for _msg in "${FAIL_MESSAGES[@]}"; do
        printf "  ${RED}•${RESET} %s\n" "$_msg"
    done
fi
printf "${BOLD}══════════════════════════════════════════════${RESET}\n"
printf "\n${DIM}Re-run at any time:  ws-verify${RESET}\n\n"

[[ $FAIL_COUNT -eq 0 ]]
