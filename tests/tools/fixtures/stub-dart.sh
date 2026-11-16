#!/usr/bin/env bash
# Stands in for dart in the tests: prints what it was asked to run and where.
echo "stub-dart: $*"
echo "stub-cwd: $(pwd)"
case "${1:-}" in
  format) echo "Formatted 3 files (0 changed) in 0.01 seconds." ;;
  run)
    # STUB_BUDGET: the test budget line a full check_structure run prints before its summary.
    if [ -n "${STUB_BUDGET:-}" ] && [ "${2##*/}" = check_structure.dart ]; then echo "$STUB_BUDGET"; fi
    echo "${2##*/}: 0 problems"
    ;;
esac
if [ "${STUB_FAIL_ON:-}" = "${1:-}" ]; then exit 1; fi
exit "${STUB_EXIT:-0}"
