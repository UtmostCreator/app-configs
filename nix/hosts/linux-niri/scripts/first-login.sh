#!/usr/bin/env bash
# Ordinary-user setup from the local installation receipt, safe to repeat.
set -euo pipefail
umask 077

restore_checkout() (
  set -eu
  local bundle=$1 revision=$2 destination=$3 ref=$4 temp
  if [[ -e $destination || -L $destination ]]; then
    [[ ! -L $destination && -e $destination/.git && ! -L $destination/.git ]] &&
      [[ $(git -C "$destination" rev-parse --show-toplevel) == "$destination" ]]
    exit $?
  fi
  temp=$(mktemp -d "${destination%/*}/.app-configs-XXXXXXXX")
  trap 'rm -rf -- "$temp"' EXIT
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_ALLOW_PROTOCOL=file
  git -c init.templateDir= init -q --initial-branch=main "$temp/repo" || exit 1
  git -C "$temp/repo" -c core.hooksPath=/dev/null fetch -q --no-tags "$bundle" "$ref" || exit 1
  [[ $(git -C "$temp/repo" rev-parse FETCH_HEAD) == "$revision" ]] || exit 1
  git -C "$temp/repo" -c core.hooksPath=/dev/null checkout -q -B main FETCH_HEAD || exit 1
  git -C "$temp/repo" remote add origin https://github.com/UtmostCreator/app-configs.git || exit 1
  git -C "$temp/repo" config branch.main.remote origin || exit 1
  git -C "$temp/repo" config branch.main.merge refs/heads/main || exit 1
  mv -nT -- "$temp/repo" "$destination" && [[ ! -e $temp/repo ]]
)

