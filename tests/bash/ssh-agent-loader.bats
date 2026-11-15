#!/usr/bin/env bats
# Tests for home/dot_config/app-configs/ssh-agent.sh (bash/zsh) and the fish
# twin home/dot_config/fish/conf.d/ssh-agent.fish — the ssh-agent
# auto-loader. ssh-add / ssh-agent / ssh-keygen / uname are PATH stubs, so no
# real agent or key is touched.
#
# Run:  bats tests/bash/ssh-agent-loader.bats

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
    SCRIPT="$REPO_ROOT/home/dot_config/app-configs/ssh-agent.sh"
    [ -f "$SCRIPT" ]

    export HOME="$BATS_TEST_TMPDIR/home"
    STUBS="$BATS_TEST_TMPDIR/bin"
    mkdir -p "$HOME/.ssh" "$STUBS"

    stub uname 'echo Linux'
    stub ssh-keygen 'exit 1'
    # ssh-add -l exits with $SSH_ADD_L_STATUS; any other call succeeds.
    stub ssh-add '[ "$1" = -l ] && exit "${SSH_ADD_L_STATUS:-0}"; exit 0'
    stub ssh-agent 'touch "$HOME/agent-started"
echo "SSH_AUTH_SOCK=/tmp/fresh.sock; export SSH_AUTH_SOCK;"
echo "SSH_AGENT_PID=4242; export SSH_AGENT_PID;"'
}

stub() {
    printf '#!/usr/bin/env bash\n%s\n' "$2" >"$STUBS/$1"
    chmod +x "$STUBS/$1"
}

# isolate_path: a PATH holding only the stubs and the few real tools the
# loader needs, so a keychain installed on the host never changes which path
# (keychain vs plain agent) the loader takes.
isolate_path() {
    local tool
    for tool in env bash awk grep tr cat touch chmod; do
        ln -sf "$(command -v "$tool")" "$STUBS/$tool"
    done
    printf '%s' "$STUBS"
}

# load_agent: source the loader in an interactive bash (it no-ops otherwise)
# and print the agent socket it left behind.
load_agent() {
    PATH="$(isolate_path)" bash --norc --noprofile -i -c \
        '. "$1"; printf "sock=%s\n" "${SSH_AUTH_SOCK:-}"' _ "$SCRIPT" 2>/dev/null
}

@test "unreachable agent (ssh-add -l exits 2) starts a fresh agent" {
    printf 'SSH_AUTH_SOCK=/tmp/dead.sock; export SSH_AUTH_SOCK;\n' >"$HOME/.ssh/agent.env"
    SSH_ADD_L_STATUS=2 run load_agent
    [ "$status" -eq 0 ]
    [ -f "$HOME/agent-started" ]
    [[ "$output" == *"sock=/tmp/fresh.sock"* ]]
    grep -q fresh.sock "$HOME/.ssh/agent.env"
}

@test "reachable agent without identities (exit 1) is reused, not replaced" {
    printf 'SSH_AUTH_SOCK=/tmp/live.sock; export SSH_AUTH_SOCK;\n' >"$HOME/.ssh/agent.env"
    SSH_ADD_L_STATUS=1 run load_agent
    [ "$status" -eq 0 ]
    [ ! -f "$HOME/agent-started" ]
    [[ "$output" == *"sock=/tmp/live.sock"* ]]
}

@test "reachable agent with identities (exit 0) is reused" {
    printf 'SSH_AUTH_SOCK=/tmp/live.sock; export SSH_AUTH_SOCK;\n' >"$HOME/.ssh/agent.env"
    SSH_ADD_L_STATUS=0 run load_agent
    [ "$status" -eq 0 ]
    [ ! -f "$HOME/agent-started" ]
}

