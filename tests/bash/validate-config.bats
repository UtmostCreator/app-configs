#!/usr/bin/env bats
# ops/validate-config.sh: architecture invariants, run by the pre-commit hook.
# Each test builds a tiny repo (good tree) and breaks exactly one thing.
# VALIDATE_CONFIG_SCRIPT overrides the script under test (used to prove a
# fixture fails on an older version).

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="${VALIDATE_CONFIG_SCRIPT:-$REPO_ROOT/ops/validate-config.sh}"
    R="$BATS_TEST_TMPDIR/repo"
    mkdir -p "$R/ops" "$R/home/.chezmoidata" "$R/repo-docs" "$R/nix/modules/home"
    cp "$SCRIPT" "$R/ops/validate-config.sh"
    git -C "$R" init -q
    printf 'home\n' >"$R/.chezmoiroot"
    printf 'name: x\n' >"$R/home/personal.yaml.example"
    for d in migration-source-of-truth migration-package-ownership; do
        printf '# Doc\n\n| a | b |\n|---|---|\n| 1 | done |\n\nEvery TBD row resolved.\n' >"$R/repo-docs/$d.md"
    done
    printf '{ pkgs, ... }:\n{\n  home.packages = with pkgs; [ jq ];\n}\n' >"$R/nix/modules/home/ok.nix"
    STUBS="$BATS_TEST_TMPDIR/bin"; mkdir -p "$STUBS"
    unset VALIDATE_EVAL_PROFILES
}

validate() { git -C "$R" add -A; run bash "$R/ops/validate-config.sh"; }
# add a path the real .gitignore would hide
track() { mkdir -p "$(dirname "$R/$1")"; printf 'x: 1\n' >"$R/$1"; git -C "$R" add -f "$1"; }

@test "good tree passes" {
    validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"all invariants pass"* ]]
}

@test "rule 1: .chezmoiroot with other content fails" {
    printf 'other\n' >"$R/.chezmoiroot"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *".chezmoiroot must contain exactly 'home'"* ]]
}

@test "rule 1: .chezmoiroot with whitespace inside the word fails" {
    printf 'ho me\n' >"$R/.chezmoiroot"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *".chezmoiroot must contain exactly 'home'"* ]]
}

@test "rule 1: missing .chezmoiroot fails" {
    rm "$R/.chezmoiroot"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *".chezmoiroot missing"* ]]
}

@test "rule 2: home/.chezmoiscripts fails and the message names that directory" {
    mkdir "$R/home/.chezmoiscripts"; : >"$R/home/.chezmoiscripts/run_once_x.sh"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"home/.chezmoiscripts/ exists"* ]]
}

@test "rule 2: home/.chezmoiops also fails" {
    mkdir "$R/home/.chezmoiops"; : >"$R/home/.chezmoiops/run_once_x.sh"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"home/.chezmoiops/ exists"* ]]
}

@test "rule 4: an unignored personal.yaml in the working tree fails" {
    printf 'a: 1\n' >"$R/home/.chezmoidata/personal.yaml"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"NOT gitignored"* ]]
}

@test "rule 4: a gitignored personal.yaml is fine" {
    printf 'a: 1\n' >"$R/home/.chezmoidata/personal.yaml"
    printf 'home/.chezmoidata/personal.yaml\n' >"$R/.gitignore"
    validate
    [ "$status" -eq 0 ]
}

@test "rule 5: tracked secret paths fail" {
    local p
    for p in home/personal.yaml home/.chezmoidata/personal.yaml home/.chezmoidata/personal.local.yaml \
             projects.yaml home/projects.yaml .env .env.local config/.env.production; do
        track "$p"
        run bash "$R/ops/validate-config.sh"
        [ "$status" -ne 0 ] || { echo "not rejected: $p"; return 1; }
        [[ "$output" == *"tracked secret path"*"$p"* ]] || { echo "unreported: $p: $output"; return 1; }
        git -C "$R" rm -q -f --cached "$p"; rm -f "$R/$p"
    done
}

@test "rule 5: a tracked secret path is caught even when the working-tree file is gone" {
    track home/personal.yaml
    rm "$R/home/personal.yaml"
    run bash "$R/ops/validate-config.sh"   # the index still lists it
    [ "$status" -ne 0 ]
    [[ "$output" == *"tracked secret path"* ]]
}

@test "rule 5: examples and .env.example are allowed" {
    track .env.example
    track home/projects.yaml.example
    validate
    [ "$status" -eq 0 ]
}

