#!/usr/bin/env bash
# Tests for install.mjs: runs it on throw-away app folders, then checks what it wrote, what it skipped, the
# placeholders it filled, the .gitignore lines it added and its exit codes. The --with-boilerplate cases run a copy
# of the installer in a fake kit whose boilerplate is a small fixture, so they never depend on the real one.
# Works from any directory; writes only inside a mktemp -d folder, which it removes. Never runs flutter or dart.
# Exits 0 only when every case passes. KIT_STRICT=1 also fails on kit parts that other packages have not written.
set -u

if [ "$#" -ne 0 ]; then
  echo "usage: $0   (runs every install case)" >&2
  exit 2
fi
command -v node >/dev/null 2>&1 || { echo "install: node not found" >&2; exit 1; }

HERE="$(cd "$(dirname "$0")" && pwd)"
KIT="$(cd "$HERE/../.." && pwd)"
INSTALL="$KIT/install.mjs"
FIX="$HERE/fixtures"
T="$(mktemp -d)"
trap 'chmod -R u+rwx "$T" 2>/dev/null; rm -rf "$T"' EXIT
export PYTHONDONTWRITEBYTECODE=1
unset CLAUDE_PROJECT_DIR DEVICE_WRITE_OK

pass=0
fail=0
notes=0
ok() { pass=$((pass + 1)); echo "ok   $1"; }
bad() { fail=$((fail + 1)); echo "FAIL $1"; [ -s "$T/out" ] && sed 's/^/     | /' "$T/out" | head -15; }
note() { notes=$((notes + 1)); echo "note $1"; }
# check <name> <command...>: passes when the command succeeds.
check() {
  local name=$1
  shift
  if "$@"; then ok "$name"; else bad "$name"; fi
}
# soft <name> <command...>: a check on parts other packages write: a note unless KIT_STRICT=1.
soft() {
  local name=$1
  shift
  if "$@" >"$T/soft" 2>&1; then ok "$name"
  elif [ "${KIT_STRICT:-0}" = 1 ]; then bad "$name"; sed 's/^/     | /' "$T/soft" | head -15
  else note "$name: $(tr '\n' ' ' <"$T/soft" | cut -c1-300)"; fi
}
# run <args...>: runs the installer from an unrelated folder; output in $T/out, exit code in $CODE.
run() {
  (cd "$T" && node "$INSTALL" "$@") >"$T/out" 2>&1
  CODE=$?
}
code_is() { [ "$CODE" -eq "$1" ]; }
has() { grep -qF -- "$1" "$T/out"; }
lacks() { ! grep -qF -- "$1" "$T/out"; }
# new_app <folder> [pubspec name]: a folder that looks like a fresh flutter create app; sets P.
new_app() {
  P="$T/$1"
  mkdir -p "$P/lib" "$P/test" "$P/android/app/src/main/res/values" "$P/android/app/src/main/res/values-night"
  printf 'name: %s\ndescription: "A new Flutter project."\nversion: 1.0.0+1\n' "${2:-orders_app}" >"$P/pubspec.yaml"
  cp "$FIX/create/main.dart.txt" "$P/lib/main.dart"
  cp "$FIX/create/widget_test.dart.txt" "$P/test/widget_test.dart"
  cp "$FIX/create/styles.xml" "$P/android/app/src/main/res/values/styles.xml"
  cp "$FIX/create/styles.xml" "$P/android/app/src/main/res/values-night/styles.xml"
  cp "$FIX/create/analysis_options.yaml" "$P/analysis_options.yaml"
  cp "$FIX/create/gitignore" "$P/.gitignore"
  cp "$FIX/create/gradle.properties" "$P/android/gradle.properties"
}
# sums <dir>: one line per file or link, with its checksum, to compare a tree before and after.
sums() {
  (cd "$1" && find . -type f -o -type l | LC_ALL=C sort | while read -r f; do
    if [ -L "$f" ]; then echo "$f link"; else echo "$f $(cksum <"$f")"; fi
  done)
}
files_of() { (cd "$1" && find . -type f | sed 's|^\./||' | LC_ALL=C sort); }
# The files a fresh install must create: every template but the boilerplate (and analysis_options.yaml, which a
# flutter create app has), every skill as a playbook, runs/.gitignore and .gitattributes.
expected_files() {
  (cd "$KIT/templates" && find . -type f ! -name '*.pyc' ! -name .DS_Store ! -path './boilerplate/*' \
    ! -path './analysis_options.yaml' ! -path '*/.dart_tool/*' | sed 's|^\./||')
  if [ -d "$KIT/skills" ]; then (cd "$KIT/skills" && find . -type f ! -name '*.pyc' ! -name .DS_Store | sed 's|^\./|docs/playbooks/|'); fi
  printf '%s\n' runs/.gitignore .gitattributes
}
CR="$(printf '\r')"
# lf_only <dir>: every .sh, .env, .py and .mjs file under it has LF line endings.
lf_only() {
  local f bad=0
  while IFS= read -r f; do
    if grep -q "$CR" "$f"; then echo "CRLF left in: ${f#"$1"/}"; bad=1; fi
  done < <(find "$1" -type f \( -name '*.sh' -o -name '*.env' -o -name '*.py' -o -name '*.mjs' \))
  return "$bad"
}
no_placeholder_left() { ! grep -rqE '\{\{(PROJECT_NAME|TODAY)\}\}' "$1"; }
# Every template without a placeholder lands byte for byte.
templates_unchanged() {
  local f
  for f in $(cd "$KIT/templates" && grep -rLE '\{\{[A-Z_]+\}\}' . | grep -v -e '^\./boilerplate/' -e '^\./analysis_options.yaml$'); do
    case "$f" in *__pycache__* | *.pyc | */.dart_tool/*) continue ;; esac
    cmp -s "$KIT/templates/$f" "$1/$f" || { echo "differs: $f"; return 1; }
  done
}
# kit_source <app path>: where the kit holds what the installer copies to that path.
kit_source() {
  case "$1" in
    docs/playbooks/*) echo "$KIT/skills/${1#docs/playbooks/}" ;;
    *) echo "$KIT/templates/$1" ;;
  esac
}
# Every path AGENTS.md and CLAUDE.md name in backticks exists after a full install, when the kit holds it.
# installed_what_the_kit_has fails on an installer bug; named_parts_in_kit reports what the kit still lacks.
named_paths() { grep -ohE '`(docs|scripts|tool|\.claude)/[A-Za-z0-9_./-]+`' "$1/AGENTS.md" "$1/CLAUDE.md" | tr -d '`' | sort -u; }
installed_what_the_kit_has() {
  local p missing=0
  for p in $(named_paths "$1"); do
    if [ -e "$(kit_source "$p")" ] && [ ! -e "$1/$p" ]; then echo "in the kit but not installed: $p"; missing=1; fi
  done
  return "$missing"
}
named_parts_in_kit() {
  local p missing=0
  for p in $(named_paths "$1"); do
    [ -e "$(kit_source "$p")" ] || { echo "named in AGENTS.md or CLAUDE.md, not in the kit yet: $p"; missing=1; }
  done
  return "$missing"
}
# Each tool keeps the kit's execute bit.
same_exec_bits() {
  local f name
  for f in "$KIT"/templates/scripts/tools/*; do
    [ -f "$f" ] || continue
    name="${f##*/}"
    if [ -x "$f" ] && [ ! -x "$1/scripts/tools/$name" ]; then echo "lost its execute bit: $name"; return 1; fi
    if [ ! -x "$f" ] && [ -x "$1/scripts/tools/$name" ]; then echo "gained an execute bit: $name"; return 1; fi
  done
  [ -x "$1/scripts/tools/q-test.sh" ]
}
# The guard hook, run as Claude Code runs it, on a command in the installed app.
guard() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"},"cwd":"%s"}' "$2" "$1" | CLAUDE_PROJECT_DIR="$1" node "$KIT/hooks/guard-bash.mjs"; }

