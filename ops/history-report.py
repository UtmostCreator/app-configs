#!/usr/bin/env python3
r"""Sanitising shell-history workflow report.

Reads shell history (atuin sqlite / atuin jsonl export / fish_history /
bash_history) plus optional sys-update run logs and a dotfiles repo, and
writes aggregate metrics only: first tokens, argument-collapsed patterns,
workflow timings, failures, n-grams and tool adoption. Raw commands, paths,
hosts, URLs and free-form arguments never reach the output.

Usage:
  python3 -I ops/history-report.py --auto --out DIR        # this machine
  python3 -I ops/history-report.py --out DIR \
      [--atuin-db NAME=PATH]... [--atuin-jsonl NAME=PATH]... \
      [--fish NAME=PATH]... [--bash NAME=PATH]... \
      [--sys-update-runs DIR] [--repo DOTFILES_REPO] [--top N]

Outputs: DIR/report.json (all metrics) and DIR/report.md (tables).
Also: `mise run history:report`. Never commit a report from a work machine
without reading it: the sanitiser is allowlist-based, but review is cheap.
"""
import argparse, collections, datetime as dt, json, os, re, shlex, shutil
import sqlite3, statistics, sys

# ---------------------------------------------------------------- vocab
KNOWN = set("""
git gh npm npx pnpm yarn bun node deno php composer artisan python python3 pip pipx uv
cargo rustc go make just mise nix nix-shell nix-env nixos-rebuild home-manager chezmoi
docker podman kubectl helm terraform ssh scp rsync mosh curl wget http jq yq
ls ll lt la eza exa cd z zi pwd cat bat less more head tail grep rg ag fd find fzf
sed awk sort uniq wc tr cut xargs tee echo printf env export set unset source exec
vim nvim vi nano code hx emacs subl open xdg-open wsl-open
mkdir rm rmdir cp mv ln touch chmod chown stat file du df dust ncdu free top htop btop
ps kill pkill killall killport ports psmem conns topn logtop curl-timing rgc
systemctl journalctl sudo doas man tldr which type command whereis history atuin
tmux zellij screen clear exit reset fish bash zsh sh watch watchexec entr
lazygit tig delta difft diff yazi yy ranger brew mas herd valet mysql psql redis-cli
sqlite3 ping dig nslookup host traceroute ip ifconfig netstat ss lsof nc telnet
tar zip unzip gzip gunzip 7z base64 openssl gpg ssh-add ssh-keygen op
claude codex opencode copilot aider gemini ollama
sys-update sys-cleanup sys-doctor sys-install sys-readiness sys-setup sys-update-log syscd
ws ws-start ws-stop ws-health ws-logs ws-restart ws-verify ws-fix
phpunit pint pest vendor/bin/phpunit vendor/bin/pint vendor/bin/pest
pytest ruff black mypy eslint prettier tsc vite nuxt next vitest jest playwright
gradle ./gradlew java kotlin mvn adb flatpak snap apt dnf pacman
date sleep time timeout true false test bats shellcheck shfmt treefmt nixfmt statix
gst gco gl gp gd gau gaa gai gcmsg gti it gi pa pat punit pint nr ni nreset reload
tree glow mdcat jless fx gum lnav k9s
scc lizard for if while read newgrp gsettings dconf wpctl pactl nix-instantiate pgrep lsusb repomix
res restsift pw-play vicinae nautilus android-studio sync-start sync-stop sync-open gh-stars-export
git-branch-origin reindex-cbm dsh-remote dsh-remote-status clipcopy wsl-open hyperfine xh zc patw lg
""".split())

GIT_SUB = set("""
add am apply archive bisect blame branch bundle checkout cherry cherry-pick clean clone
commit config describe diff fetch format-patch fsck gc grep init log ls-files ls-remote
merge mv notes pull push range-diff rebase reflog remote reset restore revert rm
shortlog show sparse-checkout stash status submodule switch tag worktree whatchanged
""".split())
NPM_SCRIPTS = set("""dev build test lint start format typecheck preview watch serve
generate prod production storybook e2e check fix clean install""".split())
ARTISAN_NS = set("""migrate test tinker make route cache config optimize queue db serve
schedule view key storage vendor event model about list horizon telescope""".split())
MULTI = {  # tools whose first argument is a meaningful subcommand
    "npm", "pnpm", "yarn", "bun", "composer", "nix", "home-manager", "chezmoi",
    "docker", "podman", "kubectl", "gh", "mise", "cargo", "go", "systemctl",
    "atuin", "brew", "herd", "valet", "op", "uv", "pip",
}
# Not in MULTI on purpose: `just <recipe>` and `claude <prompt>` would print
# project-specific recipe names or prompt words.
SUBCMD_RE = re.compile(r"^[a-z][a-z0-9:-]{0,24}$")

