#!/usr/bin/env bats

setup() {
  LOGGING_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  LOG_ERRORS="$LOGGING_DIR/errors/run.sh"
  FIXTURES="$BATS_TEST_DIRNAME/fixtures"
  TEST_ROOT="$BATS_TEST_TMPDIR/log-errors"
  mkdir -p "$TEST_ROOT"
}

@test "multiple and overlapping inputs are inode-deduplicated in encounter order" {
  mkdir -p "$TEST_ROOT/logs"
  cp "$FIXTURES/laravel.log" "$TEST_ROOT/logs/a.log"
  ln "$TEST_ROOT/logs/a.log" "$TEST_ROOT/logs/b.log"
  run bash "$LOG_ERRORS" --format json "$TEST_ROOT/logs/a.log" "$TEST_ROOT/logs"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | php -r '$j=json_decode(stream_get_contents(STDIN),true); echo count($j["files"]);')" -eq 1 ]
  [ "$(printf '%s' "$output" | php -r '$j=json_decode(stream_get_contents(STDIN),true); echo count($j["duplicate_input_paths"]);')" -eq 2 ]
}

@test "file symlinks resolve while directory symlinks are rejected without traversal" {
  mkdir -p "$TEST_ROOT/logs"
  cp "$FIXTURES/laravel.log" "$TEST_ROOT/logs/a.log"
  ln -s "$TEST_ROOT/logs/a.log" "$TEST_ROOT/file-link"
  run bash "$LOG_ERRORS" --format json "$TEST_ROOT/file-link"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"files_scanned": 1'* ]]
  ln -s "$TEST_ROOT/logs" "$TEST_ROOT/dir-link"
  run bash "$LOG_ERRORS" "$TEST_ROOT/dir-link"
  [ "$status" -eq 2 ]
}

@test "directory discovery includes rotations and JSONL but excludes compressed files" {
  mkdir -p "$TEST_ROOT/logs/nested"
  cp "$FIXTURES/laravel.log" "$TEST_ROOT/logs/app.log.1"
  cp "$FIXTURES/events.jsonl" "$TEST_ROOT/logs/nested/events.jsonl"
  cp "$FIXTURES/laravel.log" "$TEST_ROOT/logs/ignored.log.gz"
  run bash "$LOG_ERRORS" --format json "$TEST_ROOT/logs"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | php -r '$j=json_decode(stream_get_contents(STDIN),true); echo count($j["files"]);')" -eq 2 ]
}

@test "double dash supports leading-dash and metacharacter paths without mutation" {
  name="$TEST_ROOT/-odd dollar;file"
  cp "$FIXTURES/laravel.log" "$name"
  before="$(cksum "$name")"
  run bash "$LOG_ERRORS" --format json -- "$name"
  [ "$status" -eq 0 ]
  [ "$(cksum "$name")" = "$before" ]
  [ ! -e "$TEST_ROOT/file" ]
}

@test "empty directories and no matches succeed with explicit human sections" {
  mkdir -p "$TEST_ROOT/empty"
  run bash "$LOG_ERRORS" "$TEST_ROOT/empty"
  [ "$status" -eq 0 ]
  [[ "$output" == *'Scanned 0 file(s)'* ]]
  run bash "$LOG_ERRORS" --level DEBUG "$FIXTURES/laravel.log"
  [ "$status" -eq 0 ]
  [[ "$output" == *'No matching events.'* ]]
}

@test "invalid regexes missing paths and legacy options return status 2" {
  run bash "$LOG_ERRORS" --pattern '(' "$FIXTURES/laravel.log"
  [ "$status" -eq 2 ]
  run bash "$LOG_ERRORS" --preview --format json "$FIXTURES/laravel.log"
  [ "$status" -eq 2 ]
  run bash "$LOG_ERRORS" "$TEST_ROOT/missing.log"
  [ "$status" -eq 2 ]
  for legacy in --levels --unique --target-dir; do
    run bash "$LOG_ERRORS" "$legacy" anything
    [ "$status" -eq 2 ]
  done
}

@test "noise rules and include-noise report unique event metrics" {
  run bash "$LOG_ERRORS" --format json "$FIXTURES/noise.log"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | php -r '$j=json_decode(stream_get_contents(STDIN),true); echo $j["summary"]["events_matched"];')" -eq 1 ]
  [ "$(printf '%s' "$output" | php -r '$j=json_decode(stream_get_contents(STDIN),true); echo $j["noise_suppression"]["repository_rules_matched"];')" -eq 4 ]
  run bash "$LOG_ERRORS" --format json --include-noise --ignore Actionable "$FIXTURES/noise.log"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | php -r '$j=json_decode(stream_get_contents(STDIN),true); echo json_encode([$j["noise_suppression"]["repository_rules_applied"],$j["noise_suppression"]["repository_rules_matched"],$j["noise_suppression"]["cli_rules_matched"]]);')" = '[false,null,1]' ]
}

