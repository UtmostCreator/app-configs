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

GOOD_EVAL='{"packages":["jq","home-manager"],"programs":["home-manager","man","vicinae"],"services":["syncthing","vicinae"],"xdg":["flameshot/flameshot.ini","systemd/user/x.service","nix/nix.conf","dconf/.keep"],"files":[".local/share/x",".config/flameshot/flameshot.ini",".config/systemd/user/x.service",".config/nix/nix.conf",".config/dconf/.keep"]}'

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
        '{"packages":["jq","mise"],"programs":[],"services":[],"xdg":[],"files":[]}'
        '{"packages":["direnv"],"programs":[],"services":[],"xdg":[],"files":[]}'
        '{"packages":["home-manager"],"programs":[],"services":[],"xdg":[],"files":[]}'
        '{"packages":[],"programs":["git"],"services":[],"xdg":[],"files":[]}'
        '{"packages":[],"programs":[],"services":["foo"],"xdg":[],"files":[]}'
        '{"packages":[],"programs":[],"services":[],"xdg":["fish/config.fish"],"files":[]}'
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

# --- T-0014 F7: home.file must not declare a chezmoi-owned path -------------

# chezsrc <path under home/>: a tracked chezmoi source file
chezsrc() { mkdir -p "$(dirname "$R/home/$1")"; printf 'x\n' >"$R/home/$1"; }

@test "rule 12: home.file on a chezmoi-owned path fails in every spelling" {
    local body
    local -a bodies=(
        'home.file.".zshrc".text = "x";'
        'home.file.".zshrc" = { text = "x"; };'
        'home.file = { ".zshrc".text = "x"; };'
        'home.file = { ".zshrc" = { source = ./x; }; };'
        'home = { file = { ".zshrc".source = ./x; }; };'
        'home.file = lib.mkMerge [ { ".zshrc".text = "x"; } ];'
        'home.file."./.zshrc".text = "x";'
        'home.file."zshrc-link".text = "x"; home.file."zshrc-link".target = ".zshrc";'
        'home.file."zshrc-link" = { target = ".zshrc"; text = "x"; };'
        'home.file.".zshrc".text = "x"; # trailing comment'
    )
    chezsrc dot_zshrc
    for body in "${bodies[@]}"; do
        nixmod ok.nix "$body"
        validate
        [ "$status" -ne 0 ] || { echo "not rejected: $body"; return 1; }
        [[ "$output" == *"home.file.\".zshrc\""*"collides with chezmoi source home/dot_zshrc"* ]] || { echo "unreported: $body: $output"; return 1; }
    done
}

