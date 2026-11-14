#!/usr/bin/env bash
# Architecture invariant validator for the dotfiles migration.
#
# Enforces only v2 active rules. Does NOT:
#  - flag Windows native files (they're explicitly deferred / untouched)
#  - flag direnv unless Phase 3 explicitly dropped it (we did, so we flag it
#    in nix/modules/home/* only; mentioning direnv in docs is fine)
#
# Exits non-zero if any invariant is violated.
#
# Usage:
#   bash ops/validate-config.sh

set -uo pipefail

usage() {
  cat <<'USAGE'
Usage: bash ops/validate-config.sh [-h|--help]
Checks the repository invariants (read-only); takes no other arguments.
USAGE
}
case "$#:${1:-}" in
  0:) ;;
  1:-h | 1:--help) usage; exit 0 ;;
  *) printf 'validate-config: unknown argument(s): %s\n' "$*" >&2; usage >&2; exit 2 ;;
esac

# VALIDATE_CONFIG_ROOT lets the tests point the checks at a scratch repo.
ROOT_DIR="${VALIDATE_CONFIG_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT_DIR" || exit 1

ERRORS=0
ok()  { printf '[OK]   %s\n' "$*"; }
err() { printf '[FAIL] %s\n' "$*" >&2; ERRORS=$((ERRORS + 1)); }

# 1. .chezmoiroot at repo root, contents == "home"
if [[ ! -f .chezmoiroot ]]; then
  err ".chezmoiroot missing at repo root"
elif [[ "$(tr -d '[:space:]' <.chezmoiroot)" != "home" ]]; then
  err ".chezmoiroot must contain exactly 'home'"
else
  ok ".chezmoiroot present and pointing at home"
fi

# 2. No .chezmoiops/ (orchestration belongs in bootstrap + mise)
if [[ -d home/.chezmoiscripts ]]; then
  err "home/.chezmoiops/ exists; v2 forbids chezmoi orchestration"
else
  ok "no home/.chezmoiops/ (orchestration in bootstrap + mise)"
fi

# 3. personal.yaml.example committed at home/personal.yaml.example.
# It MUST live outside home/.chezmoidata/ because chezmoi autoloads every
# YAML/TOML/JSON file in .chezmoidata/ and fails on unknown suffixes
# (e.g. `.yaml.example`).
if [[ ! -f home/personal.yaml.example ]]; then
  err "home/personal.yaml.example missing"
else
  ok "personal.yaml.example present (at home/personal.yaml.example)"
fi
if [[ -f home/.chezmoidata/personal.yaml.example ]]; then
  err "home/.chezmoidata/personal.yaml.example must not exist (chezmoi will try to parse '.example' and fail). Move to home/personal.yaml.example."
fi

# 4. personal.yaml (real) must be gitignored if it exists
if [[ -f home/.chezmoidata/personal.yaml ]]; then
  if git check-ignore -q home/.chezmoidata/personal.yaml; then
    ok "personal.yaml present and gitignored"
  else
    err "personal.yaml exists but is NOT gitignored — secret leak risk"
  fi
fi

# 5. personal.yaml must not be staged
if git diff --cached --name-only 2>/dev/null \
     | grep -Fxq "home/.chezmoidata/personal.yaml"; then
  err "personal.yaml is staged for commit; unstage immediately"
else
  ok "personal.yaml not staged"
fi

# Checks 6-8 scan nix/modules with ripgrep. A missing rg must fail them, not
# let every scan "find nothing" and print ok.
HAVE_RG=1
if ! command -v rg >/dev/null 2>&1; then
  HAVE_RG=0
  err "ripgrep (rg) not found; invariants 6-8 cannot be checked"
fi

