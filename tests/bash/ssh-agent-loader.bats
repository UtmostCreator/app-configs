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

# load_agent: source the loader in an interactive bash (it no-ops otherwise)
# and print the agent socket it left behind.
load_agent() {
    PATH="$STUBS:$PATH" bash --norc --noprofile -i -c \
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
    [ "$(cat "$HOME/keychain-args")" = "--eval --quiet --agents ssh present" ]
}

@test "fish: keychain is passed only configured keys that exist" {
    command -v fish >/dev/null || skip "fish not installed"
    stub keychain 'printf "%s\n" "$*" >"$HOME/keychain-args"'
    touch "$HOME/.ssh/present"
    local fish_script="$REPO_ROOT/home/dot_config/fish/conf.d/ssh-agent.fish"
    for tool in fish bash cat awk touch chmod; do ln -sf "$(command -v "$tool")" "$STUBS/$tool"; done
    run env PATH="$STUBS" HOME="$HOME" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" \
        "$STUBS/fish" --no-config -i -c 'set -g APP_CONFIGS_SSH_KEYS present missing; source $argv[1]' "$fish_script"
    [ "$(cat "$HOME/keychain-args")" = "--eval --quiet --agents ssh present" ]
}