INTERACTIVE = [  # (label, regex on raw command) long-lived / interactive
    ("git pager (log/diff/show)", r"^git\s+(log|lg|hist|adog|diff|d|gd|ds|dc|dw|dcw|show|sh|blame|praise|pickp|pickgp)\b(?!.*(--stat|--name-only|--name-status|--no-pager|\s-\d+\b|\s-n\s))"),
    ("systemd pager", r"^(sudo\s+)?(systemctl\b.*\bstatus\b|journalctl\b(?!.*\s-f))"),
    ("remote shell", r"^(sudo\s+)?(ssh|mosh|dsh-remote)\b(?!-)"),
    ("editor", r"^(sudo\s+)?(vim?|nvim|nano|code|hx|emacs|subl)\b"),
    ("pager/man", r"^(less|more|man|tldr|glow)\b"),
    ("log tail", r"(\btail\s+-[a-zA-Z]*[fF]|journalctl\b.*\s-f|\bws-logs\b|\blog-workspace\b|\blnav\b)"),
    ("dev server", r"(\b(npm|pnpm|yarn|bun)\s+(run\s+)?(dev|start|serve|watch|storybook)\b|artisan\s+(serve|queue:work|horizon|schedule:work)|\bvite\b|docker\s+compose\s+up(?!.*\s-d)|\bws\b(\s|$)|\bws-start\b)"),
    ("watcher", r"^(watch|watchexec|entr)\b"),
    ("TUI", r"^(btop|htop|top|lazygit|tig|yazi|yy|k9s|ncdu|ranger|zellij|tmux)\b"),
    ("AI agent", r"^(claude|codex|opencode|copilot|aider|gemini|ollama)\b"),
    ("REPL/db shell", r"^(python3?|node|php|psql|mysql|sqlite3|redis-cli)\s*$|artisan\s+tinker"),
    ("nested shell", r"^(fish|bash|zsh|sh|nix\s+(develop|shell)|nix-shell)\s*$|^nix\s+(develop|shell)\b"),
    ("sleep", r"^sleep\b"),
]
INTERACTIVE = [(l, re.compile(r)) for l, r in INTERACTIVE]

WORKFLOWS = [  # (name, regex on raw)
    ("git status", r"^git\s+(st|status|s)\b|^gst\b"),
    ("git add", r"^git\s+add\b|^ga[aui]?\b"),
    ("git commit", r"^git\s+(commit|ci|cam|com|oops|fixprev|gcfp)\b|^gcmsg\b"),
    ("git push", r"^git\s+(push|pf|pnv|pfnv|ppr)\b|^gp\b"),
    ("git pull/fetch/sync", r"^git\s+(pull|up|fetch|fp|sync|rbd)\b|^gl\b"),
    ("git branch switch", r"^git\s+(checkout|co|switch|sw|swc|cob|nb|prevb|prb|fco)\b|^gco\b"),
    ("git diff/log/show", r"^git\s+(diff|d[a-z]*|log|lg|hist|show|sh|last)\b|^gd\b"),
    ("git stash", r"^git\s+(stash|ss|sst|ssu|sp|sa|sl)\b"),
    ("git rebase/merge", r"^git\s+(rebase|merge|cherry-pick)\b"),
    ("gh (PR/CI)", r"^gh\b"),
    ("php artisan test", r"artisan\s+test\b|^pat\b|^atest\b"),
    ("phpunit/pest", r"(phpunit|pest)\b|^punit\b"),
    ("php artisan (other)", r"artisan\b|^pa\b"),
    ("composer", r"^composer\b"),
    ("npm install/ci", r"^(npm|pnpm|yarn)\s+(i|install|ci|add)\b|^ni\b|^nreset\b"),
    ("npm build/lint/test", r"^(npm|pnpm|yarn)\s+(run\s+)?(build|lint|test|typecheck|format|check|generate)\b"),
    ("bats/shell tests", r"^(bats|shellcheck)\b|mise\s+(run\s+)?test"),
    ("gradle", r"gradlew?\b"),
    ("mise task", r"^mise\s+(run|r|tasks)\b|^mise\s+[a-z:]+\b"),
    ("just", r"^just\b"),
    ("sys-update", r"^sys-update\b|update-all\.sh"),
    ("home-manager switch", r"home-manager\s+(switch|build)"),
    ("nixos-rebuild", r"nixos-rebuild\b"),
    ("nix build/check/eval", r"^nix\s+(build|flake|eval|run|profile|store|log|search)\b"),
    ("chezmoi", r"^chezmoi\b"),
    ("docker", r"^(docker|podman)\b"),
    ("systemctl/journalctl", r"^(sudo\s+)?(systemctl|journalctl)\b"),
]
WORKFLOWS = [(n, re.compile(r)) for n, r in WORKFLOWS]

