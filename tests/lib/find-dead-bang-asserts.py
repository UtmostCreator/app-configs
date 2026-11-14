"""List bats statements of the form `! cmd` that are not the last statement
of a @test. bats runs tests under `set -e`, and bash never exits on a
negated command, so such a line can never fail the test. Use
`if cmd; then return 1; fi` (or `run ! cmd`) instead.

Usage: python3 -I tests/lib/find-dead-bang-asserts.py FILE...   (exit 1 if any)
"""
import re
import sys

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
                if re.match(r"^\s+! ", t) and i != len(stmts) - 1:
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
