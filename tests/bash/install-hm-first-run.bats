#!/usr/bin/env bats
# A first install on NixOS-WSL (wsl-nixos) must converge. The base-tools step
# used to `nix profile install` home-manager, and the Home Manager collision
# check then rejected it (Home Manager ships bin/home-manager itself through
# programs.home-manager.enable), so following the printed fix looped.
# Fake nix profile: `nix profile install/remove` edit a manifest; the fake
# `home-manager switch` fails like the real one when the manifest still holds a
# colliding element, and otherwise adds home-manager-path.

# `! cmd` mid-test cannot fail a test (set -e ignores it): assert absence explicitly.
no() { if "$@"; then echo "unexpected success: $*" >&2; return 1; fi; }

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    export APP_CONFIGS_SELECTION_DIR="$BATS_TEST_TMPDIR/no-selection"
    export CALLS="$BATS_TEST_TMPDIR/calls"
    export STORE="$BATS_TEST_TMPDIR/store"
    export OUT="$BATS_TEST_TMPDIR/out"
    export STUBS="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$HOME/.nix-profile" "$STUBS" "$OUT/home-path/bin" "$STORE/home-manager/bin"
    : >"$CALLS"
    touch "$OUT/home-path/bin/home-manager"
    printf '#!/usr/bin/env bash\nprintf "hm-bin %%s\\n" "$*" >>"$CALLS"\nexit 0\n' >"$STORE/home-manager/bin/home-manager"
    chmod +x "$STORE/home-manager/bin/home-manager"
    ln -s "$STORE/home-manager/bin/home-manager" "$STUBS/home-manager"
    printf '{"elements":{}}\n' >"$HOME/.nix-profile/manifest.json"
    export HM_PROFILE_MANIFEST="$HOME/.nix-profile/manifest.json"
    cat >"$STUBS/nix" <<'STUB'
#!/usr/bin/env bash
printf 'nix %s\n' "$*" >>"$CALLS"
m="$HM_PROFILE_MANIFEST"
case "$1 ${2:-}" in
  "profile install")
    shift 2
    for a in "$@"; do n="${a#nixpkgs#}"; jq --arg n "$n" --arg p "$STORE/$n" '.elements[$n]={originalUrl:"flake:nixpkgs",storePaths:[$p]}' "$m" >"$m.new" && mv "$m.new" "$m"; done ;;
  "profile remove")
    shift 2
    # Like the real thing: the element's binary leaves PATH with it.
    for n in "$@"; do jq --arg n "$n" 'del(.elements[$n])' "$m" >"$m.new" && mv "$m.new" "$m"; rm -f "$STUBS/$n"; done ;;
  "build --no-link") printf '%s\n' "$OUT" ;;
  run*) printf 'nix-run %s\n' "$*" >>"$CALLS"; shift; [ "$1" = nixpkgs#home-manager ] && { shift; [ "$1" = -- ] && shift; "$STORE/home-manager/bin/home-manager" "$@"; } ;;
esac
exit 0
STUB
    chmod +x "$STUBS/nix"
    # Hermetic PATH: the real profile's home-manager must not leak in.
    TOOLS="$BATS_TEST_TMPDIR/tools"; mkdir -p "$TOOLS"
    local t
    for t in bash jq awk sed cat cut sort paste dirname find tail head readlink mktemp mv rm touch grep tr uniq env mkdir sleep sh; do
        ln -sf "$(command -v "$t")" "$TOOLS/$t"
    done
    PATH="$STUBS:$TOOLS"
    : >"$BATS_TEST_TMPDIR/NIXOS"
    export DETECT_HOST_NIXOS_MARKER="$BATS_TEST_TMPDIR/NIXOS" DETECT_HOST_OS_RELEASE="$BATS_TEST_TMPDIR/no-os-release"
    # shellcheck source=/dev/null
    source "$REPO_ROOT/ops/lib/hm-switch.sh"
}

