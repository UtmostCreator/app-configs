#!/usr/bin/env bats

setup() {
  source "$BATS_TEST_DIRNAME/../../nix/hosts/linux-niri/scripts/first-login.sh"
  export HOME="$BATS_TEST_TMPDIR/home"
  kit="$BATS_TEST_TMPDIR/kit"
  source_repo="$BATS_TEST_TMPDIR/source"
  mkdir -p "$HOME/Projects" "$HOME/Documents" "$kit" "$source_repo" "$HOME/.nix-profile/bin"
  export PATH="$HOME/.nix-profile/bin:$PATH" GIT_CONFIG_GLOBAL=/dev/null
  git -C "$source_repo" init -q -b main
  git -C "$source_repo" -c user.name=test -c user.email=test@example.invalid commit -q --allow-empty -m fixture
  rev=$(git -C "$source_repo" rev-parse HEAD)
  printf '%s\n' "$rev" > "$kit/install-revision"
  git -C "$source_repo" bundle create "$kit/install.bundle" main
  runner=(setup_login "$kit" /fixture/chezmoi /fixture/mise /fixture/lefthook)
  report="$HOME/Documents/app-configs-setup"
  checkout="$HOME/Projects/app-configs"
  # Production checks root ownership. The Git contents here are real fixtures.
  trusted_receipt() { [[ -f $1 && ! -L $1 ]]; }
  app-configs-verify-first-boot() { [[ ${unsafe:-0} == 0 ]]; }
  app-configs-seed-shell() { [[ $1 == "$kit/install.bundle" && $2 == "$rev" ]]; }
  for tool in chezmoi mise lefthook; do
    ln -s "$(type -P true)" "$HOME/.nix-profile/bin/$tool"
  done
}

@test "restores a main bundle offline and preserves an edited branch on repeat login" {
  run "${runner[@]}"
  [ "$status" -eq 0 ]
  [ "$(git -C "$checkout" rev-parse HEAD)" = "$rev" ]
  [ "$(git -C "$checkout" remote get-url origin)" = https://github.com/UtmostCreator/app-configs.git ]
  [ "$(git -C "$checkout" config branch.main.merge)" = refs/heads/main ]
  [ "$(stat -c %a "$report")" = 700 ]
  [ "$(stat -c %a "$report/Latest/Summary.txt")" = 600 ]
  [ "$(stat -c %a "$report/Latest/Details.log")" = 600 ]
  grep -Fq 'RESULT  Automatic steps passed' "$report/Latest/Summary.txt"
  first=$(readlink "$report/Latest")
  git -C "$checkout" switch -qc local
  echo work > "$checkout/progress"
  run "${runner[@]}"
  [ "$status" -eq 0 ]
  [ "$first" != "$(readlink "$report/Latest")" ]
  [ -s "$report/$first/Summary.txt" ]
  [ "$(git -C "$checkout" branch --show-current)" = local ]
  [ "$(cat "$checkout/progress")" = work ]
}

@test "restores the HEAD-only offline bundle from the manual installation" {
  git -C "$source_repo" bundle create "$kit/legacy.bundle" HEAD
  mv "$kit/legacy.bundle" "$kit/install.bundle"
  run "${runner[@]}"
  [ "$status" -eq 0 ]
  [ "$(git -C "$checkout" rev-parse HEAD)" = "$rev" ]
}

@test "mismatched receipt yields a visible failure without publishing a checkout" {
  printf '%040d\n' 1 > "$kit/install-revision"
  run "${runner[@]}"
  [ "$status" -ne 0 ]
  [ ! -e "$checkout" ]
  grep -Fq 'FAIL  Restore the matching' "$report/Latest/Summary.txt"
}

@test "failed root health gate precedes report and checkout writes" {
  unsafe=1
  run "${runner[@]}"
  [ "$status" -ne 0 ]
  [ ! -e "$report" ]
  [ ! -e "$checkout" ]
}

@test "refuses linked report parent and preserves occupied checkout destination" {
  rmdir "$HOME/Documents"
  ln -s "$kit" "$HOME/Documents"
  run "${runner[@]}"
  [ "$status" -ne 0 ]
  [ ! -e "$kit/app-configs-setup" ]
  unlink "$HOME/Documents"
  mkdir "$HOME/Documents" "$checkout"
  touch "$checkout/keep"
  run "${runner[@]}"
  [ "$status" -ne 0 ]
  [ -f "$checkout/keep" ]
  [ ! -e "$checkout/.git" ]
  grep -q '^FAIL  Restore missing checkout' "$report/Latest/Summary.txt"
}

@test "preserves an unrelated Latest link and its destination" {
  mkdir -m 700 "$report"
  ln -s "$kit" "$report/Latest"
  run "${runner[@]}"
  [ "$status" -ne 0 ]
  [ "$(readlink "$report/Latest")" = "$kit" ]
  [ ! -e "$kit/Summary.txt" ]
}

@test "offline bootstrap records a profile failure and reports missing executables" {
  unlink "$HOME/.nix-profile/bin/mise"
  # Override discovery only for the deliberately missing fixture binary.
  command() { if [[ $* == '-v mise' ]]; then return 1; fi; builtin command "$@"; }
  nix() {
    [[ $* == '--offline profile add /fixture/mise' ]] || return 99
    return 23
  }
  run "${runner[@]}"
  [ "$status" -ne 0 ]
  grep -Fq 'offline Nix store (exit 23)' "$report/Latest/Summary.txt"
}

@test "includes only allowlisted stage timings in the ordinary user detail log" {
  printf '%s\n' '2026-11-24T20:00:00Z elapsed=120s stage=07/08 verified' \
    'unreviewed fixture output' > "$kit/install-stages"
  run "${runner[@]}"
  [ "$status" -eq 0 ]
  grep -Fq 'elapsed=120s stage=07/08 verified' "$report/Latest/Details.log"
  ! grep -Fq 'unreviewed fixture' "$report/Latest/Details.log"
}

@test "honours an existing linked Git worktree in the projects folder" {
  git -C "$source_repo" worktree add -q -b local "$checkout"
  run "${runner[@]}"
  [ "$status" -eq 0 ]
  [ -f "$checkout/.git" ]
  [ "$(git -C "$checkout" branch --show-current)" = local ]
}
