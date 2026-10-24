#!/usr/bin/env bash
# One-paste, read-only context bundle: answers the first round of "what is this host, clock, model,
# load, backlog, OOM history and log coverage?" in a single run instead of 10+ separate pastes.
# Every section runs even if another fails; failures print "-- exit=N" and are listed in the summary,
# and the script then exits 3. Missing data is never presented as healthy.
# Usage: incident-bundle.sh [SINCE="6 hours ago"] [UNTIL="now"]   (journal interval)
# Env: LOG_DIR=/var/log/apache2  APACHE_CONF_DIR=/etc/apache2  APP_ROOT=<app dir, optional>
#      ALLOW_ARTISAN=1 also runs `artisan about/schedule:list` (boots the framework: needs the execution gate).
#      SECTION_TIMEOUT=30 bounds each section (seconds); a slow or hung reader is reported as exit=124.
set -uo pipefail
(( $# <= 2 )) || { echo 'usage: incident-bundle.sh [SINCE] [UNTIL]' >&2; exit 2; }
since=${1:-'6 hours ago'}
until=${2:-now}
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
log_dir=${LOG_DIR:-/var/log/apache2}
conf_dir=${APACHE_CONF_DIR:-/etc/apache2}
section_timeout=${SECTION_TIMEOUT:-30}
if ! [[ $section_timeout =~ ^[1-9][0-9]*$ ]]; then echo 'SECTION_TIMEOUT must be a positive integer' >&2; exit 2; fi
export log_dir conf_dir
failed=()

section() {
  local name=$1 rc=0
  shift
  echo "== $name =="
  timeout --kill-after=2 "$section_timeout" bash -c '"$@"' _ "$@" 2>&1 || rc=$?
  if (( rc == 124 || rc == 137 )); then
    echo "-- exit=$rc (timed out after ${section_timeout}s)"; failed+=("$name")
  elif (( rc != 0 )); then
    echo "-- exit=$rc"; failed+=("$name")
  fi
}

clock() { date -u +'%Y-%m-%dT%H:%M:%SZ' && timedatectl show -p Timezone -p NTPSynchronized; }
host_load() { uptime && printf 'cores=%s\n' "$(nproc)" && free -m && vmstat 1 3; }
apache_model() {
  apache2ctl -V | grep -E 'Server (version|MPM)'
  apache2ctl -M | grep -E 'mpm_|php|proxy_fcgi|remoteip|status_module|unique_id'
}
apache_config() {
  grep -RhnE '^[[:space:]]*(MaxRequestWorkers|ServerLimit|MaxConnectionsPerChild|Timeout|KeepAlive|KeepAliveTimeout|LogFormat|CustomLog|ErrorLogFormat|RemoteIP)' \
    "$conf_dir/apache2.conf" "$conf_dir/mods-enabled" "$conf_dir/sites-enabled" "$conf_dir/conf-enabled"
}
workers() {
  printf 'apache2 processes=%s\n' "$(pgrep -c -x apache2 || true)"
  echo 'process states (R=running/runnable, S=sleeping):'
  ps -C apache2 -o stat= | cut -c1 | sort | uniq -c
  echo 'listen sockets (Recv-Q on LISTEN = accept backlog waiting for a worker; Send-Q = backlog limit):'
  ss -Hltn '( sport = :80 or sport = :443 )'
  echo 'tcp states on :80/:443:'
  ss -Htan '( sport = :80 or sport = :443 )' | awk '{print $1}' | sort | uniq -c
}
first_stamp() { sed -nE '1{s/^[^[]*\[([^]]+)\].*/\1/p;}'; }
log_inventory() {
  local f name first last
  shopt -s nullglob
  local files=("$log_dir"/*access*.log* "$log_dir"/*error*.log*)
  (( ${#files[@]} )) || { echo "no access/error logs under $log_dir"; return 1; }
  for f in "${files[@]}"; do
    name=${f##*/}
    if [[ $f == *.gz ]]; then
      first=$(gzip -cd -- "$f" 2>/dev/null | head -n 1 | first_stamp)
      last='not-read(gzip)'
    else
      first=$(head -n 1 -- "$f" | first_stamp)
      last=$(tail -n 1 -- "$f" | first_stamp)
    fi
    printf '%s first=%s last=%s bytes=%s\n' "$name" "${first:-empty-or-unreadable}" "${last:-empty-or-unreadable}" "$(wc -c < "$f")"
  done
  echo 'Boundaries show coverage only; access [..] is request receipt time, error [..] has no offset (verify via RB-01/EVD-02).'
}
php_runtime() {
  echo "CLI only (not the Apache/FPM SAPI): $(php -v | head -n 1)"
  shopt -s nullglob
  local ini=(/etc/php/*/apache2/php.ini /etc/php/*/apache2/conf.d/*.ini /etc/php/*/fpm/php.ini /etc/php/*/fpm/pool.d/*.conf)
  if (( ${#ini[@]} )); then
    grep -HnE '^[[:space:]]*(memory_limit|max_execution_time|opcache\.(enable|memory_consumption|max_accelerated_files|validate_timestamps|revalidate_freq)|pm\.max_children|php_admin_value\[memory_limit\])' "${ini[@]}" || echo 'no matching directives (defaults apply)'
  else
    echo 'no apache2/fpm php.ini found: effective web SAPI settings unknown'
  fi
}
release() {
  printf 'resolved=%s\n' "$(readlink -f -- "$APP_ROOT")"
  echo 'bootstrap/cache (config.php/routes-*.php/events.php absent = not cached):'
  ls -1 -- "$APP_ROOT/bootstrap/cache"
}
application() {
  php "$APP_ROOT/artisan" about --only=drivers
  php "$APP_ROOT/artisan" schedule:list
}

export -f clock host_load apache_model apache_config workers first_stamp log_inventory php_runtime release application

section 'clock' clock
section 'host load' host_load
section 'apache model' apache_model
section 'apache config' apache_config
section 'workers and backlog' workers
section 'kernel OOM' bash "$here/oom-events.sh" "$since" "$until"
section 'apache unit journal' bash "$here/service-recovery.sh" apache2 "$since" "$until"
section 'log inventory' log_inventory
section 'php runtime config' php_runtime
if [[ -n ${APP_ROOT:-} ]]; then
  section 'release' release
  if [[ ${ALLOW_ARTISAN:-} == 1 ]]; then section 'application (boots the framework)' application; fi
fi

echo '== summary =='
if (( ${#failed[@]} )); then
  printf 'failed=%s (unknown, not healthy: %s)\n' "${#failed[@]}" "$(IFS=,; echo "${failed[*]}")"
  exit 3
fi
echo 'failed=0'
