#!/usr/bin/env bash
# The gate, run once before a push or a release: formatting, the analyzer, the kit's structure and text checks,
# then the whole test suite. Each leg waits in the queue on its own and writes a log in RUNS_DIR/verify/<time>/;
# the screen gets one line per leg with its real numbers (the tests leg: how many tests ran), and the run ends
# with the test budget line of check_structure. It never edits a file: dart format only reports.
# Every leg runs even after a failure, so one run shows everything that is wrong.
# usage: verify.sh   (no arguments)
set -u
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

if [ $# -gt 0 ]; then
  echo "usage: verify.sh   (no arguments: it checks the whole project)" >&2
  exit 2
fi
if [ ! -f "$APP_DIR/pubspec.yaml" ]; then
  echo "verify: APP_DIR '$APP_DIR' has no pubspec.yaml (set APP_DIR in scripts/tools/tools.env)" >&2
  exit 2
fi
logs="$RUNS_DIR/verify/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$logs" || { echo "verify: cannot create $logs" >&2; exit 2; }
queue_line verify

passed=0
failed=0
# tests_ran <log>: "<N> tests ran: <P> passed, <F> failed[, <S> skipped]" from the last progress line of flutter
# test ("+P ~S -F: ...", after a time in the compact reporter), or nothing when the log has none.
tests_ran() {
  local esc line w p=0 s=0 f=0
  esc=$(printf '\033')
  line=$(sed "s/$esc\[[0-9;]*m//g" "$1" | grep -E '^([0-9]+:[0-9]+ )?\+[0-9]+( ~[0-9]+)?( -[0-9]+)?: ' | tail -n 1)
  [ -n "$line" ] || return 0
  for w in ${line%%: *}; do
    case "$w" in
      +*) p=${w#+} ;;
      '~'*) s=${w#'~'} ;;
      -*) f=${w#-} ;;
    esac
  done
  w=tests
  [ "$((p + f))" -eq 1 ] && w=test
  printf '%s %s ran: %s passed, %s failed' "$((p + f))" "$w" "$p" "$f"
  [ "$s" -eq 0 ] || printf ', %s skipped' "$s"
  echo
}
# leg <name> <summary pattern> <min free MB> <command...>: runs one leg, prints its line. The summary is the last
# line that matches the pattern (else the last non-empty line); the tests leg says how many tests ran.
leg() {
  local name=$1 pattern=$2 need=$3 log="$logs/$1.log" code summary ran=""
  shift 3
  run_heavy "verify $name" "$need" -- "$@" >"$log" 2>&1
  code=$?
  summary=$(grep -E -- "$pattern" "$log" | tail -n 1)
  [ -n "$summary" ] || summary=$(grep -v '^[[:space:]]*$' "$log" | tail -n 1)
  [ "$name" = tests ] && ran=$(tests_ran "$log")
  [ -z "$ran" ] || summary=$ran
  if [ "$code" -eq 0 ]; then
    passed=$((passed + 1))
    printf '  ok    %-10s %s\n' "$name" "$summary"
  else
    failed=$((failed + 1))
    printf '  FAIL  %-10s exit %s: %s   (log: %s)\n' "$name" "$code" "$summary" "$log"
  fi
}
# missing <name> <what>: a leg that cannot run counts as failed: a gate never passes on a check it skipped.
missing() {
  failed=$((failed + 1))
  printf '  FAIL  %-10s %s\n' "$1" "$2"
}

dirs=""
for d in lib test; do [ -d "$APP_DIR/$d" ] && dirs="$dirs $d"; done
# $DART and $FLUTTER are split on purpose ("fvm dart"), and so is $dirs (one or two folder names, no spaces).
if [ -n "$dirs" ]; then
  leg format 'Formatted|Changed' "$ANALYZE_MIN_FREE_MB" $DART format --output=none --set-exit-if-changed $dirs
else
  missing format "no lib/ or test/ folder"
fi
leg analyze 'issues? found' "$ANALYZE_MIN_FREE_MB" $FLUTTER analyze
for check in check_structure check_l10n; do
  if [ -f "$APP_DIR/tool/kit/$check.dart" ]; then
    leg "${check#check_}" "^$check(\.dart)?: " "$ANALYZE_MIN_FREE_MB" $DART run "tool/kit/$check.dart"
  else
    missing "${check#check_}" "tool/kit/$check.dart not found (install the kit's tool/kit/)"
  fi
done
if [ -d "$APP_DIR/test" ]; then
  leg tests 'tests passed|Some tests failed|No tests ran|[0-9]+:[0-9]+ \+[0-9]+' "$TEST_MIN_FREE_MB" \
    $FLUTTER test --concurrency="$TEST_CONCURRENCY" -r failures-only
else
  missing tests "no test/ folder"
fi

echo "verify: $passed of $((passed + failed)) legs passed (logs in $logs)"
# The test budget (F17): the line a full check_structure run prints, test/ against lib/ in counted lines. It comes
# before the exit line, so the last line of verify, like every tool's, is its exit code.
budget=$(grep -E '^budget: ' "$logs/structure.log" 2>/dev/null | tail -n 1)
[ -z "$budget" ] || echo "$budget"
code=0
[ "$failed" -eq 0 ] || code=1
echo "verify exit: $code"
exit "$code"
