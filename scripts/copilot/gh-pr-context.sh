#!/usr/bin/env bash
set -euo pipefail

pr="${1:?PR number required}"

gh pr view "$pr" --json title,body,author,files,commits,labels \
  | jq '{title, author: .author.login, labels: [.labels[].name], files: [.files[].path], commitCount: (.commits | length)}'