@test "rule 9: an empty audit doc fails" {
    : >"$R/repo-docs/migration-source-of-truth.md"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"audit doc is empty"* ]]
}

@test "rule 9: TBD variants in table cells fail" {
    local cell
    for cell in '| TBD |' '|TBD|' '| tbd |' '| TBD (later) |' '| TBC |' '| TODO |' '| ? |'; do
        printf '# Doc\n\n| a | b |\n|---|---|\n| 1 %s\n' "$cell" >"$R/repo-docs/migration-package-ownership.md"
        validate
        [ "$status" -ne 0 ] || { echo "not rejected: $cell"; return 1; }
        [[ "$output" == *"unresolved TBD"* ]]
    done
}

@test "rule 9: the word TBD in prose and in longer cells is fine" {
    printf '# Doc\n\n| a | b |\n|---|---|\n| 1 | TBD rows are tracked elsewhere |\n\nEvery TBD row resolved.\n' \
        >"$R/repo-docs/migration-package-ownership.md"
    validate
    [ "$status" -eq 0 ]
}

@test "rule 10: an untracked nix file fails" {
    git -C "$R" add -A
    printf '{ }\n' >"$R/nix/modules/home/new.nix"
    run bash "$R/ops/validate-config.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"untracked *.nix"* ]]
}

@test "git failing is a validation failure, not a silent pass" {
    printf '#!/bin/sh\nexit 3\n' >"$STUBS/git"; chmod +x "$STUBS/git"
    PATH="$STUBS:$PATH" run bash "$R/ops/validate-config.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"git"* ]]
}

@test "git ls-files failing mid-run is reported" {
    printf '#!/bin/sh\ncase "$1" in ls-files) exit 3;; esac\nexec %s "$@"\n' "$(command -v git)" >"$STUBS/git"
    chmod +x "$STUBS/git"
    git -C "$R" add -A
    PATH="$STUBS:$PATH" run bash "$R/ops/validate-config.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"git ls-files failed"* ]]
}

# --- Home Manager policy (rules 6-8), on comment/string-stripped Nix -------

# nixmod <path under nix/modules/home> <body>: write a module with the body
# inside the usual { pkgs, lib, ... }: { } wrapper.
nixmod() {
    mkdir -p "$(dirname "$R/nix/modules/home/$1")"
    printf '{ pkgs, lib, config, ... }:\n{\n%s\n}\n' "$2" >"$R/nix/modules/home/$1"
}

@test "rule 6: forbidden programs.<x>.enable spellings all fail" {
    local body
    local -a bodies=(
        'programs.git.enable = true;'
        'programs.git = { enable = true; };'
        'programs = { git.enable = true; };'
        'programs = { git = { enable = true; }; };'
        'programs.git.enable = lib.mkDefault true;'
        'programs.git = lib.mkIf pkgs.stdenv.isLinux { enable = true; };'
        'programs.git.enable = lib.mkIf pkgs.stdenv.isLinux true;'
        'config = lib.mkIf true { programs.git.enable = true; };'
        'config = lib.mkMerge [ { programs.git.enable = true; } ];'
        'programs.git.enable =
           true;'
    )
    for body in "${bodies[@]}"; do
        nixmod ok.nix "$body"
        validate
        [ "$status" -ne 0 ] || { echo "not rejected: $body"; return 1; }
        [[ "$output" == *"forbidden programs.<x>.enable"*"programs.git.enable"* ]] || { echo "unreported: $body: $output"; return 1; }
    done
}

@test "rule 6: allowlisted modules, disabled modules and sub-options pass" {
    nixmod ok.nix 'programs.home-manager.enable = true;
  programs.vicinae = { enable = true; systemd.enable = true; };
  programs.openclaw.enable = true;
  services.syncthing = { enable = true; };
  programs.git.enable = false;
  programs.fish.enable = lib.mkForce false;
  systemd.user.services.foo.enable = true;
  options.programs.bar.enable = lib.mkEnableOption "bar";'
    validate
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "rule 6: commented-out and in-string programs lines are ignored" {
    nixmod ok.nix "# programs.git.enable = true;
  /* programs.git.enable = true; */
  x = \"programs.git.enable = true;\";
  y = ''
    programs.git.enable = true;
  '';"
    validate
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "rule 6: services.<x>.enable fails in Home Manager modules but not in NixOS modules" {
    nixmod ok.nix 'services.foo.enable = true;'
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"forbidden services.<x>.enable"* ]]
    nixmod ok.nix 'services.syncthing.enable = true;'
    mkdir -p "$R/nix/modules/nixos"
    printf '{ ... }:\n{\n  services.keyd.enable = true;\n}\n' >"$R/nix/modules/nixos/keyd.nix"
    validate
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "rule 6: programs.<x>.enable in a NixOS module still fails" {
    mkdir -p "$R/nix/modules/nixos"
    printf '{ ... }:\n{\n  programs.git.enable = true;\n}\n' >"$R/nix/modules/nixos/git.nix"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"forbidden programs.<x>.enable"* ]]
}

