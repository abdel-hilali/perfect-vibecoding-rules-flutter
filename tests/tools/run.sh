#!/usr/bin/env bash
# Tests for the tools in templates/scripts/tools: lib.sh (finding ram.sh, the defaults, the lock), q-analyze.sh,
# q-test.sh, q-build.sh, verify.sh, q-status.sh, wait-milestone.sh and sweep-owners.py.
# They run against stub flutter, dart and ram.sh commands, fake journals and throw-away git repos, all inside one
# temp folder. Never a real flutter, never the network. Exit 0 only when every case passes.
set -u
if [ "$#" -gt 0 ]; then
  echo "usage: $0   (runs every tools case)" >&2
  exit 2
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
TOOLS="$(cd "$HERE/../../templates/scripts/tools" && pwd)"
FIX="$HERE/fixtures"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/tools.XXXXXX")"
DAEMON_PID=""
cleanup() {
  [ -n "$DAEMON_PID" ] && kill "$DAEMON_PID" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT
export PYTHONDONTWRITEBYTECODE=1

pass=0
failed=0
ok() { pass=$((pass + 1)); echo "ok    $1"; }
ko() {
  failed=$((failed + 1))
  echo "FAIL  $1"
  [ -n "${2:-}" ] && printf '%s\n' "$2" | head -25 | sed 's/^/      /'
}
skip() { echo "skip  $1"; }
# run CMD...: keeps the combined output in $out and the exit code in $code.
run() {
  out=$("$@" 2>&1)
  code=$?
}
# expect NAME CODE [PATTERN ...]: each PATTERN (grep -E) must match $out; a leading ! means it must not.
expect() {
  local name=$1 want=$2 p
  shift 2
  if [ "$code" != "$want" ]; then
    ko "$name (exit $code, expected $want)" "$out"
    return
  fi
  for p in "$@"; do
    case "$p" in
      '!'*)
        if printf '%s\n' "$out" | grep -qE -- "${p#!}"; then ko "$name (should not print: ${p#!})" "$out"; return; fi ;;
      *)
        if ! printf '%s\n' "$out" | grep -qE -- "$p"; then ko "$name (missing: $p)" "$out"; return; fi ;;
    esac
  done
  ok "$name"
}
digest() { cksum "$@" 2>/dev/null | awk '{print $1 $2}' | tr -d '\n'; }
# Every git command of these tests runs in a throw-away repo inside $TMP.
new_repo() {
  mkdir -p "$1"
  git -C "$1" init -q
  git -C "$1" config user.email tests@example.com
  git -C "$1" config user.name tests
  git -C "$1" config commit.gpgsign false
}

# ---- environment shared by the tools: everything points into $TMP ----
APP="$TMP/app"
mkdir -p "$APP/lib" "$APP/test/folder_test.dart" "$APP/integration_test" "$APP/tool/kit" "$TMP/bin" "$TMP/home" "$TMP/ram"
printf 'name: kit_tools_test\n' >"$APP/pubspec.yaml"
printf 'void main() {}\n' >"$APP/lib/main.dart"
printf 'void main() {}\n' >"$APP/test/a_test.dart"
printf 'void main() {}\n' >"$APP/test/b_test.dart"
printf 'void main() {}\n' >"$APP/integration_test/app_test.dart"
printf 'void main() {}\n' >"$APP/tool/kit/check_structure.dart"
printf 'void main() {}\n' >"$APP/tool/kit/check_l10n.dart"
cp "$FIX/stub-flutter.sh" "$TMP/bin/flutter"
cp "$FIX/stub-dart.sh" "$TMP/bin/dart"
cp "$FIX/stub-ram.sh" "$TMP/ram/ram.sh"
chmod +x "$TMP/bin/flutter" "$TMP/bin/dart" "$TMP/ram/ram.sh"
# HOME has no ram.sh, and RAM_SH=off, so the tools use their own queue unless a case says otherwise.
export HOME="$TMP/home" APP_DIR="$APP" FLUTTER="$TMP/bin/flutter" DART="$TMP/bin/dart" RAM_SH=off
export HEAVY_LOCK="$TMP/heavy.lock" RUNS_DIR="$TMP/runs" WAIT_POLL_S=1
export ANALYZE_MIN_FREE_MB=0 TEST_MIN_FREE_MB=0 BUILD_MIN_FREE_MB=0 MEM_WAIT_ROUNDS=0
unset TAIL_LINES STUB_EXIT STUB_LINES STUB_SLEEP STUB_DAEMON STUB_FAIL_ON STUB_IPA_LINE TEST_CONCURRENCY DEVICE_WRITE_OK
unset STUB_TEST_LINE STUB_BUDGET

