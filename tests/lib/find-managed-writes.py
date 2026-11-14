#!/usr/bin/env python3
"""Find scripts that write to files chezmoi manages without checking.

Used by tests/bash/managed-writers.bats (bug type 4: double ownership). A
script that rewrites a chezmoi-managed file makes `sys-update` refuse to run
(hand-edited managed file) and the next `chezmoi apply` undoes the edit.

  python3 -I find-managed-writes.py ROOT [--allow FILE] [--list-managed]
                                          [--nix-overlap]

Managed targets are derived from the names in ROOT/home (chezmoi source
state): dot_ -> ".", executable_/private_/readonly_/empty_/create_/exact_/
symlink_ prefixes and the .tmpl suffix dropped. modify_ files are managed
targets too (named without the prefix). run_* scripts, .chezmoi* and
*.example are not targets.

A write is: `>`/`>>` redirection, cp, install, mv, ln, tee, sed -i, touch.
Its target counts when it expands to a managed path: `$HOME/...`, `~/...`,
`$XDG_CONFIG_HOME/...`, `${XDG_CONFIG_HOME:-$HOME/.config}/...` or a variable
assigned from one of those in the same file. A write through a variable whose
value is not visible in the file (a function argument) cannot be resolved:
it is reported only if the file also names a managed path literally, so a
script that handles rc files through `local rc="$1"` is still held to the
rule. A write is guarded when `chezmoi_managed` or `chezmoi source-path`
appears within GUARD_LINES lines before it.

--nix-overlap lists targets that nix/modules/home sets through
xdg.configFile / home.file and that chezmoi also manages (double ownership).

Allowlist: `file-glob | target-glob | reason` lines; `#` comments.
Exit 1 when anything is reported.
"""
import fnmatch
import os
import re
import shlex
import subprocess
import sys

GUARD_LINES = 25
PREFIXES = ("executable_", "private_", "readonly_", "empty_", "create_", "exact_", "symlink_", "modify_")


def file_set(root):
    if os.path.isdir(os.path.join(root, ".git")):
        out = subprocess.run(
            ["git", "-C", root, "ls-files", "--cached", "--others", "--exclude-standard"],
            capture_output=True, text=True, check=True).stdout.split("\n")
        return [f for f in out if f and os.path.lexists(os.path.join(root, f))]
    files = []
    for d, dirs, names in os.walk(root):
        dirs[:] = [x for x in dirs if x != ".git"]
        files += [os.path.relpath(os.path.join(d, n), root) for n in names]
    return files


def target_of(rel):
    """home/dot_config/x.tmpl -> .config/x ; None when it is not a target."""
    parts = rel.split("/")
    if parts[0] != "home" or len(parts) < 2:
        return None
    out = []
    for i, p in enumerate(parts[1:]):
        if p.startswith(".chezmoi") or p.endswith(".example") or p in ("README.md", ".gitignore", ".DS_Store"):
            return None
        if p.startswith(("run_", "run-")):
            return None
        changed = True
        while changed:
            changed = False
            for pre in PREFIXES:
                if p.startswith(pre):
                    p = p[len(pre):]
                    changed = True
        if p.startswith("dot_"):
            p = "." + p[4:]
        if i == len(parts) - 2 and p.endswith(".tmpl"):
            p = p[:-5]
        out.append(p)
    return "/".join(out)


def managed_targets(files):
    return {t for t in (target_of(f) for f in files) if t}


HOME_ALIASES = [
    (re.compile(r'^\$\{XDG_CONFIG_HOME:-\$\{?HOME\}?/\.config\}'), "@HOME/.config"),
    (re.compile(r'^\$\{XDG_DATA_HOME:-\$\{?HOME\}?/\.local/share\}'), "@HOME/.local/share"),
    (re.compile(r'^\$\{XDG_STATE_HOME:-\$\{?HOME\}?/\.local/state\}'), "@HOME/.local/state"),
    (re.compile(r'^\$\{?XDG_CONFIG_HOME\}?'), "@HOME/.config"),
    (re.compile(r'^\$\{?XDG_DATA_HOME\}?'), "@HOME/.local/share"),
    (re.compile(r'^\$\{?XDG_STATE_HOME\}?'), "@HOME/.local/state"),
    (re.compile(r'^\$\{?HOME\}?'), "@HOME"),
    (re.compile(r'^~'), "@HOME"),
]
ASSIGN = re.compile(r'^\s*(?:local\s+|readonly\s+|export\s+)?([A-Za-z_][A-Za-z0-9_]*)=(.*)$')
REDIR = re.compile(r'(?<![0-9&<>])>>?\s*(?!&)(["\']?)([^\s"\'|;&)]+)\1')
COMMANDS = ("cp", "install", "mv", "ln", "tee", "touch", "sed")


def unquote(v):
    v = v.strip()
    v = re.split(r'\s+#', v)[0].strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
        v = v[1:-1]
    return v


def expand(value, env, depth=0):
    """Return a '@HOME/...' string, or None when not resolvable to HOME."""
    if depth > 4:
        return None
    for rx, repl in HOME_ALIASES:
        m = rx.match(value)
        if m:
            return repl + value[m.end():]
    m = re.match(r'^\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?(.*)$', value)
    if m and m.group(1) in env:
        base = expand(env[m.group(1)], env, depth + 1)
        if base:
            return base + m.group(2)
    return None


