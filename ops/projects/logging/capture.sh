#!/usr/bin/env bash
set -Eeuo pipefail

LABEL=""
OUTPUT=""
QUIET="0"

usage() {
  printf 'Usage: %s --label BACKEND-NPM|FRONTEND-NPM --output FILE [--quiet]\n' "$0" >&2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --label) LABEL="${2:-}"; shift 2 ;;
    --output) OUTPUT="${2:-}"; shift 2 ;;
    --quiet) QUIET="1"; shift ;;
    *) usage; exit 2 ;;
  esac
done

if [[ ! "$LABEL" =~ ^(BACKEND-NPM|FRONTEND-NPM)$ || -z "$OUTPUT" ]]; then
  usage
  exit 2
fi

mkdir -p "$(dirname "$OUTPUT")"

if command -v perl >/dev/null 2>&1; then
  exec perl -MTime::HiRes=gettimeofday -MPOSIX=strftime -e '
    use strict;
    use warnings;
    $| = 1;

    my ($label, $output, $quiet) = @ARGV;
    open(my $log, ">>", $output) or die "cannot append to $output: $!\n";
    select((select($log), $| = 1)[0]);

    while (defined(my $line = <STDIN>)) {
      print STDOUT $line unless $quiet eq "1";
      $line =~ s/\r?\n\z//;
      $line =~ s/.*\r//;
      $line =~ s/\e\][^\a]*(?:\a|\e\\)//g;
      $line =~ s/\e\[[0-?]*[ -\/]*[@-~]//g;

      if ($line =~ /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z \[(?:BACKEND-NPM|FRONTEND-NPM)\](?: |$)/) {
        print {$log} "$line\n";
        next;
      }

      my ($seconds, $micros) = gettimeofday();
      my $stamp = strftime("%Y-%m-%dT%H:%M:%S", gmtime($seconds));
      $stamp .= sprintf(".%03dZ", int($micros / 1000));
      print {$log} "$stamp [$label] $line\n";
    }
  ' "$LABEL" "$OUTPUT" "$QUIET"
fi

printf 'Warning: perl/Time::HiRes unavailable; npm log timestamps have one-second precision.\n' >&2
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$QUIET" == "1" ]] || printf '%s\n' "$line"
  clean="$(printf '%s' "$line" | sed $'s/.*\r//; s/\033\\][^\a]*\(\a\|\033\\\\\)//g; s/\033\\[[0-?]*[ -\\/]*[@-~]//g')"
  if [[ "$clean" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T.*Z\ \[(BACKEND-NPM|FRONTEND-NPM)\] ]]; then
    printf '%s\n' "$clean" >>"$OUTPUT"
  else
    printf '%s [%s] %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%S.000Z')" "$LABEL" "$clean" >>"$OUTPUT"
  fi
done
