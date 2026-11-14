#!/usr/bin/env bash
# Body of `mise run test:bash`: run the bats suite, and fail (not skip) when
# bats is missing so the task never reports success without running tests.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if ! command -v bats >/dev/null 2>&1; then
    echo "[test:bash] bats not found; shell tests did NOT run." >&2
    echo "[test:bash] Install: bats is provided by nix/modules/home/dev.nix; run sys-update." >&2
    exit 1
fi

exec bats tests/bash "$@"