echo "== arguments"
check "install.mjs parses" node --check "$INSTALL"
check "no child_process: no shell commands, the same on every system" bash -c '! grep -q child_process "$1"' _ "$INSTALL"
run --help
check "--help: exit 0 and the usage line" eval 'code_is 0 && has "usage: node install.mjs"'
run
check "no folder: exit 2 and the usage line" eval 'code_is 2 && has "usage: node install.mjs"'
run "$T/nowhere"
check "a missing folder: exit 2" eval 'code_is 2 && has "not a folder"'
new_app args-app
sums "$P" >"$T/before"
run "$P" --frobnicate
check "an unknown option: exit 2" eval 'code_is 2 && has "unknown option"'
run "$P" "$P"
check "two folders: exit 2" code_is 2
check "wrong arguments write nothing" eval 'sums "$P" | cmp -s "$T/before" -'
mkdir -p "$T/not-flutter/lib"
run "$T/not-flutter"
check "no pubspec.yaml: refused, exit 2, with the flutter create hint" eval 'code_is 2 && has "no pubspec.yaml" && has "flutter create"'
check "...and writes nothing" test "$(ls -A "$T/not-flutter")" = "lib"
listing() { ls -A "$KIT" "$KIT/templates"; }
before="$(listing)"
run "$KIT"
check "the kit itself is refused: exit 2" eval 'code_is 2 && has "refused"'
run "$KIT/templates"
check "a folder inside the kit is refused: exit 2" eval 'code_is 2 && has "refused"'
check "a refusal writes nothing in the kit" test "$before" = "$(listing)"

