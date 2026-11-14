#!/usr/bin/env bash
# Architecture invariant validator for the dotfiles migration.
#
# Enforces only v2 active rules. Does NOT:
#  - flag Windows native files (they're explicitly deferred / untouched)
#  - flag direnv unless Phase 3 explicitly dropped it (we did, so we flag it
#    in Home Manager package lists only; mentioning direnv in docs is fine)
#
# Nix scan scope: programs.* in nix/modules/**, nix/lib and nix/hosts/*/home.nix;
# services.*, home.packages, xdg.configFile and home.file only in the Home
# Manager files among those (everything except nix/modules/nixos and
# nix/modules/darwin).
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
    -h | --help)
      printf 'Usage: bash ops/validate-config.sh [--eval] [-h|--help]\n'
      printf 'Checks the repository invariants (read-only); --eval also evaluates the flake.\n'
      exit 0
      ;;
    *)
      printf 'usage: validate-config.sh [--eval]\n' >&2
      exit 2
      ;;
  esac
done

# VALIDATE_CONFIG_ROOT lets the tests point the checks at a scratch repo.
ROOT_DIR="${VALIDATE_CONFIG_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
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
CHEZ_TMP="" # scratch dir for rendering home/.chezmoiignore (rule 12), made on demand
cleanup() {
  rm -f "$TRACKED_FILE"
  [[ -n "$CHEZ_TMP" ]] && rm -rf "$CHEZ_TMP"
  return 0
}
trap cleanup EXIT
if ! git ls-files -z >"$TRACKED_FILE"; then
  err "git ls-files failed; cannot validate tracked paths"
  : >"$TRACKED_FILE"
fi