# --- fish loader (home/dot_config/fish/conf.d/ssh-agent.fish) ---------------
#
# PATH holds only the stubs and the few real tools they call, so a keychain on
# the host never routes the loader away from the plain ssh-agent fallback.
load_agent_fish() {
    local fish_script="$REPO_ROOT/home/dot_config/fish/conf.d/ssh-agent.fish"
    local tool
    for tool in fish bash cat awk touch chmod; do
        ln -sf "$(command -v "$tool")" "$STUBS/$tool"
    done
    PATH="$STUBS" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" \
        "$STUBS/fish" --no-config -i -c \
        'source $argv[1]; printf "sock=%s\n" "$SSH_AUTH_SOCK"' "$fish_script" 2>/dev/null
}

@test "fish: unreachable agent (ssh-add -l exits 2) starts a fresh agent" {
    command -v fish >/dev/null || skip "fish not installed"
    printf 'SSH_AUTH_SOCK=/tmp/dead.sock; export SSH_AUTH_SOCK;\n' >"$HOME/.ssh/agent.env"
    SSH_ADD_L_STATUS=2 run load_agent_fish
    [ "$status" -eq 0 ]
    [ -f "$HOME/agent-started" ]
    [[ "$output" == *"sock=/tmp/fresh.sock"* ]]
    grep -q fresh.sock "$HOME/.ssh/agent.env"
}

@test "fish: reachable agent without identities (exit 1) is reused, not replaced" {
    command -v fish >/dev/null || skip "fish not installed"
    printf 'SSH_AUTH_SOCK=/tmp/live.sock; export SSH_AUTH_SOCK;\n' >"$HOME/.ssh/agent.env"
    SSH_ADD_L_STATUS=1 run load_agent_fish
    [ "$status" -eq 0 ]
    [ ! -f "$HOME/agent-started" ]
    [[ "$output" == *"sock=/tmp/live.sock"* ]]
    grep -q live.sock "$HOME/.ssh/agent.env"
}

@test "fish: reachable agent with identities (exit 0) is reused" {
    command -v fish >/dev/null || skip "fish not installed"
    printf 'SSH_AUTH_SOCK=/tmp/live.sock; export SSH_AUTH_SOCK;\n' >"$HOME/.ssh/agent.env"
    SSH_ADD_L_STATUS=0 run load_agent_fish
    [ "$status" -eq 0 ]
    [ ! -f "$HOME/agent-started" ]
}

@test "fish: starting an agent does not leave the shell with umask 077" {
    command -v fish >/dev/null || skip "fish not installed"
    printf 'SSH_AUTH_SOCK=/tmp/dead.sock; export SSH_AUTH_SOCK;\n' >"$HOME/.ssh/agent.env"
    local fish_script="$REPO_ROOT/home/dot_config/fish/conf.d/ssh-agent.fish"
    for tool in fish bash cat awk touch chmod; do ln -sf "$(command -v "$tool")" "$STUBS/$tool"; done
    SSH_ADD_L_STATUS=2 run env PATH="$STUBS" HOME="$HOME" \
        "$STUBS/fish" --no-config -i -c 'umask 0022; source $argv[1]; umask' "$fish_script"
    [ -f "$HOME/agent-started" ]
    [ "${lines[-1]}" = "0022" ]
    # the agent env file itself stays private
    [ "$(stat -c %a "$HOME/.ssh/agent.env")" = "600" ]
}

@test "bash: a pre-existing world-readable agent.env becomes 0600 when the agent is replaced" {
    printf 'SSH_AUTH_SOCK=/tmp/dead.sock; export SSH_AUTH_SOCK;\n' >"$HOME/.ssh/agent.env"
    chmod 644 "$HOME/.ssh/agent.env"
    SSH_ADD_L_STATUS=2 run load_agent
    [ -f "$HOME/agent-started" ]
    [ "$(stat -c %a "$HOME/.ssh/agent.env")" = "600" ]
}

# keychain gets only the configured keys that exist, in bash and fish alike.
@test "bash: keychain is passed only configured keys that exist" {
    stub keychain 'printf "%s\n" "$*" >"$HOME/keychain-args"'
    touch "$HOME/.ssh/present"
    APP_CONFIGS_SSH_KEYS="present missing" run load_agent
    [ "$status" -eq 0 ]
    # default key lifetime is 8 h, so --timeout 480 (minutes) precedes the keys
    [ "$(cat "$HOME/keychain-args")" = "--eval --quiet --timeout 480 present" ]
}