echo "== a fresh install"
new_app fresh-app orders_app
files_of "$P" >"$T/base"
day1="$(date +%F)"
run "$P"
day2="$(date +%F)"
check "exit 0" code_is 0
expected_files | LC_ALL=C sort >"$T/expected"
files_of "$P" | LC_ALL=C comm -13 "$T/base" - >"$T/got"
check "creates exactly the templates, the playbooks, runs/.gitignore and .gitattributes" cmp -s "$T/expected" "$T/got"
check "the summary counts them" has "$(wc -l <"$T/expected" | tr -d ' ') created, 0 skipped"
check "names the project by its pubspec name, not its folder" has "project name: orders_app"
check "AGENTS.md: the project name" grep -qx '# orders_app' "$P/AGENTS.md"
check "CLAUDE.md: line 1 imports AGENTS.md" test "$(head -1 "$P/CLAUDE.md")" = "@AGENTS.md"
check "CLAUDE.md: the project name" grep -q '^# Claude Code notes for orders_app$' "$P/CLAUDE.md"
check "{{PURPOSE}} is left for the owner, and the next steps name it" eval 'grep -q "{{PURPOSE}}" "$P/AGENTS.md" && has "where {{PURPOSE}} stands: AGENTS.md"'
check "no other placeholder is left anywhere" no_placeholder_left "$P"
if grep -rq '{{TODAY}}' "$KIT/templates" 2>/dev/null; then
  check "{{TODAY}} became today's date" grep -rqE "$day1|$day2" "$P/docs"