@test "rules 7/8: bootstrap tools and direnv in a multi-line home.packages list fail" {
    local tool
    for tool in mise chezmoi home-manager lefthook direnv pkgs.mise; do
        nixmod ok.nix "home.packages = with pkgs; [
    jq
    $tool
    ripgrep
  ];"
        validate
        [ "$status" -ne 0 ] || { echo "not rejected: $tool"; return 1; }
        [[ "$output" == *"${tool#pkgs.}"*"home.packages"* ]] || { echo "unreported: $tool: $output"; return 1; }
    done
}

@test "rules 7/8: tools in other list shapes fail" {
    local body
    local -a bodies=(
        'home.packages = (with pkgs; [ jq ]) ++ [ pkgs.mise ];'
        'home.packages = lib.optionals true [ pkgs.chezmoi ];'
        'home.packages = let extra = [ pkgs.jq ]; in extra ++ [ pkgs.lefthook ];'
        'home = { packages = with pkgs; [
    direnv ]; };'
        'x = with pkgs; [
    mise
  ];'
    )
    for body in "${bodies[@]}"; do
        nixmod ok.nix "$body"
        validate
        [ "$status" -ne 0 ] || { echo "not rejected: $body"; return 1; }
    done
}

@test "rules 7/8: tool names in comments, strings and longer names are fine" {
    nixmod ok.nix 'home.packages = with pkgs; [
    jq # mise is installed by bootstrap
    mise-completions
    nix-direnv
  ];
  x = "mise";
  # never include direnv, chezmoi, home-manager or lefthook here'
    validate
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "rule 7: no [OK] line is printed for a rule that reported errors" {
    nixmod ok.nix 'home.packages = with pkgs; [
    mise
  ];'
    validate
    [ "$status" -ne 0 ]
    [[ "$output" != *"[OK]   bootstrap"* ]]
}

@test "a scan that fails is a validation failure" {
    printf '#!/bin/sh\nexit 4\n' >"$STUBS/awk"; chmod +x "$STUBS/awk"
    git -C "$R" add -A
    PATH="$STUBS:$PATH" run bash "$R/ops/validate-config.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"scan failed"* ]]
}

# --- xdg.configFile allowlist and path collisions (rules 11-12) ------------

@test "rule 11: allowlisted xdg.configFile keys pass in every spelling" {
    nixmod ok.nix 'xdg.configFile."flameshot/flameshot.ini".text = "x";
  xdg.configFile."wireplumber/wireplumber.conf.d/51-kanto-ora4.conf" = lib.mkIf true { text = "x"; };
  xdg.configFile = { "gremlins/gremlins/.gremlins.yaml".text = "x"; };
  xdg = { configFile."mimeapps.list".text = "x"; };
  xdg.configFile."systemd/user/foo.service".force = true;
  xdg.configFile."systemd/user/${n}.timer".force = true;'
    validate
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "rule 11: other xdg.configFile keys fail in every spelling" {
    local body
    local -a bodies=(
        'xdg.configFile."fish/config.fish".text = "x";'
        'xdg.configFile."fish/config.fish" = { text = "x"; };'
        'xdg.configFile = { "fish/config.fish".text = "x"; };'
        'xdg = { configFile."fish/config.fish".text = "x"; };'
        'xdg.configFile = lib.mkIf true { "fish/config.fish".text = "x"; };'
        'xdg.configFile."${n}/x.conf".text = "x";'
        'xdg.configFile."flameshot/flameshot.ini.bak".text = "x";'
        'xdg.configFile."systemd/other/x".text = "x";'
    )
    for body in "${bodies[@]}"; do
        nixmod ok.nix "$body"
        validate
        [ "$status" -ne 0 ] || { echo "not rejected: $body"; return 1; }
        [[ "$output" == *"is not allowlisted"* ]] || { echo "unreported: $body: $output"; return 1; }
    done
}

@test "rule 11: xdg.configFile = <expr> is a note in text mode, not a failure" {
    nixmod ok.nix 'xdg.configFile = takeOver;'
    validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"[NOTE]"*"--eval"* ]]
}

