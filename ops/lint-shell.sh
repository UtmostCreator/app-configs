#!/usr/bin/env bash
# Body of `mise run lint:shell`.
#
# 1. bash -n on EVERY committed shell script, one file per call. `bash -n a b`
#    only parses a (b is just an argument), and the old task also hid failures
#    behind `|| echo`, so broken scripts passed.
#    Chezmoi *.tmpl scripts with a shell shebang are rendered with
#    `chezmoi execute-template` and the output is checked the same way;
#    chezmoi is required (the task fails without it) when any such template
#    exists.
# 2. ShellCheck on the curated list below. A missing shellcheck fails the task:
#    a lint that silently skips is not a passing lint.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if ! command -v shellcheck >/dev/null 2>&1; then
  echo "[lint:shell] shellcheck not found; nothing was linted." >&2
  echo "[lint:shell] Install: shellcheck is provided by nix/modules/home/dev.nix; run sys-update." >&2
  exit 1
fi

# Committed *.sh files plus extensionless ~/.local/bin helpers with a POSIX
# shell shebang (python and other interpreters are skipped).
files=()
while IFS= read -r -d '' f; do files+=("$f"); done < <(git ls-files -z -- '*.sh')
while IFS= read -r -d '' f; do
  [[ "$f" == *.tmpl || "$f" == *.sh ]] && continue
  head -n1 "$f" 2>/dev/null | grep -qE '^#!.*\b(ba)?sh\b' && files+=("$f")
done < <(git ls-files -z -- 'home/dot_local/bin/executable_*')

failed=0
for f in "${files[@]}"; do
  if ! out="$(bash -n "$f" 2>&1)"; then
    printf '[lint:shell] syntax error: %s\n%s\n' "$f" "$out" >&2
    failed=$((failed + 1))
  fi
done
echo "[lint:shell] bash -n: ${#files[@]} files, $failed with syntax errors"

# Committed chezmoi templates whose first line is a shell shebang. They are
# rendered with stub data and an empty config, then syntax-checked.
tmpls=()
while IFS= read -r -d '' f; do
  head -n1 "$f" 2>/dev/null | grep -qE '^#!.*\b(ba)?sh\b' && tmpls+=("$f")
done < <(git ls-files -z -- 'home/*.tmpl')
if ((${#tmpls[@]})); then
  if ! command -v chezmoi >/dev/null 2>&1; then
    echo "[lint:shell] chezmoi not found; ${#tmpls[@]} shell templates were not checked." >&2
    exit 1
  fi
  work="$(mktemp -d)"
  trap 'rm -rf "$work"' EXIT
  : >"$work/chezmoi.toml"
  tfailed=0
  for f in "${tmpls[@]}"; do
    if ! out="$(chezmoi execute-template --config "$work/chezmoi.toml" --source home \
      --override-data '{"name":"T","email":"t@e.t","signingKey":""}' <"$f" 2>&1 >"$work/rendered.sh")"; then
      printf '[lint:shell] template render error: %s\n%s\n' "$f" "$out" >&2
      tfailed=$((tfailed + 1))
    elif ! out="$(bash -n "$work/rendered.sh" 2>&1)"; then
      printf '[lint:shell] syntax error in rendered template: %s\n%s\n' "$f" "$out" >&2
      tfailed=$((tfailed + 1))
    fi
  done
  failed=$((failed + tfailed))
  echo "[lint:shell] bash -n (rendered): ${#tmpls[@]} templates, $tfailed failed"
fi

curated=(
  ops/snapshot-home.sh ops/validate-config.sh ops/update-version-report.sh
  ops/lib/update-facts.sh ops/lib/update-ui.sh ops/lib/profile-conflicts.sh
  ops/generate-package-matrix.sh ops/doctor.sh
  ops/install.sh ops/update-all.sh ops/cleanup.sh ops/readiness.sh
  ops/system-setup.sh ops/tailscale-setup.sh ops/vscode-extensions.sh
  ops/detect-os-disks.sh ops/syncthing-obsidian-stignore.sh ops/bootstrap.sh
  ops/detect-host.sh ops/lint-shell.sh ops/run-bats.sh ops/wsl-check.sh
  ops/seed-personal-yaml.sh ops/unix/ssh-agent-setup.sh
)
present=()
for f in "${curated[@]}"; do [[ -f "$f" ]] && present+=("$f"); done
if ((${#present[@]})); then
  shellcheck -x "${present[@]}" || failed=$((failed + 1))
  echo "[lint:shell] shellcheck: ${#present[@]} files"
fi

((failed == 0))