ADOPTION = {  # tool -> (regex on raw) ; plus "baseline" comparisons
    "cd": r"^cd\b", "z/zi (zoxide)": r"^(z|zi)\b",
    "ls": r"^ls\b", "eza/ll/lt": r"^(eza|ll|lt)\b",
    "cat": r"^cat\b", "bat": r"(^|\|\s*)bat\b",
    "grep": r"(^|\|\s*)grep\b", "rg/rgc/rggi": r"(^|\|\s*)(rg|rgc|rggi)\b",
    "find": r"^find\b", "fd": r"^fd\b",
    "fzf (explicit)": r"(^|\|\s*)fzf\b|git\s+fco",
    "top/htop": r"^(top|htop)\b", "btop": r"^btop\b",
    "du/ncdu": r"^(du|ncdu)\b", "dust": r"^dust\b",
    "lazygit/tig": r"^(lazygit|tig)\b", "delta/difft": r"(^|\|\s*)(delta|difft)\b|difftool",
    "yazi/yy": r"^(yazi|yy)\b", "just": r"^just\b", "mise run/tasks": r"^mise\s+(run|r|tasks|[a-z]+:[a-z:]+)\b",
    "watchexec": r"^watchexec\b", "gh": r"^gh\b", "git ppr/prreview": r"^git\s+(ppr|prreview|prfiles)\b",
    "atuin (cli)": r"^atuin\b", "history (builtin)": r"^history\b",
    "git sw/switch": r"^git\s+(switch|sw|swc)\b", "git checkout/co": r"^git\s+(checkout|co)\b",
}
ADOPTION = {k: re.compile(v) for k, v in ADOPTION.items()}

FAIL_IGNORE = {130, 141, -1}  # Ctrl-C, SIGPIPE, not recorded

# ---------------------------------------------------------------- load
def load_atuin_db(path):
    uri = "file:%s?mode=ro" % path
    con = sqlite3.connect(uri, uri=True)
    rows = con.execute("select timestamp,duration,exit,command,session from history "
                       "where deleted_at is null order by timestamp").fetchall()
    return [dict(ts=r[0] / 1e9, dur=(r[1] / 1e9 if r[1] and r[1] > 0 else None),
                 exit=r[2], cmd=r[3], session=r[4]) for r in rows]

def load_atuin_jsonl(path):
    out = []
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            try:
                r = json.loads(line)
            except ValueError:
                continue
            if r.get("deleted_at"):
                continue
            d = r.get("duration")
            out.append(dict(ts=r["timestamp"] / 1e9, dur=(d / 1e9 if d and d > 0 else None),
                            exit=r.get("exit"), cmd=r.get("command", ""), session=r.get("session")))
    out.sort(key=lambda r: r["ts"])
    return out

def load_fish(path):
    out, cur = [], None
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith("- cmd: "):
                cur = dict(ts=None, dur=None, exit=None, session=None,
                           cmd=line[7:].rstrip("\n").replace("\\n", "\n").replace("\\\\", "\\"))
                out.append(cur)
            elif line.startswith("  when: ") and cur is not None:
                cur["ts"] = int(line[8:].strip() or 0)
    return out

def load_bash(path):
    out, ts = [], None
    with open(path, encoding="utf-8", errors="replace") as fh:
        for line in fh:
            line = line.rstrip("\n")
            if re.fullmatch(r"#\d{9,}", line):
                ts = int(line[1:]); continue
            if line.strip():
                out.append(dict(ts=ts, dur=None, exit=None, session=None, cmd=line))
    return out

# ---------------------------------------------------------------- sanitise
PATHISH = re.compile(r"[/~.]|^\$")
def norm_token(t):
    if t.startswith("-"):
        name, eq, _ = t.partition("=")
        if t.startswith("--"):
            ok = re.fullmatch(r"--[a-z][a-z0-9-]{0,24}", name)
            return (name + ("=<v>" if eq else "")) if ok else "--<flag>"
        # short flags: keep a cluster of letters (-la), mask attached values (-Pxyz)
        return name if re.fullmatch(r"-[a-zA-Z0-9]{0,3}", name) else name[:2] + "<v>"
    if PATHISH.search(t):
        return "<path>"
    return "<arg>"

def split(cmd):
    first = cmd.strip().split("\n")[0]
    first = re.split(r"\s*(?:\|\||&&|;|\|)\s*", first)[0]
    try:
        return shlex.split(first, comments=False)
    except ValueError:
        return first.split()

def first_token(cmd):
    toks = split(cmd)
    while toks and re.fullmatch(r"[A-Z_][A-Z0-9_]*=.*", toks[0]):
        toks = toks[1:]  # leading VAR=val
    if not toks:
        return "<empty>"
    t = toks[0]
    if t == "./vendor/bin/phpunit" or t.endswith("/phpunit"):
        return "phpunit"
    if t in KNOWN:
        return t
    if "/" in t or t.startswith("."):
        return "<script>"
    # never print unknown names: they may be private tools or project names
    return "<local-tool>" if shutil.which(t) else "<unknown>"

def pattern(cmd):
    p = _pattern(cmd)
    first = cmd.strip().split("\n")[0]
    if "\n" in cmd.strip():
        return p + " <multiline>"
    if re.search(r"\s(&&|\|\||;)\s|\s\|\s", first):
        return p + " +chain"
    return p

ENV_ASSIGN = re.compile(r"[A-Z_][A-Z0-9_]*=.*")
NPM_FAMILY = ("npm", "pnpm", "yarn", "bun")
NPM_SUBS = NPM_SCRIPTS | {"run", "i", "ci", "install", "add", "outdated", "audit", "update", "exec", "test", "x"}
TWO_LEVEL = ("nix", "docker", "gh")  # `nix flake check`, `docker compose up`, `gh pr view`

