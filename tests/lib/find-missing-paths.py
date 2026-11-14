#!/usr/bin/env python3
"""List repo-relative paths that code or docs reference but the repo lacks.

Used by tests/bash/path-contract.bats (bug type 7: stale references).

  python3 -I find-missing-paths.py ROOT [--allow FILE] [--check-allow-used]

--check-allow-used also fails on allowlist entries that matched nothing.

Existence is judged against the file set (git tracked + untracked-not-ignored,
or a plain walk when ROOT has no .git), never against the disk, so a
gitignored local file cannot make the check pass here and fail in CI.

Sources scanned:
  shell     ops/**, scripts/**, home/dot_local/bin/*, home/**/*.{tmpl,fish,sh,zsh},
            nix/modules/home/scripts/*.sh, .lefthook.yml, .github/workflows/*.yml
            and the `run =` blocks of mise.toml:
              bash|source|. <repo path>, and $REPO_ROOT|$ROOT|$ROOT_DIR|
              $SCRIPT_DIR|$DOTFILES_DIR|$WS_*_DIR based paths. A variable is
              resolved only when the file defines it from BASH_SOURCE (the
              `$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)` idiom), or it
              is a known template variable; anything else is not guessed.
  nix       every ./relative or ../relative path literal in *.nix, resolved
            from the .nix file (imports, readFile, ExecStart scripts).
  markdown  relative links and backticked ops/ home/ nix/ tests/ docs/
            scripts/ paths in *.md outside docs/plans and docs/research.

Allowlist file: one entry per line, `source-glob | path-glob | reason`;
`#` starts a comment. Globs are fnmatch patterns over the repo-relative
source file and over the referenced path as written (variables resolved).
Output: `source:line: path (kind)` per missing reference; exit 1 if any.
"""
import fnmatch
import os
import re
import subprocess
import sys

TEMPLATE_VARS = {
    "DOTFILES_DIR": "",
    "dots": "",
    "WS_PROJECTS_DIR": "ops/projects",
    "WS_LOGGING_DIR": "ops/projects/logging",
    "WS_HEALTH_DIR": "ops/projects/health",
}
BASH_SRC = re.compile(r'\$\(cd "\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\)((?:/\.\.)*)" && pwd\)')
DEF = re.compile(r'^\s*(?:readonly\s+|export\s+)?([A-Za-z_][A-Za-z0-9_]*)=')
VAR_PATH = re.compile(r'\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?/([A-Za-z0-9_.][A-Za-z0-9_./-]*)')
SRC_DIR_PATH = re.compile(r'(?:\$\{BASH_SOURCE\[0\]%/\*\}|\$\(dirname "\$\{BASH_SOURCE\[0\]\}"\))/([A-Za-z0-9_.][A-Za-z0-9_./-]*)')
LITERAL = re.compile(r'(?:^|[\s;&|(`"\'])(?:bash|sh|source|\.|python3(?: -I)?)\s+["\']?((?:ops|scripts|home|nix|tests)/[A-Za-z0-9_.][A-Za-z0-9_./-]*)')
MISE_LITERAL = re.compile(r'(?:^|[^A-Za-z0-9_./-])((?:ops|scripts)/[A-Za-z0-9_][A-Za-z0-9_./-]*\.(?:sh|py))')
NIX_PATH = re.compile(r'(?<![A-Za-z0-9_"$}.)\]/-])(\.\.?/[A-Za-z0-9_.][A-Za-z0-9_./-]*)')
MD_LINK = re.compile(r'\]\(([^)\s]+)\)')
MD_TICK = re.compile(r'`((?:ops|home|nix|tests|docs|scripts)/[^`\s]+)`')


def file_set(root):
    if os.path.isdir(os.path.join(root, ".git")):
        out = subprocess.run(
            ["git", "-C", root, "ls-files", "--cached", "--others", "--exclude-standard"],
            capture_output=True, text=True, check=True).stdout.split("\n")
        files = [f for f in out if f and os.path.lexists(os.path.join(root, f))]
    else:
        files = []
        for d, dirs, names in os.walk(root):
            dirs[:] = [x for x in dirs if x != ".git"]
            for n in names:
                files.append(os.path.relpath(os.path.join(d, n), root))
    dirs = set()
    for f in files:
        p = os.path.dirname(f)
        while p:
            dirs.add(p)
            p = os.path.dirname(p)
    return set(files), dirs


def clean(p):
    p = p.rstrip(".,:;)")
    # `file:12`, `file:2-5`, `file:33,49,53`: a line reference into the file.
    p = re.sub(r':[0-9][0-9,-]*$', '', p)
    if re.search(r'[$*{}<>`~\\]|\.\.\.|…', p) or p.endswith("/..."):
        return None
    return p


