# Shared helpers for the tools in this folder. Source it from a tool; do not run it.
# It loads tools.env, fills the defaults that depend on other values, and finds the RAM plugin's queue.

TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tools.env
. "$TOOLS_DIR/tools.env"

if [ -z "$APP_DIR" ]; then
  APP_DIR="$(cd "$TOOLS_DIR/../.." && pwd)"   # the tools live in <app>/scripts/tools, even inside a monorepo
fi
[ -n "$RUNS_DIR" ] || RUNS_DIR="$APP_DIR/runs"
if [ -z "$DART" ]; then
  case "$FLUTTER" in
    "fvm flutter") DART="fvm dart" ;;
    */flutter) DART="${FLUTTER%flutter}dart" ;;   # /opt/flutter/bin/flutter -> /opt/flutter/bin/dart
    *) DART="dart" ;;
  esac
fi
case "$TEST_CONCURRENCY" in '' | *[!0-9]* | 0) TEST_CONCURRENCY=2 ;; esac
# One lock for every app of this user: two analyzers or test runs at once, even in two apps, can fill the memory.
if [ -z "$HEAVY_LOCK" ]; then
  HEAVY_LOCK="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/perfect-vibecoding-heavy-$(id -u).lock"
fi

# Free memory in MB: MemAvailable on Linux, free + inactive pages on macOS.
mem_free_mb() {
  if [ -r /proc/meminfo ]; then
    awk '/MemAvailable/ {print int($2 / 1024)}' /proc/meminfo
  elif command -v vm_stat >/dev/null 2>&1; then
    vm_stat | awk '/page size of/ {ps = $8} /Pages free/ {f = $3} /Pages inactive/ {i = $3}
      END {gsub(/\./, "", f); gsub(/\./, "", i); print int((f + i) * ps / 1048576)}'
  else
    echo 999999
  fi
}

# Waits until at least $1 MB are free, checking every 15 seconds, at most $2 rounds.
wait_for_memory() {
  local need=$1 rounds=${2:-$MEM_WAIT_ROUNDS} n=0
  while [ "$(mem_free_mb)" -lt "$need" ] && [ "$n" -lt "$rounds" ]; do
    sleep 15
    n=$((n + 1))
  done
}

# Prints the path of the RAM plugin's ram.sh, or nothing. In order: RAM_SH, ram.sh on PATH, the standalone
# install, then the newest copy in Claude Code's plugin cache. RAM_SH=off never uses it.
find_ram_sh() {
  local c
  case "$RAM_SH" in
    off | none | 0) return 0 ;;
    '') ;;
    *)
      if [ -f "$RAM_SH" ]; then echo "$RAM_SH"; return 0; fi
      echo "warning: RAM_SH=$RAM_SH is not a file; looking for ram.sh elsewhere" >&2
      ;;
  esac
  c=$(command -v ram.sh 2>/dev/null)
  if [ -n "$c" ] && [ -f "$c" ]; then echo "$c"; return 0; fi
  [ -n "${HOME:-}" ] || return 0
  c="$HOME/.local/share/perfect-vibecoding-ram/ram.sh"
  if [ -f "$c" ]; then echo "$c"; return 0; fi
  c=$(ls -t "$HOME"/.claude/plugins/cache/*/perfect-vibecoding-ram-management/*/skills/ram/scripts/ram.sh 2>/dev/null | head -n 1)
  if [ -n "$c" ] && [ -f "$c" ]; then echo "$c"; fi
  return 0
}
RAM_FOUND="$(find_ram_sh)"

# queue_line <tool>: says which queue the job waits in, before its output starts.
queue_line() {
  if [ -n "$RAM_FOUND" ]; then
    echo "$1: queued through ram.sh, the machine-wide queue ($RAM_FOUND); a wait of minutes is normal"
  else
    echo "$1: queued (one heavy job at a time on this machine); a wait of minutes is normal"
  fi
}

# Runs "$@" while holding the heavy-job lock, so only one heavy job runs on the machine at a time. The job itself
# runs with the lock's descriptor closed: a daemon it starts (Gradle, the Kotlin daemon) must not keep the lock.
# Without flock (stock macOS) it warns and runs unqueued: a lock that can go stale is worse than none.
with_heavy_lock() {
  if command -v flock >/dev/null 2>&1; then
    mkdir -p "$(dirname "$HEAVY_LOCK")"
    (
      flock 9
      "$@" 9>&-
    ) 9>"$HEAVY_LOCK"
  else
    echo "warning: flock not found, running without the queue" >&2
    "$@"
  fi
}

# _when_free <MB> <command...>: waits for that much free memory (at most MEM_WAIT_ROUNDS rounds), then runs it.
_when_free() {
  local need=$1 free
  shift
  free=$(mem_free_mb)
  if [ "$free" -lt "$need" ]; then
    echo "queue: $free MB free, waiting for $need MB (at most $MEM_WAIT_ROUNDS rounds of 15 s)"
    wait_for_memory "$need"
  fi
  "$@"
}

# run_heavy <label> <min free MB> [--alone] -- <command...>: runs the command from APP_DIR as one heavy job.
# With the RAM plugin: `ram.sh run --name <label> [--alone] -- <command>` (the machine-wide queue, a memory cap,
# one job per folder). Without it: the tools' own lock (one per user), then a wait for free memory.
run_heavy() {
  local label=$1 need=$2 alone=""
  shift 2
  if [ "${1:-}" = --alone ]; then alone=--alone; shift; fi
  [ "${1:-}" = -- ] && shift
  cd "$APP_DIR" || return 2
  if [ -n "$RAM_FOUND" ]; then
    # $alone is empty or one word: unquoted on purpose, so an empty one adds no argument.
    bash "$RAM_FOUND" run --name "$label" $alone -- "$@"
    return $?
  fi
  with_heavy_lock _when_free "$need" "$@"
}