def _sub_git(rest):
    sub = rest[0]
    return [sub if (sub in GIT_SUB or sub in GIT_ALIASES) else "<sub>"], rest[1:]

def _sub_php(rest):
    if rest[0] != "artisan":
        return [], rest
    words, rest = ["artisan"], rest[1:]
    if rest:
        ns = rest[0].split(":")[0]
        words.append(rest[0] if ns in ARTISAN_NS and SUBCMD_RE.match(rest[0]) else "<artisan-cmd>")
        rest = rest[1:]
    return words, rest

def _sub_npm(rest):
    sub = rest[0] if SUBCMD_RE.match(rest[0]) and rest[0] in NPM_SUBS else "<sub>"
    words, rest = [sub], rest[1:]
    if sub == "run" and rest:
        words.append(rest[0] if rest[0] in NPM_SCRIPTS else "<script>")
        rest = rest[1:]
    return words, rest

def _sub_multi(head, rest):
    if not SUBCMD_RE.match(rest[0]):
        return [], rest
    words, rest = [rest[0]], rest[1:]
    if head in TWO_LEVEL and rest and SUBCMD_RE.match(rest[0]):
        words.append(rest[0])
        rest = rest[1:]
    return words, rest

def subcommand_words(head, rest):
    """Readable subcommand words for known tools, and the arguments left over."""
    if not rest:
        return [], rest
    if head == "git":
        return _sub_git(rest)
    if head == "php":
        return _sub_php(rest)
    if head in NPM_FAMILY:
        return _sub_npm(rest)
    if head in MULTI:
        return _sub_multi(head, rest)
    return [], rest

def masked_args(rest):
    """Arguments as placeholders, collapsing runs of the same placeholder."""
    out, last = [], None
    for t in rest:
        n = norm_token(t)
        if n == last and n.startswith("<"):
            continue
        out.append(n)
        last = n
    return out

def _pattern(cmd):
    toks = split(cmd)
    while toks and ENV_ASSIGN.fullmatch(toks[0]):
        toks = toks[1:]
    if not toks:
        return "<empty>"
    head = first_token(cmd)
    if head.startswith("<"):
        return head
    rest = toks[1:]
    if head == "sudo" and rest:
        return "sudo " + pattern(" ".join(shlex.quote(x) for x in rest))
    words, rest = subcommand_words(head, rest)
    return " ".join(([head] + words + masked_args(rest))[:8])

GIT_ALIASES = set()

# ---------------------------------------------------------------- stats
def pct(vals, p):
    if not vals:
        return None
    v = sorted(vals)
    k = (len(v) - 1) * p
    lo = int(k); hi = min(lo + 1, len(v) - 1)
    return v[lo] + (v[hi] - v[lo]) * (k - lo)

OUTLIER_S = 3600  # a non-interactive command "running" >1h is a stray/held session

def tstats(rows, cap=True):
    durs = [r["dur"] for r in rows if r["dur"] is not None and r["exit"] != -1]
    outl = sum(1 for d in durs if d > OUTLIER_S)
    if cap:
        durs = [d for d in durs if d <= OUTLIER_S]
    ex = [r for r in rows if r["exit"] is not None and r["exit"] not in FAIL_IGNORE]
    fails = sum(1 for r in ex if r["exit"] != 0)
    return dict(n=len(rows), fail_rate=(round(fails / len(ex), 3) if ex else None),
                median_s=rnd(pct(durs, .5)), p90_s=rnd(pct(durs, .9)),
                total_min=rnd(sum(durs) / 60) if durs else None, outliers_gt1h=outl)

def rnd(x):
    return None if x is None else round(x, 2)

def interactive_label(cmd):
    c = cmd.strip()
    for l, rx in INTERACTIVE:
        if rx.search(c):
            return l
    return None

def lev(a, b):
    if abs(len(a) - len(b)) > 2:
        return 9
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]

def raw_first(cmd):
    toks = split(cmd)
    return toks[0] if toks else ""

NOT_A_FAILURE = (0, None, -1, 130, 141)  # success, unknown, unrecorded, Ctrl-C, SIGPIPE
WRAPPERS = ("bash", "sh", "zsh", "fish", "exec", "sudo", "env", "nix", "xargs", "source", "set")
NIX_CMD = re.compile(r"^(sudo\s+)?(nix|home-manager|nixos-rebuild|sys-update|chezmoi)\b")
CURVE_POINTS = (5, 10, 25, 50, 100, 200)
NGRAM_GAP_S = 300  # consecutive commands further apart are not one sequence
RETRY_GAP_S = 60

def failed(r):
    return r["exit"] not in NOT_A_FAILURE

def date_range(rows):
    ts = [r["ts"] for r in rows if r["ts"]]
    if not ts:
        return None
    day = lambda t: dt.datetime.fromtimestamp(t, dt.timezone.utc).date().isoformat()
    return [day(min(ts)), day(max(ts))]

def coverage_curve(pattern_counts, n):
    cum, curve = 0, {}
    for i, (_, c) in enumerate(pattern_counts.most_common(), 1):
        cum += c
        if i in CURVE_POINTS:
            curve[i] = round(cum / n, 3)
    return curve