manifest_has() { jq -e --arg n "$1" '.elements | has($n)' "$HM_PROFILE_MANIFEST" >/dev/null; }
bootstrap_profile_install() { nix profile install nixpkgs#chezmoi nixpkgs#home-manager nixpkgs#mise; }

@test "the real machine's state (home-manager in the profile, no HM generation) converges without manual steps" {
    bootstrap_profile_install
    : >"$CALLS"
    run hm_switch /repo/nix wsl
    echo "$output"
    [ "$status" -eq 0 ]
    no manifest_has home-manager
    manifest_has chezmoi
    manifest_has mise
    grep -qx 'nix profile remove home-manager' "$CALLS"
    grep -qx 'hm-bin switch -b hm-bak --flake /repo/nix#wsl-nixos' "$CALLS"
    # the saved binary did the switch: not PATH (removed with the element), not nix run
    no grep -q '^nix-run' "$CALLS"
    no test -e "$STUBS/home-manager"
}

@test "after that, a re-run succeeds too (nothing left to collide)" {
    bootstrap_profile_install
    run hm_switch /repo/nix wsl
    [ "$status" -eq 0 ]
    : >"$CALLS"
    run hm_switch /repo/nix wsl
    [ "$status" -eq 0 ]
    refute_remove
}

refute_remove() { if grep -q 'profile remove' "$CALLS"; then echo "unexpected remove" >&2; return 1; fi; }

@test "no home-manager anywhere (fresh machine): the first switch bootstraps through nix run, nothing is profile-installed" {
    rm "$STUBS/home-manager"
    run hm_switch /repo/nix wsl
    echo "$output"
    [ "$status" -eq 0 ]
    grep -qx 'nix run nixpkgs#home-manager -- switch -b hm-bak --flake /repo/nix#wsl-nixos' "$CALLS"
    no manifest_has home-manager
}

@test "a genuine user collision still fails closed, and nothing is removed" {
    bootstrap_profile_install
    mkdir -p "$STORE/parallel/bin"; touch "$STORE/parallel/bin/parallel" "$OUT/home-path/bin/parallel"
    jq --arg p "$STORE/parallel" '.elements.parallel={originalUrl:"flake:nixpkgs",storePaths:[$p]}' "$HM_PROFILE_MANIFEST" >"$HM_PROFILE_MANIFEST.new" && mv "$HM_PROFILE_MANIFEST.new" "$HM_PROFILE_MANIFEST"
    : >"$CALLS"
    run hm_switch /repo/nix wsl
    [ "$status" -ne 0 ]
    [[ "$output" == *"parallel"* ]]
    manifest_has parallel
    manifest_has home-manager
    if grep -q 'profile remove\|hm-bin' "$CALLS"; then cat "$CALLS"; return 1; fi
}

@test "the collision message is one line per package with a file count" {
    mkdir -p "$STORE/parallel/bin" "$STORE/parallel/share"
    local i
    for i in 1 2 3; do touch "$STORE/parallel/share/f$i" "$OUT/home-path/share/f$i" 2>/dev/null || { mkdir -p "$OUT/home-path/share"; touch "$STORE/parallel/share/f$i" "$OUT/home-path/share/f$i"; }; done
    touch "$STORE/parallel/bin/parallel" "$OUT/home-path/bin/parallel"
    jq --arg p "$STORE/parallel" '.elements.parallel={originalUrl:"flake:nixpkgs",storePaths:[$p]}' "$HM_PROFILE_MANIFEST" >"$HM_PROFILE_MANIFEST.new" && mv "$HM_PROFILE_MANIFEST.new" "$HM_PROFILE_MANIFEST"
    run hm_switch /repo/nix wsl
    [ "$status" -ne 0 ]
    [ "$(printf '%s\n' "$output" | grep -c 'parallel')" -ge 1 ]
    printf '%s\n' "$output" | grep -qE "^  parallel: 4 file\(s\)"
    [[ "$output" != *" ships "* ]]
    [[ "$output" == *"nix profile remove parallel"* ]]
}

@test "the install base-tools step no longer profile-installs home-manager" {
    run grep -nE 'for t in chezmoi mise home-manager lefthook' "$REPO_ROOT/ops/install.sh"
    [ "$status" -ne 0 ]
}
