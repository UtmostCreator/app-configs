#!/usr/bin/env bash
# shellcheck shell=bash
# Preflight checks shared by install.sh, bootstrap.sh, update-all.sh and the
# other mutating ops scripts, so one cannot lose a guard the others have.
#
# Contract for callers: define fail "<message>" (print and exit non-zero) and
# warn "<message>" before calling the functions that report through them.
#
#   preflight_bats_guard TAG WHAT REPO_ROOT   refuse to mutate from a bats test
#   preflight_host_checks REPO_ROOT PROFILE   WSL1 refusal + username check
#   preflight_personal_yaml REPO_ROOT PROFILE RUNNER...
#                                             seed personal.yaml when missing
#   preflight_refresh_nix_path                make fresh nix-profile tools visible

# True when $1 is inside $2, comparing as given and with $2 resolved, so a
# symlinked temp root (macOS /var -> /private/var) does not defeat the guard.
_preflight_under() {
  local path="$1" root="$2" real
  # Anchored: the root itself or a path inside it. A bare prefix match also
  # accepted siblings such as "$root-evil".
  [[ "$path" == "$root" || "$path" == "$root"/* ]] && return 0
  real="$(cd -P "$root" 2>/dev/null && pwd)" || return 1
  [[ "$path" == "$real" || "$path" == "$real"/* ]]
}

# Under bats a mutating run must stay inside the test's scratch directory:
# both HOME and the repository it mutates. An install test that forgot
# --dry-run once switched Home Manager on the developer's machine, and a test
# that pointed HOME at scratch but ran the real repo would still rewrite it.
# Call this only for a run that would mutate. Exit status 3.
preflight_bats_guard() {
  local tag="$1" what="$2" repo_root="$3"
  [[ -n "${BATS_TEST_TMPDIR:-}" ]] || return 0
  if _preflight_under "$HOME" "$BATS_TEST_TMPDIR" && _preflight_under "$repo_root" "$BATS_TEST_TMPDIR"; then
    return 0
  fi
  printf '[%s] refusing %s from a bats test (HOME=%s, repo=%s); use a dry run, or a scratch HOME and a repo copy under $BATS_TEST_TMPDIR\n' \
    "$tag" "$what" "$HOME" "$repo_root" >&2
  exit 3
}

# Home Manager builds for the username in nix/vars/default.nix. A different
# login user (common on WSL, where the distro asks for a new name) would only
# fail later inside home-manager switch, so stop here with the fix. The value
# is evaluated by Nix, not scraped with sed, so any valid way of writing the
# attribute works and a broken file is an error, not "no check". Needs nix.
preflight_check_login_user() {
  local repo_root="$1" nix_user login_user err why
  err="$(mktemp)" || fail "cannot create a temp file"
  if ! nix_user="$(nix eval --raw -f "$repo_root/nix/vars/default.nix" username 2>"$err")"; then
    why="$(tail -n 3 "$err" | tr '\n' ' ')"
    rm -f "$err"
    fail "cannot read username from nix/vars/default.nix (nix eval failed: $why)"
  fi
  rm -f "$err"
  [[ -n "$nix_user" ]] || fail "nix/vars/default.nix has an empty username"
  login_user="${USER:-$(id -un)}"
  if [[ "$login_user" != "$nix_user" ]]; then
    fail "login user '$login_user' does not match username '$nix_user' in nix/vars/default.nix. Log in as '$nix_user' (WSL: create that user and set it as [user] default in /etc/wsl.conf), or change username and homeDirectory there."
  fi
}

# The wsl profile means WSL2. Refuse WSL1 before installing anything.
preflight_wsl_check() {
  local repo_root="$1" profile="$2"
  if [[ "$profile" == wsl && "$(bash "$repo_root/ops/detect-host.sh" --wsl-version)" == 1 ]]; then
    fail "WSL1 is not supported (no systemd, no real Linux kernel for Nix). Convert from PowerShell: wsl --set-version <distro> 2   (list distros: wsl --list --verbose)"
  fi
}

# Combined host preflight (install.sh and bootstrap.sh): WSL1 refusal, then the
# login-user check. With Nix installed the user is read with `nix eval`. Without
# Nix (fresh machine) the authoritative check has to wait until Nix exists, so a
# best-effort sed match of nix/vars/default.nix runs instead. MODE, the third
# argument, says what a mismatch does there: "fail" (the default, bootstrap)
# stops; "warn" (install.sh, which re-checks after its Nix step) only warns.
# Any other MODE is a caller bug and fails closed.
preflight_host_checks() {
  local repo_root="$1" profile="$2" mode="${3:-fail}"
  case "$mode" in
    fail | warn) ;;
    *) fail "preflight_host_checks: unknown mode '$mode' (use fail or warn)" ;;
  esac
  preflight_wsl_check "$repo_root" "$profile"
  if command -v nix >/dev/null 2>&1; then
    preflight_check_login_user "$repo_root"
    return 0
  fi
  local early_user login_user="${USER:-$(id -un)}"
  early_user="$(sed -nE 's/^[[:space:]]*username = "([^"]+)";.*/\1/p' "$repo_root/nix/vars/default.nix" 2>/dev/null || true)"
  [[ -n "$early_user" && "$login_user" != "$early_user" ]] || return 0
  if [[ "$mode" == warn ]]; then
    warn "login user '$login_user' differs from username '$early_user' in nix/vars/default.nix (best-effort early warning; the authoritative check runs once Nix is installed)"
  else
    fail "login user '$login_user' does not match username '$early_user' in nix/vars/default.nix. Log in as '$early_user' (WSL: create that user and set it as [user] default in /etc/wsl.conf), or change username and homeDirectory there."
  fi
}

# Personal data must exist (chezmoi + flake need it). Create it from the
# example when missing so installation can proceed unattended. The Git template
# treats the example identity as unset until the user replaces it. RUNNER is
# the caller's dry-run-aware command wrapper (it prints instead of running in
# a dry run).
preflight_personal_yaml() {
  local repo_root="$1" profile="$2"; shift 2
  local target="$repo_root/home/.chezmoidata/personal.yaml"
  local example="$repo_root/home/personal.yaml.example"
  [[ -f "$target" ]] && return 0
  [[ -f "$example" ]] || fail "no personal.yaml and no example to seed from"
  warn "home/.chezmoidata/personal.yaml missing; seeding from example for host '$profile'. Git identity remains unset until you edit it."
  "$@" bash "$repo_root/ops/seed-personal-yaml.sh" "$example" "$target" "$profile"
}

# Refresh PATH so freshly installed nix-profile tools are visible. Tests set
# NIX_PATH_REFRESH=0 so a real system Nix cannot shadow their PATH stubs.
preflight_refresh_nix_path() {
  [[ "${NIX_PATH_REFRESH:-1}" == 0 ]] && return 0
  local f
  for f in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
           "$HOME/.nix-profile/etc/profile.d/nix.sh" /etc/profile.d/nix.sh; do
    # shellcheck disable=SC1090
    [[ -r "$f" ]] && . "$f" || true
  done
  export PATH="$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:$PATH"
}