def adoption(rows):
    return {k: sum(1 for r in rows if rx.search(r["cmd"].strip())) for k, rx in ADOPTION.items()}

def workflow_stats(rows):
    wf = {}
    for wname, rx in WORKFLOWS:
        sel = [r for r in rows if rx.search(r["cmd"].strip()) and not interactive_label(r["cmd"])]
        if sel:
            wf[wname] = tstats(sel)
    return wf

def interactive_stats(rows):
    ic = collections.defaultdict(list)
    for r in rows:
        label = interactive_label(r["cmd"])
        if label:
            ic[label].append(r)
    return {k: tstats(v, cap=False) for k, v in sorted(ic.items(), key=lambda kv: -len(kv[1]))}

def slowest_by_total(rows, top):
    byp = collections.defaultdict(list)
    for r in rows:
        if not interactive_label(r["cmd"]):
            byp[pattern(r["cmd"])].append(r)
    slow = [(p, tstats(v)) for p, v in byp.items() if len(v) >= 3]
    slow = [s for s in slow if s[1]["total_min"]]
    slow.sort(key=lambda s: -s[1]["total_min"])
    return slow[:top]

def closest(word, vocab):
    # sorted(): ties break alphabetically. min() over a set picked by hash
    # order, which Python randomises per process, so reports differed run to run.
    return min(sorted(vocab), key=lambda k: lev(word, k))

def classify_127(first):
    """Why a command exited 127 ("not found"), without naming private tools."""
    if first in WRAPPERS:
        return "127 raised inside a %s-wrapped command/script" % first
    if first in KNOWN:
        return "known tool not on PATH at the time"
    if shutil.which(first):
        return "<local-tool> not on PATH at the time"
    best = closest(first, KNOWN) if first else ""
    limit = 1 if len(best) <= 4 else 2
    if first and 3 <= len(first) <= 12 and lev(first, best) <= limit:
        return "typo of %s" % best
    return "<unknown command>"

def exit127(rows, top):
    return collections.Counter(classify_127(raw_first(r["cmd"])) for r in rows if r["exit"] == 127).most_common(top)

def git_subcommand_typos(rows, top):
    vocab = GIT_SUB | set(GIT_ALIASES)
    gt = collections.Counter()
    for r in rows:
        t = split(r["cmd"])
        if len(t) > 1 and t[0] == "git" and not t[1].startswith("-") and t[1] not in vocab and r["exit"] not in (0, -1):
            best = closest(t[1], vocab)
            gt[("git typo of %s" % best) if lev(t[1], best) <= 2 else "git <unknown subcommand>"] += 1
    return gt.most_common(top)

def failing_patterns(rows):
    """(failures per pattern, attempts per pattern), Ctrl-C/SIGPIPE excluded."""
    ex = [r for r in rows if r["exit"] is not None and r["exit"] not in FAIL_IGNORE]
    return (collections.Counter(pattern(r["cmd"]) for r in ex if r["exit"] != 0),
            collections.Counter(pattern(r["cmd"]) for r in ex))

def sessions(rows):
    sess = collections.defaultdict(list)
    for r in rows:
        sess[r["session"]].append(r)
    for s in sess.values():
        s.sort(key=lambda r: r["ts"])
    return list(sess.values())

def retries_and_sudo(sess):
    """A failed command run again (or with sudo) within RETRY_GAP_S."""
    retries, sudo_rerun = collections.Counter(), collections.Counter()
    for s in sess:
        for a, b in zip(s, s[1:]):
            gap = b["ts"] - (a["ts"] + (a["dur"] or 0))
            if not failed(a) or gap > RETRY_GAP_S:
                continue
            if b["cmd"].strip() == a["cmd"].strip():
                retries[pattern(a["cmd"])] += 1
            elif b["cmd"].strip() in ("sudo " + a["cmd"].strip(), "sudo !!"):
                sudo_rerun[pattern(a["cmd"])] += 1
    return retries, sudo_rerun

def ngrams(sess):
    """Back-to-back pattern sequences within NGRAM_GAP_S: bigrams, trigrams, repeats."""
    bi, tri, rep = collections.Counter(), collections.Counter(), collections.Counter()
    for s in sess:
        pats = [pattern(r["cmd"]) for r in s]
        tss = [r["ts"] for r in s]
        for i in range(len(pats) - 1):
            if tss[i + 1] - tss[i] > NGRAM_GAP_S:
                continue
            if pats[i] == pats[i + 1]:
                rep[pats[i]] += 1
                continue
            bi[(pats[i], pats[i + 1])] += 1
            if i + 2 < len(pats) and tss[i + 2] - tss[i + 1] <= NGRAM_GAP_S and pats[i + 1] != pats[i + 2]:
                tri[(pats[i], pats[i + 1], pats[i + 2])] += 1
    return bi, tri, rep

