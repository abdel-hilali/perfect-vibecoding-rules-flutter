#!/usr/bin/env bash
# What runs before you start anything heavy. With the RAM plugin: `ram.sh status` (free memory, pressure, who
# uses it, the watchdog, the machine-wide queue). Without it: free memory, the state of the tools' own lock, and
# the heavy processes this user runs (Flutter tools, test runners, the analysis server, Gradle and Kotlin
# daemons, emulators). Read-only: it stops nothing.
# usage: q-status.sh   (no arguments)
set -u
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

if [ $# -gt 0 ]; then
  echo "usage: q-status.sh   (no arguments)" >&2
  exit 2
fi
if [ -n "$RAM_FOUND" ]; then
  echo "q-status: ram.sh status ($RAM_FOUND)"
  bash "$RAM_FOUND" status
  exit $?
fi

echo "memory: $(mem_free_mb) MB free (the RAM plugin is not installed: no machine-wide queue, no watchdog)"
if command -v flock >/dev/null 2>&1; then
  mkdir -p "$(dirname "$HEAVY_LOCK")"
  if (flock -n 9) 9>"$HEAVY_LOCK"; then
    echo "queue: free ($HEAVY_LOCK)"
  else
    echo "queue: a heavy job holds the lock ($HEAVY_LOCK)"
  fi
else
  echo "queue: none (flock not found: the tools run unqueued)"
fi
# The pattern travels in awk's environment, not in its arguments: awk's own command line would match it.
ps -U "$(id -u)" -o pid=,rss=,etime=,args= 2>/dev/null |
  HEAVY_PATTERN='flutter_tools|flutter_tester|analysis_server|GradleDaemon|KotlinCompileDaemon|qemu-system|/emulator/emulator' awk '
  BEGIN { pat = ENVIRON["HEAVY_PATTERN"]; n = 0; print "heavy processes of this user:" }
  $0 ~ pat {
    n++
    args = ""
    for (i = 4; i <= NF; i++) args = args " " $i
    printf "  pid %-7s %6d MB  up %-11s %s\n", $1, $2 / 1024, $3, substr(args, 2, 100)
  }
  END { if (n == 0) print "  none" }'
