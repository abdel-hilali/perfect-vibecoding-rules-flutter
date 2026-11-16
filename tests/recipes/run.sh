#!/usr/bin/env bash
# Tests the recipes skill against the starter it quotes, with tests/recipes/check.mjs:
# 1. A self-test of check.mjs on planted recipes and a planted starter, so a checker that stopped seeing drift
#    fails here.
# 2. The kit: every excerpt that names a starter file matches templates/boilerplate, and every recipe keeps its
#    size. A block marked "not in the starter" is listed, never failed.
# Works from any directory. Writes only inside a temp folder, removed at the end.
# Exits 0 only when every check passes; the last line gives the numbers.
# usage: tests/recipes/run.sh
set -u

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
USAGE="usage: tests/recipes/run.sh"
case "${1:-}" in
  "") ;;
  -h | --help) echo "$USAGE"; exit 0 ;;
  *) echo "$USAGE" >&2; exit 2 ;;
esac
command -v node >/dev/null 2>&1 || { echo "recipes: node is required" >&2; exit 1; }
node --check "$HERE/check.mjs" || { echo "recipes: syntax error in check.mjs"; exit 1; }
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT

# The planted starter: one Dart file and the pubspec fragment.
S="$T/starter"
mkdir -p "$S/lib"
printf 'class A {\n  void one() {}\n  void two() {}\n  void three() {}\n}\n' >"$S/lib/a.dart"
printf 'dependencies:\n  dio: ^5.11.1\n' >"$S/pubspec.fragment.yaml"

# One case: its name, the exit code and a line that check.mjs must give, the number of prose lines that set the
# planted recipe's size (40 put it over the 2 KB floor), and its code block.
cases=0
passed=0
check_case() {
  local name=$1 want_code=$2 want_line=$3 prose=$4 block=$5 dir code
  cases=$((cases + 1))
  dir="$T/case$cases"
  mkdir -p "$dir"
  {
    printf '# Case\n\n'
    for _ in $(seq "$prose"); do echo "A line of prose that sets the size of this planted recipe."; done
    printf '\n```dart\n%s\n```\n' "$block"
  } >"$dir/case.md"
  node "$HERE/check.mjs" "$dir" "$S" >"$T/case.out" 2>&1
  code=$?
  if [ "$code" -eq "$want_code" ] && grep -qF -- "$want_line" "$T/case.out"; then
    passed=$((passed + 1))
  else
    echo "FAIL self-test: $name (exit $code, wanted $want_code and the line: $want_line)"
    sed 's/^/  | /' "$T/case.out"
  fi
}

ok_line="recipes: 1 excerpt checked against the starter, 0 not in the starter"
check_case "an excerpt that matches passes" 0 "$ok_line" 40 $'// lib/a.dart\n  void one() {}\n  void two() {}'
check_case "a // ... line cuts the excerpt" 0 "$ok_line" 40 \
  $'// lib/a.dart\n  void one() {}\n  // ...\n  void three() {}'
check_case "pubspec.yaml means the fragment" 0 "$ok_line" 40 $'# pubspec.yaml\n  dio: ^5.11.1'
# A run of lines must match together: the message names the run's first line.
check_case "a changed line fails" 1 "lib/a.dart: lines not found in order, from: void one() {}" 40 \
  $'// lib/a.dart\n  void one() {}\n  void TWO() {}'
check_case "runs out of order fail" 1 "lib/a.dart: lines not found in order, from: void one() {}" 40 \
  $'// lib/a.dart\n  void three() {}\n  // ...\n  void one() {}'
check_case "a file the starter lacks fails" 1 "case.md:45: lib/b.dart: no such file in the starter" 40 \
  $'// lib/b.dart\n  void one() {}'
check_case "a block marked not in the starter is listed, never failed" 0 \
  "not in the starter: case.md:45 lib/b.dart" 40 \
  $'// lib/b.dart (not in the starter)\n  void four() {}'
check_case "a stale mark is named" 0 "lib/a.dart (the starter has this file now: quote it)" 40 \
  $'// lib/a.dart (not in the starter)\n  void one() {}'
check_case "a recipe over 5 KB fails" 1 "bytes (2 to 5 KB)" 90 $'// lib/a.dart\n  void one() {}'
check_case "an open fence fails" 1 "case.md: a code block is not closed" 40 $'// lib/a.dart\n  void one() {}\n```'

node "$HERE/check.mjs" "$ROOT/skills/recipes" "$ROOT/templates/boilerplate" >"$T/kit.out" 2>&1
kit_code=$?
grep -v '^recipes: ' "$T/kit.out"
kit_line="$(grep '^recipes: ' "$T/kit.out" | tail -n 1)"
[ -n "$kit_line" ] || kit_line="recipes: check.mjs gave no count (exit $kit_code)"
echo "$kit_line; self-test $passed of $cases cases"
[ "$kit_code" -eq 0 ] && [ "$passed" -eq "$cases" ]
