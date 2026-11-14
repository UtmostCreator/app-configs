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
#   bash ops/validate-config.sh           # fast text checks (pre-commit hook)
#   bash ops/validate-config.sh --eval    # also check the evaluated Home Manager
#                                         # config (needs nix + jq; for CI)

set -uo pipefail

EVAL=0
for arg in "$@"; do
  case "$arg" in
    --eval) EVAL=1 ;;
    *)
      printf 'usage: validate-config.sh [--eval]\n' >&2
      exit 2
      ;;
  esac
done

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

# --- Nix text analysis (awk; no Nix evaluation, so it stays fast) -----------
# NIX_STRIP: remove comments (# and /* */) and neutralise string contents.
# Double-quoted strings keep their text with `{ } ; = # $` and blanks replaced
# by `_` (so attribute keys like "flameshot/flameshot.ini" stay readable);
# indented '' strings become "". Line count is preserved.
read -r -d '' NIX_STRIP <<'AWK' || true
function neut(c) { return (c ~ /[{};=#$ \t]/) ? "_" : c }
BEGIN { st = 0; sbuf = "" }
{
  line = $0; n = length(line); out = ""
  for (i = 1; i <= n; i++) {
    c = substr(line, i, 1); d = substr(line, i, 2); t = substr(line, i, 3)
    if (st == 0) {
      if (c == "#") break
      else if (d == "/*") { st = 3; i++ }
      else if (c == "\"") { st = 1; sbuf = "" }
      else if (d == "''") { st = 2; i++ }
      else out = out c
    } else if (st == 1) {
      if (c == "\\") { sbuf = sbuf "__"; i++ }
      else if (c == "\"") { st = 0; out = out "\"" sbuf "\"" }
      else sbuf = sbuf neut(c)
    } else if (st == 2) {
      if (t == "'''") i += 2
      else if (d == "''" && (substr(line, i + 2, 1) == "$" || substr(line, i + 2, 1) == "\\")) i += 2
      else if (d == "''") { st = 0; i++; out = out "\"\"" }
    } else if (st == 3) {
      if (d == "*/") { st = 0; i++ }
    }
  }
  if (st == 1) sbuf = sbuf "_"
  print out
}
AWK

# NIX_SCAN: tokenise stripped Nix and walk the bindings, tracking the attribute
# path through nested `{ }` (so `programs = { x = { enable = true; }; }` is
# programs.x.enable). Emits one line per finding:
#   PROGRAM|file:line|programs.<x>.enable = <rhs>
#   SERVICE|file:line|services.<x>.enable = <rhs>      (only when hm=1)
#   TOOL|file:line|<tool>|<home.packages|with pkgs>    (only when hm=1)
#   XDG|file:line|<configFile key>                     (only when hm=1)
#   XDGDYN|file:line|<expr>   (xdg.configFile = <expr>; keys unknowable here)
# Limits (text, not evaluation): `let`-bound attrsets, `//` merges and
# generated attribute names are not followed; `--eval` covers those.
read -r -d '' NIX_SCAN <<'AWK' || true
function isword(t) { return t ~ /^[A-Za-z_"]/ && !(t in KW) }
function lastseg(t,   m) { m = t; sub(/^.*\./, "", m); return m }
function where(i) { return file ":" tl[i] }
BEGIN {
  nk = split("if then else let in with assert inherit rec or import", ka, " ")
  for (k = 1; k <= nk; k++) KW[ka[k]] = 1
  nk = split(tools, ta, " "); for (k = 1; k <= nk; k++) TOOL[ta[k]] = 1
  nk = split(allowed_programs, pa, " "); for (k = 1; k <= nk; k++) AP[pa[k]] = 1
  nk = split(allowed_services, sa, " "); for (k = 1; k <= nk; k++) AS[sa[k]] = 1
  n = 0
}
{
  line = $0
  while (gsub(/\$\{[^{}]*\}/, "DYN", line)) { }
  pos = 1; len = length(line)
  while (pos <= len) {
    rest = substr(line, pos)
    if (match(rest, /^[ \t\r]+/)) { pos += RLENGTH; continue }
    if (match(rest, /^([A-Za-z_][A-Za-z0-9_'-]*|"[^"]*")(\.([A-Za-z_][A-Za-z0-9_'-]*|"[^"]*"))*/)) {
      tk = substr(rest, 1, RLENGTH); pos += RLENGTH
    } else if (match(rest, /^(==|!=|\/\/|\+\+|->|&&|\|\||<=|>=|\.\.\.)/)) {
      tk = substr(rest, 1, RLENGTH); pos += RLENGTH
    } else { tk = substr(rest, 1, 1); pos++ }
    n++; tok[n] = tk; tl[n] = NR
  }
}
# Right-hand side tokens from j up to the `;` ending the binding (brackets and
# `with`/`let` aware). Sets RHS (joined) and HB (1 if a `{` occurs).
function rhs_scan(j,   d, lc, ws, k, t, cnt) {
  RHS = ""; HB = 0; d = 0; lc = 0; ws = 0; cnt = 0
  for (k = j; k <= n && cnt < 60; k++) {
    cnt++
    t = tok[k]
    if (t == "{") HB = 1
    if (t == "{" || t == "[" || t == "(") d++
    else if (t == "}" || t == "]" || t == ")") { d--; if (d < 0) break }
    else if (t == "let") lc++
    else if (t == "in") { if (lc > 0) lc-- }
    else if (t == "with" || t == "assert") ws++
    else if (t == ";") { if (ws > 0) ws--; else if (d == 0 && lc == 0) break }
    RHS = RHS (RHS == "" ? "" : " ") t
  }
}
function scan_tools(j, ctx,   d, lc, ws, k, t, ls) {
  d = 0; lc = 0; ws = 0
  for (k = j; k <= n; k++) {
    t = tok[k]
    if (t == "{" || t == "[" || t == "(") d++
    else if (t == "}" || t == "]" || t == ")") { d--; if (d < 0) break }
    else if (t == "let") lc++
    else if (t == "in") { if (lc > 0) lc-- }
    else if (t == "with" || t == "assert") ws++
    else if (t == ";") { if (ws > 0) ws--; else if (d == 0 && lc == 0) break }
    else if (isword(t) && !(k in SEEN)) {
      ls = lastseg(t)
      if (ls in TOOL) { SEEN[k] = 1; print "TOOL|" where(k) "|" ls "|" ctx }
    }
  }
}
function record(f, i,   mid, rest, key, isoff) {
  if (f ~ /\.enable$/ && (f ~ /^programs\./ || f ~ /^services\./)) {
    rhs_scan(i + 2)
    isoff = (RHS == "false" || RHS ~ /^(lib\.)?mk[A-Za-z]+( [0-9]+)? false$/)
    mid = f; sub(/^[a-z]+\./, "", mid); sub(/\.enable$/, "", mid); sub(/\..*$/, "", mid)  # first segment: the module
    if (f ~ /^programs\./) {
      if (!(mid in AP) && !isoff) print "PROGRAM|" where(i) "|" f " = " RHS
    } else if (hm == 1 && !(mid in AS) && !isoff) {
      print "SERVICE|" where(i) "|" f " = " RHS
    }
  }
  if (hm != 1) return
  if (f == "home.packages") scan_tools(i + 2, "home.packages")
  if (f ~ /^xdg\.configFile/) {
    if (f == "xdg.configFile") {
      rhs_scan(i + 2)
      if (!HB) print "XDGDYN|" where(i) "|" RHS
    } else {
      rest = substr(f, length("xdg.configFile.") + 1)
      if (substr(rest, 1, 1) == "\"") { match(rest, /^"[^"]*"/); key = substr(rest, 2, RLENGTH - 2) }
      else { key = rest; sub(/\..*$/, "", key) }
      if (!(key in XSEEN)) { XSEEN[key] = 1; print "XDG|" where(i) "|" key }
    }
  }
}
END {
  depth = 0; pref[0] = ""; pend[0] = ""; lets[0] = 0; withs = 0
  for (i = 1; i <= n; i++) {
    t = tok[i]
    if (t == "{") {
      depth++
      pref[depth] = (pend[depth - 1] != "") ? pend[depth - 1] : pref[depth - 1]
      pend[depth] = ""; lets[depth] = 0
    } else if (t == "}") { if (depth > 0) depth--
    } else if (t == "let") { lets[depth]++
    } else if (t == "in") { if (lets[depth] > 0) lets[depth]--
    } else if (t == "with" || t == "assert") {
      withs++
      if (hm == 1 && t == "with" && tok[i + 1] == "pkgs" && tok[i + 2] == ";") scan_tools(i + 3, "with pkgs")
    } else if (t == ";") {
      if (withs > 0) withs--
      else if (lets[depth] == 0) pend[depth] = ""
    } else if (isword(t) && tok[i + 1] == "=" && (tok[i - 1] == "{" || tok[i - 1] == ";") && lets[depth] == 0) {
      f = (pref[depth] == "") ? t : pref[depth] "." t
      pend[depth] = f
      sub(/^config\./, "", f)
      record(f, i)
    }
  }
}
AWK

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

# 6-8. Home Manager policy, checked on comment- and string-stripped Nix
# (see NIX_STRIP / NIX_SCAN above), so commented-out lines and text inside
# strings never match and multi-line lists and nested attrsets are seen.
#   6. Only these HM modules may be enabled: programs.home-manager,
#      programs.vicinae, programs.openclaw, services.syncthing. Every other
#      programs.<x>.enable / services.<x>.enable (dotted, nested in
#      `programs = { x = { enable = ...; }; }`, behind lib.mkDefault/mkIf,
#      inside mkMerge lists) is a violation unless its value is literally
#      `false`. services.* is only checked in Home Manager files; NixOS and
#      nix-darwin modules legitimately enable system services.
#   7. mise, chezmoi, home-manager, lefthook (bootstrap-installed) must not be
#      in home.packages or in any `with pkgs; [ ... ]` list.
#   8. direnv (Phase 3: DROPPED) likewise.
ALLOWED_PROGRAMS="home-manager vicinae openclaw"
ALLOWED_SERVICES="syncthing"
BOOTSTRAP_TOOLS="mise chezmoi home-manager lefthook"

NIX_FINDINGS=""
scan_failed=0
nix_dirs=()
for d in nix/modules nix/lib nix/hosts; do
  [[ -d "$d" ]] && nix_dirs+=("$d")
done
if ((${#nix_dirs[@]} > 0)); then
  if ! nix_files="$(find "${nix_dirs[@]}" -type f \( -path 'nix/hosts/*' -name home.nix -o -path 'nix/modules/*' -name '*.nix' -o -path 'nix/lib/*' -name '*.nix' \) | LC_ALL=C sort)"; then
    err "find failed; cannot scan nix modules"
    nix_files=""
  fi
  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    case "$f" in
      nix/modules/nixos/* | nix/modules/darwin/*) hm=0 ;;
      *) hm=1 ;;
    esac
    if ! res="$(awk "$NIX_STRIP" "$f" | awk -v file="$f" -v hm="$hm" \
          -v allowed_programs="$ALLOWED_PROGRAMS" -v allowed_services="$ALLOWED_SERVICES" \
          -v tools="$BOOTSTRAP_TOOLS direnv" "$NIX_SCAN")"; then
      err "scan failed for $f"
      scan_failed=1
      continue
    fi
    [[ -n "$res" ]] && NIX_FINDINGS+="$res"$'\n'
  done <<<"$nix_files"
fi

e0=$ERRORS
while IFS='|' read -r kind where a _; do
  [[ "$kind" == "PROGRAM" || "$kind" == "SERVICE" ]] || continue
  err "forbidden $([[ "$kind" == PROGRAM ]] && echo programs || echo services).<x>.enable at $where: $a (allowed: programs: $ALLOWED_PROGRAMS; services: $ALLOWED_SERVICES)"
done <<<"$NIX_FINDINGS"
if ((ERRORS == e0 && scan_failed == 0)); then
  ok "only allowlisted programs.<x>/services.<x> enabled in nix/modules"
fi

e0=$ERRORS
while IFS='|' read -r kind where tool ctx; do
  [[ "$kind" == "TOOL" ]] || continue
  if [[ "$tool" == "direnv" ]]; then
    err "direnv was DROPPED in Phase 3 but found in $ctx at $where"
    else
    err "bootstrap tool '$tool' referenced in $ctx at $where"
  fi
done <<<"$NIX_FINDINGS"
if ((ERRORS == e0 && scan_failed == 0)); then
  ok "bootstrap-managed tools and direnv not in Home Manager package lists"
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

# 11. xdg.configFile targets in Home Manager modules: one owner per target
# path. Home Manager may own only the allowlisted keys below (plus systemd/user/*
# takeover entries); every other ~/.config file belongs to chezmoi
# (home/dot_config). `xdg.configFile = <expr>` (e.g. a let-bound genAttrs) is
# not followable in text; it is reported as a note and covered by --eval.
ALLOWED_XDG_KEYS="flameshot/flameshot.ini wireplumber/wireplumber.conf.d/51-kanto-ora4.conf gremlins/gremlins/.gremlins.yaml mimeapps.list"
ALLOWED_XDG_PREFIX="systemd/user/"

xdg_key_allowed() {
  local k="$1" a
  for a in $ALLOWED_XDG_KEYS; do
    [[ "$k" == "$a" ]] && return 0
  done
  [[ "$k" == "$ALLOWED_XDG_PREFIX"* ]]
}

e0=$ERRORS
XDG_TEXT_KEYS=""
while IFS='|' read -r kind where a _; do
  case "$kind" in
    XDG)
      XDG_TEXT_KEYS+="$a"$'\n'
      xdg_key_allowed "$a" ||
        err "xdg.configFile.\"$a\" at $where is not allowlisted (allowed: $ALLOWED_XDG_KEYS, $ALLOWED_XDG_PREFIX*); other ~/.config files belong to chezmoi (home/dot_config)"
      ;;
    XDGDYN)
      printf '[NOTE] %s: xdg.configFile = %s is not checked in text mode; run with --eval\n' "$where" "$a"
      ;;
  esac
done <<<"$NIX_FINDINGS"
if ((ERRORS == e0 && scan_failed == 0)); then
  ok "xdg.configFile keys limited to the allowlist"
fi

# 12. Path collisions: an xdg.configFile target must not also be a chezmoi
# source under home/dot_config, unless home/.chezmoiignore excludes it on
# Linux (a `.config/<target>` line, or a parent directory, inside an
# `ne .chezmoi.os "darwin"` block). Source names are mapped to target names by
# dropping chezmoi attribute prefixes (exact_, private_, executable_, ...), the
# dot_ prefix (-> ".") and a .tmpl suffix. Prints "<target>\t<source path>".
chezmoi_config_sources() {
  tr '\0' '\n' <"$TRACKED_FILE" | awk '
    index($0, "home/dot_config/") == 1 {
      p = substr($0, length("home/dot_config/") + 1)
      n = split(p, c, "/"); out = ""
      for (i = 1; i <= n; i++) {
        s = c[i]
        while (match(s, /^(exact|private|readonly|executable|empty|create|modify|remove|symlink|literal)_/)) s = substr(s, RLENGTH + 1)
        if (s ~ /^dot_/) s = "." substr(s, 5)
        if (i == n) sub(/\.tmpl$/, "", s)
        out = out (i > 1 ? "/" : "") s
      }
      print out "\t" $0
    }'
}

# chezmoiignore_covers <target>: exit 0 when home/.chezmoiignore ignores
# .config/<target> (or a parent) on Linux, per the block rule above.
chezmoiignore_covers() {
  [[ -f home/.chezmoiignore ]] || return 1
  awk -v target="$1" '
    BEGIN { n = split(target, c, "/"); for (i = 1; i <= n; i++) { p = (i > 1 ? p "/" : "") c[i]; want[".config/" p] = 1 } }
    /^[ \t]*\{\{-?[ \t]*if / {
      sp++
      if ($0 ~ /eq \.chezmoi\.os "darwin"/) kind[sp] = "d"
      else if ($0 ~ /ne \.chezmoi\.os "darwin"/) kind[sp] = "l"
      else kind[sp] = "o"
      next
    }
    /^[ \t]*\{\{-?[ \t]*else/ { if (kind[sp] == "d") kind[sp] = "l"; else if (kind[sp] == "l") kind[sp] = "d"; next }
    /^[ \t]*\{\{-?[ \t]*end/ { if (sp > 0) sp--; next }
    /^[ \t]*(#|\{\{)/ { next }
    {
      line = $0; gsub(/^[ \t]+|[ \t]+$/, "", line)
      for (i = 1; i <= sp; i++) if (kind[i] != "l") next
      if (line in want) found = 1
    }
    END { exit found ? 0 : 1 }' home/.chezmoiignore
}

# check_xdg_collisions <newline-separated xdg targets>
check_xdg_collisions() {
  local keys="$1" sources key tgt src
  sources="$(chezmoi_config_sources)" || { err "cannot list chezmoi sources under home/dot_config"; return; }
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    while IFS=$'\t' read -r tgt src; do
      [[ "$tgt" == "$key" ]] || continue
      chezmoiignore_covers "$key" ||
        err "xdg.configFile.\"$key\" (Home Manager) collides with chezmoi source $src; one owner per path: ignore it on Linux in home/.chezmoiignore or drop one side"
    done <<<"$sources"
  done <<<"$keys"
}

e0=$ERRORS
check_xdg_collisions "$XDG_TEXT_KEYS"
if ((ERRORS == e0)); then
  ok "no xdg.configFile target is also a live chezmoi source"
fi

# 13. (--eval only) The same policy on the *evaluated* Home Manager config, for
# what text cannot see: let-bound/merged attrsets, xdg.configFile = <expr>,
# options enabled by other modules or defaults, and package names after
# overlays. One `nix eval --json` per profile (~1 s each, ~3 s total here) is
# too slow and too dependent on the nix store/network for the pre-commit hook,
# so the default run skips it; CI runs `bash ops/validate-config.sh --eval`.
# Needs nix and jq; their absence is a failure, not a skip.
# Tolerated, not declared by us: the home-manager package that
# programs.home-manager adds to home.packages, programs.man (Home Manager default) and
# services.vicinae (renamed alias of programs.vicinae); xdg keys Home Manager
# generates itself (dconf/.keep, environment.d/10-home-manager.conf,
# nix/nix.conf).
EVAL_PROFILES="${VALIDATE_EVAL_PROFILES:-linux-desktop linux-cli wsl}"
# shellcheck disable=SC2016 # Nix source, not shell: no expansion wanted
EVAL_QUERY='cfg: let
  inherit (builtins) attrNames filter map isAttrs tryEval;
  on = set: n: let r = tryEval (let v = set.${n}; in isAttrs v && (v.enable or false) == true); in r.success && r.value;
  en = set: filter (on set) (attrNames set);
in {
  packages = map (p: p.pname or (builtins.parseDrvName p.name).name) cfg.home.packages;
  programs = en cfg.programs;
  services = en cfg.services;
  xdg = attrNames cfg.xdg.configFile;
}'

in_list() { # in_list <word> <space-separated list>
  local w="$1" x
  for x in $2; do
    [[ "$x" == "$w" ]] && return 0
  done
  return 1
}

if ((EVAL)); then
  if ! command -v nix >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
    err "--eval needs nix and jq on PATH"
  else
    e0=$ERRORS
    for profile in $EVAL_PROFILES; do
      if ! json="$(nix eval --no-eval-cache --json "path:$ROOT_DIR/nix#homeConfigurations.$profile.config" --apply "$EVAL_QUERY" 2>/dev/null)" ||
         ! jq -e 'has("packages") and has("programs") and has("services") and has("xdg")' <<<"$json" >/dev/null 2>&1; then
        err "nix eval failed for homeConfigurations.$profile"
        continue
      fi
      # programs.home-manager.enable (allowed) puts the home-manager package into
      # home.packages itself, so that one name is expected when it is enabled.
      hm_self=0
      jq -e '.programs | index("home-manager")' <<<"$json" >/dev/null 2>&1 && hm_self=1
      while IFS= read -r name; do
        [[ "$name" == "home-manager" && $hm_self -eq 1 ]] && continue
        in_list "$name" "$BOOTSTRAP_TOOLS direnv" &&
          err "[$profile] '$name' is in evaluated home.packages (bootstrap-installed or dropped tool)"
      done < <(jq -r '.packages[]' <<<"$json")
      while IFS= read -r name; do
        in_list "$name" "$ALLOWED_PROGRAMS man" ||
          err "[$profile] evaluated programs.$name.enable is true; allowed: $ALLOWED_PROGRAMS"
      done < <(jq -r '.programs[]' <<<"$json")
      while IFS= read -r name; do
        in_list "$name" "$ALLOWED_SERVICES vicinae" ||
          err "[$profile] evaluated services.$name.enable is true; allowed: $ALLOWED_SERVICES"
      done < <(jq -r '.services[]' <<<"$json")
      profile_keys="$(jq -r '.xdg[]' <<<"$json")"
      while IFS= read -r name; do
        [[ -z "$name" ]] && continue
        in_list "$name" "dconf/.keep environment.d/10-home-manager.conf nix/nix.conf" && continue
        xdg_key_allowed "$name" ||
          err "[$profile] evaluated xdg.configFile.\"$name\" is not allowlisted"
      done <<<"$profile_keys"
      check_xdg_collisions "$profile_keys"
    done
    if ((ERRORS == e0)); then
      ok "evaluated Home Manager config follows the policy ($EVAL_PROFILES)"
    fi
  fi
fi

echo
if ((ERRORS > 0)); then
  printf '[validate-config] %d invariant violation(s)\n' "$ERRORS" >&2
  exit 1
fi
printf '[validate-config] all invariants pass\n'