@test "selection spans continuations and pattern is ORed with selected levels" {
  run bash "$LOG_ERRORS" --format json --contains '/srv/app/public/index.php' "$FIXTURES/laravel.log"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"events_matched": 1'* ]]
  run bash "$LOG_ERRORS" --format json --pattern 'Request completed' "$FIXTURES/laravel.log"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"events_matched": 2'* ]]
}

@test "smart grouping merges changing IDs while exact and none preserve occurrences" {
  run bash "$LOG_ERRORS" --format json "$FIXTURES/laravel-long.log"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | php -r '$j=json_decode(stream_get_contents(STDIN),true); echo $j["summary"]["groups"].":".$j["files"][0]["groups"][0]["count"];')" = '1:2' ]
  run bash "$LOG_ERRORS" --format json --group exact "$FIXTURES/laravel-long.log"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"groups": 2'* ]]
  run bash "$LOG_ERRORS" --format json --group none "$FIXTURES/laravel-long.log"
  [ "$status" -eq 0 ]
  [[ "$output" == *'"groups": 2'* ]]
}

@test "mixed clock kinds disable chronology claims and order by source position" {
  run bash "$LOG_ERRORS" --format json "$FIXTURES/mixed-clocks.log"
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | php -r '$j=json_decode(stream_get_contents(STDIN),true); $f=$j["files"][0]; echo $f["ordering"].":".$f["groups"][0]["representative"]["start_line"].":".json_encode($f["groups"][0]["chronology_comparable"]);')" = 'source-position:3:false' ]
}

@test "full human and structured output preserve complete stack traces" {
  run bash "$LOG_ERRORS" --full --no-pager "$FIXTURES/laravel-long.log"
  [ "$status" -eq 0 ]
  [[ "$output" == *'#2 /srv/app/public/index.php(20): handle()'* ]]
  run bash "$LOG_ERRORS" --format json "$FIXTURES/npm-continuation.log"
  [ "$status" -eq 0 ]
  [[ "$output" == *'Caused by: missing route'* ]]
  [[ "$output" == *'/workspace/src/build.js:21:9'* ]]
}

@test "JSON has schema contracts and JSONL emits only decodable group records" {
  run bash "$LOG_ERRORS" --format json "$FIXTURES/events.jsonl"
  [ "$status" -eq 0 ]
  printf '%s' "$output" | php -r '$j=json_decode(stream_get_contents(STDIN),true,128,JSON_THROW_ON_ERROR); if ($j["schema_version"]!==1 || !isset($j["files"][0]["groups"][0]["representative"]["raw"]) || $j["files"][0]["groups"][0]["representative"]["timestamp_kind"]!=="utc") exit(1);'
  run bash "$LOG_ERRORS" --format jsonl "$FIXTURES/laravel-long.log"
  [ "$status" -eq 0 ]
  while IFS= read -r record; do
    RECORD="$record" php -r '$j=json_decode(getenv("RECORD"),true,128,JSON_THROW_ON_ERROR); if ($j["record_type"]!=="error_group" || !isset($j["group"]["representative"]["raw"])) exit(1);'
  done <<<"$output"
  run bash "$LOG_ERRORS" --format jsonl --level DEBUG "$FIXTURES/laravel.log"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "declared malformed JSONL returns partial status 3 with recoverable results" {
  run bash "$LOG_ERRORS" --format json "$FIXTURES/malformed.jsonl"
  [ "$status" -eq 3 ]
  [[ "$output" == *'malformed_jsonl_record'* ]]
  [[ "$output" == *'Recovered failure'* ]]
  [[ "$output" == *'truncated record'* ]]
}

@test "redirected output is plain and repeated scans are deterministic" {
  run bash "$LOG_ERRORS" --no-pager "$FIXTURES/laravel-long.log"
  [ "$status" -eq 0 ]
  first="$output"
  [[ "$first" != *$'\033'* ]]
  run bash "$LOG_ERRORS" --no-pager "$FIXTURES/laravel-long.log"
  [ "$status" -eq 0 ]
  [ "$output" = "$first" ]
}

@test "preview mode prints styled human output outside interactive pagers" {
  run env -u NO_COLOR TERM=xterm-256color bash "$LOG_ERRORS" --preview "$FIXTURES/laravel.log"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'\033[1;37;44m LOG ERRORS '* ]]
  [[ "$output" != *'/ search  n/N matches  & filter'* ]]
}

