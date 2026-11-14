#!/usr/bin/env bats
#
# ops/generate-package-matrix.sh: tools documented in
# repo-docs/software-and-cli-tools.md but absent from the install script must be
# surfaced for every documented tool, not just a hard-coded subset. The script
# anchors on its own location, so the test runs a copy inside a fixture tree.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  T="$BATS_TEST_TMPDIR/repo"
  mkdir -p "$T/ops" "$T/repo-docs"
  cp "$REPO_ROOT/ops/generate-package-matrix.sh" "$T/ops/"
  cat > "$T/repo-docs/install-dev-tools.sh" <<'EOF'
FORMULAE=(
  fzf
  bat
)
CASKS=()
EOF
  cat > "$T/repo-docs/software-and-cli-tools.md" <<'EOF'
# Tools
- **[fzf](https://github.com/junegunn/fzf)** - fuzzy finder
- **[bat](https://github.com/sharkdp/bat)** - cat with wings
- **[Zellij](https://github.com/zellij-org/zellij)** - terminal multiplexer
- **[GitHub Copilot CLI](https://github.com/github/copilot-cli)** - copilot
Prose mentions `mkcert` too.
EOF
  OUT="$BATS_TEST_TMPDIR/matrix.md"
}

gen() { run bash "$T/ops/generate-package-matrix.sh" --no-probe --output "$OUT"; }

@test "documented tool outside the old fixed list is reported as missing" {
  gen
  [ "$status" -eq 0 ]
  grep -q '`zellij`' "$OUT"
}

@test "multi-word documented tool is reported by its repository name" {
  gen
  grep -q '`copilot-cli`' "$OUT"
}

@test "tools already in the install script are not reported as missing" {
  gen
  ! grep -q 'mentioned only in docs' <(grep -E '`(fzf|bat)`' "$OUT")
}

@test "previously detected prose-mentioned tools are still reported" {
  gen
  grep -q '`mkcert`' "$OUT"
}
