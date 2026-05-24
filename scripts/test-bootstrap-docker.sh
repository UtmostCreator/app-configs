#!/usr/bin/env bash
# Fresh Ubuntu container dry-run of scripts/bootstrap.sh.
#
# Used as the optional final gate before deleting legacy folders or
# before merging the dotfiles migration. Requires Docker.
#
# Defaults to --dry-run inside the container (no mutations on the
# container OR the host). Pass --apply to flip the container to
# bootstrap --yes (still does not touch the host).
#
# Usage:
#   bash scripts/test-bootstrap-docker.sh             # dry-run
#   bash scripts/test-bootstrap-docker.sh --apply     # full --yes inside container
#   IMAGE=debian:12 bash scripts/test-bootstrap-docker.sh

set -euo pipefail

MODE="dry-run"
for arg in "$@"; do
  case "$arg" in
    --dry-run) MODE="dry-run" ;;
    --apply)   MODE="apply" ;;
    -h|--help)
      sed -n '2,15p' "$0"
      exit 0
      ;;
    *)
      printf '[test-bootstrap-docker] unknown arg: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

IMAGE="${IMAGE:-ubuntu:24.04}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v docker >/dev/null 2>&1 || {
  printf '[test-bootstrap-docker] docker not on PATH — skip with a recorded reason.\n' >&2
  exit 1
}

bootstrap_flag="--dry-run"
[[ "$MODE" == "apply" ]] && bootstrap_flag="--yes"

printf '[test-bootstrap-docker] image=%s bootstrap=%s\n' "$IMAGE" "$bootstrap_flag"

docker run --rm \
  --mount "type=bind,src=$REPO_ROOT,dst=/repo-source,readonly" \
  -e HOST_PROFILE=linux-desktop \
  -e CI=true \
  -e "BOOTSTRAP_FLAG=$bootstrap_flag" \
  "$IMAGE" \
  bash -lc '
    set -e
    apt-get update -qq
    apt-get install -y -qq curl git ca-certificates sudo bash xz-utils >/dev/null
    useradd -m -s /bin/bash tester
    cp -r /repo-source /home/tester/repo
    chown -R tester:tester /home/tester/repo
    su - tester -lc "
      cd ~/repo
      cp home/personal.yaml.example home/.chezmoidata/personal.yaml
      sed -i \"s/hostProfile: .*/hostProfile: linux-desktop/\" home/.chezmoidata/personal.yaml
      bash scripts/bootstrap.sh ${BOOTSTRAP_FLAG}
    "
  '

printf '[test-bootstrap-docker] container exited cleanly with %s\n' "$bootstrap_flag"