@test "fish: keychain is passed only configured keys that exist" {
    command -v fish >/dev/null || skip "fish not installed"
    stub keychain 'printf "%s\n" "$*" >"$HOME/keychain-args"'
    touch "$HOME/.ssh/present"
    local fish_script="$REPO_ROOT/home/dot_config/fish/conf.d/ssh-agent.fish"
    for tool in fish bash cat awk touch chmod; do ln -sf "$(command -v "$tool")" "$STUBS/$tool"; done
    run env PATH="$STUBS" HOME="$HOME" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" \
        "$STUBS/fish" --no-config -i -c 'set -g APP_CONFIGS_SSH_KEYS present missing; source $argv[1]' "$fish_script"
    [ "$(cat "$HOME/keychain-args")" = "--eval --quiet --timeout 480 present" ]
}

# --- multi-key splitting (zsh does not word-split unquoted expansions) ------
#
# The loader is sourced by zsh from ~/.zshrc, so a multi-key list must load
# every key there too. zsh is optional on the host: the zsh test skips when it
# is missing, and the bash tests below cover the same loader code path plus a
# static guard against reintroducing the bare `for k in $VAR` split.

multi_key_setup() {
    : >"$HOME/.ssh/k1"; : >"$HOME/.ssh/k2"
    stub ssh-add '[ "$1" = -l ] && exit "${SSH_ADD_L_STATUS:-0}"; echo "$*" >>"$HOME/added.log"; exit 0'
    printf 'SSH_AUTH_SOCK=/tmp/live.sock; export SSH_AUTH_SOCK;\n' >"$HOME/.ssh/agent.env"
}

@test "zsh: every key in a multi-key APP_CONFIGS_SSH_KEYS is loaded" {
    command -v zsh >/dev/null || skip "zsh not installed (run with zsh on PATH to exercise this)"
    multi_key_setup
    APP_CONFIGS_SSH_KEYS="k1 k2" SSH_ADD_L_STATUS=1 PATH="$(isolate_path)" \
        "$(command -v zsh)" -f -i -c '. "$1"' _ "$SCRIPT" 2>/dev/null
    grep -qF "$HOME/.ssh/k1" "$HOME/added.log"
    grep -qF "$HOME/.ssh/k2" "$HOME/added.log"
}

@test "bash: every key in a multi-key APP_CONFIGS_SSH_KEYS is loaded" {
    multi_key_setup
    APP_CONFIGS_SSH_KEYS="k1   k2" SSH_ADD_L_STATUS=1 PATH="$(isolate_path)" \
        bash --norc --noprofile -i -c '. "$1"' _ "$SCRIPT" 2>/dev/null
    grep -qF "$HOME/.ssh/k1" "$HOME/added.log"
    grep -qF "$HOME/.ssh/k2" "$HOME/added.log"
}

@test "loader never word-splits APP_CONFIGS_SSH_KEYS with a bare for-loop" {
    run grep -nE 'for [a-z_]+ in \$APP_CONFIGS_SSH_KEYS' "$SCRIPT"
    [ "$status" -eq 1 ]
}

# keychain is the preferred Linux path: it must receive one argv entry per key.
keychain_argv_setup() {
    : >"$HOME/.ssh/k1"; : >"$HOME/.ssh/k2"
    stub keychain 'for a in "$@"; do printf "arg=%s\n" "$a"; done >>"$HOME/kc.log"'
}

KEYCHAIN_WANT=$'arg=--eval\narg=--quiet\narg=--timeout\narg=480\narg=k1\narg=k2'