@test "interactive human output always uses the searchable color pager" {
  command -v script >/dev/null 2>&1 || skip "script(1) is required for pseudo-terminal pager coverage"
  fake_bin="$TEST_ROOT/interactive-bin"
  pager_args="$TEST_ROOT/pager-args"
  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@" >"$PAGER_ARGS"\ncat\n' >"$fake_bin/less"
  chmod +x "$fake_bin/less"

  run script -q -e -c "env -u NO_COLOR PATH='$fake_bin:$PATH' PAGER_ARGS='$pager_args' TERM=xterm-256color LESS=-FSX bash '$LOG_ERRORS' '$FIXTURES/laravel.log'" /dev/null

  [ "$status" -eq 0 ]
  [[ "$output" == *$'\033[1;37;44m LOG ERRORS '* ]]
  [[ "$output" == *'/ search  n/N matches  & filter'* ]]
  [[ "$output" == *'[01]'* ]]
  grep -Fx -- '-R' "$pager_args"
  grep -Fx -- '-I' "$pager_args"
  grep -Fx -- '-J' "$pager_args"
  grep -Fx -- '-L' "$pager_args"
  ! grep -Fx -- '-F' "$pager_args"
  ! grep -Fx -- '-S' "$pager_args"
  ! grep -Fx -- '-X' "$pager_args"

  run script -q -e -c "env -u NO_COLOR PATH='$fake_bin:$PATH' PAGER_ARGS='$TEST_ROOT/no-pager-args' TERM=xterm-256color bash '$LOG_ERRORS' --no-pager '$FIXTURES/laravel.log'" /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" != *'/ search  n/N matches  & filter'* ]]
  [ ! -e "$TEST_ROOT/no-pager-args" ]
}

@test "human summaries shorten huge payloads while full output remains lossless" {
  long_message="$(printf 'x%.0s' {1..300})END"
  printf '[2026-09-03 09:00:00] local.ERROR: %s\n' "$long_message" >"$TEST_ROOT/long.log"

  run bash "$LOG_ERRORS" --no-pager "$TEST_ROOT/long.log"
  [ "$status" -eq 0 ]
  [[ "$output" == *'…'* ]]
  [[ "$output" != *'END'* ]]

  run bash "$LOG_ERRORS" --no-pager --full "$TEST_ROOT/long.log"
  [ "$status" -eq 0 ]
  [[ "$output" == *'END'* ]]
}

@test "human and normalized JSON reports match golden contracts" {
  run bash -c 'cd "$1" && bash errors/run.sh --no-pager test/fixtures/laravel.log' _ "$LOGGING_DIR"
  [ "$status" -eq 0 ]
  [ "$output" = "$(<"$BATS_TEST_DIRNAME/golden/log-errors-human.txt")" ]

  actual_json="$TEST_ROOT/actual.json"
  run bash -c 'cd "$1" && bash errors/run.sh --format json test/fixtures/events.jsonl' _ "$LOGGING_DIR"
  [ "$status" -eq 0 ]
  printf '%s' "$output" | php -r '
    $j=json_decode(stream_get_contents(STDIN),true,128,JSON_THROW_ON_ERROR); $f=$j["files"][0]; $g=$f["groups"][0];
    $o=["schema_version"=>$j["schema_version"],"summary"=>$j["summary"],"noise_suppression"=>$j["noise_suppression"],
      "file"=>["path"=>$f["path"],"format"=>$f["format"],"events_scanned"=>$f["events_scanned"],"matching_events"=>$f["matching_events"],"ordering"=>$f["ordering"]],
      "group"=>["fingerprint"=>$g["fingerprint"],"count"=>$g["count"],"highest_severity"=>$g["highest_severity"],"first_timestamp"=>$g["first_timestamp"],"latest_timestamp"=>$g["latest_timestamp"],"occurrence_ranges"=>$g["occurrence_ranges"],"exception_class"=>$g["exception_class"],"application_frame"=>$g["application_frame"],"context"=>$g["context"],"correlation_ids"=>$g["correlation_ids"],"chronology_comparable"=>$g["chronology_comparable"],"representative"=>$g["representative"]],
      "warnings"=>$j["warnings"]]; echo json_encode($o,JSON_PRETTY_PRINT|JSON_UNESCAPED_SLASHES),"\n";
  ' >"$actual_json"
  diff -u "$BATS_TEST_DIRNAME/golden/log-errors-json.json" "$actual_json"
}