@test "rule 11: a commented-out xdg.configFile is ignored" {
    nixmod ok.nix '# xdg.configFile."fish/config.fish".text = "x";'
    validate
    [ "$status" -eq 0 ]
}

# collision fixtures: an allowlisted HM target that is also a chezmoi source
collide() {
    nixmod ok.nix 'xdg.configFile."flameshot/flameshot.ini".text = "x";'
    mkdir -p "$R/home/dot_config/flameshot"
    printf '[General]\n' >"$R/home/dot_config/flameshot/$1"
}

@test "rule 12: an allowlisted target that is also a chezmoi source fails" {
    local src
    for src in flameshot.ini private_flameshot.ini flameshot.ini.tmpl executable_flameshot.ini.tmpl; do
        rm -rf "$R/home/dot_config"
        collide "$src"
        validate
        [ "$status" -ne 0 ] || { echo "not rejected: $src"; return 1; }
        [[ "$output" == *"collides with chezmoi source home/dot_config/flameshot/$src"* ]] || { echo "unreported: $src: $output"; return 1; }
    done
}

@test "rule 12: a dot_ directory and a top-level file collide too" {
    nixmod ok.nix 'xdg.configFile."mimeapps.list".text = "x";
  xdg.configFile."gremlins/gremlins/.gremlins.yaml".text = "x";'
    mkdir -p "$R/home/dot_config/gremlins/gremlins"
    printf 'a: 1\n' >"$R/home/dot_config/mimeapps.list"
    printf 'a: 1\n' >"$R/home/dot_config/gremlins/gremlins/dot_gremlins.yaml"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"\"mimeapps.list\""*"collides"* ]]
    [[ "$output" == *"\"gremlins/gremlins/.gremlins.yaml\""*"collides"* ]]
}

@test "rule 12: no collision when .chezmoiignore excludes the target on Linux" {
    collide flameshot.ini
    printf '{{- if ne .chezmoi.os "darwin" }}\n# HM owns it on Linux\n.config/flameshot\n.config/flameshot/**\n{{- end }}\n' >"$R/home/.chezmoiignore"
    validate
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "rule 12: an ignore line only for darwin, or commented out, does not count" {
    collide flameshot.ini
    printf '{{- if eq .chezmoi.os "darwin" }}\n.config/flameshot\n{{- end }}\n# .config/flameshot\n' >"$R/home/.chezmoiignore"
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"collides"* ]]
}

@test "rule 12: a different chezmoi file in the same directory is not a collision" {
    collide other.ini
    validate
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

# --- --eval: the policy on the evaluated config (rule 13) ------------------

GOOD_EVAL='{"packages":["jq","home-manager"],"programs":["home-manager","man","vicinae"],"services":["syncthing","vicinae"],"xdg":["flameshot/flameshot.ini","systemd/user/x.service","nix/nix.conf","dconf/.keep"]}'

# eval_with <json>: stub nix to print the JSON for every profile; calls are logged
eval_with() {
    printf '%s\n' "$1" >"$BATS_TEST_TMPDIR/eval.json"
    printf '#!/bin/sh\necho called >>"%s/nix.log"\ncat "%s/eval.json"\n' "$BATS_TEST_TMPDIR" "$BATS_TEST_TMPDIR" >"$STUBS/nix"
    chmod +x "$STUBS/nix"
    git -C "$R" add -A
    PATH="$STUBS:$PATH" run bash "$R/ops/validate-config.sh" --eval
}

@test "--eval: a policy-conforming evaluated config passes, one eval per profile" {
    eval_with "$GOOD_EVAL"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"evaluated Home Manager config follows the policy"* ]]
    [ "$(wc -l <"$BATS_TEST_TMPDIR/nix.log")" -eq 4 ]
}

@test "--eval: violations in the evaluated config fail" {
    local json
    local -a bad=(
        '{"packages":["jq","mise"],"programs":[],"services":[],"xdg":[]}'
        '{"packages":["direnv"],"programs":[],"services":[],"xdg":[]}'
        '{"packages":["home-manager"],"programs":[],"services":[],"xdg":[]}'
        '{"packages":[],"programs":["git"],"services":[],"xdg":[]}'
        '{"packages":[],"programs":[],"services":["foo"],"xdg":[]}'
        '{"packages":[],"programs":[],"services":[],"xdg":["fish/config.fish"]}'
    )
    for json in "${bad[@]}"; do
        eval_with "$json"
        [ "$status" -ne 0 ] || { echo "not rejected: $json"; return 1; }
        [[ "$output" == *"evaluated"* ]] || { echo "unreported: $json: $output"; return 1; }
    done
}