# --- Nix text analysis (awk; no Nix evaluation, so it stays fast) -----------
# NIX_STRIP: remove comments (# and /* */) and neutralise string contents.
# Double-quoted strings keep their text with `{ } ; = # $` and blanks replaced
# by `_` (so attribute keys like "flameshot/flameshot.ini" stay readable); a `${`
# becomes the control character \001, so a scan can tell an interpolated key
# from a literal one. Indented '' strings become "". Line count is preserved.
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
      else if (c == "$" && substr(line, i + 1, 1) == "{") sbuf = sbuf "\001"  # interpolation marker
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
#   HF|file:line|<target>     (home.file; only when hm=1; a literal `target`
#                              option wins over the attribute name)
#   HFDYN|file:line|<expr>    (home.file declaration whose target text cannot
#                              decide: anything parse_set() does not accept,
#                              interpolated names, a non-literal `target`, and
#                              a top-level `home`/`config.home` binding that is
#                              not an attrset literal, since it can hide
#                              home.file; see parse_set for the exact shapes)
# Limits (text, not evaluation): `let`-bound attrsets, `//` merges and
# generated attribute names are not followed; `--eval` covers those. For
# home.file they are reported (HFDYN) instead of ignored; for xdg.configFile
# only a whole-attrset expression is (XDGDYN).
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
  n = 0; nhf = 0
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
function rhs_scan(j, lim,   d, lc, ws, k, t, cnt) {
  if (lim == "") lim = 60
  RHS = ""; HB = 0; d = 0; lc = 0; ws = 0; cnt = 0; RN = 0
  for (k = j; k <= n && cnt < lim; k++) {
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
    RTK[++RN] = t
  }
}
# parse_set(mode): 1 only when the right-hand side just scanned (RTK[1..RN]) has
# a shape this scanner can follow completely, 0 (= undecidable here) otherwise.
# Fail-closed by construction: only the shapes below are accepted.
#   RHS   := [ONE WRAPPER] `{ BODY }`  |  mkMerge `[` (`{ BODY }`)* `]`
#   WRAPPER := mkIf COND | optionalAttrs COND | mkOverride <digits> | mkDefault
#              | mkForce | mkBefore | mkAfter   (optionally `lib.`-prefixed)
#   COND  := UNIT ((&& | || | == | !=) UNIT)*; UNIT := [!] (word | `( flat )`)
#            where `flat` holds no { } [ ] ;
#   mode 0  home.file = RHS: BODY bindings are `"k".attr = <value>;` or
#           `name = { ENTRYBODY };`
#   mode 1  home.file.<n> = RHS: BODY is an ENTRYBODY, bindings `attr = <value>;`
#   mode 2  home = RHS: BODY is skipped (the key walker follows it)
# Never accepted: inherit, //, let, with, rec, import, or, in, assert anywhere
# (in mode 2 only outside the braces), attribute selection after } ) or ],
# parentheses or other calls anywhere but a wrapper's condition, bare names
# (`files`, `mkLinks {..}`, `mkMerge [ base ]`), `if`.
function peek_is_word(t) { return t ~ /^[A-Za-z_"]/ && !(t in KW) }
function skip_value(   d, u) {
  d = 0
  while (pi <= RN) {
    u = RTK[pi]
    if (u == "{" || u == "[" || u == "(") d++
    else if (u == "}" || u == "]" || u == ")") { d--; if (d < 0) return 0 }
    else if (u == ";" && d == 0) { pi++; return 1 }
    pi++
  }
  return 0
}
function skip_braces(   d, u) {
  d = 1
  while (pi <= RN) {
    u = RTK[pi++]
    if (u == "{") d++
    else if (u == "}") { d--; if (d == 0) return 1 }
  }
  return 0
}
function parse_body(bmode,   t, k2, hasattr) {
  while (pi <= RN) {
    t = RTK[pi]
    if (t == "}") { pi++; return 1 }
    if (!peek_is_word(t)) return 0
    k2 = t; gsub(/"[^"]*"/, "Q", k2); hasattr = (k2 ~ /\./)
    pi++
    if (RTK[pi] != "=") return 0
    pi++
    if (bmode == 0 && !hasattr) {
      if (RTK[pi] != "{") return 0
      pi++
      if (!parse_body(1)) return 0
      if (RTK[pi] != ";") return 0
      pi++
    } else if (!skip_value()) return 0
  }
  return 0
}
function parse_cond(   t, u, d) {
  while (1) {
    if (RTK[pi] == "!") pi++
    t = RTK[pi]
    if (t == "(") {
      d = 1; pi++
      while (pi <= RN && d > 0) {
        u = RTK[pi]
        if (u == "{" || u == "}" || u == "[" || u == "]" || u == ";") return 0
        if (u == "(") d++
        else if (u == ")") d--
        pi++
      }
      if (d > 0) return 0
    } else if (peek_is_word(t)) pi++
    else return 0
    t = RTK[pi]
    if (t == "&&" || t == "||" || t == "==" || t == "!=") { pi++; continue }
    return 1
  }
}
function parse_set(mode,   k, u, bd, t) {
  bd = 0
  for (k = 1; k <= RN; k++) {
    u = RTK[k]
    if (u == "{") bd++
    else if (u == "}") bd--
    if (mode == 2 && bd > 0) continue
    if (u ~ /^(inherit|\/\/|let|with|rec|import|or|in|assert)$/) return 0
    if (u == "." && k > 1 && RTK[k - 1] ~ /^[})\]]$/) return 0
  }
  pi = 1
  t = RTK[pi]
  if (t ~ /^(lib\.)?mkMerge$/) {
    pi++
    if (RTK[pi] != "[") return 0
    pi++
    while (RTK[pi] == "{") {
      pi++
      if (mode == 2 ? !skip_braces() : !parse_body(mode == 1 ? 1 : 0)) return 0
    }
    if (RTK[pi] != "]") return 0
    pi++
  } else {
    if (t ~ /^(lib\.)?(mkIf|optionalAttrs)$/) { pi++; if (!parse_cond()) return 0 }
    else if (t ~ /^(lib\.)?(mkDefault|mkForce|mkBefore|mkAfter)$/) pi++
    else if (t ~ /^(lib\.)?mkOverride$/) {
      pi++
      if (RTK[pi] !~ /^[0-9]$/) return 0
      while (RTK[pi] ~ /^[0-9]$/) pi++
    }
    if (RTK[pi] != "{") return 0
    pi++
    if (mode == 2 ? !skip_braces() : !parse_body(mode == 1 ? 1 : 0)) return 0
  }
  return (pi == RN + 1)
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
function record(f, i,   mid, rest, key, attr, a2, isoff) {
  if (f ~ /\.enable$/ && (f ~ /^programs\./ || f ~ /^services\./)) {
    rhs_scan(i + 2)
    isoff = (RHS == "false" || RHS ~ /^(lib\.)?mk[A-Za-z]+( [0-9]+)? false$/)
    mid = f; sub(/^[a-z]+\./, "", mid); sub(/\.enable$/, "", mid);
    if (substr(mid, 1, 1) == "\"") { match(mid, /^"[^"]*"/); mid = substr(mid, 2, RLENGTH - 2) }
    else sub(/\..*$/, "", mid)  # the module name, unquoted
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
      gsub(/\001/, "${}", key)
      if (!(key in XSEEN)) { XSEEN[key] = 1; print "XDG|" where(i) "|" key }
    }
  }
  if (f == "home") {
    rhs_scan(i + 2, 100000)
    if (!parse_set(2)) print "HFDYN|" where(i) "|home = " RHS
  }
  if (f ~ /^home\.file(\.|$)/) {
    if (f == "home.file") {
      rhs_scan(i + 2, 100000)
      if (!parse_set(0)) print "HFDYN|" where(i) "|home.file = " RHS
    } else {
      rest = substr(f, length("home.file.") + 1)
      if (substr(rest, 1, 1) == "\"") { match(rest, /^"[^"]*"/); key = substr(rest, 2, RLENGTH - 2); attr = substr(rest, RLENGTH + 1) }
      else { key = rest; sub(/\..*$/, "", key); attr = substr(rest, length(key) + 1) }
      if (!(key in HFK)) { HFK[key] = where(i); HFO[++nhf] = key }
      a2 = attr; gsub(/"/, "", a2)
      if (a2 == ".target") {
        rhs_scan(i + 2, 100000)
        if (RHS ~ /^"[^"\001]*"$/) HFT[key] = substr(RHS, 2, length(RHS) - 2)
        else HFTD[key] = ".target = " RHS
      } else if (a2 == "") {
        rhs_scan(i + 2, 100000)
        if (!parse_set(1)) HFTD[key] = " = " RHS
      }
    }
  }
}
# home.file targets, emitted once the whole file is walked (a `target` option
# may come after the options that created the entry).
function emit_home_file(   j, key, t, w, disp) {
  for (j = 1; j <= nhf; j++) {
    key = HFO[j]; w = HFK[key]
    t = (key in HFT) ? HFT[key] : key
    sub(/^(\.\/)+/, "", t); sub(/\/+$/, "", t)
    disp = t; gsub(/\001/, "${...}", disp)
    if (key in HFTD) print "HFDYN|" w "|home.file.\"" key "\"" HFTD[key]
    else if (t ~ /\001/ || t == "DYN" || t ~ /(^|\/)DYN(\/|$)/) print "HFDYN|" w "|home.file.\"" disp "\""
    else print "HF|" w "|" t
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
  if (hm == 1) emit_home_file()
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
#      in home.packages or after any `with pkgs;` (scanned up to the end of the
#      enclosing bracket or the next `;`, so `with pkgs; mise` is caught too).
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
    scan_failed=1
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
  else
    awk -F'|' '
      /^[[:space:]]*\|/ {
        for (i = 2; i < NF; i++) {
          c = tolower($i); gsub(/^[ \t]+|[ \t]+$/, "", c)
          if (c ~ /^(tbd|tbc)[ ]*([(:,;.?!\[-].*)?$/ || c == "todo" || c ~ /^\?+$/) { found = 1 }
        }
      }
      END { exit found ? 10 : 0 }' "$f"
    case $? in
      0) ok "audit doc present and resolved: $f" ;;
      10) err "audit doc has unresolved TBD table cells: $f" ;;
      *) err "audit doc scan failed: $f" ;; # awk error: fail closed
    esac
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

# 12. Path collisions: a Home Manager target (xdg.configFile or home.file) must
# not also be a chezmoi target, unless home/.chezmoiignore excludes the chezmoi
# copy on every host that Home Manager can declare it for. "Chezmoi target"
# means any tracked file under home/ (not only home/dot_config): source names
# are mapped to target names by dropping chezmoi attribute prefixes (exact_,
# private_, executable_, ...), the dot_ prefix (-> ".") and a .tmpl suffix.
# Source files that are not targets (.chezmoi* at the top level, run_*
# scripts) are skipped. A Home Manager directory target that contains a
# chezmoi target collides too.
#
# Ownership per host is decided by chezmoi itself, not by reading its ignore
# syntax: for each (os, hostProfile, gui) combination, `chezmoi managed` runs
# hermetically on a scratch source that holds a copy of home/.chezmoiignore
# plus an empty placeholder at the colliding source path (nothing else from
# the repo, so personal.yaml is never read). The chezmoi copy counts as ignored
# on that host when its target is absent from the managed list, whatever
# pattern syntax (globs, `!` re-includes, templates) did that. Hermetic means:
# scratch --source/--destination/--config, scratch HOME, XDG_CONFIG_HOME and
# XDG_CONFIG_DIRS, and template data only from --override-data (chezmoi.os,
# hostProfile, gui). Other .chezmoi.* values (arch, hostname, username, homeDir,
# ...) still come from the machine running the check, so an ignore file that
# branches on them is judged for this machine only.
#
# Which hosts must be covered:
#   text mode  every Linux host (hostProfile linux-desktop, linux-cli, wsl,
#              each with gui true and false), because Home Manager modules
#              that the text scan sees may be used by any of them. An ignore
#              that covers only some of these fails and lists the uncovered
#              hosts, so a host-gated ignore (`wsl` only, `gui` only, darwin
#              only) is rejected.
#   --eval     only the evaluated profile's own host (macos is os darwin), so
#              a target Home Manager declares on Linux only is judged on Linux.
# A chezmoi that cannot run (missing, template error) is a failure: the
# collision cannot be decided, so it is not passed, and no [OK] is printed for
# the rules that needed it.
TEXT_HOSTS="linux:linux-desktop linux:linux-cli linux:wsl"
RENDER_BROKEN=0
UNCOVERED=""

chezmoi_sources() {
  tr '\0' '\n' <"$TRACKED_FILE" | awk '
    index($0, "home/") == 1 {
      p = substr($0, length("home/") + 1)
      n = split(p, c, "/"); out = ""; skip = 0
      if (c[1] ~ /^\.chezmoi/) next
      for (i = 1; i <= n; i++) {
        s = c[i]
        while (match(s, /^(exact|private|readonly|executable|empty|create|modify|remove|symlink|literal)_/)) s = substr(s, RLENGTH + 1)
        if (s ~ /^run_/) skip = 1
        if (s ~ /^dot_/) s = "." substr(s, 5)
        if (i == n) sub(/\.tmpl$/, "", s)
        out = out (i > 1 ? "/" : "") s
      }
      if (!skip) print out "\t" $0
    }'
}

# managed_on_host <os> <hostProfile> <gui> <source path under home/> <target>:
# exit 0 when chezmoi manages <target> on that host, 1 when it does not, 2 when
# chezmoi cannot decide (error printed once, then RENDER_BROKEN stops retries).
managed_on_host() {
  local os="$1" prof="$2" gui="$3" src="$4" tgt="$5" sdir list
  [[ $RENDER_BROKEN -eq 1 ]] && return 2
  if ! command -v chezmoi >/dev/null 2>&1; then
    RENDER_BROKEN=1
    err "chezmoi not found on PATH; cannot decide path ownership from home/.chezmoiignore"
    return 2
  fi
  if [[ -z "$CHEZ_TMP" ]]; then
    CHEZ_TMP="$(mktemp -d)" || { RENDER_BROKEN=1; err "mktemp failed; cannot decide path ownership"; return 2; }
    mkdir -p "$CHEZ_TMP/home"
  fi
  sdir="$CHEZ_TMP/src"
  rm -rf "$sdir"
  mkdir -p "$sdir/$(dirname "${src#home/}")"
  : >"$sdir/${src#home/}"
  [[ -f home/.chezmoiignore ]] && cp home/.chezmoiignore "$sdir/.chezmoiignore"
  if ! list="$(HOME="$CHEZ_TMP/home" XDG_CONFIG_HOME="$CHEZ_TMP/home/.config" XDG_CONFIG_DIRS="$CHEZ_TMP/home/xdg" \
        chezmoi managed --source "$sdir" --destination "$CHEZ_TMP/home/dest" --config "$CHEZ_TMP/chezmoi.toml" \
        --no-tty --path-style relative \
        --override-data "{\"chezmoi\":{\"os\":\"$os\"},\"hostProfile\":\"$prof\",\"gui\":$gui}" \
        2>"$CHEZ_TMP/chezmoi.err")"; then
    RENDER_BROKEN=1
    err "chezmoi managed failed for home/.chezmoiignore (os=$os hostProfile=$prof gui=$gui); path ownership is undecidable:"
    tail -n 3 "$CHEZ_TMP/chezmoi.err" | sed 's/^/      /' >&2
    return 2
  fi
  grep -Fxq -- "$tgt" <<<"$list" && return 0
  return 1
}

# ignored_on_hosts <hosts "os:profile ..."> <source path> <target>: sets
# UNCOVERED to the hosts where chezmoi still manages the target (space
# separated, "os/profile/gui=<bool>"); returns 1 when chezmoi could not decide
# (already reported). Not run in a subshell, so errors survive.
ignored_on_hosts() {
  local hosts="$1" src="$2" tgt="$3" h os prof gui rc
  UNCOVERED=""
  for h in $hosts; do
    os="${h%%:*}"; prof="${h#*:}"
    for gui in true false; do
      managed_on_host "$os" "$prof" "$gui" "$src" "$tgt"; rc=$?
      [[ $rc -eq 2 ]] && return 1
      [[ $rc -eq 0 ]] && UNCOVERED+="$os/$prof/gui=$gui "
    done
  done
  return 0
}

# check_path_collisions <xdg|home.file> <hosts> <newline-separated full targets>
check_path_collisions() {
  local kind="$1" hosts="$2" keys="$3" sources key tgt src label
  sources="$(chezmoi_sources)" || { err "cannot list chezmoi sources under home/"; return; }
  while IFS= read -r key; do
    [[ -z "$key" ]] && continue
    if [[ "$kind" == xdg ]]; then label="xdg.configFile.\"${key#.config/}\""; else label="home.file.\"$key\""; fi
    while IFS=$'\t' read -r tgt src; do
      [[ "$tgt" == "$key" || "$tgt" == "$key"/* ]] || continue
      ignored_on_hosts "$hosts" "$src" "$tgt" || return
      [[ -z "$UNCOVERED" ]] && continue
      err "$label (Home Manager) collides with chezmoi source $src; not ignored on: ${UNCOVERED% }. One owner per path: ignore it in home/.chezmoiignore on every host where Home Manager owns it, or drop one side"
    done <<<"$sources"
  done <<<"$keys"
}

# xdg keys are relative to ~/.config; chezmoi targets are relative to ~.
check_xdg_collisions() { # check_xdg_collisions <hosts> <newline-separated xdg keys>
  local keys="" k
  while IFS= read -r k; do
    [[ -z "$k" ]] && continue
    keys+=".config/$k"$'\n'
  done <<<"$2"
  check_path_collisions xdg "$1" "$keys"
}

e0=$ERRORS
check_xdg_collisions "$TEXT_HOSTS" "$XDG_TEXT_KEYS"
if ((ERRORS == e0 && scan_failed == 0 && RENDER_BROKEN == 0)); then
  ok "no xdg.configFile target is also a live chezmoi source"
fi

# home.file: literal targets are collision-checked; a declaration whose target
# text cannot decide (interpolated or let-bound name, merge, generated attrset,
# non-literal `target`) is a NOTE and is never reported as verified.
e0=$ERRORS
HF_TEXT_KEYS=""
hf_dyn=0
while IFS='|' read -r kind where a _; do
  case "$kind" in
    HF) HF_TEXT_KEYS+="$a"$'\n' ;;
    HFDYN)
      hf_dyn=$((hf_dyn + 1))
      printf '[NOTE] %s: %s cannot be resolved in text mode; its chezmoi ownership is only decided by --eval\n' "$where" "$a"
      ;;
  esac
done <<<"$NIX_FINDINGS"
check_path_collisions home.file "$TEXT_HOSTS" "$HF_TEXT_KEYS"
if ((ERRORS == e0 && scan_failed == 0 && RENDER_BROKEN == 0)); then
  if ((hf_dyn == 0)); then
    ok "no literal home.file target is also a live chezmoi source"
  else
    printf '[NOTE] home.file: %d declaration(s) not verifiable in text mode (literal ones passed); run with --eval\n' "$hf_dyn"
  fi
fi

# 13. (--eval only) The same policy on the *evaluated* Home Manager config, for
# what text cannot see: let-bound/merged attrsets, xdg.configFile = <expr>,
# options enabled by other modules or defaults, and package names after
# overlays. One `nix eval --json` per profile (~1 s each, ~4 s total here) is
# too slow and too dependent on the nix store/network for the pre-commit hook,
# so the default run skips it. It is meant for CI, but ops/ci.sh does not
# run it yet (wiring it needs the user's approval).
# It also resolves every home.file target (cfg.home.file.<n>.target, so a
# `target` option is honoured) and applies the chezmoi collision check per
# profile host: the nested, let-bound and generated home.file declarations
# that text mode reports as NOTE are decided here.
# Needs nix and jq; their absence is a failure, not a skip.
# Tolerated, not declared by us: the home-manager package that
# programs.home-manager adds to home.packages, programs.man (Home Manager default) and
# services.vicinae (renamed alias of programs.vicinae); xdg keys Home Manager
# generates itself (dconf/.keep, environment.d/10-home-manager.conf,
# nix/nix.conf).
EVAL_PROFILES="${VALIDATE_EVAL_PROFILES:-linux-desktop linux-cli wsl macos}"
# shellcheck disable=SC2016 # Nix source, not shell: no expansion wanted
EVAL_QUERY='cfg: let
  inherit (builtins) attrNames attrValues filter map isAttrs tryEval;
  on = set: n: let r = tryEval (let v = set.${n}; in isAttrs v && (v.enable or false) == true); in r.success && r.value;
  en = set: filter (on set) (attrNames set);
in {
  packages = map (p: p.pname or (builtins.parseDrvName p.name).name) cfg.home.packages;
  programs = en cfg.programs;
  services = en cfg.services;
  xdg = attrNames cfg.xdg.configFile;
  files = map (f: f.target) (filter (f: f.enable or true) (attrValues cfg.home.file));
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
      eval_err="$(mktemp)"
      if ! json="$(nix eval --no-eval-cache --json "path:$ROOT_DIR/nix#homeConfigurations.$profile.config" --apply "$EVAL_QUERY" 2>"$eval_err")" ||
         ! jq -e 'has("packages") and has("programs") and has("services") and has("xdg") and has("files")' <<<"$json" >/dev/null 2>&1; then
        err "nix eval failed for homeConfigurations.$profile"
        tail -n 5 "$eval_err" | sed 's/^/      /' >&2
        rm -f "$eval_err"
        continue
      fi
      rm -f "$eval_err"
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
      # Ownership is judged on this profile's own host (macos is darwin).
      case "$profile" in macos | darwin*) host="darwin:$profile" ;; *) host="linux:$profile" ;; esac
      check_xdg_collisions "$host" "$profile_keys"
      # Home Manager also lists every xdg.configFile entry in home.file (as
      # .config/<key>): those were checked above, so report each only once.
      check_path_collisions home.file "$host" "$(jq -r '(.xdg | map(".config/" + .)) as $x | .files[] | select(. as $f | $x | index($f) | not)' <<<"$json")"
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