@test "launcher dependency failures return status 4" {
  mkdir -p "$TEST_ROOT/no-core"
  cp "$LOG_ERRORS" "$TEST_ROOT/no-core/log-errors.sh"
  run bash "$TEST_ROOT/no-core/log-errors.sh" --help
  [ "$status" -eq 4 ]

  fake_bin="$TEST_ROOT/fake-bin"
  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\nexit 1\n' >"$fake_bin/php"
  chmod +x "$fake_bin/php"
  run env PATH="$fake_bin:$PATH" bash "$LOG_ERRORS" --help
  [ "$status" -eq 4 ]
  [[ "$output" == *'PHP 8.2 or newer is required'* ]]

  syntax_dir="$TEST_ROOT/bad-core"
  mkdir -p "$syntax_dir"
  cp "$LOG_ERRORS" "$syntax_dir/log-errors.sh"
  printf '<?php syntax error' >"$syntax_dir/core.php"
  run bash "$syntax_dir/log-errors.sh" --help
  [ "$status" -eq 4 ]
  [[ "$output" == *'failed PHP syntax validation'* ]]
}

@test "output and pager failures return status 1 while a missing pager falls back" {
  if [[ -e /dev/full ]]; then
    run bash -c 'bash "$1" --format json "$2" >/dev/full' _ "$LOG_ERRORS" "$FIXTURES/laravel.log"
    [ "$status" -eq 1 ]
  fi

  command -v script >/dev/null 2>&1 || skip "script(1) is required for pseudo-terminal pager coverage"
  fake_bin="$TEST_ROOT/pager-bin"
  mkdir -p "$fake_bin"
  printf '#!/usr/bin/env bash\n/bin/cat >/dev/null\nexit 42\n' >"$fake_bin/less"
  chmod +x "$fake_bin/less"
  run script -q -e -c "env PATH='$fake_bin:$PATH' COLUMNS=20 LINES=5 bash '$LOG_ERRORS' --full '$FIXTURES/laravel-long.log'" /dev/null
  [ "$status" -eq 1 ]
  [[ "$output" == *'Pager failed with status 42'* ]]

  early_quit_bin="$TEST_ROOT/early-quit-bin"
  mkdir -p "$early_quit_bin"
  printf '#!/usr/bin/env bash\nexec 0<&-\nsleep 0.2\nexit 0\n' >"$early_quit_bin/less"
  chmod +x "$early_quit_bin/less"
  { printf '[2026-09-03 09:00:00] local.ERROR: '; dd if=/dev/zero bs=1048576 count=1 2>/dev/null | tr '\0' x; printf '\n'; } >"$TEST_ROOT/huge.log"
  run script -q -e -c "env PATH='$early_quit_bin:$PATH' TERM=xterm-256color bash '$LOG_ERRORS' --full '$TEST_ROOT/huge.log'" /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" != *'Pager input failed'* ]]

  no_less="$TEST_ROOT/no-less"
  mkdir -p "$no_less"
  ln -s "$(command -v php)" "$no_less/php"
  ln -s "$(command -v dirname)" "$no_less/dirname"
  real_bash="$(command -v bash)"
  run script -q -e -c "env PATH='$no_less' COLUMNS=20 LINES=5 '$real_bash' '$LOG_ERRORS' --full '$FIXTURES/laravel-long.log'" /dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *'less is unavailable; printing the report directly'* ]]
}

@test "an unreadable input is a partial status 3 when permissions are enforced" {
  cp "$FIXTURES/laravel.log" "$TEST_ROOT/unreadable.log"
  chmod 000 "$TEST_ROOT/unreadable.log"
  if [[ -r "$TEST_ROOT/unreadable.log" ]]; then
    skip "current user can bypass file permissions"
  fi
  run bash "$LOG_ERRORS" --format json "$TEST_ROOT/unreadable.log"
  [ "$status" -eq 3 ]
  [[ "$output" == *'"partial": true'* ]]
}

@test "SIGINT exits with status 130" {
  large="$TEST_ROOT/large.log"
  awk 'BEGIN { for (i=0; i<2000000; i++) print "ERROR repeated failure " i }' >"$large"
  bash "$LOG_ERRORS" --group none --format json "$large" >/dev/null 2>&1 &
  pid=$!
  sleep 0.1
  kill -INT "$pid"
  interrupted=0
  wait "$pid" || interrupted=$?
  [ "$interrupted" -eq 130 ]
}