@test "--eval: an evaluated xdg key that is also a chezmoi source fails" {
    mkdir -p "$R/home/dot_config/flameshot"
    printf '[General]\n' >"$R/home/dot_config/flameshot/flameshot.ini"
    eval_with "$GOOD_EVAL"
    [ "$status" -ne 0 ]
    [[ "$output" == *"collides with chezmoi source"* ]]
}

@test "--eval: a failing or garbled nix eval is a failure" {
    printf '#!/bin/sh\nexit 1\n' >"$STUBS/nix"; chmod +x "$STUBS/nix"
    git -C "$R" add -A
    PATH="$STUBS:$PATH" run bash "$R/ops/validate-config.sh" --eval
    [ "$status" -ne 0 ]
    [[ "$output" == *"nix eval failed"* ]]
    eval_with 'not json'
    [ "$status" -ne 0 ]
    [[ "$output" == *"nix eval failed"* ]]
}

@test "the default run never calls nix" {
    printf '#!/bin/sh\necho called >>"%s/nix.log"\nexit 1\n' "$BATS_TEST_TMPDIR" >"$STUBS/nix"; chmod +x "$STUBS/nix"
    validate_with_stubs() { git -C "$R" add -A; PATH="$STUBS:$PATH" run bash "$R/ops/validate-config.sh"; }
    validate_with_stubs
    [ "$status" -eq 0 ]
    [ ! -e "$BATS_TEST_TMPDIR/nix.log" ]
}

@test "an unknown argument is a usage error" {
    run bash "$R/ops/validate-config.sh" --bogus
    [ "$status" -eq 2 ]
    [[ "$output" == *"usage:"* ]]
}

# --- fail-closed and quoting regressions (review follow-ups) ---------------

@test "rule 9: an awk that errors is a scan failure, not a pass" {
    printf '#!/bin/sh\ncase "$1" in -F*) exit 2;; esac\nexec %s "$@"\n' "$(command -v awk)" >"$STUBS/awk"
    chmod +x "$STUBS/awk"
    git -C "$R" add -A
    PATH="$STUBS:$PATH" run bash "$R/ops/validate-config.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"audit doc scan failed"* ]]
    [[ "$output" != *"[OK]   audit doc"* ]]
}

@test "a failing find means no [OK] for the nix rules" {
    printf '#!/bin/sh\nexit 1\n' >"$STUBS/find"; chmod +x "$STUBS/find"
    git -C "$R" add -A
    PATH="$STUBS:$PATH" run bash "$R/ops/validate-config.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"find failed"* ]]
    [[ "$output" != *"[OK]   only allowlisted"* ]]
    [[ "$output" != *"[OK]   bootstrap"* ]]
    [[ "$output" != *"[OK]   xdg"* ]]
    [[ "$output" != *"[OK]   no xdg.configFile target"* ]]
}

@test "git missing from PATH fails closed" {
    mkdir "$BATS_TEST_TMPDIR/empty"
    cd "$R"
    PATH="$BATS_TEST_TMPDIR/empty" run "$(command -v bash)" "$R/ops/validate-config.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"git not found"* ]]
}

@test "rule 6: quoted attribute names of allowlisted modules pass, others fail" {
    nixmod ok.nix 'programs."home-manager".enable = true;
  services."syncthing".enable = true;
  programs."vicinae" = { enable = true; };'
    validate
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    nixmod ok.nix 'programs."vicinae.x".enable = true;'
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"forbidden programs.<x>.enable"* ]]
    nixmod ok.nix 'programs."git".enable = true;'
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"forbidden programs.<x>.enable"* ]]
}

@test "--eval: a failing nix eval shows the tail of its stderr" {
    printf '#!/bin/sh\necho "error: attribute boom missing" >&2\nexit 1\n' >"$STUBS/nix"; chmod +x "$STUBS/nix"
    git -C "$R" add -A
    PATH="$STUBS:$PATH" run bash "$R/ops/validate-config.sh" --eval
    [ "$status" -ne 0 ]
    [[ "$output" == *"attribute boom missing"* ]]
}
