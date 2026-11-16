#!/usr/bin/env bash
# Runs `flutter analyze` on the whole project, or on the files and folders given, one heavy job at a time.
# The analyzer takes one to two GB on a mid-size app: two at once, beside other agents' tests, can freeze a
# 16 GB machine. So it waits in the queue, then prints only the tail of the output and the exit code.
# Relative paths are read from APP_DIR.
# usage: q-analyze.sh [<file or folder> ...]   (no argument = the whole project; TAIL_LINES=N shows more or fewer lines)
set -u
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  echo "usage: q-analyze.sh [<file or folder> ...]   (no options; no argument analyzes the whole project)" >&2
  exit 2
}
for p in "$@"; do
  case "$p" in
    '') usage ;;
    -*) echo "refused: '$p' is an option; pass files or folders only" >&2; usage ;;
  esac
  case "$p" in /*) q=$p ;; *) q=$APP_DIR/$p ;; esac
  if [ ! -e "$q" ]; then
    echo "refused: '$p' does not exist here (relative paths start at APP_DIR: $APP_DIR)" >&2
    exit 2
  fi
done
if [ ! -f "$APP_DIR/pubspec.yaml" ]; then
  echo "q-analyze: APP_DIR '$APP_DIR' has no pubspec.yaml (set APP_DIR in scripts/tools/tools.env)" >&2
  exit 2
fi

queue_line q-analyze
# $FLUTTER is split on purpose: "fvm flutter" is two words.
run_heavy analyze "$ANALYZE_MIN_FREE_MB" -- $FLUTTER analyze "$@" 2>&1 | tail -n "${TAIL_LINES:-60}"
code=${PIPESTATUS[0]}
echo "analyze exit: $code"
exit "$code"