fi
check "templates without placeholders land byte for byte" templates_unchanged "$P"
if [ -d "$KIT/skills" ]; then check "playbooks are the skills, byte for byte" diff -r "$KIT/skills" "$P/docs/playbooks"; fi
check "the tools keep the kit's execute bits" same_exec_bits "$P"
check "runs/ ignores itself in git" grep -qx '\*' "$P/runs/.gitignore"
check ".gitattributes keeps the scripts LF" eval 'for l in "*.sh text eol=lf" "*.py text eol=lf" "*.mjs text eol=lf" "*.dart text eol=lf" "scripts/tools/tools.env text eol=lf"; do grep -qxF "$l" "$P/.gitattributes" || exit 1; done'
check ".gitignore keeps its own lines" eval 'head -n "$(wc -l <"$FIX/create/gitignore")" "$P/.gitignore" | cmp -s "$FIX/create/gitignore" -'
check ".gitignore gains the missing lines" eval 'for l in "runs/" "claude-chats/" "assets/.env" "!assets/.env.example" "android/key.properties" "*.jks" "*.keystore"; do grep -qxF "$l" "$P/.gitignore" || exit 1; done'
check "...but not build/symbols/, which /build/ already covers" eval '! grep -qxF "build/symbols/" "$P/.gitignore"'
check "the flutter create analysis_options.yaml is kept" cmp -s "$FIX/create/analysis_options.yaml" "$P/analysis_options.yaml"
if [ -f "$KIT/templates/analysis_options.yaml" ]; then
  check "...with a note: the flutter create default, replace it with the kit's" has "analysis_options.yaml is the flutter create default"
fi
check "the demo main.dart is untouched without --with-boilerplate" cmp -s "$FIX/create/main.dart.txt" "$P/lib/main.dart"
check "prints the next steps" has "Next steps:"
check "every path AGENTS.md and CLAUDE.md name, when the kit holds it, is installed" installed_what_the_kit_has "$P"
soft "every path AGENTS.md and CLAUDE.md name is in the kit" named_parts_in_kit "$P"
soft "AGENTS.md lists a playbook for every skill" bash -c 'for s in "$2"/skills/*/; do [ -d "$s" ] || continue; s=${s%/}; grep -qF "docs/playbooks/${s##*/}/SKILL.md" "$1/AGENTS.md" || { echo "no row: ${s##*/}"; exit 1; }; done' _ "$P" "$KIT"

echo "== the installed tools and the guard read the installed files"
check "lib.sh takes the app as APP_DIR" test "$(bash -c 'unset APP_DIR; . "$1/scripts/tools/lib.sh" && echo "$APP_DIR"' _ "$P")" = "$P"
check "q-test.sh refuses a folder with exit 2" bash -c '"$1/scripts/tools/q-test.sh" test >/dev/null 2>&1; [ $? -eq 2 ]' _ "$P"
guard "$P" "adb uninstall com.example.app" >"$T/out" 2>&1
check "the guard reads DEVICE_WRITE_OK=0 from the installed tools.env: denied" has '"permissionDecision":"deny"'
sed 's/DEVICE_WRITE_OK:=0/DEVICE_WRITE_OK:=1/' "$P/scripts/tools/tools.env" >"$T/tools.env" && cat "$T/tools.env" >"$P/scripts/tools/tools.env"
guard "$P" "adb uninstall com.example.app" >"$T/out" 2>&1
check "...and DEVICE_WRITE_OK=1 there: allowed, with a warning" eval 'lacks "permissionDecision" && has "DEVICE_WRITE_OK=1"'

echo "== a second run changes nothing"
sums "$P" >"$T/before"
run "$P"
check "exit 0" code_is 0
check "creates nothing" grep -q '^0 created, ' "$T/out"
check "lists what it skipped" has "skipped  AGENTS.md (already exists"
check "no file changed, .gitignore included" eval 'sums "$P" | cmp -s "$T/before" -'
check "no merge note for the kit's own AGENTS.md" lacks "merge the kit's rules"
check "no import note for the kit's own CLAUDE.md" lacks "add the line @AGENTS.md"
check "no warning for the .gitattributes it wrote" lacks "lacks these lines"
check "no .gitignore line added twice" lacks "added to .gitignore"

