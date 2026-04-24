#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-design-patterns}"

mkdir -p "$ROOT"

touch "$ROOT/README.md"

mkdir -p \
  "$ROOT/_shared/interfaces" \
  "$ROOT/_shared/utils" \
  "$ROOT/_shared/examples" \
  "$ROOT/playground"

create_pattern() {
  local category="$1"
  local pattern="$2"
  shift 2

  local dir="$ROOT/$category/$pattern"

  mkdir -p "$dir"
  touch "$dir/README.md"
  touch "$dir/diagram.png"

  for subdir in "$@"; do
    mkdir -p "$dir/$subdir"
  done
}

# Creational
create_pattern "creational" "factory-method" "example-basic" "example-real-world" "tests"
create_pattern "creational" "abstract-factory" "example-basic" "example-real-world" "tests"
create_pattern "creational" "builder" "example-basic" "example-real-world" "tests"
create_pattern "creational" "prototype" "example-basic" "example-real-world" "tests"
create_pattern "creational" "singleton" "example-basic" "example-thread-safe" "tests"

# Structural
for pattern in adapter bridge composite decorator facade flyweight proxy; do
  create_pattern "structural" "$pattern" "example-basic" "example-real-world" "tests"
done

# Behavioral
for pattern in \
  chain-of-responsibility \
  command \
  iterator \
  mediator \
  memento \
  observer \
  state \
  strategy \
  template-method \
  visitor
do
  create_pattern "behavioral" "$pattern" "example-basic" "example-real-world" "tests"
done

echo "Created design patterns structure in: $ROOT"