def next_after_failure(sess, failing):
    after = collections.defaultdict(collections.Counter)
    for s in sess:
        for a, b in zip(s, s[1:]):
            if failed(a):
                after[pattern(a["cmd"])][pattern(b["cmd"])] += 1
    return {p: after[p].most_common(5) for p, _ in failing.most_common(8)}

def nix_failures(rows, top):
    return collections.Counter(pattern(r["cmd"].strip()) for r in rows
                               if NIX_CMD.match(r["cmd"].strip()) and failed(r)).most_common(top)

def analyse_source(name, rows, top):
    """All metrics for one history source. Key order is the report order."""
    res = {"name": name, "entries": len(rows)}
    span = date_range(rows)
    if span:
        res["date_range"] = span
    pc = collections.Counter(pattern(r["cmd"]) for r in rows)
    res["top_first_tokens"] = collections.Counter(first_token(r["cmd"]) for r in rows).most_common(top)
    res["top_patterns"] = pc.most_common(top)
    res["coverage_curve"] = coverage_curve(pc, len(rows) or 1)
    res["distinct_patterns"] = len(pc)
    if not any(r["dur"] is not None for r in rows):
        # untimed sources (fish, bash) have no exit codes or sessions either
        res["adoption"] = adoption(rows)
        return res
    res["workflows"] = workflow_stats(rows)
    res["interactive"] = interactive_stats(rows)
    res["slowest_by_total"] = slowest_by_total(rows, top)
    res["exit127"] = exit127(rows, top)
    res["git_subcommand_typos"] = git_subcommand_typos(rows, top)
    fails, tries = failing_patterns(rows)
    res["top_failing_patterns"] = [(p, c, round(c / tries[p], 2)) for p, c in fails.most_common(top)]
    res["exit_codes"] = collections.Counter(r["exit"] for r in rows).most_common(12)
    sess = sessions(rows)
    retries, sudo_rerun = retries_and_sudo(sess)
    bi, tri, rep = ngrams(sess)
    res["retry_same_cmd_60s"] = retries.most_common(top)
    res["next_after_failure"] = next_after_failure(sess, fails)
    res["retry_total"] = sum(retries.values())
    res["sudo_rerun"] = sudo_rerun.most_common(top)
    res["bigrams"] = [(" -> ".join(k), v) for k, v in bi.most_common(top)]
    res["trigrams"] = [(" -> ".join(k), v) for k, v in tri.most_common(top)]
    res["immediate_repeats"] = rep.most_common(10)
    res["adoption"] = adoption(rows)
    res["nix_hm_failures"] = nix_failures(rows, top)
    return res

# ---------------------------------------------------------------- sys-update logs
STATUS_LINE = re.compile(r"^\[(✓|✗|!|·|→)\]")
NIX_ERROR = re.compile(r"error: (Cannot build|Build failed|hash mismatch|Path '.*' .* not tracked|.* has been removed from nixpkgs|executing .git.)")
RERUN_WINDOW_S = 1800

def nix_error_kind(match):
    k = match.group(1)
    if "not tracked" in k:
        return "path not tracked by git"
    if "removed" in k:
        return "package removed from nixpkgs"
    if "git" in k:
        return "git not on PATH"
    return k

def step_names(status, mark):
    """Step names from status lines like '[✗] home-manager: switch failed'."""
    return [re.sub(r":.*", "", l[4:]).strip() for l in status if l.startswith(mark)]

def parse_run(path, start):
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    status = [l for l in lines if STATUS_LINE.match(l)]
    fails = step_names(status, "[✗]")
    report_only = len(lines) <= 8 and not fails
    errs = collections.Counter(nix_error_kind(m) for m in map(NIX_ERROR.search, lines) if m)
    return dict(start=start, dur=os.path.getmtime(path) - start, fails=fails,
                warns=step_names(status, "[!]"), report_only=report_only, errs=errs,
                ok=(not fails and not report_only))

def load_runs(d):
    runs = []
    for f in sorted(os.listdir(d)):
        if not f.endswith(".log"):
            continue
        try:
            start = dt.datetime.strptime(f[:16], "%Y%m%dT%H%M%SZ").replace(tzinfo=dt.timezone.utc).timestamp()
        except ValueError:
            continue
        runs.append(parse_run(os.path.join(d, f), start))
    return runs

def minutes_pct(durs, q):
    return rnd(pct(durs, q) / 60) if durs else None

def run_day(run):
    return dt.datetime.fromtimestamp(run["start"], dt.timezone.utc).date().isoformat()

def analyse_sysupdate(d):
    runs = load_runs(d)
    full = [r for r in runs if not r["report_only"]]
    durs_ok = [r["dur"] for r in full if r["ok"] and r["dur"] < 7200]
    durs_fail = [r["dur"] for r in full if not r["ok"] and r["dur"] < 7200]
    errors = collections.Counter()
    for r in runs:
        errors.update(r["errs"])
    # a failed apply followed by another run within RERUN_WINDOW_S
    reruns = sum(1 for a, b in zip(full, full[1:]) if not a["ok"] and b["start"] - a["start"] < RERUN_WINDOW_S)
    return dict(runs=len(runs), report_or_preflight_only=len(runs) - len(full), apply_runs=len(full),
                apply_success=sum(1 for r in full if r["ok"]),
                ok_median_min=minutes_pct(durs_ok, .5), ok_p90_min=minutes_pct(durs_ok, .9),
                fail_median_min=minutes_pct(durs_fail, .5),
                failed_step_counts=collections.Counter(f for r in runs for f in r["fails"]).most_common(),
                warning_step_counts=collections.Counter(w for r in runs for w in r["warns"]).most_common(10),
                nix_error_kinds=errors.most_common(), fail_then_rerun_within_30min=reruns,
                date_range=[run_day(runs[0]), run_day(runs[-1])] if runs else None)