@test "zsh: keychain receives one argv entry per key" {
    command -v zsh >/dev/null || skip "zsh not installed (run with zsh on PATH to exercise this)"
    keychain_argv_setup
    APP_CONFIGS_SSH_KEYS="k1 k2" PATH="$(isolate_path)" \
        "$(command -v zsh)" -f -i -c '. "$1"' _ "$SCRIPT" 2>/dev/null
    [ "$(cat "$HOME/kc.log")" = "$KEYCHAIN_WANT" ]
}

@test "bash: keychain receives one argv entry per key" {
    keychain_argv_setup
    APP_CONFIGS_SSH_KEYS="k1  k2" PATH="$(isolate_path)" \
        bash --norc --noprofile -i -c '. "$1"' _ "$SCRIPT" 2>/dev/null
    [ "$(cat "$HOME/kc.log")" = "$KEYCHAIN_WANT" ]
}

# keychain 3 deprecates --agents (a warning on every new shell); keychain 2.8+
# and 3.x are both ssh-only by default for ssh key names.
@test "bash: keychain is never given the deprecated --agents flag" {
    stub keychain 'printf "%s\n" "$*" >"$HOME/keychain-args"; echo "export KC_SOURCED=yes"'
    touch "$HOME/.ssh/present"
    APP_CONFIGS_SSH_KEYS="present" PATH="$(isolate_path)" \
        bash --norc --noprofile -i -c '. "$1"; printf "kc=%s\n" "${KC_SOURCED:-}" >"$HOME/kc-out"' _ "$SCRIPT" 2>/dev/null
    if grep -q -- '--agents' "$HOME/keychain-args"; then echo 'assertion failed: --agents passed' >&2; return 1; fi
    grep -q -- '--eval' "$HOME/keychain-args"
    grep -q 'present' "$HOME/keychain-args"
    [ "$(cat "$HOME/kc-out")" = "kc=yes" ]
}

@test "fish: keychain is never given the deprecated --agents flag" {
    command -v fish >/dev/null || skip "fish not installed"
    stub keychain 'printf "%s\n" "$*" >"$HOME/keychain-args"; echo "set -gx KC_SOURCED yes"'
    touch "$HOME/.ssh/present"
    local fish_script="$REPO_ROOT/home/dot_config/fish/conf.d/ssh-agent.fish"
    for tool in fish bash cat awk touch chmod; do ln -sf "$(command -v "$tool")" "$STUBS/$tool"; done
    run env PATH="$STUBS" HOME="$HOME" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" \
        "$STUBS/fish" --no-config -i -c 'set -g APP_CONFIGS_SSH_KEYS present; source $argv[1]; echo "kc=$KC_SOURCED"' "$fish_script"
    if grep -q -- '--agents' "$HOME/keychain-args"; then echo 'assertion failed: --agents passed' >&2; return 1; fi
    grep -q -- '--eval' "$HOME/keychain-args"
    grep -q 'present' "$HOME/keychain-args"
    [[ "$output" == *"kc=yes"* ]]
}

# --- key lifetime (APP_CONFIGS_SSH_KEY_LIFETIME, hours; default 8) ----------
#
# keychain --timeout takes minutes; ssh-add -t takes seconds. 0 or empty means
# "until the agent dies"; anything that is not a non-negative integer is
# ignored (default kept) without printing an error.

lifetime_keychain_stub() {
    touch "$HOME/.ssh/present"
    stub keychain 'printf "%s\n" "$*" >"$HOME/keychain-args"'
}

# bash_keychain_args VALUE...: env assignments for the run, e.g. APP_CONFIGS_SSH_KEY_LIFETIME=24
bash_keychain_args() {
    env "$@" APP_CONFIGS_SSH_KEYS=present PATH="$(isolate_path)" \
        bash --norc --noprofile -i -c '. "$1"' _ "$SCRIPT" 2>"$HOME/stderr"
    cat "$HOME/keychain-args"
}

