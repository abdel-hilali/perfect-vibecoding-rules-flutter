#!/usr/bin/env bash
# Stands in for flutter in the tests: prints what it was asked to run and where, then exits with STUB_EXIT
# (or 1 when STUB_FAIL_ON names this subcommand).
# STUB_STARTED=<file>: marks the start, for a test that must look while the job runs.
if [ -n "${STUB_STARTED:-}" ]; then : >"$STUB_STARTED"; fi
echo "stub-flutter: $*"
echo "stub-cwd: $(pwd)"
case "${1:-}" in
  analyze) echo "No issues found! (ran in 0.1s)" ;;
  # STUB_TEST_LINE: the summary line a test run ends with.
  test) echo "${STUB_TEST_LINE:-00:01 +2: All tests passed!}" ;;
  build)
    # STUB_IPA_LINE: the line an older Flutter prints instead ("Built IPA to <absolute path>.").
    if [ "${2:-}" = ipa ]; then echo "${STUB_IPA_LINE:-Built IPA to build/ios/ipa (12.3MB)}"; else echo "Built build/app/outputs/flutter-apk/app-release.apk (20.1MB)"; fi
    ;;
esac
n=${STUB_LINES:-0}
i=1
while [ "$i" -le "$n" ]; do
  echo "stub line $i"
  i=$((i + 1))
done
if [ -n "${STUB_SLEEP:-}" ]; then sleep "$STUB_SLEEP"; fi
# A daemon, as Gradle starts one: it outlives the job, with its own stdio.
if [ -n "${STUB_DAEMON:-}" ]; then
  sleep 30 >/dev/null 2>&1 </dev/null &
  echo $! >"$STUB_DAEMON"
fi
if [ "${STUB_FAIL_ON:-}" = "${1:-}" ]; then exit 1; fi
exit "${STUB_EXIT:-0}"