def load_allow(path):
    rules = []
    if not path:
        return rules
    for line in open(path):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        parts = [x.strip() for x in line.split("|")]
        if len(parts) < 2:
            continue
        rules.append((parts[0], parts[1]))
    return rules


def main():
    args = sys.argv[1:]
    allow = None
    if "--check-allow-used" in args:
        args.remove("--check-allow-used")
    if "--allow" in args:
        i = args.index("--allow")
        allow = args[i + 1]
        del args[i:i + 2]
    root = os.path.abspath(args[0])
    files, dirs = file_set(root)
    files.add(".git")  # the repository itself, never part of the file set
    rules = load_allow(allow)
    missing = []

    def exists(rel):
        rel = os.path.normpath(rel)
        return rel in files or rel in dirs

    used = set()

    def report(src, lineno, ref, kind, resolved):
        if exists(resolved):
            return
        resolved = os.path.normpath(resolved)
        for i, (sg, pg) in enumerate(rules):
            if fnmatch.fnmatch(src, sg) and (fnmatch.fnmatch(ref, pg) or fnmatch.fnmatch(resolved, pg)):
                used.add(i)
                return
        missing.append(f"{src}:{lineno}: {ref} ({kind})")

    def read(rel):
        try:
            return open(os.path.join(root, rel), errors="replace").read().split("\n")
        except OSError:
            return []

    shell_re = re.compile(
        r'^(ops/.*|scripts/.*|home/dot_local/bin/.*|home/.*\.(tmpl|fish|sh|zsh)|'
        r'nix/modules/home/scripts/.*\.sh|\.lefthook\.yml|\.github/workflows/.*\.yml)$')
    for src in sorted(files):
        if src.endswith((".bats", ".md", ".json", ".yaml", ".example")) or "/test/" in src:
            continue
        if not shell_re.match(src):
            continue
        lines = read(src)
        here = os.path.dirname(src)
        # Variables this file derives from BASH_SOURCE: name -> repo-relative dir.
        known = {}
        for line in lines:
            m = DEF.match(line)
            b = BASH_SRC.search(line)
            if m and b:
                known[m.group(1)] = os.path.normpath(os.path.join(here, *([".."] * b.group(1).count("/.."))))
        for n, line in enumerate(lines, 1):
            if line.lstrip().startswith("#"):
                continue
            for m in VAR_PATH.finditer(line):
                var, rest = m.group(1), clean(m.group(2))
                if rest is None:
                    continue
                if var in known:
                    base = known[var]
                elif var in TEMPLATE_VARS:
                    base = TEMPLATE_VARS[var]
                else:
                    continue
                report(src, n, f"${var}/{rest}", "var", os.path.join(base, rest))
            for m in SRC_DIR_PATH.finditer(line):
                rest = clean(m.group(1))
                if rest:
                    report(src, n, "$BASH_SOURCE dir/" + rest, "sibling", os.path.join(here, rest))
            for m in LITERAL.finditer(line):
                rest = clean(m.group(1))
                if rest:
                    report(src, n, rest, "literal", rest)

    # mise.toml run blocks
    in_run = False
    for n, line in enumerate(read("mise.toml"), 1):
        if line.startswith("[tasks"):
            in_run = False
        if line.startswith("run = "):
            in_run = True
        if in_run:
            for m in MISE_LITERAL.finditer(line):
                report("mise.toml", n, m.group(1), "mise", m.group(1))

    for src in sorted(f for f in files if f.endswith(".nix")):
        here = os.path.dirname(src)
        for n, line in enumerate(read(src), 1):
            if line.lstrip().startswith("#"):
                continue
            for m in NIX_PATH.finditer(line):
                rest = clean(m.group(1))
                if rest:
                    report(src, n, rest, "nix", os.path.join(here, rest))

    for src in sorted(f for f in files if f.endswith(".md")):
        if src.startswith(("docs/plans/", "docs/research/")):
            continue
        here = os.path.dirname(src)
        in_fence = False
        for n, line in enumerate(read(src), 1):
            if line.lstrip().startswith("```"):
                in_fence = not in_fence
                continue
            if in_fence:
                continue
            for m in MD_LINK.finditer(line):
                tgt = m.group(1).split("#", 1)[0]
                if not tgt or re.match(r'^[a-z][a-z0-9+.-]*:', tgt) or tgt.startswith("/"):
                    continue
                tgt = clean(tgt)
                if tgt:
                    report(src, n, tgt, "link", os.path.join(here, tgt))
            for m in MD_TICK.finditer(line):
                tgt = clean(m.group(1))
                if tgt:
                    report(src, n, tgt, "path", tgt)

    for m in sorted(set(missing)):
        print(m)
    stale = [r for i, r in enumerate(rules) if i not in used]
    if stale and "--check-allow-used" in sys.argv:
        for sg, pg in stale:
            print(f"unused allowlist entry: {sg} | {pg}")
        return 1
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main())
