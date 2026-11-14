#!/usr/bin/env bash
# Architecture invariant validator for the dotfiles migration.
#
# Enforces only v2 active rules. Does NOT:
#  - flag Windows native files (they're explicitly deferred / untouched)
#  - flag direnv unless Phase 3 explicitly dropped it (we did, so we flag it
#    in nix/modules/home/* only; mentioning direnv in docs is fine)
#
# Exits non-zero if any invariant is violated. Fails closed: a tool that
# cannot run (git missing, `git ls-files` failing) is a violation, not a pass.
#
# Usage:
#   bash ops/validate-config.sh

set -uo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR" || exit 1

ERRORS=0
ok()  { printf '[OK]   %s\n' "$*"; }
err() { printf '[FAIL] %s\n' "$*" >&2; ERRORS=$((ERRORS + 1)); }

if ! command -v git >/dev/null 2>&1; then
  err "git not found; cannot validate"
  exit 1
fi
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  err "$ROOT_DIR is not a git work tree; cannot validate"
  exit 1
fi

# Tracked paths (the index, NUL-separated), read once. Reading the index rather
# than the working tree means a secret that is tracked but deleted on disk, or
# staged but gitignored, is still seen.
TRACKED_FILE="$(mktemp)"
trap 'rm -f "$TRACKED_FILE"' EXIT
if ! git ls-files -z >"$TRACKED_FILE"; then
  err "git ls-files failed; cannot validate tracked paths"
  : >"$TRACKED_FILE"
fi

# 1. .chezmoiroot at repo root, contents == "home" (surrounding whitespace is
# trimmed, like chezmoi does; anything else, including "ho me", fails).
if [[ ! -f .chezmoiroot ]]; then
  err ".chezmoiroot missing at repo root"
else
  chezmoiroot="$(<.chezmoiroot)"
  chezmoiroot="${chezmoiroot#"${chezmoiroot%%[![:space:]]*}"}"
  chezmoiroot="${chezmoiroot%"${chezmoiroot##*[![:space:]]}"}"
  if [[ "$chezmoiroot" != "home" ]]; then
    err ".chezmoiroot must contain exactly 'home'"
  else
    ok ".chezmoiroot present and pointing at home"
  fi
fi

# 2. No chezmoi orchestration directories (orchestration belongs in bootstrap +
# mise). Both names are invariants: .chezmoiscripts is what chezmoi actually
# runs (the original validator checked it); .chezmoiops is the name the v2 plan
# (docs/plans/migration/implementation.md) forbids.
e0=$ERRORS
for d in home/.chezmoiscripts home/.chezmoiops; do
  if [[ -d "$d" ]]; then
    err "$d/ exists; v2 forbids chezmoi orchestration"
  fi
done
if ((ERRORS == e0)); then
  ok "no home/.chezmoiscripts/ or home/.chezmoiops/ (orchestration in bootstrap + mise)"
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

# 5. No secret path may be tracked (staged counts: the index is what commits).
# Secret paths: home/personal*.{yaml,yml,json,toml}, home/.chezmoidata/personal*
# of the same types, projects.yaml anywhere, and .env / .env.* except
# .env.example. `*.example` files never match: the patterns need the real
# extension at the end of the name.
tracked_secrets="$(tr '\0' '\n' <"$TRACKED_FILE" | grep -E \
  -e '^home/personal(\.[^/]*)?\.(yaml|yml|json|toml)$' \
  -e '^home/\.chezmoidata/personal[^/]*\.(yaml|yml|json|toml)$' \
  -e '(^|/)projects\.yaml$' \
  -e '(^|/)\.env(\.[^/]*)?$' | grep -Ev '(^|/)\.env\.example$' || true)"
if [[ -n "$tracked_secrets" ]]; then
  while IFS= read -r f; do
    err "tracked secret path (unstage or untrack it): $f"
  done <<<"$tracked_secrets"
else
  ok "no tracked secret paths (personal data, projects.yaml, .env)"
fi

# 6. Home Manager modules: only programs.home-manager.enable allowed
if [[ -d nix/modules ]]; then
  bad="$(rg --no-line-number -nP '^\s*programs\.[A-Za-z0-9_-]+\.enable\s*=\s*true' nix/modules 2>/dev/null \
        | grep -Ev 'programs\.home-manager\.enable' || true)"
  if [[ -n "$bad" ]]; then
    err "forbidden programs.<x>.enable found in nix/modules:"
    printf '%s\n' "$bad" | sed 's/^/      /' >&2
  else
    ok "no forbidden programs.<x>.enable in nix/modules"
  fi
fi

# 7. Bootstrap-managed tools must not appear in Home Manager modules
if [[ -d nix/modules/home ]]; then
  for tool in mise chezmoi home-manager lefthook; do
    if rg --no-line-number -nFw "$tool" nix/modules/home 2>/dev/null \
         | grep -qE ':\s*(home\.packages|with pkgs)'; then
      err "bootstrap tool '$tool' referenced in nix/modules/home"
    fi
  done
  ok "bootstrap-managed tools not duplicated in Home Manager modules"
fi

# 8. direnv (Phase 3 decision: DROPPED) must not appear in nix/modules/home
if [[ -d nix/modules/home ]]; then
  if rg --no-line-number -nFw direnv nix/modules/home 2>/dev/null \
       | grep -qE ':\s*(home\.packages|with pkgs)'; then
    err "direnv was DROPPED in Phase 3 but found in nix/modules/home"
  else
    ok "direnv not in Home Manager modules (per Phase 3 DROPPED decision)"
  fi
fi

# 9. Migration audit docs must exist, be non-empty, and have no unresolved
# table cells. A cell is unresolved when, trimmed and case-insensitive, it is
# TBD or TBC (optionally followed by punctuation and more text, e.g.
# "TBD (later)"), TODO, or only question marks. Prose such as "Every TBD row
# resolved." and longer cells like "TBD rows are tracked" do not trip it.
for f in repo-docs/migration-source-of-truth.md repo-docs/migration-package-ownership.md; do
  if [[ ! -f "$f" ]]; then
    err "audit doc missing: $f"
  elif ! grep -q '[^[:space:]]' "$f"; then
    err "audit doc is empty: $f"
  elif awk -F'|' '
      /^[[:space:]]*\|/ {
        for (i = 2; i < NF; i++) {
          c = tolower($i); gsub(/^[ \t]+|[ \t]+$/, "", c)
          if (c ~ /^(tbd|tbc)[ ]*([(:,;.?!\[-].*)?$/ || c == "todo" || c ~ /^\?+$/) { found = 1 }
        }
      }
      END { exit found ? 0 : 1 }' "$f"; then
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
# Known caveat (note only): intent-to-add (`git add -N`) makes a file count as
# tracked here and for flakes, but its content is not staged, so a commit
# would not contain it. This rule cannot see that; review the staged diff.
if [[ -d nix ]]; then
  if ! untracked_nix="$(git ls-files --others --exclude-standard -- 'nix/**/*.nix' 'nix/*.nix')"; then
    err "git ls-files failed; cannot check for untracked *.nix under nix/"
  elif [[ -n "$untracked_nix" ]]; then
    err "untracked *.nix under nix/ — flakes ignore untracked files; run 'git add' so evaluation can see them:"
    printf '%s\n' "$untracked_nix" | sed 's/^/      /' >&2
  else
    ok "no untracked *.nix under nix/ (flake can see every module)"
  fi
fi

echo
if ((ERRORS > 0)); then
  printf '[validate-config] %d invariant violation(s)\n' "$ERRORS" >&2
  exit 1
fi
printf '[validate-config] all invariants pass\n'