# 6. Home Manager modules: no programs.<x> modules except an explicit
#    allowlist. Both spellings are matched: `programs.x.enable = true;` and
#    the attrset form `programs.x = { enable = true; ... };`.
#    Allowlist (keep in sync with docs/architecture/tool-ownership.md):
#      home-manager  the HM bootstrap itself
#      vicinae       nix/modules/home/vicinae.nix (launcher, no chezmoi config)
#      openclaw      nix/modules/home/openclaw.nix (user service)
PROGRAMS_ALLOWLIST='home-manager|vicinae|openclaw'
if [[ -d nix/modules && $HAVE_RG == 1 ]]; then
  bad="$(rg --no-line-number -nP \
          '^\s*programs\.(?!('"$PROGRAMS_ALLOWLIST"')\b)[A-Za-z0-9_-]+(\.enable\s*=\s*true|\s*=\s*\{)' \
          nix/modules)"
  rc=$?
  if (( rc > 1 )); then
    err "rg failed while scanning nix/modules for programs.<x> (exit $rc)"
  elif [[ -n "$bad" ]]; then
    err "forbidden programs.<x> (not in allowlist: ${PROGRAMS_ALLOWLIST//|/, }) found in nix/modules:"
    printf '%s\n' "$bad" | sed 's/^/      /' >&2
  else
    ok "no forbidden programs.<x> in nix/modules (allowlist: ${PROGRAMS_ALLOWLIST//|/, })"
  fi
fi

# nix_lists_tool <tool>: true when nix/modules/home mentions <tool> as a
# package: on the same line as home.packages / with pkgs, or as its own list
# entry (`tool` or `pkgs.tool`, optional trailing comment) on a multi-line list.
nix_lists_tool() {
  rg --no-line-number -nFw "$1" nix/modules/home | grep -qE ':\s*(home\.packages|with pkgs)' && return 0
  rg --no-line-number -nP '^\s*(pkgs\.)?'"$1"'\s*(#.*)?$' nix/modules/home >/dev/null
}

# 7. Bootstrap-managed tools must not appear in Home Manager modules
if [[ -d nix/modules/home && $HAVE_RG == 1 ]]; then
  for tool in mise chezmoi home-manager lefthook; do
    if nix_lists_tool "$tool"; then
      err "bootstrap tool '$tool' referenced in nix/modules/home"
    fi
  done
  ok "bootstrap-managed tools check done (nix/modules/home)"
fi

# 8. direnv (Phase 3 decision: DROPPED) must not appear in nix/modules/home
if [[ -d nix/modules/home && $HAVE_RG == 1 ]]; then
  if nix_lists_tool direnv; then
    err "direnv was DROPPED in Phase 3 but found in nix/modules/home"
  else
    ok "direnv not in Home Manager modules (per Phase 3 DROPPED decision)"
  fi
fi

# 9. Migration audit docs must exist and have no leftover TBDs in table cells.
# We look for "| TBD" anywhere (cell value with surrounding pipes) rather than
# the bare word TBD so checklist sentences like "Every TBD row resolved" don't
# trip the rule.
for f in repo-docs/migration-source-of-truth.md repo-docs/migration-package-ownership.md; do
  if [[ ! -f "$f" ]]; then
    err "audit doc missing: $f"
  elif grep -nE '\|[[:space:]]*TBD[[:space:]]*\|' "$f" >/dev/null 2>&1; then
    err "audit doc has unresolved TBD table cells: $f"
  else
    ok "audit doc present and resolved: $f"
  fi
done

# 10. No untracked *.nix under nix/. Nix flakes evaluate ONLY git-tracked files
# (`nix/flake.nix` is consumed via the git tree), so a new module that is on
# disk but never `git add`-ed is invisible to evaluation. If that module is
# imported, the build dies with "Path '...' is not tracked by Git"; if it is a
# new flake input/module not yet imported it can still pass locally and break
# in CI/a clean checkout. Either way it is a latent build break, so flag it.
# Intent-to-add (`git add -N`) counts as tracked and is fine.
if [[ -d nix ]]; then
  untracked_nix="$(git ls-files --others --exclude-standard -- 'nix/**/*.nix' 'nix/*.nix' 2>/dev/null || true)"
  if [[ -n "$untracked_nix" ]]; then
    err "untracked *.nix under nix/ — flakes ignore untracked files; run 'git add' so evaluation can see them:"
    printf '%s\n' "$untracked_nix" | sed 's/^/      /' >&2
  else
    ok "no untracked *.nix under nix/ (flake can see every module)"
  fi
fi

echo
if (( ERRORS > 0 )); then
  printf '[validate-config] %d invariant violation(s)\n' "$ERRORS" >&2
  exit 1
fi
printf '[validate-config] all invariants pass\n'
