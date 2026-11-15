# shellcheck shell=bash
# Helpers for tests that run independent slow commands (nix evals, probes)
# concurrently. Load with: load ../lib/throttle
#
# bg_cap MAX [OVERRIDE]  print how many to run at once: OVERRIDE when it is a
#                        positive integer, else min(MAX, nproc), at least 1.
# bg_limited N CMD...    start CMD in the background, first waiting for a slot
#                        when N of this shell's background jobs already run.
#                        The caller waits for the rest with `wait`.

bg_cap() {
    local max="$1" override="${2:-}" cpus
    if [[ "$override" =~ ^[1-9][0-9]*$ ]]; then
        echo "$override"
        return 0
    fi
    cpus="$(nproc 2>/dev/null || echo 1)"
    [[ "$cpus" =~ ^[1-9][0-9]*$ ]] || cpus=1
    if ((cpus < max)); then echo "$cpus"; else echo "$max"; fi
}

bg_limited() {
    local max="$1"
    shift
    while [ "$(jobs -rp | wc -l)" -ge "$max" ]; do wait -n || true; done
    "$@" &
}