# ---------------------------------------------------------------- dotfiles inventory
def inventory(repo):
    inv = {"git_alias": set(), "fish_abbr": set(), "fish_function": set(), "bin": set(), "mise_task": set()}
    g = os.path.join(repo, "home/dot_gitconfig.tmpl")
    if os.path.exists(g):
        sect = None
        for l in open(g, encoding="utf-8", errors="replace"):
            m = re.match(r"^\[([^\]]+)\]", l)
            if m:
                sect = m.group(1); continue
            m = re.match(r"^\s+([A-Za-z0-9_-]+)\s*=", l)
            if sect == "alias" and m:
                inv["git_alias"].add(m.group(1))
    fdir = os.path.join(repo, "home/dot_config/fish")
    for root, _, files in os.walk(fdir):
        for f in files:
            for l in open(os.path.join(root, f), encoding="utf-8", errors="replace"):
                m = re.match(r"^\s*abbr -a (\S+)", l)
                if m: inv["fish_abbr"].add(m.group(1))
                m = re.match(r"^\s*function (\S+)", l)
                if m and not m.group(1).startswith("__"): inv["fish_function"].add(m.group(1))
    b = os.path.join(repo, "home/dot_local/bin")
    if os.path.isdir(b):
        inv["bin"] = {re.sub(r"^executable_|\.tmpl$", "", f).replace(".tmpl", "") for f in os.listdir(b)}
    mt = os.path.join(repo, "mise.toml")
    if os.path.exists(mt):
        inv["mise_task"] = {m[1] for m in re.findall(r'^\[tasks\.("?)([^\]"]+)\1\]', open(mt).read(), re.M)}
    return {k: sorted(v) for k, v in inv.items()}

def shortcut_usage(inv, rows):
    use = {}
    for a in inv["git_alias"]:
        if a in GIT_SUB: continue
        rx = re.compile(r"^git\s+%s(\s|$)" % re.escape(a))
        use["git " + a] = sum(1 for r in rows if rx.search(r["cmd"].strip()))
    for kind in ("fish_abbr", "fish_function", "bin"):
        for a in inv[kind]:
            rx = re.compile(r"^%s(\s|$)" % re.escape(a))
            use[a] = sum(1 for r in rows if rx.search(r["cmd"].strip()))
    for t in inv["mise_task"]:
        rx = re.compile(r"^mise\s+(run\s+|r\s+)?%s(\s|$)" % re.escape(t))
        use["mise " + t] = sum(1 for r in rows if rx.search(r["cmd"].strip()))
    return use

# ---------------------------------------------------------------- report
def md_table(hdr, rows):
    out = ["| " + " | ".join(hdr) + " |", "|" + "---|" * len(hdr)]
    for r in rows:
        out.append("| " + " | ".join("" if c is None else str(c) for c in r) + " |")
    return "\n".join(out)

def to_md(rep):
    out = ["# Shell history workflow report (sanitised)\n"]
    for s in rep["sources"]:
        out.append("## %s\n\n%d entries, %s, %d distinct patterns. Coverage by top-N patterns: %s\n" % (
            s["name"], s["entries"], " to ".join(s.get("date_range", ["?"])), s["distinct_patterns"],
            ", ".join("top%s=%d%%" % (k, v * 100) for k, v in s["coverage_curve"].items())))
        out.append(md_table(["first token", "n"], s["top_first_tokens"][:15]) + "\n")
        out.append(md_table(["pattern", "n"], s["top_patterns"][:20]) + "\n")
        if "workflows" in s:
            out.append(md_table(["workflow", "n", "fail", "median s", "p90 s", "total min", ">1h dropped"],
                                [[k, v["n"], v["fail_rate"], v["median_s"], v["p90_s"], v["total_min"], v["outliers_gt1h"]] for k, v in s["workflows"].items()]) + "\n")
            out.append(md_table(["interactive class", "n", "median s", "total min"],
                                [[k, v["n"], v["median_s"], v["total_min"]] for k, v in s["interactive"].items()]) + "\n")
            out.append(md_table(["slowest repeated pattern", "n", "fail", "median s", "p90 s", "total min"],
                                [[p, v["n"], v["fail_rate"], v["median_s"], v["p90_s"], v["total_min"]] for p, v in s["slowest_by_total"][:15]]) + "\n")
            out.append(md_table(["exit 127", "n"], s["exit127"]) + "\n")
            out.append(md_table(["git subcommand typo (failed)", "n"], s["git_subcommand_typos"]) + "\n")
            out.append(md_table(["failing pattern", "next command after failure"], [[k, "; ".join("%s (%d)" % x for x in v)] for k, v in s["next_after_failure"].items()]) + "\n")
            out.append(md_table(["failing pattern", "fails", "rate"], s["top_failing_patterns"][:15]) + "\n")
            out.append(md_table(["retried <60s after failure", "n"], s["retry_same_cmd_60s"][:10]) + "\n")
            out.append(md_table(["sudo re-run", "n"], s["sudo_rerun"]) + "\n")
            out.append(md_table(["nix/hm failure", "n"], s["nix_hm_failures"]) + "\n")
            out.append(md_table(["bigram", "n"], s["bigrams"][:20]) + "\n")
            out.append(md_table(["trigram", "n"], s["trigrams"][:12]) + "\n")
        out.append(md_table(["tool", "uses"], sorted(s["adoption"].items(), key=lambda kv: -kv[1])) + "\n")
    if rep.get("sys_update"):
        out.append("## sys-update runs\n\n```json\n%s\n```\n" % json.dumps(rep["sys_update"], indent=1))
    if rep.get("shortcut_usage"):
        out.append("## Provided shortcut usage\n")
        for src, use in rep["shortcut_usage"].items():
            used = sorted(((k, v) for k, v in use.items() if v), key=lambda kv: -kv[1])
            out.append("### %s\n\n%s\n\nUnused: %d of %d\n" % (src, md_table(["shortcut", "uses"], used[:40]),
                                                            sum(1 for v in use.values() if not v), len(use)))
    return "\n".join(out)

