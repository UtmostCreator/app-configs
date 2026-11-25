#!/usr/bin/env bash
# Test a mounted filesystem using a single disposable file.
set -euo pipefail
export LC_ALL=C
umask 077

usage() { printf '%s\n' 'Usage: bash ops/niri/check-filesystem-write.sh TARGET_DIRECTORY'; }
die() { printf 'FAIL  %s\n' "$*" >&2; exit 1; }

if [[ ${1:-} == --help && $# == 1 ]]; then usage; exit 0; fi
if (( $# != 1 )); then usage >&2; exit 2; fi
directory=$(realpath -e -- "$1") || die 'The target directory is unavailable.'
[[ -d $directory && -w $directory ]] || die 'The target must be a writable directory.'
options=$(findmnt -nro OPTIONS -T "$directory") || die 'Cannot identify the target filesystem.'
case ",$options," in
  *,ro,*|*,emergency_ro,*) die 'The target filesystem reports read-only or emergency read-only.' ;;
  *,rw,*) ;;
  *) die 'The target filesystem does not report a writable mount.' ;;
esac

mount=$(findmnt -no TARGET -T "$directory") || die 'Cannot identify the mount point.'
printf 'Testing a 16 MiB file on %s\n' "$mount"
probe=$(mktemp -- "$directory/.disk-write-check.XXXXXXXX") || die 'Could not create the test file.'
trap 'rm -f -- "$probe"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

expected=$(dd if=/dev/urandom bs=1M count=16 iflag=fullblock status=none | tee -- "$probe" | sha256sum) ||
  die 'Could not write the complete test payload.'
[[ $(stat -c %s -- "$probe") == 16777216 ]] || die 'The test file has the wrong size.'
timeout 30s sync -d -- "$probe" || die 'Could not flush the test file.'
actual=$(timeout 30s dd if="$probe" iflag=direct bs=1M status=none | sha256sum) ||
  die 'Direct readback failed or is unsupported by this filesystem.'
[[ $expected == "$actual" ]] || die 'The readback checksum differs from the written payload.'
printf 'PASS  16 MiB written, flushed and read back with a matching checksum.\n'