def targets_in(line):
    """(kind, raw-target) pairs written by this line."""
    found = []
    for m in REDIR.finditer(line):
        if m.group(2) not in ("/dev/null",) and not m.group(2).startswith("/dev/"):
            found.append(("redirect", m.group(2)))
    for seg in re.split(r'\|\||&&|[|;]', line):
        try:
            toks = shlex.split(seg, comments=True)
        except ValueError:
            continue
        while toks and (toks[0] in ("then", "do", "else", "{", "(", "!", "sudo", "command") or "=" in toks[0].split("/")[0]):
            toks = toks[1:]
        if not toks or toks[0] not in COMMANDS:
            continue
        args = [t for t in toks[1:] if not t.startswith("-")]
        if toks[0] == "sed":
            if not any(t.startswith("-i") or t == "--in-place" for t in toks[1:]) or not args:
                continue
            found.append(("sed -i", args[-1]))
        elif toks[0] == "tee":
            found += [("tee", a) for a in args]
        elif toks[0] == "touch":
            found += [("touch", a) for a in args]
        elif len(args) >= 2:
            found.append((toks[0], args[-1]))
    return found


def load_allow(path):
    rules = []
    if path:
        for line in open(path):
            line = line.split("#", 1)[0].strip()
            parts = [x.strip() for x in line.split("|")]
            if len(parts) >= 2 and parts[0]:
                rules.append((parts[0], parts[1]))
    return rules


def nix_overlap(root, files, managed):
    hits = []
    for f in files:
        if not (f.startswith("nix/modules/home/") and f.endswith(".nix")):
            continue
        text = open(os.path.join(root, f), errors="replace").read()
        for m in re.finditer(r'(?:xdg\.configFile|xdg\.dataFile|home\.file)\.?"?([^"\s=]+)"?\s*(?:=|\.)', text):
            name = m.group(1)
            for t in (name, ".config/" + name, ".local/share/" + name):
                if t in managed:
                    hits.append(f"{f}: nix writes {t}, chezmoi manages it too")
        for m in re.finditer(r'(?:xdg\.configFile|xdg\.dataFile|home\.file)\s*=\s*\{(.*?)\n  \};', text, re.S):
            for k in re.finditer(r'^\s*"([^"]+)"\s*=', m.group(1), re.M):
                for t in (k.group(1), ".config/" + k.group(1), ".local/share/" + k.group(1)):
                    if t in managed:
                        hits.append(f"{f}: nix writes {t}, chezmoi manages it too")
    return sorted(set(hits))


def main():
    args = sys.argv[1:]
    allow = None
    if "--allow" in args:
        i = args.index("--allow")
        allow = args[i + 1]
        del args[i:i + 2]
    flags = {a for a in args if a.startswith("--")}
    root = os.path.abspath([a for a in args if not a.startswith("--")][0])
    files = file_set(root)
    managed = managed_targets(files)
    if "--list-managed" in flags:
        print("\n".join(sorted(managed)))
        return 0
    rules = load_allow(allow)
    used = set()
    out = []

    def allowed(src, tgt):
        for i, (sg, tg) in enumerate(rules):
            if fnmatch.fnmatch(src, sg) and fnmatch.fnmatch(tgt, tg):
                used.add(i)
                return True
        return False

    if "--nix-overlap" in flags:
        out += [h for h in nix_overlap(root, files, managed) if not allowed(h.split(":")[0], h.split("writes ")[1].split(",")[0])]
    else:
        scripts = [f for f in files if (
            (f.startswith(("ops/", "scripts/")) and "/test/" not in f and not f.endswith((".md", ".json", ".bats", ".txt", ".py")))
            or f.startswith("home/dot_local/bin/")
            or re.match(r'nix/modules/home/scripts/.*\.sh$', f))]
        for src in sorted(scripts):
            lines = open(os.path.join(root, src), errors="replace").read().split("\n")
            env = {}
            for line in lines:
                m = ASSIGN.match(line)
                if m:
                    env[m.group(1)] = unquote(m.group(2))
            names_managed = False
            for line in lines:
                if line.lstrip().startswith("#"):
                    continue
                for m in re.finditer(r'(?:\$\{?HOME\}?|~)/([A-Za-z0-9_./-]+)', line):
                    if m.group(1).rstrip("/") in managed:
                        names_managed = True
            for n, line in enumerate(lines, 1):
                if line.lstrip().startswith("#"):
                    continue
                for kind, raw in targets_in(line):
                    raw = unquote(raw)
                    resolved = expand(raw, env)
                    unresolved_var = resolved is None and re.match(r'^\$\{?[A-Za-z_]', raw)
                    if resolved is None:
                        if not (unresolved_var and names_managed):
                            continue
                        label = raw
                    else:
                        rel = resolved.split("@HOME/", 1)[1] if "@HOME/" in resolved else None
                        if rel is None or rel.rstrip("/") not in managed:
                            continue
                        label = rel
                    window = "\n".join(lines[max(0, n - 1 - GUARD_LINES):n - 1])
                    if "chezmoi_managed" in window or "chezmoi source-path" in window:
                        continue
                    if allowed(src, label):
                        continue
                    out.append(f"{src}:{n}: {kind} -> {label} (unguarded write to a chezmoi-managed path)")

    for o in sorted(set(out)):
        print(o)
    stale = [r for i, r in enumerate(rules) if i not in used]
    if stale and "--check-allow-used" in flags:
        for sg, tg in stale:
            print(f"unused allowlist entry: {sg} | {tg}")
        return 1
    return 1 if out else 0


if __name__ == "__main__":
    sys.exit(main())