# ---- static checks on the tools ----
for t in lib.sh q-analyze.sh q-test.sh q-build.sh verify.sh q-status.sh wait-milestone.sh; do
  run bash -n "$TOOLS/$t"
  expect "$t: bash -n" 0
done
run python3 -I -c 'import ast, sys; ast.parse(open(sys.argv[1]).read())' "$TOOLS/sweep-owners.py"
expect "sweep-owners.py: parses" 0
notx=""
for t in q-analyze.sh q-test.sh q-build.sh verify.sh q-status.sh wait-milestone.sh sweep-owners.py; do
  [ -x "$TOOLS/$t" ] || notx="$notx $t"
done
if [ -z "$notx" ]; then ok "the tools are executable"; else ko "not executable:$notx"; fi
if [ -x "$TOOLS/lib.sh" ] || [ -x "$TOOLS/tools.env" ]; then ko "lib.sh and tools.env are sourced, never run: no execute bit"; else ok "lib.sh and tools.env carry no execute bit"; fi
if grep -nE '^[^#]*\bp(kill|grep)[[:space:]]+-f' "$TOOLS"/*.sh "$TOOLS/sweep-owners.py" >/dev/null; then
  ko "a tool calls pkill or pgrep with the full-command flag"
else
  ok "no tool calls pkill or pgrep with the full-command flag"
fi
if grep -nE 'declare -A|mapfile|readarray|\$\{[A-Za-z_]+,,\}|\$\{[A-Za-z_]+\^\^\}' "$TOOLS"/*.sh >/dev/null; then
  ko "a tool uses bash 4 only syntax (macOS ships bash 3.2)"
else
  ok "no bash 4 only syntax (declare -A, mapfile, \${x,,})"
fi
for t in q-analyze.sh q-test.sh q-build.sh verify.sh q-status.sh wait-milestone.sh; do
  grep -q '^set -u' "$TOOLS/$t" || ko "$t: no set -u"
done
ok "every tool sets -u"

# ---- lib.sh: defaults ----
run bash -c 'unset APP_DIR RUNS_DIR DART; . "$1/lib.sh"; echo "app=$APP_DIR runs=$RUNS_DIR dart=$DART lock=$HEAVY_LOCK"' _ "$TOOLS"
expect "lib.sh: APP_DIR defaults to two folders above the tools" 0 "app=$(cd "$TOOLS/../.." && pwd) " "runs=$(cd "$TOOLS/../.." && pwd)/runs "
run bash -c 'unset DART HEAVY_LOCK; FLUTTER="fvm flutter"; . "$1/lib.sh"; echo "dart=$DART"; echo "lock=$HEAVY_LOCK"' _ "$TOOLS"
expect "lib.sh: FLUTTER=\"fvm flutter\" gives DART=\"fvm dart\"; one lock per user" 0 '^dart=fvm dart$' "perfect-vibecoding-heavy-$(id -u)\.lock$"
run bash -c 'unset DART; FLUTTER=/opt/sdk/flutter/bin/flutter; . "$1/lib.sh"; echo "dart=$DART"' _ "$TOOLS"
expect "lib.sh: a FLUTTER path gives the dart beside it" 0 '^dart=/opt/sdk/flutter/bin/dart$'
run bash -c 'unset DART; FLUTTER=flutter; TEST_CONCURRENCY=x; . "$1/lib.sh"; echo "dart=$DART c=$TEST_CONCURRENCY"' _ "$TOOLS"
expect "lib.sh: plain flutter gives plain dart; a bad TEST_CONCURRENCY falls back to 2" 0 '^dart=dart c=2$'

# ---- lib.sh: finding ram.sh ----
find_ram() { bash -c '. "$1/lib.sh"; echo "found=$RAM_FOUND"' _ "$TOOLS"; }
run env RAM_SH="$TMP/ram/ram.sh" bash -c '. "$1/lib.sh"; echo "found=$RAM_FOUND"' _ "$TOOLS"
expect "lib.sh: finds ram.sh through RAM_SH" 0 "^found=$TMP/ram/ram.sh$"
run env RAM_SH="$TMP/ram/ram.sh" "$TOOLS/q-analyze.sh"
expect "q-analyze: through ram.sh run --name analyze" 0 'queued through ram.sh' \
  "stub-ram\[$TMP/ram/ram.sh\]: run --name analyze -- $TMP/bin/flutter analyze$" '^stub-flutter: analyze$' '^analyze exit: 0$'
run env RAM_SH="$TMP/ram/missing.sh" bash -c '. "$1/lib.sh"; echo "found=$RAM_FOUND"' _ "$TOOLS"
expect "lib.sh: a RAM_SH that is not a file warns and looks elsewhere" 0 'RAM_SH=.*missing.sh is not a file' '^found=$'
run env RAM_SH=off bash -c '. "$1/lib.sh"; echo "found=$RAM_FOUND"' _ "$TOOLS"
expect "lib.sh: RAM_SH=off never uses ram.sh" 0 '^found=$'
# The search order, with a PATH that holds only this test's bin folders and the system's.
SAFE_PATH="$TMP/bin:/usr/bin:/bin"
if PATH="$SAFE_PATH" command -v ram.sh >/dev/null 2>&1; then
  skip "lib.sh: search order (a ram.sh is on the system PATH)"
else
  H="$TMP/home-order"
  C="$H/.claude/plugins/cache/example-market/perfect-vibecoding-ram-management"
  mkdir -p "$H/.local/share/perfect-vibecoding-ram" "$C/2.0.0/skills/ram/scripts" "$C/1.5.0/skills/ram/scripts" "$TMP/pathbin"
  for d in "$C/2.0.0" "$C/1.5.0"; do cp "$FIX/stub-ram.sh" "$d/skills/ram/scripts/ram.sh"; done
  touch -t 202501010000 "$C/2.0.0/skills/ram/scripts/ram.sh"
  run env -u RAM_SH HOME="$H" PATH="$SAFE_PATH" bash -c '. "$1/lib.sh"; echo "found=$RAM_FOUND"' _ "$TOOLS"
  expect "lib.sh: else the newest copy in the plugin cache (by time, not by name)" 0 "^found=$C/1.5.0/skills/ram/scripts/ram.sh$"
  cp "$FIX/stub-ram.sh" "$H/.local/share/perfect-vibecoding-ram/ram.sh"
  run env -u RAM_SH HOME="$H" PATH="$SAFE_PATH" bash -c '. "$1/lib.sh"; echo "found=$RAM_FOUND"' _ "$TOOLS"
  expect "lib.sh: the standalone install comes before the plugin cache" 0 "^found=$H/.local/share/perfect-vibecoding-ram/ram.sh$"
  cp "$FIX/stub-ram.sh" "$TMP/pathbin/ram.sh"
  chmod +x "$TMP/pathbin/ram.sh"
  run env -u RAM_SH HOME="$H" PATH="$TMP/pathbin:$SAFE_PATH" bash -c '. "$1/lib.sh"; echo "found=$RAM_FOUND"' _ "$TOOLS"
  expect "lib.sh: ram.sh on PATH comes before the standalone install" 0 "^found=$TMP/pathbin/ram.sh$"
  run env RAM_SH="$TMP/ram/ram.sh" HOME="$H" PATH="$TMP/pathbin:$SAFE_PATH" bash -c '. "$1/lib.sh"; echo "found=$RAM_FOUND"' _ "$TOOLS"
  expect "lib.sh: RAM_SH comes first" 0 "^found=$TMP/ram/ram.sh$"
  run env -u RAM_SH HOME="$TMP/home" PATH="$SAFE_PATH" bash -c '. "$1/lib.sh"; echo "found=$RAM_FOUND"' _ "$TOOLS"
  expect "lib.sh: nothing found, nothing used" 0 '^found=$'
fi

# ---- q-analyze.sh ----
run "$TOOLS/q-analyze.sh"
expect "q-analyze: the whole project, from APP_DIR, in the tools' own queue" 0 'queued \(one heavy job at a time' \
  '^stub-flutter: analyze$' "^stub-cwd: $APP$" '^analyze exit: 0$'
run "$TOOLS/q-analyze.sh" lib test/a_test.dart
expect "q-analyze: the files and folders given" 0 '^stub-flutter: analyze lib test/a_test.dart$'
STUB_EXIT=3 run "$TOOLS/q-analyze.sh"
expect "q-analyze: passes the analyzer's exit code on" 3 '^analyze exit: 3$'
STUB_LINES=40 TAIL_LINES=3 run "$TOOLS/q-analyze.sh"
expect "q-analyze: prints only the tail (TAIL_LINES)" 0 '^stub line 40$' '!^stub line 37$' '^analyze exit: 0$'
run "$TOOLS/q-analyze.sh" --fatal-infos
expect "q-analyze: refuses an option" 2 'is an option' '!stub-flutter'
run "$TOOLS/q-analyze.sh" lib/gone.dart
expect "q-analyze: refuses a path that does not exist" 2 'does not exist' '!stub-flutter'
APP_DIR="$TMP/bin" run "$TOOLS/q-analyze.sh"
expect "q-analyze: refuses an APP_DIR without pubspec.yaml" 2 'no pubspec.yaml' '!stub-flutter'
FLUTTER="$TMP/bin/flutter --suppress-analytics" run "$TOOLS/q-analyze.sh"
expect "q-analyze: FLUTTER may hold two words (fvm flutter)" 0 '^stub-flutter: --suppress-analytics analyze$'
# Without the RAM plugin, a job waits for free memory first (0 rounds here, so it runs at once after the line).
ANALYZE_MIN_FREE_MB=99999999 run "$TOOLS/q-analyze.sh"
expect "q-analyze: without ram.sh, waits for free memory, then runs" 0 'queue: [0-9]+ MB free, waiting for 99999999 MB' \
  '^stub-flutter: analyze$' '^analyze exit: 0$'

# ---- q-test.sh ----
run "$TOOLS/q-test.sh"
expect "q-test: no file gives a usage line" 2 '^usage: q-test.sh'
run "$TOOLS/q-test.sh" test/a_test.dart test/b_test.dart
expect "q-test: runs the files, two at a time, failures only" 0 \
  '^stub-flutter: test --concurrency=2 -r failures-only test/a_test.dart test/b_test.dart$' '^test exit: 0$'
TEST_CONCURRENCY=3 run "$TOOLS/q-test.sh" test/a_test.dart
expect "q-test: --concurrency from TEST_CONCURRENCY" 0 '^stub-flutter: test --concurrency=3 -r failures-only test/a_test.dart$'
STUB_EXIT=1 run "$TOOLS/q-test.sh" "$APP/test/a_test.dart"
expect "q-test: an absolute path works; passes the exit code on" 1 '^test exit: 1$'
run "$TOOLS/q-test.sh" test
expect "q-test: refuses a folder" 2 'not a test FILE' '!stub-flutter'
run "$TOOLS/q-test.sh" .
expect "q-test: refuses the whole project" 2 'not a test FILE' '!stub-flutter'
run "$TOOLS/q-test.sh" lib/main.dart
expect "q-test: refuses a file that is not a test" 2 'not a test FILE' '!stub-flutter'
run "$TOOLS/q-test.sh" test/a_test.dart lib/main.dart
expect "q-test: refuses the whole call when one argument is wrong" 2 'not a test FILE' '!stub-flutter'
run "$TOOLS/q-test.sh" test/folder_test.dart
expect "q-test: refuses a folder named like a test file" 2 'not a file' '!stub-flutter'
run "$TOOLS/q-test.sh" test/gone_test.dart
expect "q-test: refuses a missing test file" 2 'not a file' '!stub-flutter'
run "$TOOLS/q-test.sh" -r expanded test/a_test.dart
expect "q-test: refuses options" 2 'is an option' '!stub-flutter'
run "$TOOLS/q-test.sh" integration_test/app_test.dart
expect "q-test: refuses an integration test (it needs a device)" 2 'integration test' '!stub-flutter'
run "$TOOLS/q-test.sh" -d emulator-5554 integration_test/app_test.dart
expect "q-test -d: one integration test, on that device" 0 'alone in the queue' \
  '^stub-flutter: test integration_test/app_test.dart -d emulator-5554$' '^test exit: 0$'
STUB_EXIT=1 RAM_SH="$TMP/ram/ram.sh" run "$TOOLS/q-test.sh" -d emulator-5554 "$APP/integration_test/app_test.dart"
expect "q-test -d: through ram.sh, alone in the queue; passes the exit code on" 1 "stub-ram\[.*\]: run --name \
device-test --alone -- $TMP/bin/flutter test $APP/integration_test/app_test.dart -d emulator-5554$" '^test exit: 1$'
# Every other use of -d: refused with exit 2, and nothing runs.
bad=""
for args in "-d" "-d emulator-5554" "-d -r integration_test/app_test.dart" "-d emulator-5554 test/a_test.dart" \
  "-d emulator-5554 integration_test/app_test.dart integration_test/app_test.dart" "-d emulator-5554 integration_test" \
  "-d emulator-5554 integration_test/gone_test.dart" "test/a_test.dart -d emulator-5554"; do
  run "$TOOLS/q-test.sh" $args
  if [ "$code" != 2 ] || printf '%s\n' "$out" | grep -q '^stub-flutter'; then bad="$bad [$args]"; fi
done
if [ -z "$bad" ]; then ok "q-test -d: refuses no file, two files, a unit test, a folder, a missing file, a late -d"
else ko "q-test -d: not refused:$bad"; fi

# ---- q-build.sh ----
run "$TOOLS/q-build.sh"
expect "q-build: no target gives a usage line" 2 '^usage: q-build.sh'
run "$TOOLS/q-build.sh" exe
expect "q-build: refuses an unknown target" 2 'not a flutter build target' '!stub-flutter'
run "$TOOLS/q-build.sh" apk --release
log=$(ls "$RUNS_DIR"/build/*-apk.log 2>/dev/null | head -n 1)
expect "q-build: builds, prints the tail, the artifact and the exit code" 0 'alone in the queue' \
  '^stub-flutter: build apk --release$' "^artifact: $APP/build/app/outputs/flutter-apk/app-release.apk$" '^build exit: 0$'
if [ -n "$log" ] && grep -q '^stub-flutter: build apk --release$' "$log"; then ok "q-build: the full log is in RUNS_DIR/build/"; else ko "q-build: no log in $RUNS_DIR/build/"; fi
STUB_LINES=50 run "$TOOLS/q-build.sh" ipa
expect "q-build: shows only the last 30 lines; an IPA's path" 0 '^stub line 50$' '!^stub line 20$' "^artifact: $APP/build/ios/ipa$"
STUB_IPA_LINE="Built IPA to $APP/build/ios/ipa." run "$TOOLS/q-build.sh" ipa
expect "q-build: an older Flutter's IPA line, with its final dot" 0 "^artifact: $APP/build/ios/ipa$"
STUB_EXIT=1 run "$TOOLS/q-build.sh" apk
expect "q-build: passes the build's exit code on" 1 '^build exit: 1$'
RAM_SH="$TMP/ram/ram.sh" run "$TOOLS/q-build.sh" appbundle
expect "q-build: through ram.sh, alone" 0 "stub-ram\[.*\]: run --name build appbundle --alone -- $TMP/bin/flutter build appbundle$"
# APP_VERSION (sent as X-App-Version) is the build's own version, unless the caller defines it.
# Rows: the pubspec version line | the options | what flutter build gets after the target.
cp "$APP/pubspec.yaml" "$TMP/pubspec.keep"
printf '{"APP_VERSION": "7.7.7"}\n' >"$APP/defines.json"
printf '{"FLAVOR": "dev"}\n' >"$APP/other.json"
bad=""
while IFS='|' read -r ver opts want; do
  printf 'name: kit_tools_test\n%s\n' "$ver" >"$APP/pubspec.yaml"
  run "$TOOLS/q-build.sh" apk $opts
  got=$(printf '%s\n' "$out" | sed -n 's/^stub-flutter: build apk *//p')
  if [ "$code" != 0 ] || [ "$got" != "$want" ]; then bad="$bad [$ver|$opts] gave '$got'"; fi
