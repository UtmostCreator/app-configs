"""List bats statements that can never fail the test because they are not
the last statement of a @test. bats runs tests under `set -e`, which
ignores:
  - a negated command (`! cmd`); use `if cmd; then return 1; fi` or `run ! cmd`;
  - a `[ ... ] && ...` / `[[ ... ]] && ...` chain whose test is false; use one
    assertion per line, or `[ ... ] || return 1`.

Usage: python3 -I tests/lib/find-dead-bang-asserts.py FILE...   (exit 1 if any)
"""
import re
import sys

# `[ ... ] && x` or `[[ ... ]] && x` at the start of a statement or after `;`.
AND_CHAIN = re.compile(r"(^\s*|;\s*)\[\[? .*? \]\]? && ")

hits = []
for path in sys.argv[1:]:
    lines = open(path, encoding="utf-8").read().split("\n")
    in_test, heredoc, body = False, None, []
    for no, line in enumerate(lines, 1):
        if heredoc:
            if line.strip() == heredoc:
                heredoc = None
            continue
        if re.match(r"^@test ", line):
            in_test, body = True, []
            continue
        if in_test and line == "}":
            stmts = [(n, t) for n, t in body if t.strip() and not t.strip().startswith("#")]
            for i, (n, t) in enumerate(stmts):
                if i == len(stmts) - 1:
                    continue
                if re.match(r"^\s+! ", t) or (
                    AND_CHAIN.search(t)
                    and not t.lstrip().startswith(("'", '"'))  # a quoted literal
                    and "|| return" not in t
                    and "|| {" not in t
                ):
                    hits.append(f"{path}:{n}: {t.strip()}")
            in_test = False
            continue
        if in_test:
            m = re.search(r"<<-?\s*['\"]?(\w+)['\"]?\s*$", line)
            if m and not line.lstrip().startswith("#"):
                heredoc = m.group(1)
            body.append((no, line))
print("\n".join(hits))
sys.exit(1 if hits else 0)
