#!/usr/bin/env bash
# Runs `flutter build <target> [options]` alone in the queue: no other queued job runs beside it. A release build
# starts Gradle and the Kotlin daemon (several GB for minutes); beside an analyzer or a test run it can freeze the
# machine. The full output goes to a log in RUNS_DIR/build/; the screen gets its last 30 lines, the artifact path
# and the exit code. It adds --dart-define=APP_VERSION=<the build's version: pubspec.yaml's, or --build-name and
# --build-number> unless the caller defines APP_VERSION: the app sends it as X-App-Version, so a build never
# reports another version than its own.
# usage: q-build.sh <target> [flutter build options ...]   (targets: apk appbundle ipa ios web linux macos windows aar)
set -u
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"

usage() {
  echo "usage: q-build.sh <target> [flutter build options ...]" >&2
  echo "       (targets: apk appbundle ipa ios web linux macos windows aar ios-framework macos-framework)" >&2
  exit 2
}
# app_version [flutter build options ...]: prints the build's version (pubspec.yaml's, with --build-name and
# --build-number in its place when given), or nothing when the options define APP_VERSION already (on the
# command line, or in a --dart-define-from-file file, which a define would override) or no version is known.
app_version() {
  local prev="" a file name="" number="" v
  for a in "$@"; do
    case "$a" in
      --dart-define=APP_VERSION=*) return 0 ;;
      --build-name=*) name=${a#*=} ;;
      --build-number=*) number=${a#*=} ;;
    esac
    file=""
    case "$prev" in
      --dart-define) case "$a" in APP_VERSION=*) return 0 ;; esac ;;
      --build-name) name=$a ;;
      --build-number) number=$a ;;
      --dart-define-from-file) file=$a ;;
    esac
    case "$a" in --dart-define-from-file=*) file=${a#*=} ;; esac
    if [ -n "$file" ]; then
      case "$file" in /*) ;; *) file="$APP_DIR/$file" ;; esac
      grep -q APP_VERSION "$file" 2>/dev/null && return 0
    fi
    prev=$a
  done
  v=$(sed -n "s/^version:[[:space:]]*[\"']\{0,1\}\([^\"'[:space:]#]*\).*/\1/p" "$APP_DIR/pubspec.yaml" | head -n 1)
  [ -n "$name" ] || name=${v%%+*}
  if [ -z "$number" ]; then case "$v" in *+*) number=${v#*+} ;; esac; fi
  [ -n "$name" ] || return 0
  if [ -n "$number" ]; then echo "$name+$number"; else echo "$name"; fi
}
[ $# -gt 0 ] || usage
target=$1
shift
case "$target" in
  apk | appbundle | ipa | ios | web | linux | macos | windows | aar | ios-framework | macos-framework) ;;
  *) echo "refused: '$target' is not a flutter build target" >&2; usage ;;
esac
if [ ! -f "$APP_DIR/pubspec.yaml" ]; then
  echo "q-build: APP_DIR '$APP_DIR' has no pubspec.yaml (set APP_DIR in scripts/tools/tools.env)" >&2
  exit 2
fi
mkdir -p "$RUNS_DIR/build" || { echo "q-build: cannot create $RUNS_DIR/build" >&2; exit 2; }
log="$RUNS_DIR/build/$(date +%Y%m%d-%H%M%S)-$target.log"

version=$(app_version "$@")
if [ -n "$version" ]; then
  set -- "--dart-define=APP_VERSION=$version" "$@"
  echo "q-build: --dart-define=APP_VERSION=$version (the build's version, sent as X-App-Version)"
fi
echo "q-build: flutter build $target, alone in the queue (a build takes several GB; a wait of minutes is normal)"
queue_line q-build
echo "q-build: full log in $log"
# $FLUTTER is split on purpose: "fvm flutter" is two words.
run_heavy "build $target" "$BUILD_MIN_FREE_MB" --alone -- $FLUTTER build "$target" "$@" >"$log" 2>&1
code=$?
tail -n 30 "$log"
# Flutter ends a build with "Built <path> (<size>)", or "Built IPA to <path>" (older versions add a final ".").
artifact=$(sed -n 's/.*Built \(IPA to \)\{0,1\}\([^ ]*\).*/\2/p' "$log" | tail -n 1)
artifact=${artifact%.}
if [ -z "$artifact" ]; then
  echo "artifact: none named in the log"
else
  case "$artifact" in /*) ;; *) artifact="$APP_DIR/$artifact" ;; esac
  echo "artifact: $artifact"
fi
echo "build exit: $code"
exit "$code"