trusted_receipt() {
  local path=$1 owner mode
  [[ -f $path && $(realpath -e -- "$path") == "$path" ]] || return 1
  for path in "${path%/*}" "$path"; do
    read -r owner mode < <(stat -c '%u %a' -- "$path") || return 1
    [[ $owner == 0 ]] && (( (8#$mode & 0022) == 0 )) || return 1
  done
}

setup_login() (
  local receipts=$1
  shift
  local reports="$HOME/Documents/app-configs-setup" repo="$HOME/Projects/app-configs"
  local revision ref dir run result=0 bundle="$receipts/install.bundle" rc=0
  local -a missing=()
  local -a tools=(chezmoi mise lefthook)
  local -a packages=("$@")
  [[ ${#packages[@]} == 3 && -d $HOME && ! -L $HOME && -O $HOME ]] || exit 2
  app-configs-verify-first-boot --storage-only || {
    echo 'FAIL  Storage preflight. Inspect this user service in the journal.' >&2
    exit 1
  }
  for dir in "$HOME/Documents" "$HOME/Projects"; do
    [[ ! -L $dir && -d $dir && -O $dir ]] || {
      echo "Review the type and ownership of ${dir##*/} in the account home" >&2
      exit 1
    }
  done
  [[ ! -L $reports ]] || exit 1
  [[ -e $reports ]] || mkdir -m 0700 -- "$reports" || exit 1
  [[ -d $reports && -O $reports && $(stat -c %a "$reports") == 700 ]] || exit 1
  exec 9<"$reports"
  flock -w 5 9 || { echo 'Another setup report is in progress' >&2; exit 1; }
  if [[ -L $reports/Latest ]]; then
    [[ $(readlink "$reports/Latest") =~ ^run-[[:alnum:]-]+$ ]] || exit 1
  elif [[ -e $reports/Latest ]]; then
    echo 'Review the existing Latest file in the setup folder' >&2; exit 1
  fi
  run=$(mktemp -d "$reports/run-$(date -u +%Y%m%dT%H%M%SZ)-XXXXXXXX")
  local summary="$run/Summary.txt" detail="$run/Details.log"
  printf 'Niri setup report • %s UTC\n' "$(date -u '+%F %T')" > "$summary"
  printf '%s START  Local first-login setup\n' "$(date -u +%FT%TZ)" > "$detail"
  status() {
    printf '%s\n' "$*" >> "$summary" || exit 1
    printf '%s  %s\n' "$(date -u +%FT%TZ)" "$*" >> "$detail" || exit 1
  }
  step() {
    local label=$1 code=0
    shift
    printf '%s START %s\n' "$(date -u +%FT%TZ)" "$label" >> "$detail" || exit 1
    # No raw shell, Git, account or authentication output in user reports.
    "$@" >/dev/null 2>&1 || code=$?
    if (( code )); then
      status "FAIL  $label (exit $code)"
      result=1
    else
      status "PASS  $label"
    fi
    return "$code"
  }
  status 'PASS  Root health and installation disk topology'
  if trusted_receipt "$receipts/install-stages"; then
    # Do not export raw installer output even if a restored file is malformed.
    printf 'Installer stages on the live system (UTC):\n' >> "$detail"
    LC_ALL=C grep -Ex '[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z elapsed=[0-9]+s stage=0[1-8]/08 (started|verified)' \
      "$receipts/install-stages" >> "$detail" ||
      status 'WARN  No readable installer stage timestamps'
  else
    status 'INFO  No installer timeline receipt on this deployment'
  fi
  revision=''
  if trusted_receipt "$receipts/install-revision"; then
    read -r revision < "$receipts/install-revision" || revision=''
  fi
  ref=''
  if [[ $revision =~ ^[0-9a-f]{40}$ ]] && trusted_receipt "$bundle"; then
    ref=$(git bundle list-heads "$bundle" refs/heads/main HEAD 2>/dev/null |
      awk -v sha="$revision" '$1 == sha && ($2 == "HEAD" || $2 == "refs/heads/main") && !found {print $2; found=1}') || ref=''
  fi
  if [[ -n $ref ]]; then
    status "PASS  Installation bundle names recorded commit $revision"
    step 'Restore missing checkout or preserve existing checkout' restore_checkout "$bundle" "$revision" "$repo" "$ref" || :
    step 'Seed missing interactive shell and SSH client loaders' app-configs-seed-shell "$bundle" "$revision" || :
  else
    status 'FAIL  Restore the matching install.bundle and install-revision in /var/lib/app-configs'
    result=1
  fi
  for i in "${!tools[@]}"; do
    if ! command -v "${tools[i]}" >/dev/null; then
      missing+=("${packages[i]}")
    fi
  done
  if (( ${#missing[@]} )); then
    step 'Add missing bootstrap tools from the offline Nix store' nix --offline profile add "${missing[@]}" || :
  fi
  for tool in "${tools[@]}"; do
    step "$tool available to user" type -P "$tool" || :
  done
  if [[ $revision =~ ^[0-9a-f]{40}$ ]]; then
    local recorded='' current='' child verify_arg=--current-profile
    if trusted_receipt "$receipts/install-system"; then
      read -r recorded < "$receipts/install-system" || recorded=''
    fi
    if [[ $recorded =~ ^/nix/store/[a-z0-9]{32}-nixos-system-linux-niri-[A-Za-z0-9._-]+$ ]]; then
      status "INFO  Original installed system: $recorded"
      current=$(readlink -e /run/booted-system) || current=''
      if [[ $current == "$recorded" ]]; then verify_arg=$recorded; fi
      child=$(readlink -e "$recorded/specialisation/nvidia-open") || child=''
      if [[ -n $child && $current == "$child" ]]; then verify_arg=$recorded; fi
    else
      status 'INFO  Original system path unavailable. Checking registered generation.'
    fi
    # Later generations may have a newer checkout; preserve install provenance.
    if [[ $verify_arg != --current-profile ]] && {
      [[ $(git -C "$repo" rev-parse HEAD 2>/dev/null) != "$revision" ]] ||
      [[ -n $(git --no-optional-locks -C "$repo" status --porcelain 2>/dev/null) ]]
    }; then
      verify_arg=--current-profile
    fi
    app-configs-verify-first-boot "$verify_arg" "$revision" >> "$detail" || rc=$?
    if (( rc )); then
      status "FAIL  Installed profile verification (exit $rc). See Details.log"
      result=1
    else
      status 'PASS  Installed profile verification'
    fi
  fi
  status 'ACTION  Sign in to Codex/Claude or enrol an SSH identity when needed.'
  status 'ACTION  Test audio, Bluetooth and suspend with your devices.'
  status 'INFO  Private installer logs: sudo ls -lt /var/log/app-configs/'
  status 'INFO  Run sys-readiness to repeat verification.'
  if (( result )); then status 'RESULT  Review failed steps before updating'; else status 'RESULT  Automatic steps passed'; fi
  ln -s -- "${run##*/}" "$run/.latest"
  mv -Tf -- "$run/.latest" "$reports/Latest"
  printf 'Setup report: %s/Latest/Summary.txt\n' "$reports"
  exit "$result"
)

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  (( EUID != 0 )) || { echo 'Run as the installed ordinary user' >&2; exit 2; }
  setup_login /var/lib/app-configs "$@"
fi