fish_keychain_args() {
    local fish_script="$REPO_ROOT/home/dot_config/fish/conf.d/ssh-agent.fish" tool
    for tool in fish bash cat awk touch chmod; do ln -sf "$(command -v "$tool")" "$STUBS/$tool"; done
    env PATH="$STUBS" HOME="$HOME" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" \
        "$STUBS/fish" --no-config -i -c "set -g APP_CONFIGS_SSH_KEYS present; $1; source \$argv[1]" "$fish_script" 2>"$HOME/stderr"
    cat "$HOME/keychain-args"
}

# An interactive bash prints job-control notes on stderr; only a complaint
# about the lifetime value counts as noise.
no_lifetime_noise() {
    if grep -qiE 'lifetime|expression|integer|syntax|math|error|invalid' "$HOME/stderr"; then
        cat "$HOME/stderr" >&2
        return 1
    fi
}

@test "bash: default lifetime gives keychain --timeout 480 before the keys" {
    lifetime_keychain_stub
    run bash_keychain_args
    [ "$output" = "--eval --quiet --timeout 480 present" ]
}

@test "bash: APP_CONFIGS_SSH_KEY_LIFETIME=24 gives --timeout 1440" {
    lifetime_keychain_stub
    run bash_keychain_args APP_CONFIGS_SSH_KEY_LIFETIME=24
    [ "$output" = "--eval --quiet --timeout 1440 present" ]
}

@test "bash: lifetime 0 or empty passes no --timeout" {
    lifetime_keychain_stub
    run bash_keychain_args APP_CONFIGS_SSH_KEY_LIFETIME=0
    [ "$output" = "--eval --quiet present" ]
    run bash_keychain_args APP_CONFIGS_SSH_KEY_LIFETIME=
    [ "$output" = "--eval --quiet present" ]
}

@test "bash: invalid lifetime (abc, -1, 1.5) keeps the default, silently" {
    lifetime_keychain_stub
    local v
    for v in abc -1 1.5; do
        run bash_keychain_args APP_CONFIGS_SSH_KEY_LIFETIME="$v"
        [ "$output" = "--eval --quiet --timeout 480 present" ]
        no_lifetime_noise
    done
}

@test "fish: default lifetime gives keychain --timeout 480 before the keys" {
    command -v fish >/dev/null || skip "fish not installed"
    lifetime_keychain_stub
    run fish_keychain_args true
    [ "$output" = "--eval --quiet --timeout 480 present" ]
}

@test "fish: APP_CONFIGS_SSH_KEY_LIFETIME=24 gives --timeout 1440" {
    command -v fish >/dev/null || skip "fish not installed"
    lifetime_keychain_stub
    run fish_keychain_args 'set -g APP_CONFIGS_SSH_KEY_LIFETIME 24'
    [ "$output" = "--eval --quiet --timeout 1440 present" ]
}

@test "fish: lifetime 0 or empty passes no --timeout" {
    command -v fish >/dev/null || skip "fish not installed"
    lifetime_keychain_stub
    run fish_keychain_args 'set -g APP_CONFIGS_SSH_KEY_LIFETIME 0'
    [ "$output" = "--eval --quiet present" ]
    run fish_keychain_args 'set -g APP_CONFIGS_SSH_KEY_LIFETIME ""'
    [ "$output" = "--eval --quiet present" ]
    run fish_keychain_args 'set -g APP_CONFIGS_SSH_KEY_LIFETIME'
    [ "$output" = "--eval --quiet present" ]
}

@test "fish: invalid lifetime (abc, -1) keeps the default, silently" {
    command -v fish >/dev/null || skip "fish not installed"
    lifetime_keychain_stub
    local v
    for v in abc -1; do
        run fish_keychain_args "set -g APP_CONFIGS_SSH_KEY_LIFETIME $v"
        [ "$output" = "--eval --quiet --timeout 480 present" ]
        no_lifetime_noise
    done
}

plain_lifetime_setup() {
    : >"$HOME/.ssh/present"
    stub ssh-add '[ "$1" = -l ] && exit "${SSH_ADD_L_STATUS:-0}"; echo "$*" >>"$HOME/added.log"; exit 0'
    printf 'SSH_AUTH_SOCK=/tmp/live.sock; export SSH_AUTH_SOCK;\n' >"$HOME/.ssh/agent.env"
}