echo "== never overwrites"
new_app own-app
printf '# Our own rules\n' >"$P/AGENTS.md"
printf '# Our notes\n' >"$P/CLAUDE.md"
mkdir -p "$P/docs"
printf 'keep me\n' >"$P/docs/RULES.md"
ln -s "$T/link-target" "$P/docs/HANDOFF.md"
printf '*.png binary\n*.sh text eol=lf\n' >"$P/.gitattributes"
printf 'include: package:flutter_lints/flutter.yaml\nanalyzer:\n  language:\n    strict-casts: true\n' >"$P/analysis_options.yaml"
printf 'build/\nruns' >"$P/.gitignore"
run "$P"
check "exit 0" code_is 0
check "an existing AGENTS.md is kept" test "$(cat "$P/AGENTS.md")" = "# Our own rules"
check "an existing CLAUDE.md is kept" test "$(cat "$P/CLAUDE.md")" = "# Our notes"
check "an existing docs/RULES.md is kept" test "$(cat "$P/docs/RULES.md")" = "keep me"
check "a dangling link is left as it is" test -L "$P/docs/HANDOFF.md"
check "the link is never followed" test ! -e "$T/link-target"
check "reports each skipped file" eval 'has "skipped  AGENTS.md" && has "skipped  docs/RULES.md" && has "skipped  docs/HANDOFF.md"'
check "asks to merge an AGENTS.md that lacks the kit's rules" has "merge the kit's rules into it by hand"
check "asks to import AGENTS.md from an existing CLAUDE.md" has "add the line @AGENTS.md"
check "still installs the rest" test -f "$P/scripts/tools/q-test.sh"
check "an existing .gitattributes is kept" test "$(cat "$P/.gitattributes")" = "$(printf '*.png binary\n*.sh text eol=lf')"
check "...and a warning names only the lines it lacks" eval 'has "      *.py text eol=lf" && has "      *.dart text eol=lf" && lacks "      *.sh text eol=lf"'
check "a customized analysis_options.yaml is kept" grep -q 'strict-casts: true' "$P/analysis_options.yaml"
check "...with a note to merge the kit's sections by hand" has "merge the kit's analyzer and linter sections"
check ".gitignore without a final newline: its last line stays whole" eval 'grep -qx "runs" "$P/.gitignore" && grep -qx "claude-chats/" "$P/.gitignore"'
check "...and runs (written without a slash) counts as runs/" eval '! grep -qx "runs/" "$P/.gitignore"'
new_app covered-app
printf '/runs/\nclaude-chats\n.env\n!assets/.env.example\nkey.properties\n**/*.jks\n**/*.keystore\n/build\n' >"$P/.gitignore"
printf '* text=auto eol=lf\n' >"$P/.gitattributes"
run "$P"
check "no .gitignore or .gitattributes change when they already hold the lines, in other forms" eval 'code_is 0 && lacks "added to .gitignore" && lacks "lacks these lines"'
new_app no-ignore-app
rm "$P/.gitignore"
run "$P"
check "no .gitignore: one is written with the lines" eval 'code_is 0 && grep -qx "runs/" "$P/.gitignore" && head -1 "$P/.gitignore" | grep -q "^# Added by perfect-vibecoding-rules-flutter"'
new_app import-app
printf '@AGENTS.md\n\n# Our notes\n' >"$P/CLAUDE.md"
run "$P"
check "no import note when CLAUDE.md already imports AGENTS.md" eval 'code_is 0 && lacks "add the line @AGENTS.md"'
if [ -f "$KIT/templates/analysis_options.yaml" ]; then
  new_app kit-lints-app
  cp "$KIT/templates/analysis_options.yaml" "$P/analysis_options.yaml"
  run "$P"
  check "the kit's own analysis_options.yaml: skipped, with no merge note" eval 'code_is 0 && has "skipped  analysis_options.yaml" && lacks "merge the kit'"'"'s analyzer" && lacks "flutter create default"'
fi

