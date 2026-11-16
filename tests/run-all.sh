#!/usr/bin/env bash
# Runs every test area of the kit and prints one line per area. Exits 0 only when every area that ran passes.
# Works from any directory. Each area writes only inside its own temporary folder; this script keeps the areas'
# output in one temporary folder, which it removes.
#
# usage: tests/run-all.sh [--verbose] [--lenient] [area ...]
#   areas: static install guard-bash save-chat tools token-guard checks recipes (default: all of them)
#   --verbose prints each area's full output, not only the output of an area that failed.
#   Strict by default: a problem in a file that another package of the kit writes fails the run too.
#   --lenient (or KIT_STRICT=0) makes those problems warnings, so a half-built kit still shows which areas of its
#             own pass. --strict (or KIT_STRICT=1) is the default.
# The checks area runs Dart (dart run, about a second a case): run it through the queue (ram.sh run --).
# An area whose run.sh does not exist yet is listed as skipped, never as passed. Optional: KIT_CLAUDE_VALIDATE=1
# also runs `claude plugin validate .` in the static area, and KIT_PRIVATE_PATTERN='name1|name2' (real names, never
# stored in the kit) fails it on every line holding one.
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ALL_AREAS="static install guard-bash save-chat tools token-guard checks recipes"
USAGE="usage: tests/run-all.sh [--verbose] [--lenient] [area ...]   (strict unless --lenient or KIT_STRICT=0)
  areas: $ALL_AREAS"

verbose=0
areas=""
# Strict unless the caller says otherwise: the areas read KIT_STRICT.
export KIT_STRICT="${KIT_STRICT:-1}"
for arg in "$@"; do
  case "$arg" in
    -h | --help) echo "$USAGE"; exit 0 ;;
    -v | --verbose) verbose=1 ;;
    --strict) KIT_STRICT=1 ;;
    --lenient) KIT_STRICT=0 ;;
    -*) echo "$USAGE" >&2; exit 2 ;;
    *)
      case " $ALL_AREAS " in
        *" $arg "*) areas="$areas $arg" ;;
        *) echo "unknown area: $arg" >&2; echo "$USAGE" >&2; exit 2 ;;
      esac
      ;;
  esac
done
[ -n "$areas" ] || areas=$ALL_AREAS

for tool in node python3; do
  command -v "$tool" >/dev/null 2>&1 || { echo "run-all: $tool is required" >&2; exit 1; }
done

LOGS="$(mktemp -d)"
trap 'rm -rf "$LOGS"' EXIT
# Python must not leave __pycache__ folders in the kit.
export PYTHONDONTWRITEBYTECODE=1

passed=0
failed=0
skipped=0
summary=""
for area in $areas; do
  log="$LOGS/$area.log"
  if [ ! -f "$HERE/$area/run.sh" ]; then
    skipped=$((skipped + 1))
    line=$(printf 'skip  %-12s        tests/%s/run.sh does not exist yet' "$area" "$area")
    echo "$line"
    summary="$summary$line
"
    continue
  fi
  start=$SECONDS
  bash "$HERE/$area/run.sh" >"$log" 2>&1
  code=$?
  took=$((SECONDS - start))
  # The last line of each area is its own count of passed and failed cases.
  last="$(grep -v '^[[:space:]]*$' "$log" | tail -n 1)"
  if [ "$code" -eq 0 ]; then
    passed=$((passed + 1))
    line=$(printf 'ok    %-12s %4ss  %s' "$area" "$took" "$last")
    [ "$verbose" -eq 1 ] && cat "$log"
  else
    failed=$((failed + 1))
    line=$(printf 'FAIL  %-12s %4ss  exit %s: %s' "$area" "$took" "$code" "$last")
    echo "---- $area: full output"
    cat "$log"
    echo "---- end of $area"
  fi
  echo "$line"
  summary="$summary$line
"
done

echo
label=" (strict)"
[ "$KIT_STRICT" = 1 ] || label=" (lenient: problems in other packages' files are warnings)"
echo "== summary$label"
printf '%s' "$summary"
echo "run-all: $passed area(s) passed, $failed failed, $skipped skipped"
[ "$failed" -eq 0 ]