@test "rule 12: home.file collides with every chezmoi source spelling and nested targets" {
    local src
    for src in dot_zshrc private_dot_zshrc dot_zshrc.tmpl executable_dot_zshrc.tmpl; do
        rm -rf "$R/home"/*zshrc*
        chezsrc "$src"
        nixmod ok.nix 'home.file.".zshrc".text = "x";'
        validate
        [ "$status" -ne 0 ] || { echo "not rejected: $src"; return 1; }
        [[ "$output" == *"collides with chezmoi source home/$src"* ]] || { echo "unreported: $src: $output"; return 1; }
    done
    rm -rf "$R/home"/*zshrc*
    chezsrc private_dot_config/fish/config.fish
    nixmod ok.nix 'home.file.".config/fish/config.fish".text = "x";'
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"collides with chezmoi source home/private_dot_config/fish/config.fish"* ]]
}

@test "rule 12: a home.file directory that contains a chezmoi target collides" {
    chezsrc private_dot_ssh/config
    nixmod ok.nix 'home.file.".ssh".source = ./ssh;'
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"home.file.\".ssh\""*"collides"* ]]
}

@test "rule 12: an xdg.configFile target under private_dot_config is a chezmoi target too" {
    chezsrc private_dot_config/mimeapps.list
    nixmod ok.nix 'xdg.configFile."mimeapps.list".text = "x";'
    validate
    [ "$status" -ne 0 ]
    [[ "$output" == *"\"mimeapps.list\""*"collides"* ]]
}

@test "rule 12: valid home.file declarations pass and are reported as checked" {
    chezsrc dot_zshrc
    chezsrc dot_zshrc.d/extra.zsh
    chezsrc run_once_setup.sh
    chezsrc .chezmoiignore
    nixmod ok.nix 'home.file.".zsh".text = "x";
  home.file.".zshrc2".text = "x";
  home.file.".local/share/foo".text = "x";
  # home.file.".zshrc".text = "commented out";
  programs.home-manager.enable = true;
  home.sessionVariables.NOTE = "home.file.\".zshrc\".text = x";'
    validate
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"[OK]   no literal home.file target is also a live chezmoi source"* ]]
}

@test "rule 12: a home.file in a NixOS module is not a Home Manager declaration" {
    chezsrc dot_zshrc
    mkdir -p "$R/nix/modules/nixos"
    printf '{ ... }:\n{\n  home.file.".zshrc".text = "x";\n}\n' >"$R/nix/modules/nixos/x.nix"
    validate
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "rule 12: dynamic home.file declarations are a NOTE, never an [OK]" {
    local body
    local -a bodies=(
        'home.file."${name}".text = "x";'
        'home.file."${config.home.homeDirectory}/x".text = "x";'
        'home.file = lib.mapAttrs (n: v: { text = v; }) { a = "1"; };'
        'home.file = files;'
        'home.file = { ".a".text = "1"; } // extra;'
        'home.file.".a".target = "${name}";'
        'home.file.".a" = { target = lib.mkForce ".zshrc"; text = "x"; };'
        'home.file.zsh = base;'
        'home.file.zsh = mkZsh ".zshrc";'
        'home.file = mkLinks { zsh = { text = "x"; }; };'
        'home.file = lib.attrsets.mapAttrs'"'"' (n: v: lib.nameValuePair ".zshrc" v) { a = { text = "x"; }; };'
        'home.file = pkgs.lib.genAttrs [ ".zshrc" ] (n: { text = "x"; });'
        'home.file.zsh = { inherit target; };'
        'home.file.zsh = { text = "x"; } // base;'
        'home.file = lib.mkMerge [ base { ".a".text = "x"; } ];'
        'home.file = lib.mkIf (builtins.elem 1 [ 1 ]) (mkLinks { a = 1; });'
        'home.file = lib.mkMerge [ { ".a".text = "x"; } (lib.mkIf true extra) ];'
        'home.file = (mkLinks [ ".zshrc" ]);'
        'home.file.zsh = lib.mkMerge [ { text = "x"; } (base) ];'
        'home.file = { inherit zshrc; };'
        'home.file = { inherit (s) ".zshrc"; };'
        'home.file.zsh = { inherit (s) target; };'
        'home.file = { ".a".text = "x"; }.x;'
        'home.file = rec { ".a".text = "x"; };'
        'home.file = if c then { ".a".text = "x"; } else { };'
        'home.file = lib.mkIf (c) (lib.mkMerge [ { ".a".text = "x"; } ]);'
        'home.file = lib.mkIf a b { ".a".text = "x"; };'
        'home.file = lib.mkMerge [ { ".a".text = "x"; } ] ++ more;'
        'home.file = { ".a" = foo { text = "x"; }; };'
        'home.file.zsh = { text = "x"; }.y;'
        'home.file.zsh = lib.mkIf c (lib.mkMerge [ { text = "x"; } ]);'
    )
    chezsrc dot_zshrc
    for body in "${bodies[@]}"; do
        nixmod ok.nix "$body"
        validate
        [ "$status" -eq 0 ] || { echo "rejected: $body: $output"; return 1; }
        [[ "$output" == *"[NOTE] "*"home.file"*"--eval"* ]] || { echo "no note: $body: $output"; return 1; }
        [[ "$output" != *"[OK]   no literal home.file target"* ]] || { echo "verified: $body"; return 1; }
    done
}

@test "rule 12: a let-bound target option behind a bare home.file entry is a NOTE" {
    chezsrc dot_zshrc
    printf '{ lib, ... }:\nlet\n  base = { target = ".zshrc"; };\nin\n{\n  home.file.zsh = base;\n}\n' >"$R/nix/modules/home/ok.nix"
    validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"[NOTE] "*'home.file."zsh" = base'* ]]
    [[ "$output" != *"[OK]   no literal home.file target"* ]]
}

@test "rule 12: wrapped attrset literals stay decidable" {
    chezsrc dot_zshrc
    local body
    local -a bodies=(
        'home.file = lib.mkIf config.x.enable { ".zshrc".text = "x"; };'
        'home.file = lib.mkMerge [ { ".zshrc".text = "x"; } { ".b".text = "y"; } ];'
        'home.file = lib.mkIf (a && !b) { ".zshrc".text = "x"; };'
        'home.file = lib.mkOverride 90 { ".zshrc".text = "x"; };'
        'home = { packages = with pkgs; [ jq ]; file = { ".zshrc".text = "x"; }; };'
        'home.file = lib.optionalAttrs pkgs.stdenv.isLinux { ".zshrc".text = "x"; };'
        'home.file.".zshrc" = lib.mkForce { text = "x"; };'
        'home.file = lib.mkDefault { ".zshrc" = { text = "x"; }; };'
    )
    for body in "${bodies[@]}"; do
        nixmod ok.nix "$body"
        validate
        [ "$status" -ne 0 ] || { echo "not rejected: $body"; return 1; }
        [[ "$output" == *"collides with chezmoi source home/dot_zshrc"* ]] || { echo "unreported: $body: $output"; return 1; }
        [[ "$output" != *"[NOTE]"*"home"* ]] || { echo "needless note: $body: $output"; return 1; }
    done
}

@test "rule 12: home bound to anything but an attrset literal hides home.file, so it is a NOTE" {
    local body
    local -a bodies=(
        'home = base;'
        'home = lib.mkIf c base;'
        'config.home = base;'
        'home = { packages = [ ]; } // extra;'
        'home = lib.mkMerge [ base ];'
        'home = (mk { });'
    )
    chezsrc dot_zshrc
    for body in "${bodies[@]}"; do
        nixmod ok.nix "$body"
        validate
        [ "$status" -eq 0 ] || { echo "rejected: $body: $output"; return 1; }
        [[ "$output" == *"[NOTE] "*": home = "*"--eval"* ]] || { echo "no note: $body: $output"; return 1; }
        [[ "$output" != *"[OK]   no literal home.file target"* ]] || { echo "verified: $body"; return 1; }
    done
    nixmod ok.nix 'home = { stateVersion = "24.05"; packages = with pkgs; [ jq ]; };'
    validate
    [ "$status" -eq 0 ]
    [[ "$output" != *"[NOTE]"* ]]
    [[ "$output" == *"[OK]   no literal home.file target"* ]]
}

@test "rule 12: a let-bound home.file attrset is a NOTE" {
    chezsrc dot_zshrc
    printf '{ lib, ... }:\nlet\n  files = { ".zshrc".text = "x"; };\nin\n{\n  home.file = files;\n}\n' >"$R/nix/modules/home/ok.nix"
    validate
    [ "$status" -eq 0 ]
    [[ "$output" == *"[NOTE] "*"home.file = files"* ]]
}

@test "rule 12: home.file on a chezmoi path passes when .chezmoiignore covers it on every Linux host" {
    chezsrc dot_zshrc
    nixmod ok.nix 'home.file.".zshrc".text = "x";'
    printf '{{- if ne .chezmoi.os "darwin" }}\n.zshrc\n{{- end }}\n' >"$R/home/.chezmoiignore"
    validate
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

# --- T-0014 F5: host-gated .chezmoiignore, decided by rendering it ----------

# ignore_case <ignore file body>: flameshot collision plus that .chezmoiignore
ignore_case() { collide flameshot.ini; printf '%b' "$1" >"$R/home/.chezmoiignore"; validate; }

@test "rule 12: host-gated ignores that make Linux ownership unambiguous are accepted" {
    local body
    local -a ok=(
        '{{ if ne .chezmoi.os "darwin" }}\n.config/flameshot\n{{ end }}\n'
        '{{ if eq .chezmoi.os "linux" }}\n.config/flameshot/**\n{{ end }}\n'
        '{{ if not (eq .chezmoi.os "darwin") }}\n.config/flameshot\n{{ end }}\n'
        '{{ if eq .chezmoi.os "darwin" }}\n{{ else }}\n.config/flameshot\n{{ end }}\n'
        '{{ if and (ne .chezmoi.os "darwin") true }}\n.config/flameshot/flameshot.ini\n{{ end }}\n'
        '.config/flameshot/*.ini\n'
        '.config/flameshot/[f]lameshot.ini\n'
        '.config/flameshot/{flameshot,x}.ini\n'
        '.config/flameshot\n!.config/flameshot/flameshot.ini\n'
        '{{- $p := default "linux-desktop" .hostProfile -}}\n{{ if or (eq $p "wsl") (ne $p "wsl") }}\n.config/flameshot\n{{ end }}\n'
        '.config/*\n'
    )
    for body in "${ok[@]}"; do
        ignore_case "$body"
        [ "$status" -eq 0 ] || { echo "rejected: $body: $output"; return 1; }
    done
}

@test "rule 12: ignores that leave Linux ownership ambiguous or unset fail and name the hosts" {
    local body
    local -a bad=(
        '{{ if eq .chezmoi.os "darwin" }}\n.config/flameshot\n{{ end }}\n'
        '{{ if eq .hostProfile "wsl" }}\n.config/flameshot\n{{ end }}\n'
        '{{ if not .gui }}\n.config/flameshot\n{{ end }}\n'
        '{{ if and (ne .chezmoi.os "darwin") .gui }}\n.config/flameshot\n{{ end }}\n'
        '.config/flameshot\n!.config/flameshot\n'
        '.config/fl**.ini\n'
        '.config/flameshot/*\n!.config/flameshot/[f]lameshot.ini\n'
        '.config/flameshot/*\n!.config/flameshot/{flameshot,x}.ini\n'
        '.config/flameshot/other.ini\n'
        '# .config/flameshot\n'
    )
    for body in "${bad[@]}"; do
        ignore_case "$body"
        [ "$status" -ne 0 ] || { echo "not rejected: $body"; return 1; }
        [[ "$output" == *"collides with chezmoi source home/dot_config/flameshot/flameshot.ini; not ignored on: "* ]] || { echo "unreported: $body: $output"; return 1; }
    done
    ignore_case '{{ if eq .hostProfile "wsl" }}\n.config/flameshot\n{{ end }}\n'
    [[ "$output" == *"linux/linux-desktop/gui=true"* ]]
    [[ "$output" != *"linux/wsl/gui"* ]]
}

@test "rule 12: an ignore file that cannot be rendered fails closed" {
    ignore_case '{{ if }}\n.config/flameshot\n'
    [ "$status" -ne 0 ]
    [[ "$output" == *"chezmoi managed failed for home/.chezmoiignore"* ]]
    ignore_case '{{ if .personal.laptop }}\n.config/flameshot\n{{ end }}\n.config/flameshot\n'
    [ "$status" -ne 0 ]
    [[ "$output" == *"chezmoi managed failed for home/.chezmoiignore"* ]]
}

@test "rule 12: no [OK] is printed for the collision rules when chezmoi could not decide" {
    ignore_case '{{ if }}\n'
    [ "$status" -ne 0 ]
    [[ "$output" != *"[OK]   no xdg.configFile target is also"* ]]
    [[ "$output" != *"[OK]   no literal home.file target"* ]]
}

# nochezmoi_path: a PATH with the tools the validator needs, but no chezmoi
nochezmoi_path() {
    local t
    NOCHEZ="$BATS_TEST_TMPDIR/nochezmoi"
    mkdir -p "$NOCHEZ"
    for t in git awk tr find sort sed mktemp rm cat mv tail grep wc dirname; do ln -s "$(command -v $t)" "$NOCHEZ/$t"; done
}

@test "rule 12: a missing chezmoi cannot decide an ownership question, so it fails" {
    collide flameshot.ini
    printf '{{ if ne .chezmoi.os "darwin" }}\n.config/flameshot\n{{ end }}\n' >"$R/home/.chezmoiignore"
    git -C "$R" add -A
    nochezmoi_path
    PATH="$NOCHEZ" run "$(command -v bash)" "$R/ops/validate-config.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"chezmoi not found"* ]]
}

@test "rule 12: no chezmoi is needed when nothing collides" {
    git -C "$R" add -A
    nochezmoi_path
    PATH="$NOCHEZ" run "$(command -v bash)" "$R/ops/validate-config.sh"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "rule 12: deciding ownership never reads the caller's chezmoi config, HOME or XDG dirs" {
    collide flameshot.ini
    printf '{{ if ne .chezmoi.os "darwin" }}\n.config/flameshot\n{{ end }}\n' >"$R/home/.chezmoiignore"
    local d
    for d in h/.config/chezmoi h/xdg/chezmoi h/.local/share/chezmoi; do
        mkdir -p "$BATS_TEST_TMPDIR/$d"
        printf 'this is [not valid toml\n' >"$BATS_TEST_TMPDIR/$d/chezmoi.toml"
    done
    printf 'sourceDir = "/nonexistent"\n' >"$BATS_TEST_TMPDIR/h/.chezmoi.toml"
    git -C "$R" add -A
    find "$BATS_TEST_TMPDIR/h" | LC_ALL=C sort >"$BATS_TEST_TMPDIR/before.txt"
    HOME="$BATS_TEST_TMPDIR/h" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/h/.config" XDG_CONFIG_DIRS="$BATS_TEST_TMPDIR/h/xdg" \
        run bash "$R/ops/validate-config.sh"
    find "$BATS_TEST_TMPDIR/h" | LC_ALL=C sort >"$BATS_TEST_TMPDIR/after.txt"
    diff "$BATS_TEST_TMPDIR/before.txt" "$BATS_TEST_TMPDIR/after.txt" || return 1
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

# --- T-0014 F7/F5 in --eval: evaluated home.file targets, per-profile hosts --

@test "--eval: an evaluated home.file target that is a chezmoi source fails" {
    chezsrc dot_zshrc
    eval_with '{"packages":[],"programs":[],"services":[],"xdg":[],"files":[".zshrc"]}'
    [ "$status" -ne 0 ]
    [[ "$output" == *"home.file.\".zshrc\""*"collides with chezmoi source home/dot_zshrc"* ]]
}

@test "--eval: a let-bound home.file declaration is a NOTE in text mode and decided by --eval" {
    chezsrc dot_zshrc
    printf '{ lib, ... }:\nlet\n  files = { ".zshrc".text = "x"; };\nin\n{\n  home.file = files;\n}\n' >"$R/nix/modules/home/ok.nix"
    eval_with "$GOOD_EVAL"
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
    [[ "$output" == *"[NOTE] "*"home.file = files"* ]]
    eval_with '{"packages":[],"programs":[],"services":[],"xdg":[],"files":[".zshrc"]}'
    [ "$status" -ne 0 ]
    [[ "$output" == *"collides with chezmoi source home/dot_zshrc"* ]]
}

@test "--eval: ownership is judged on each profile's own host (macos is darwin)" {
    chezsrc dot_zshrc
    printf '{{ if ne .chezmoi.os "darwin" }}\n.zshrc\n{{ end }}\n' >"$R/home/.chezmoiignore"
    eval_with '{"packages":[],"programs":[],"services":[],"xdg":[],"files":[".zshrc"]}'
    [ "$status" -ne 0 ]
    [[ "$output" == *"darwin/macos/gui="* ]]
    [[ "$output" != *"linux/"*"gui="* ]]
    VALIDATE_EVAL_PROFILES="linux-desktop wsl" eval_with '{"packages":[],"programs":[],"services":[],"xdg":[],"files":[".zshrc"]}'
    [ "$status" -eq 0 ] || { echo "$output"; return 1; }
}

@test "--eval: output without a files list is a failed eval" {
    eval_with '{"packages":[],"programs":[],"services":[],"xdg":[]}'
    [ "$status" -ne 0 ]
    [[ "$output" == *"nix eval failed"* ]]
}

@test "--eval: one collision of an xdg.configFile target is reported once, not again via home.file" {
    mkdir -p "$R/home/dot_config/flameshot"
    printf '[General]\n' >"$R/home/dot_config/flameshot/flameshot.ini"
    VALIDATE_EVAL_PROFILES=wsl eval_with "$GOOD_EVAL"
    [ "$status" -ne 0 ]
    [ "$(grep -c 'collides with chezmoi source' <<<"$output")" -eq 1 ]
}
