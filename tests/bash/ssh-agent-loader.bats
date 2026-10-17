#!/usr/bin/env bats
# Tests for home/dot_config/app-configs/ssh-agent.sh — the bash/zsh ssh-agent
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