done <<'ROWS'
version: 1.2.3+4||--dart-define=APP_VERSION=1.2.3+4
version: "2.0.0+7" # quoted|--release|--dart-define=APP_VERSION=2.0.0+7 --release
version: 1.2.3+4|--dart-define=APP_VERSION=9.9.9|--dart-define=APP_VERSION=9.9.9
version: 1.2.3+4|--dart-define APP_VERSION=9.9.9|--dart-define APP_VERSION=9.9.9
version: 1.2.3+4|--dart-define-from-file=defines.json|--dart-define-from-file=defines.json
version: 1.2.3+4|--dart-define-from-file other.json|--dart-define=APP_VERSION=1.2.3+4 --dart-define-from-file other.json
version: 1.2.3+4|--build-number=9|--dart-define=APP_VERSION=1.2.3+9 --build-number=9
version: 1.2.3+4|--build-name 2.0.0|--dart-define=APP_VERSION=2.0.0+4 --build-name 2.0.0
|--release|--release
ROWS
if [ -z "$bad" ]; then ok "q-build: APP_VERSION is the build's version, never over the caller's own"
else ko "q-build: APP_VERSION:$bad"; fi
cp "$TMP/pubspec.keep" "$APP/pubspec.yaml"
rm -f "$APP/defines.json" "$APP/other.json"

