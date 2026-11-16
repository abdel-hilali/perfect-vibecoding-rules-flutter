#!/usr/bin/env bash
# Stands in for the RAM plugin's ram.sh: names itself and its arguments, then runs the command after "--".
echo "stub-ram[$0]: $*" >&2
if [ "${1:-}" = status ]; then
  echo "stub-ram status"
  exit 0
fi
while [ $# -gt 0 ] && [ "$1" != -- ]; do shift; done
[ $# -gt 0 ] && shift
"$@"