echo "== options and odd folders"
new_app plugin-app
run "$P" --no-playbooks
check "--no-playbooks: exit 0" code_is 0
check "--no-playbooks: no docs/playbooks/" test ! -e "$P/docs/playbooks"
check "--no-playbooks: AGENTS.md and CLAUDE.md still there" test -f "$P/AGENTS.md" -a -f "$P/CLAUDE.md"
check "--no-playbooks: the next steps name the plugin command" has "/perfect-vibecoding-rules-flutter:new-project"
new_app dry-app
sums "$P" >"$T/before"
run "$P" --dry-run
check "--dry-run: exit 0 and the plan" eval 'code_is 0 && has "would create  AGENTS.md" && has "would add to .gitignore: runs/"'
check "--dry-run: writes nothing" eval 'sums "$P" | cmp -s "$T/before" -'
new_app full-runs-app
mkdir -p "$P/runs/old"
printf 'log\n' >"$P/runs/old/log.txt"
run "$P"
check "a runs/ that holds files gets no runs/.gitignore" test ! -e "$P/runs/.gitignore"
check "...and a warning instead" has "runs/ already holds files"
new_app empty-runs-app
mkdir -p "$P/runs"
run "$P"
check "an empty runs/ gets its .gitignore" test -f "$P/runs/.gitignore"
new_app "spaced name app" spaced_app
run "$P"
check "a folder name with spaces" eval 'code_is 0 && grep -qx "# spaced_app" "$P/AGENTS.md"'
new_app rel-app
(cd "$T" && node "$INSTALL" rel-app) >"$T/out" 2>&1
check "a relative folder works" test -f "$T/rel-app/AGENTS.md"
new_app blocked-app
printf 'a file\n' >"$P/scripts"
run "$P"
check "a file where scripts/ must go: exit 1, FAILED lines" eval 'code_is 1 && has "FAILED   scripts/tools/lib.sh"'
check "...and the rest still installed" test -f "$P/AGENTS.md"

echo "== a Windows clone of the kit (CRLF line endings)"
WK="$T/kit-crlf"
mkdir -p "$WK/skills"
cp "$INSTALL" "$WK/install.mjs"
cp -R "$KIT/templates" "$WK/templates"
rm -rf "$WK/templates/boilerplate"
# What a Windows checkout without .gitattributes holds: every text file with CRLF.
find "$WK/templates" -type f \( -name '*.sh' -o -name '*.env' -o -name '*.py' -o -name '*.mjs' -o -name '*.md' \) -print0 |
  xargs -0 node -e 'const fs = require("fs"); for (const f of process.argv.slice(1)) fs.writeFileSync(f, fs.readFileSync(f, "utf8").replace(/\r?\n/g, "\r\n"));'
check "the copy really holds CRLF" grep -q "$CR" "$WK/templates/scripts/tools/lib.sh"
new_app crlf-app
(cd "$T" && node "$WK/install.mjs" "$P" --no-playbooks) >"$T/out" 2>&1
CODE=$?
check "exit 0" code_is 0
check ".sh, .env, .py and .mjs files land with LF line endings" lf_only "$P"
check "the tools run: q-test.sh prints its usage and exits 2" bash -c '"$1/scripts/tools/q-test.sh" >"$2" 2>&1; [ $? -eq 2 ] && grep -qi usage "$2" && ! grep -q "command not found" "$2"' _ "$P" "$T/tool-out"
check "the tools keep their execute bits" test -x "$P/scripts/tools/q-build.sh"

