#!/usr/bin/env bash
# Runs `flutter test` on the test FILES given, one heavy job at a time, TEST_CONCURRENCY files at once, printing
# failures only. It refuses anything that is not a test file: a folder or an empty argument list would run the
# whole suite, which takes minutes and the memory every other agent needs. Integration tests install and drive
# the app on a device (the device playbook): it runs one only with -d <serial>, one file, alone in the queue,
# since it builds the app first. Relative paths are read from APP_DIR.
# usage: q-test.sh <test file> [<test file> ...]   (files named *_test.dart; TAIL_LINES=N shows more or fewer lines)
#        q-test.sh -d <serial> integration_test/<file>_test.dart   (on the owner's yes: it installs the app)
set -u
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  echo "usage: q-test.sh <test file> [<test file> ...]   (files named *_test.dart, never a folder or an option)" >&2
  echo "       q-test.sh -d <serial> integration_test/<file>_test.dart   (one integration test, on that device)" >&2
  exit 2
}
[ $# -gt 0 ] || usage
device=""
if [ "$1" = -d ]; then
  if [ $# -ne 3 ]; then
    echo "refused: -d takes a device serial and one integration test file" >&2
    usage
  fi
  device=$2
  shift 2
  case "$device" in
    '' | -*) echo "refused: '$device' is not a device serial (flutter devices lists them)" >&2; usage ;;
  esac
fi
for f in "$@"; do
  case "$f" in
    -*) echo "refused: '$f' is an option; pass test files only (-d <serial> comes first)" >&2; usage ;;
    *_test.dart) ;;
    *) echo "refused: '$f' is not a test FILE (*_test.dart)" >&2; exit 2 ;;
  esac
  if [ -n "$device" ]; then
    # Flutter treats a file as an integration test only under the app's own integration_test/ folder.
    case "$f" in
      integration_test/* | ./integration_test/* | "$APP_DIR"/integration_test/*) ;;
      *) echo "refused: -d is for a file under integration_test/ of $APP_DIR; '$f' is not" >&2; exit 2 ;;
    esac
  else
    case "$f" in
      integration_test/* | ./integration_test/* | */integration_test/*)
        echo "refused: '$f' is an integration test: it runs on a phone or an emulator, with -d <serial> and the" \
          "owner's yes (see the device playbook)" >&2
        exit 2
        ;;
    esac
  fi
  case "$f" in /*) p=$f ;; *) p=$APP_DIR/$f ;; esac
  if [ ! -f "$p" ]; then
    echo "refused: '$f' is not a file here (relative paths start at APP_DIR: $APP_DIR)" >&2
    exit 2
  fi
done

queue_line q-test
# $FLUTTER is split on purpose: "fvm flutter" is two words.
if [ -n "$device" ]; then
  # It builds the app with Gradle before the test: alone in the queue, with a build's memory.
  echo "q-test: $1 on $device, alone in the queue (it builds and installs the app; a wait of minutes is normal)"
  run_heavy device-test "$BUILD_MIN_FREE_MB" --alone -- $FLUTTER test "$1" -d "$device" 2>&1 |
    tail -n "${TAIL_LINES:-80}"
  code=${PIPESTATUS[0]}
else
  run_heavy test "$TEST_MIN_FREE_MB" -- $FLUTTER test --concurrency="$TEST_CONCURRENCY" -r failures-only "$@" 2>&1 |
    tail -n "${TAIL_LINES:-80}"
  code=${PIPESTATUS[0]}
fi
echo "test exit: $code"
exit "$code"