@test "bash plain agent: default adds the key with ssh-add -t 28800" {
    plain_lifetime_setup
    APP_CONFIGS_SSH_KEYS=present SSH_ADD_L_STATUS=1 PATH="$(isolate_path)" \
        bash --norc --noprofile -i -c '. "$1"' _ "$SCRIPT" 2>/dev/null
    [ "$(cat "$HOME/added.log")" = "-t 28800 $HOME/.ssh/present" ]
}

@test "bash plain agent: lifetime 0 adds the key without -t" {
    plain_lifetime_setup
    APP_CONFIGS_SSH_KEY_LIFETIME=0 APP_CONFIGS_SSH_KEYS=present SSH_ADD_L_STATUS=1 PATH="$(isolate_path)" \
        bash --norc --noprofile -i -c '. "$1"' _ "$SCRIPT" 2>/dev/null
    [ "$(cat "$HOME/added.log")" = "$HOME/.ssh/present" ]
}

@test "fish plain agent: default -t 28800, lifetime 0 no -t" {
    command -v fish >/dev/null || skip "fish not installed"
    plain_lifetime_setup
    local fish_script="$REPO_ROOT/home/dot_config/fish/conf.d/ssh-agent.fish" tool
    for tool in fish bash cat awk touch chmod; do ln -sf "$(command -v "$tool")" "$STUBS/$tool"; done
    SSH_ADD_L_STATUS=1 env PATH="$STUBS" HOME="$HOME" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" \
        "$STUBS/fish" --no-config -i -c 'set -g APP_CONFIGS_SSH_KEYS present; source $argv[1]' "$fish_script" 2>/dev/null
    [ "$(cat "$HOME/added.log")" = "-t 28800 $HOME/.ssh/present" ]
    rm "$HOME/added.log"
    SSH_ADD_L_STATUS=1 env PATH="$STUBS" HOME="$HOME" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" \
        "$STUBS/fish" --no-config -i -c 'set -g APP_CONFIGS_SSH_KEYS present; set -g APP_CONFIGS_SSH_KEY_LIFETIME 0; source $argv[1]' "$fish_script" 2>/dev/null
    [ "$(cat "$HOME/added.log")" = "$HOME/.ssh/present" ]
}

@test "macOS: the lifetime never reaches ssh-add -t or keychain --timeout" {
    plain_lifetime_setup
    stub uname 'echo Darwin'
    stub keychain 'echo called >"$HOME/kc-called"'
    APP_CONFIGS_SSH_KEY_LIFETIME=24 APP_CONFIGS_SSH_KEYS=present SSH_ADD_L_STATUS=1 PATH="$(isolate_path)" \
        bash --norc --noprofile -i -c '. "$1"' _ "$SCRIPT" 2>/dev/null
    [ "$(cat "$HOME/added.log")" = "--apple-use-keychain $HOME/.ssh/present" ]
    [ ! -f "$HOME/kc-called" ]
}

@test "fish macOS: the lifetime never reaches ssh-add -t" {
    command -v fish >/dev/null || skip "fish not installed"
    plain_lifetime_setup
    stub uname 'echo Darwin'
    local fish_script="$REPO_ROOT/home/dot_config/fish/conf.d/ssh-agent.fish" tool
    for tool in fish bash cat awk touch chmod; do ln -sf "$(command -v "$tool")" "$STUBS/$tool"; done
    SSH_ADD_L_STATUS=1 env PATH="$STUBS" HOME="$HOME" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" \
        "$STUBS/fish" --no-config -i -c 'set -g APP_CONFIGS_SSH_KEYS present; set -g APP_CONFIGS_SSH_KEY_LIFETIME 24; source $argv[1]' "$fish_script" 2>/dev/null
    [ "$(cat "$HOME/added.log")" = "--apple-use-keychain $HOME/.ssh/present" ]
}