echo "== --with-boilerplate (a fake kit with a fixture boilerplate)"
FK="$T/kit-fake"
mkdir -p "$FK/skills"
cp "$INSTALL" "$FK/install.mjs"
cp -R "$KIT/templates" "$FK/templates"
rm -rf "$FK/templates/boilerplate"
cp -R "$FIX/boilerplate" "$FK/templates/boilerplate"
find "$FK/templates/boilerplate" -name '*.dart.txt' | while IFS= read -r f; do mv "$f" "${f%.txt}"; done
fake() { (cd "$T" && node "$FK/install.mjs" "$@") >"$T/out" 2>&1; CODE=$?; }
new_app bp-app orders_app
sums "$P" >"$T/before"
fake "$P" --with-boilerplate --dry-run
check "--dry-run: names the demo files it would replace, writes nothing" eval 'code_is 0 && has "would replace  lib/main.dart" && sums "$P" | cmp -s "$T/before" -'
fake "$P" --with-boilerplate
BK="$(ls -d "$P"/runs/kit-install/*/ 2>/dev/null | head -n 1)"
check "exit 0" code_is 0
check "lib/main.dart is the boilerplate's, imports renamed to the app's package" grep -qx "import 'package:orders_app/core/app.dart';" "$P/lib/main.dart"
check "...and the tests' imports too" grep -qx "import 'package:orders_app/core/app.dart';" "$P/test/core/app_test.dart"
check "no kit_app import is left" bash -c '! grep -rq "package:kit_app/" "$1/lib" "$1/test"' _ "$P"
check "the demo main.dart moved to runs/kit-install/, whole" cmp -s "$FIX/create/main.dart.txt" "${BK}lib/main.dart"
check "the demo widget test moved there too (it cannot compile any more)" eval 'test ! -e "$P/test/widget_test.dart" && cmp -s "$FIX/create/widget_test.dart.txt" "${BK}test/widget_test.dart"'
check "the demo styles.xml is replaced, and kept in the backup" eval 'grep -q "kit: edge to edge" "$P/android/app/src/main/res/values/styles.xml" && cmp -s "$FIX/create/styles.xml" "${BK}android/app/src/main/res/values/styles.xml"'
check "an android/res/ path lands under android/app/src/main/res/" grep -q "kit: Android 12 splash" "$P/android/app/src/main/res/values-v31/styles.xml"
check "a demo file without a boilerplate twin stays" cmp -s "$FIX/create/styles.xml" "$P/android/app/src/main/res/values-night/styles.xml"
check "l10n.yaml and assets/.env.example land" test -f "$P/l10n.yaml" -a -f "$P/assets/.env.example"
check "gradle.properties is offered, never copied" eval 'cmp -s "$FIX/create/gradle.properties" "$P/android/gradle.properties" && has "8 GB Gradle heap"'
check "the pubspec fragment is printed to merge by hand, never copied" eval 'has "Merge into pubspec.yaml by hand" && has "go_router: ^18.1.1" && test ! -e "$P/pubspec.fragment.yaml"'
check "the boilerplate's README stays in the kit" bash -c '! grep -rqs "Fake boilerplate" "$1" --include=README.md' _ "$P"
check "the output names each replaced file" has "replaced  lib/main.dart (the flutter create demo moves to runs/kit-install/"
check "the next steps sort the renamed imports and list the iOS languages" \
  eval 'has "dart fix --apply --code=directives_ordering and dart format lib test" && has "CFBundleLocalizations"'
sums "$P" >"$T/before"
fake "$P" --with-boilerplate
check "a second --with-boilerplate run is refused: lib/ is not fresh any more" eval 'code_is 2 && has "only for a fresh app"'
check "...and writes nothing" eval 'sums "$P" | cmp -s "$T/before" -'
new_app own-main-app
printf 'void main() {}\n' >"$P/lib/main.dart"
fake "$P" --with-boilerplate
check "a main.dart that is not the demo is kept, with a note" eval 'code_is 0 && test "$(cat "$P/lib/main.dart")" = "void main() {}" && has "lib/main.dart is not the flutter create demo any more"'
rm -rf "$FK/templates/boilerplate" "$FK/templates/CLAUDE.md" "$FK/templates/docs/CHANGELOG.md"
new_app no-bp-app
fake "$P" --with-boilerplate
check "a kit without a boilerplate refuses --with-boilerplate" eval 'code_is 2 && has "no templates/boilerplate/"'
fake "$P"
check "a kit part that is missing is named, never an error" eval 'code_is 0 && has "this kit has no templates/CLAUDE.md yet"'
check "...the changelog the release steps write to as well" has "this kit has no templates/docs/CHANGELOG.md yet"

echo
echo "install: $pass passed, $fail failed, $notes note(s) on parts other packages write"
[ "$fail" -eq 0 ]