# ---- the tools' own queue (flock) ----
if command -v flock >/dev/null 2>&1; then
  STUB_SLEEP=3 STUB_STARTED="$TMP/started" "$TOOLS/q-analyze.sh" >"$TMP/slow.out" 2>&1 &
  slow=$!
  i=0
  while [ ! -e "$TMP/started" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
  if (flock -n 9) 9>"$HEAVY_LOCK"; then ko "queue: the lock is free while a job runs"; else ok "queue: a running job holds the lock"; fi
  run "$TOOLS/q-status.sh"
  expect "q-status: names the held lock" 0 'queue: a heavy job holds the lock'
  wait "$slow"
  if (flock -n 9) 9>"$HEAVY_LOCK"; then ok "queue: the lock is free after the job"; else ko "queue: the lock is still held after the job"; fi
  STUB_DAEMON="$TMP/daemon.pid" run "$TOOLS/q-analyze.sh"
  DAEMON_PID=$(cat "$TMP/daemon.pid" 2>/dev/null)
  if [ -n "$DAEMON_PID" ] && kill -0 "$DAEMON_PID" 2>/dev/null; then
    if (flock -n 9) 9>"$HEAVY_LOCK"; then ok "queue: a daemon the job started does not keep the lock"; else ko "queue: a daemon the job started keeps the lock"; fi
    kill "$DAEMON_PID" 2>/dev/null
  else
    ko "queue: the stub daemon did not start"
  fi
  DAEMON_PID=""
else
  skip "queue: flock not found (macOS without flock): the tools warn and run unqueued"
fi

# ---- q-status.sh ----
run "$TOOLS/q-status.sh" extra
expect "q-status: an argument gives a usage line" 2 '^usage: q-status.sh'
run "$TOOLS/q-status.sh"
expect "q-status: memory, the queue and the heavy processes" 0 '^memory: [0-9]+ MB free' 'queue: (free|none)' \
  '^heavy processes of this user:$'
RAM_SH="$TMP/ram/ram.sh" run "$TOOLS/q-status.sh"
expect "q-status: ram.sh status when the RAM plugin is there" 0 'stub-ram\[.*\]: status$' '^stub-ram status$' '!^memory:'

# ---- verify.sh ----
run "$TOOLS/verify.sh" extra
expect "verify: an argument gives a usage line" 2 '^usage: verify.sh'
run "$TOOLS/verify.sh"
expect "verify: five legs, one line each, with their numbers" 0 \
  'ok +format +Formatted 3 files \(0 changed\)' 'ok +analyze +No issues found' 'ok +structure +check_structure.dart: 0 problems' \
  'ok +l10n +check_l10n.dart: 0 problems' 'ok +tests +2 tests ran: 2 passed, 0 failed$' 'verify: 5 of 5 legs passed' \
  '^verify exit: 0$' '!^budget: '
vlog=$(ls -d "$RUNS_DIR"/verify/*/ 2>/dev/null | tail -n 1)
if grep -q '^stub-dart: format --output=none --set-exit-if-changed lib test$' "$vlog/format.log" 2>/dev/null; then
  ok "verify: dart format only reports (--output=none), on lib and test"
else
  ko "verify: the format leg did not run dart format --output=none --set-exit-if-changed lib test"
fi
if grep -q '^stub-flutter: test --concurrency=2 -r failures-only$' "$vlog/tests.log" 2>/dev/null; then ok "verify: the whole suite, two files at a time"; else ko "verify: the tests leg ran something else"; fi
STUB_FAIL_ON=analyze run "$TOOLS/verify.sh"
expect "verify: a failed leg fails the gate, and the other legs still run" 1 'FAIL +analyze +exit 1' 'ok +tests' \
  'verify: 4 of 5 legs passed' '^verify exit: 1$'
# The tests leg counts from the reporter's last progress line, colours and all: passed + failed ran, skipped did not.
STUB_FAIL_ON=test STUB_TEST_LINE="$(printf '\033[32m+120\033[0m ~3\033[31m -2\033[0m: Some tests failed.')" \
  run "$TOOLS/verify.sh"
expect "verify: the tests leg says how many tests ran, failed and skipped" 1 \
  'FAIL +tests +exit 1: 122 tests ran: 120 passed, 2 failed, 3 skipped +\(log: '
STUB_BUDGET='budget: test/ 40 counted lines, lib/ 100' run "$TOOLS/verify.sh"
if [ "$code" = 0 ] && [ "$(printf '%s\n' "$out" | tail -n 2 | head -n 1)" = 'budget: test/ 40 counted lines, lib/ 100' ] &&
  [ "$(printf '%s\n' "$out" | tail -n 1)" = 'verify exit: 0' ]; then
  ok "verify: check_structure's budget line comes just before the exit line, which stays last"
else
  ko "verify: the budget line is not just before the exit line" "$out"
fi
mv "$APP/tool/kit/check_l10n.dart" "$TMP/check_l10n.dart"
run "$TOOLS/verify.sh"
expect "verify: a missing check fails the gate, never passes it" 1 'FAIL +l10n +tool/kit/check_l10n.dart not found' 'verify: 4 of 5'
mv "$TMP/check_l10n.dart" "$APP/tool/kit/check_l10n.dart"

# ---- wait-milestone.sh ----
J="$TMP/journal.jsonl"
cp "$FIX/journal-running.jsonl" "$J"
printf 'one\ntwo\nthree\n' >"$TMP/B1.md"
run "$TOOLS/wait-milestone.sh"
expect "wait-milestone: no journal gives a usage line" 2 '^usage: wait-milestone.sh'
run "$TOOLS/wait-milestone.sh" "$J" 1 "$TMP/B1.md" "$TMP/B2.md"
expect "wait-milestone: wakes on the timer with a short status, no dev port" 0 'TIMER: 1 s passed' \
  'agents: 2 started, 0 returned a result' 'B1.md: 3 lines, last write [0-9:]+' 'B2.md: not written yet' \
  'memory: [0-9]+ MB free$' '!dev port'
run "$TOOLS/wait-milestone.sh" "$TMP/none.jsonl" 1
expect "wait-milestone: a journal not written yet is not an error" 0 'TIMER' 'journal: not found yet'
t0=$(date +%s)
"$TOOLS/wait-milestone.sh" "$J" 30 >"$TMP/wait.out" 2>&1 &
waiter=$!
sleep 2
cat "$FIX/journal-running.jsonl" "$FIX/journal-ended.jsonl" >"$TMP/journal.next"
mv "$TMP/journal.next" "$J"
wait "$waiter"
code=$?
t1=$(date +%s)
out=$(cat "$TMP/wait.out")
expect "wait-milestone: wakes when an agent ends, and names it" 0 'MILESTONE: 2 agent event' \
  'agents: 2 started, 1 returned a result, 1 other end event' 'result \| build:A' \
  'error \| build:B \| agent stopped: out of memory'
if [ $((t1 - t0)) -lt 15 ]; then ok "wait-milestone: woke in $((t1 - t0)) s, not at the 30 s timer"; else ko "wait-milestone: took $((t1 - t0)) s"; fi

# ---- sweep-owners.py (git runs only in throw-away repos inside $TMP) ----
if ! command -v git >/dev/null 2>&1; then
  skip "sweep-owners: git not found"
else
  SW="$TOOLS/sweep-owners.py"
  R="$TMP/repo"
  new_repo "$R"
  mkdir -p "$R/lib" "$R/test/t"
  for f in lib/a.dart lib/b.dart lib/keep.dart test/t/one_test.dart; do printf 'x\n' >"$R/$f"; done
  git -C "$R" add -A && git -C "$R" commit -qm init
  printf 'y\n' >"$R/lib/a.dart"
  rm "$R/lib/b.dart"
  printf 'new\n' >"$R/lib/c.dart"
  printf 'new\n' >"$R/lib/stray.dart"
  printf 'new\n' >"$R/lib/space name.dart"
  printf 'new\n' >"$R/test/t/two_test.dart"
  # The wave journal gets one broken line, as a journal cut by a crash would have.
  WAVE="$TMP/wave.jsonl"
  { head -n 4 "$FIX/journal-wave.jsonl"; echo "not a json line"; tail -n +5 "$FIX/journal-wave.jsonl"; } >"$WAVE"
  git -C "$R" status >/dev/null # settle the index once, so only the sweep could change it from here
  before_sum=$(digest "$R/.git/index" "$WAVE")
  before_status=$(GIT_OPTIONAL_LOCKS=0 git -C "$R" status --porcelain --untracked-files=all)

  run python3 -I "$SW"
  expect "sweep-owners: no journal gives a usage line" 2 '^usage: python3 -I sweep-owners.py'
  run python3 -I "$SW" --repo "$TMP/bin" "$WAVE"
  expect "sweep-owners: refuses a folder outside git" 2 'not inside a git work tree'
  run python3 -I "$SW" --repo "$R" "$TMP/missing.jsonl"
  expect "sweep-owners: refuses a journal it cannot read" 2 'cannot read'
  run python3 -I "$SW" --repo "$R" "$WAVE"
  expect "sweep-owners: a wave with a stray file and a double claim fails" 1 \
    'changed paths: 6' 'agent results: 3 · unreadable lines: 1' \
    'UNCLAIMED \(changed, no agent names it\): 1' '^ +\?\? lib/stray.dart$' \
    'CLAIMED BY MORE THAN ONE AGENT: 1' 'lib/a.dart <- build:A, build:B +\[same run: a conflict\]' \
    'TOUCHED OUTSIDE THEIR LIST: 1' 'lib/keep.dart <- build:B' \
    'claimed but not changed.*: 2' '!lib/c.dart' '!lib/space name.dart' '!test/t/two_test.dart'
  after_sum=$(digest "$R/.git/index" "$WAVE")
  after_status=$(GIT_OPTIONAL_LOCKS=0 git -C "$R" status --porcelain --untracked-files=all)
  if [ "$before_status" = "$after_status" ] && [ "$before_sum" = "$after_sum" ]; then
    ok "sweep-owners: read-only (tree, index and journal unchanged)"
  else
    ko "sweep-owners: something changed during the sweep"
  fi
  R2="$TMP/repo2"
  new_repo "$R2"
  printf 'x\n' >"$R2/a.dart" && git -C "$R2" add -A && git -C "$R2" commit -qm init
  printf 'y\n' >"$R2/a.dart"
  printf '%s\n' '{"type":"started","agentId":"x","label":"build:X"}' \
    '{"type":"result","agentId":"x","result":{"files_changed":["./a.dart"],"files_created":[],"files_deleted":[],"touched_outside_list":[]}}' \
    >"$TMP/clean.jsonl"
  run python3 -I "$SW" --repo "$R2" "$TMP/clean.jsonl"
  expect "sweep-owners: a clean wave passes" 0 'UNCLAIMED.*: 0' 'CLAIMED BY MORE THAN ONE AGENT: 0' 'claimed but not changed.*: 0'
  # Without --repo and APP_DIR, the sweep takes the app the way the bash tools do: tools.env beside it, else two
  # folders up, never the folder it was started from.
  R4="$TMP/mono4"
  new_repo "$R4"
  mkdir -p "$R4/apps/mobile/scripts/tools" "$R4/apps/mobile/lib" "$R4/other"
  cp "$SW" "$TOOLS/tools.env" "$R4/apps/mobile/scripts/tools/"
  printf 'x\n' >"$R4/apps/mobile/lib/x.dart" && printf 'x\n' >"$R4/other/y.dart"
  git -C "$R4" add -A && git -C "$R4" commit -qm init
  printf 'y\n' >"$R4/apps/mobile/lib/x.dart" && printf 'y\n' >"$R4/other/y.dart"
  printf '%s\n' '{"type":"result","agentId":"w","result":{"id":"W","files_changed":["lib/x.dart"]}}' >"$TMP/mobile.jsonl"
  (cd "$R4" && env -u APP_DIR python3 -I apps/mobile/scripts/tools/sweep-owners.py "$TMP/mobile.jsonl" >"$TMP/sw4.out" 2>&1)
  code=$?
  out=$(cat "$TMP/sw4.out")
  expect "sweep-owners: with the kit's tools.env, the app two folders above the script" 0 \
    'repo: .*/mono4/apps/mobile · changed paths: 1' 'UNCLAIMED.*: 0' '!other/y.dart'
fi

echo
echo "tools: $pass passed, $failed failed"
[ "$failed" -eq 0 ]
