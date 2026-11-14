#!/usr/bin/env bats
#
# ops/cleanup.sh against stub tools only: the real system is never touched.
# Every external command (nix, mise, npm, home-manager, nix-collect-garbage)
# is a stub that logs its argv to $STUB_LOG and fails when FAIL_<NAME>=1.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  export NO_COLOR=1
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export STUB_LOG="$BATS_TEST_TMPDIR/calls.log"
  : > "$STUB_LOG"
  STUBS="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUBS"
  for tool in nix mise npm home-manager nix-collect-garbage; do
    name="$(printf '%s' "$tool" | tr 'a-z-' 'A-Z_')"
    cat > "$STUBS/$tool" <<STUB
#!/usr/bin/env bash
printf '%s %s\n' "$tool" "\$*" >> "\$STUB_LOG"
if [[ "$tool \$1" == "home-manager generations" ]]; then
  [[ -n "\${HM_GENS:-}" ]] && cat "\$HM_GENS"
  exit 0
fi
[[ "\${FAIL_$name:-0}" == 1 ]] && exit 1
exit 0
STUB
    chmod +x "$STUBS/$tool"
  done
  # Generations, newest first, as `home-manager generations` prints them.
  HM_GENS="$BATS_TEST_TMPDIR/gens"
  local now spec
  now="$(date +%s)"
  : > "$HM_GENS"
  for spec in "10:1" "9:20" "8:30" "7:40"; do
    printf '%s : id %s -> /nix/store/x-home-manager-generation\n' \
      "$(date -d "@$((now - ${spec#*:} * 86400))" '+%Y-%m-%d %H:%M')" "${spec%:*}" >> "$HM_GENS"
  done
  export HM_GENS
}

clean() { run env PATH="$STUBS:$PATH" bash "$REPO_ROOT/ops/cleanup.sh" "$@"; }
# Run with a PATH that has the stubs and the basic tools but no home-manager,
# so a system-installed home-manager cannot leak in.
clean_no_hm() {
  local iso="$BATS_TEST_TMPDIR/iso-bin" t p
  mkdir -p "$iso"
  for t in bash env awk sed df wc cat date grep tr mkdir; do
    p="$(command -v "$t")" && ln -sf "$p" "$iso/$t"
  done
  rm -f "$STUBS/home-manager"
  run env PATH="$STUBS:$iso" "$iso/bash" "$REPO_ROOT/ops/cleanup.sh" "$@"
}
not_called() { run grep -q -- "$1" "$STUB_LOG"; [ "$status" -ne 0 ]; }

@test "all steps succeed: exit 0" {
  clean --apply --yes --gc
  [ "$status" -eq 0 ]
}

@test "a failing tool makes the script exit non-zero" {
  export FAIL_NIX=1
  clean --apply --yes
  [ "$status" -ne 0 ]
}

@test "remaining steps still run after a failure, and the summary names every failed step" {
  export FAIL_NIX=1 FAIL_MISE=1 FAIL_NPM=1
  clean --apply --yes
  [ "$status" -ne 0 ]
  grep -q '^npm cache verify' "$STUB_LOG"
  [[ "$output" == *"3 step(s) failed"* ]]
  [[ "$output" == *"nix store optimise"* ]]
  [[ "$output" == *"mise cache prune"* ]]
  [[ "$output" == *"npm cache verify"* ]]
}

@test "report mode exits 0 and runs nothing" {
  clean
  [ "$status" -eq 0 ]
  not_called '^nix \|^mise \|^npm '
}

@test "uses mise cache prune, never clear" {
  clean --apply --yes
  grep -qx 'mise cache prune' "$STUB_LOG"
  not_called 'mise cache clear'
}

@test "KEEP_DAYS defaults to 14 and is overridable" {
  clean --apply --yes --gc
  grep -qx 'nix-collect-garbage --delete-older-than 14d' "$STUB_LOG"
  : > "$STUB_LOG"
  export KEEP_DAYS=30
  clean --apply --yes --gc
  grep -qx 'nix-collect-garbage --delete-older-than 30d' "$STUB_LOG"
}

@test "without protection, aged generations are expired as before" {
  clean --apply --yes --gc
  grep -qx 'home-manager expire-generations -14 days' "$STUB_LOG"
}

@test "--protect-hm-generation: protected aged generation is never removed" {
  clean --apply --yes --gc --protect-hm-generation 8
  [ "$status" -eq 0 ]
  not_called 'expire-generations'
  not_called 'delete-older-than'
  removed="$(grep '^home-manager remove-generations' "$STUB_LOG")"
  [[ " $removed " == *" 9 "* ]]
  [[ " $removed " == *" 7 "* ]]
  [[ " $removed " != *" 8 "* ]]
  [[ " $removed " != *" 10 "* ]]
}

@test "PROTECT_HM_GENERATIONS env (space-separated) and flag are merged" {
  export PROTECT_HM_GENERATIONS="9 7"
  clean --apply --yes --gc --protect-hm-generation 8
  [ "$status" -eq 0 ]
  not_called '^home-manager remove-generations'
  not_called 'expire-generations'
}

@test "protection never lets the global age-based GC run" {
  export PROTECT_HM_GENERATIONS="8"
  clean --apply --yes --gc
  not_called 'delete-older-than'
  grep -q '^nix-collect-garbage $' "$STUB_LOG"
}

@test "non-numeric protected generation is rejected before anything runs" {
  clean --apply --yes --gc --protect-hm-generation abc
  [ "$status" -ne 0 ]
  [ ! -s "$STUB_LOG" ]
}

@test "--protect-hm-generation without a value is rejected" {
  clean --apply --yes --protect-hm-generation
  [ "$status" -ne 0 ]
  [ ! -s "$STUB_LOG" ]
}

@test "protected generation survives every GC path: no age-based or delete-all flags anywhere" {
  export PROTECT_HM_GENERATIONS="8"
  clean --apply --yes --gc
  [ "$status" -eq 0 ]
  not_called 'delete-older-than'
  not_called 'expire-generations'
  not_called ' -d\b'
  not_called 'delete-generations'
  not_called 'remove-generations.* 8\b'
  not_called '^nix-env'
}

@test "protection cannot be established: GC is skipped and exit is non-zero" {
  export PROTECT_HM_GENERATIONS="8"
  cat > "$STUBS/home-manager" <<'STUB'
#!/usr/bin/env bash
printf 'home-manager %s\n' "$*" >> "$STUB_LOG"
[[ "$1" == generations ]] && exit 1
exit 0
STUB
  clean --apply --yes --gc
  [ "$status" -ne 0 ]
  [[ "$output" == *"protection not established"* ]]
  not_called 'nix-collect-garbage'
  not_called 'remove-generations'
}

@test "empty --protect-hm-generation value is rejected, nothing runs" {
  clean --apply --yes --gc --protect-hm-generation ""
  [ "$status" -ne 0 ]
  [ ! -s "$STUB_LOG" ]
}

@test "PROTECT_HM_GENERATIONS set but with no valid id is rejected" {
  export PROTECT_HM_GENERATIONS="   "
  clean --apply --yes --gc
  [ "$status" -ne 0 ]
  [ ! -s "$STUB_LOG" ]
}

@test "tab and newline separated env ids are all protected" {
  export PROTECT_HM_GENERATIONS=$'9\t7\n8'
  clean --apply --yes --gc
  [ "$status" -eq 0 ]
  not_called '^home-manager remove-generations'
}

@test "leading-zero id is normalised and protects that generation" {
  clean --apply --yes --gc --protect-hm-generation 08
  [ "$status" -eq 0 ]
  removed="$(grep '^home-manager remove-generations' "$STUB_LOG")"
  [[ " $removed " == *" 9 "* ]]
  [[ " $removed " != *" 8 "* ]]
}

@test "protected GC runs nix profile wipe-history with KEEP_DAYS" {
  clean --apply --yes --gc --protect-hm-generation 8
  grep -qx 'nix profile wipe-history --older-than 14d' "$STUB_LOG"
}

@test "the newest generation is kept even when it is aged" {
  : > "$HM_GENS"
  printf '%s : id 5 -> /nix/store/x\n%s : id 4 -> /nix/store/x\n' \
    "$(date -d @$(( $(date +%s) - 40 * 86400 )) '+%Y-%m-%d %H:%M')" \
    "$(date -d @$(( $(date +%s) - 50 * 86400 )) '+%Y-%m-%d %H:%M')" >> "$HM_GENS"
  clean --apply --yes --gc --protect-hm-generation 1
  removed="$(grep '^home-manager remove-generations' "$STUB_LOG")"
  [[ " $removed " == *" 4 "* ]]
  [[ " $removed " != *" 5 "* ]]
}

@test "non-numeric KEEP_DAYS is rejected before anything runs" {
  export KEEP_DAYS="14; rm"
  clean --apply --yes --gc
  [ "$status" -ne 0 ]
  [ ! -s "$STUB_LOG" ]
}

@test "--help prints the full header and no code" {
  clean --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Exit status"* ]]
  [[ "$output" != *"set -uo pipefail"* ]]
}

@test "gc without home-manager warns that HM generations were not aged" {
  clean_no_hm --apply --yes --gc
  [[ "$output" == *"home-manager not on PATH"* ]]
}

@test "KEEP_DAYS with a leading zero is decimal: 031 means 31 days for the HM cutoff" {
  : > "$HM_GENS"
  local now; now="$(date +%s)"
  printf '%s : id 5 -> /nix/store/x\n%s : id 4 -> /nix/store/x\n%s : id 3 -> /nix/store/x\n' \
    "$(date -d "@$((now - 1 * 86400))" '+%Y-%m-%d %H:%M')" \
    "$(date -d "@$((now - 28 * 86400))" '+%Y-%m-%d %H:%M')" \
    "$(date -d "@$((now - 40 * 86400))" '+%Y-%m-%d %H:%M')" >> "$HM_GENS"
  export KEEP_DAYS=031
  clean --apply --yes --gc --protect-hm-generation 1
  [ "$status" -eq 0 ]
  removed="$(grep '^home-manager remove-generations' "$STUB_LOG")"
  [[ " $removed " == *" 3 "* ]]
  [[ " $removed " != *" 4 "* ]]
  grep -qx 'nix profile wipe-history --older-than 31d' "$STUB_LOG"
}

@test "KEEP_DAYS=08 is accepted as 8 days, not an octal error" {
  export KEEP_DAYS=08
  clean --apply --yes --gc
  [ "$status" -eq 0 ]
  grep -qx 'nix-collect-garbage --delete-older-than 8d' "$STUB_LOG"
}

@test "protected gc without home-manager warns and still runs the safe GC" {
  export PROTECT_HM_GENERATIONS=8
  clean_no_hm --apply --yes --gc
  [[ "$output" == *"home-manager not on PATH"* ]]
  grep -q '^nix-collect-garbage $' "$STUB_LOG"
}