def kv(s):
    if "=" not in s:
        return os.path.basename(s), s
    return s.split("=", 1)

def auto_sources(a):
    """Add this machine's history sources to `a`. The atuin db is copied to a
    private temp dir first so a running atuin daemon cannot lock it."""
    import tempfile
    home = os.path.expanduser("~")
    data = os.environ.get("XDG_DATA_HOME", os.path.join(home, ".local/share"))
    state = os.environ.get("XDG_STATE_HOME", os.path.join(home, ".local/state"))
    tmpdir = tempfile.mkdtemp(prefix="history-report-")
    db = os.path.join(data, "atuin/history.db")
    if os.path.isfile(db):
        copy = os.path.join(tmpdir, "history.db")
        shutil.copy2(db, copy)
        for ext in ("-wal", "-shm"):
            if os.path.isfile(db + ext):
                shutil.copy2(db + ext, copy + ext)
        a.atuin_db.append("atuin=" + copy)
    fish = os.path.join(data, "fish/fish_history")
    if os.path.isfile(fish):
        a.fish.append("fish=" + fish)
    bash = os.path.join(home, ".bash_history")
    if os.path.isfile(bash):
        a.bash.append("bash=" + bash)
    runs = os.path.join(state, "sys-update/runs")
    if not a.sys_update_runs and os.path.isdir(runs):
        a.sys_update_runs = runs
    if not (a.atuin_db or a.fish or a.bash):
        sys.exit("history-report: no history found (atuin, fish or bash)")
    return tmpdir

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--atuin-db", action="append", default=[])
    ap.add_argument("--atuin-jsonl", action="append", default=[])
    ap.add_argument("--fish", action="append", default=[])
    ap.add_argument("--bash", action="append", default=[])
    ap.add_argument("--sys-update-runs")
    ap.add_argument("--repo", default=os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                    help="dotfiles repo for the shortcut inventory (default: this repo)")
    ap.add_argument("--auto", action="store_true",
                    help="use this machine's atuin db (read from a temp copy), fish and bash history, sys-update runs")
    ap.add_argument("--top", type=int, default=25)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    tmpdir = None
    if a.auto:
        tmpdir = auto_sources(a)
    inv = inventory(a.repo) if a.repo and os.path.isdir(a.repo) else None
    if inv:
        GIT_ALIASES.update(inv["git_alias"])
    loaders = [(load_atuin_db, a.atuin_db), (load_atuin_jsonl, a.atuin_jsonl), (load_fish, a.fish), (load_bash, a.bash)]
    rep = {"generated": dt.date.today().isoformat(), "sources": [], "shortcut_usage": {}}
    for fn, specs in loaders:
        for spec in specs:
            name, path = kv(spec)
            rows = [r for r in fn(path) if r["cmd"] and r["cmd"].strip()]
            rep["sources"].append(analyse_source(name, rows, a.top))
            if inv:
                rep["shortcut_usage"][name] = shortcut_usage(inv, rows)
    if a.sys_update_runs:
        rep["sys_update"] = analyse_sysupdate(a.sys_update_runs)
    if inv:
        rep["inventory_counts"] = {k: len(v) for k, v in inv.items()}
    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, "report.json"), "w") as fh:
        json.dump(rep, fh, indent=1, default=list)
    with open(os.path.join(a.out, "report.md"), "w") as fh:
        fh.write(to_md(rep))
    if tmpdir:
        shutil.rmtree(tmpdir, ignore_errors=True)
    print("wrote", os.path.join(a.out, "report.md"))

if __name__ == "__main__":
    main()
