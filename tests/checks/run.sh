#!/usr/bin/env bash
# Tests for the check scripts in templates/tool/kit/: check_structure.dart and check_l10n.dart, run with `dart run`
# on the fixture trees in fixtures/ (a small fake project with good and bad files for each rule; good and bad ARB
# sets) and on projects generated in a temporary folder (the default limits, config errors, modes).
# Works from any folder, needs Dart on the PATH but no network and no package, writes only inside a temporary
# folder, and exits 0 only when every case passes. Each `dart run` takes about a second and little memory.
set -u
if [ "$#" -gt 0 ]; then
  echo "usage: $0   (runs every checks case)" >&2
  exit 2
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
KIT="$(cd "$HERE/../.." && pwd)"
TOOL="$KIT/templates/tool/kit"
S="$TOOL/check_structure.dart"
L="$TOOL/check_l10n.dart"
FIX="$HERE/fixtures"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

if ! command -v dart >/dev/null 2>&1; then
  echo "dart is not on the PATH: install the Flutter or Dart SDK first"
  exit 1
fi
# Run from an empty folder: `dart run` next to a pubspec.yaml would resolve that package (and may reach the network).
cd "$TMP" || exit 1

pass=0
fail=0
OUT="$TMP/out"

ok() { pass=$((pass + 1)); printf '  ok   %s\n' "$1"; }
bad() { fail=$((fail + 1)); printf '  FAIL %s\n' "$1"; sed 's/^/       | /' "$OUT" | head -40; }

# expect NAME EXIT CMD...: runs CMD (output kept in $OUT) and checks its exit code.
expect() {
  local name="$1" want="$2"
  shift 2
  "$@" >"$OUT" 2>&1
  local got=$?
  if [ "$got" -eq "$want" ]; then ok "$name"; else bad "$name (exit $got, wanted $want)"; fi
}
# has NAME TEXT: the last output contains TEXT.  lacks NAME TEXT: it does not.
has() { if grep -qF -- "$2" "$OUT"; then ok "$1"; else bad "$1 (missing: $2)"; fi; }
lacks() { if grep -qF -- "$2" "$OUT"; then bad "$1 (unexpected: $2)"; else ok "$1"; fi; }
# lines NAME N: the last output has exactly N lines.
lines() {
  local n
  n=$(wc -l <"$OUT" | tr -d ' ')
  if [ "$n" -eq "$2" ]; then ok "$1"; else bad "$1 ($n lines, wanted $2)"; fi
}
# gen N FORMAT: N lines of FORMAT, %d replaced by the line's index.
gen() {
  local i=0
  while [ "$i" -lt "$1" ]; do
    printf "$2\n" "$i"
    i=$((i + 1))
  done
}

S_GOOD="$FIX/structure/good"
S_BAD="$FIX/structure/bad"

echo "== check_structure: the good project"
expect "good project passes" 0 dart run "$S" --root "$S_GOOD"
# 30 Dart files, 3 of them generated (firebase_options.dart, *.g.dart, lib/core/l10n/generated/): never checked.
has "pass line, generated files skipped" "check_structure: passed, 0 errors and 0 warnings in 27 files"

echo "== check_structure: the bad project (every rule)"
expect "bad project fails" 1 dart run "$S" --root "$S_BAD" --max-lines 0
# The good twin of each size file sits exactly on its limit, with braces in strings, nested block comments, raw and
# triple-quoted strings and comment lines inside: one line more fails, so each count is exact.
has "F1 function: one counted line over" "load has 13 counted lines (limit 12)"
has "F1 build: one counted line over" "build has 21 counted lines (limit 20)"
has "F1 file: one counted line over" "big_page.dart:1: F1-file: the file has 81 counted lines (limit 80)"
has "F1 test file: its own limit" "test/big_test.dart:1: F1-file: the file has 91 counted lines (limit 90)"
has "F1 test helper: a function limit" "test/big_test.dart:8: F1-function: check has"
has "F1 sizeExceptions: maxLines stops growth" "over the 85 of its sizeExceptions entry"
has "F1 sizeExceptions: stale entry" "stale_page.dart:1: F1-exception: warning: the file is within the F1 limits now"
has "F1 sizeExceptions: missing file" "sizeExceptions names lib/gone.dart, which does not exist"
has "F2 file directly in lib/" "lib/utils.dart:1: F2-folder: a file directly in lib/"
has "F2 folder outside core and features" "lib/helpers/ is outside lib/core/ and lib/features/"
has "F2 file directly in core/" "lib/core/constants.dart:1: F2-folder"
has "F2 core folder, once per folder" "lib/core/utils/ is not a core folder (coreFolders in tool/kit/kit_config.json) (2 files)"
has "F2 module suffix" "orders_di.dart:1: F2-suffix: files in core/config/injection-modules/ are <feature>_module.dart"
has "F2 loose file in a feature" "orders_api.dart:1: F2-folder: only orders_routes.dart sits directly in the feature folder"
has "F2 controllers folder from the config" "lib/features/orders/presentation/bloc/ is not a feature folder"
has "F2 datasource suffix" "files in data/datasources/ end with _datasource.dart"
has "F2 model suffix" "files in data/models/ end with _model.dart"
has "F2 repository impl suffix" "files in data/repositories/ end with _repository_impl.dart"
has "F2 repository suffix" "files in domain/repositories/ end with _repository.dart"
has "F2 entity without suffix" "entity files have no suffix"
has "F2 controller suffix" "files in presentation/controllers/ end with _controller.dart"
has "F2 page suffix" "orders_screen.dart:1: F2-suffix: files in presentation/pages/ end with _page.dart"
has "F2 use case class" "a use case file holds the one class named after it: class GetOrders"
has "F2 snake_case names" "file names are snake_case: order_details_page.dart"
has "F2 domain imports Flutter" "domain/ imports package:flutter/material.dart"
has "F2 domain imports data" "order_entity.dart:3: F2-import: domain/ imports lib/features/orders/data/models/order.dart"
has "F2 presentation imports data (package: import)" "presentation/ imports lib/features/orders/data/models/order.dart"
has "F2 another feature's internals" "imports lib/features/members/presentation/widgets/member_card.dart: another feature"
has "F8 Colors.red" "orders_screen.dart:17: F8-color: Colors.red outside lib/core/theme/"
has "F8 Color(0x...)" "F8-color: Color(0xFF00FF00)"
has "F8 Color.fromARGB" "F8-color: Color.fromARGB"
has "F8 Color.fromRGBO" "F8-color: Color.fromRGBO"
has "F10 raw Icon(Icons.x)" "orders_screen.dart:21: F10-icon: Icon(Icons.add)"
has "F10 raw SvgPicture" "orders_screen.dart:22: F10-icon: SvgPicture"
has "F11 literal Text, a warning" 'F11-text: warning: literal text "Hello orders" in Text()'
has "F11 hintText" '"Search orders" in hintText'
has "F11 tooltip" '"More" in tooltip'
has "F12 widget helper, a warning" "F12-helper: warning: _buildHeader returns a widget"
has "summary with counts per rule" "check_structure: FAILED, 32 errors and 6 warnings in 25 files [F1-file 3, F1-function 2"
lacks "no finding from the good twin's tricky strings" "orders_page.dart"

echo "== check_structure: output cap, --json, --files, --strict, --config"
expect "capped output still fails" 1 dart run "$S" --root "$S_BAD" --max-lines 3
lines "3 findings, the 'more' line, the budget line and the summary" 6
has "the 'more' line" "... 35 more findings not shown (--max-lines 0 shows all; --files narrows the run)"
expect "--json fails the same way" 1 dart run "$S" --root "$S_BAD" --json
if command -v python3 >/dev/null 2>&1; then
  cp "$OUT" "$TMP/json" # expect rewrites $OUT, so python3 reads a copy
  expect "--json is valid JSON with the counts" 0 python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
assert d["tool"] == "check_structure" and d["passed"] is False, d
assert d["errors"] == 32 and d["warnings"] == 6 and d["counts"]["F8-color"] == 4, d
assert len(d["findings"]) == 38 and d["more"] == 0 and d["findings"][0]["severity"] == "error", d
assert d["budget"] == {"test": 91, "lib": 296}, d' "$TMP/json"
else
  echo "  skip --json parse (no python3)"
fi
expect "--files: findings in those files fail" 1 dart run "$S" --root "$S_BAD" --files \
  lib/features/orders/presentation/pages/orders_screen.dart README.md lib/gone.dart
has "--files: F11 is an error there" 'F11-text: literal text "Hello orders"'
lacks "--files: no warning left" "warning:"
has "--files: other files skipped and counted" "in 1 file (2 skipped: not Dart, missing, or outside lib/ and test/)"
lacks "--files: only that file" "lib/utils.dart"
expect "--files: a clean file passes" 0 dart run "$S" --root "$S_BAD" --files "$S_BAD/lib/main.dart"
expect "--files with no file passes" 0 dart run "$S" --root "$S_BAD" --files
has "--files with no file: nothing checked" "passed, 0 errors and 0 warnings in 0 files"

W="$TMP/warn"
mkdir -p "$W/lib/features/notes/presentation/widgets" "$W/tool/kit"
printf "const label = Text('Hello');\n" >"$W/lib/features/notes/presentation/widgets/note_label.dart"
expect "a warning alone passes" 0 dart run "$S" --root "$W"
has "a warning alone: counted" "passed, 0 errors and 1 warning in 1 file [F11-text 1]"
expect "--strict: a warning fails" 1 dart run "$S" --root "$W" --strict
has "--strict: says why" "FAILED (--strict: warnings fail the run)"
echo '{"rules": {"F11": false}}' >"$W/tool/kit/kit_config.json"
expect "a family switched off" 0 dart run "$S" --root "$W" --strict
has "a family switched off: no finding" "0 errors and 0 warnings"
echo '{"rules": {"F11-text": false, "F12-helper": true}}' >"$W/tool/kit/kit_config.json"
expect "one check switched off" 0 dart run "$S" --root "$W" --strict
echo '{}' >"$TMP/all-on.json"
expect "--config replaces the project's config" 1 dart run "$S" --root "$W" --config "$TMP/all-on.json" --strict
has "--config: the switched-off check is back" "[F11-text 1]"

echo "== check_structure: Flutter's UI packages in domain/, every icon family"
U="$TMP/ui"
mkdir -p "$U/lib/features/notes/domain/entities" "$U/lib/features/notes/presentation/widgets"
printf "import 'package:material_ui/material_ui.dart';\nimport 'package:cupertino_ui/cupertino_ui.dart';\n\nclass Note {}\n" \
  >"$U/lib/features/notes/domain/entities/note.dart"
{
  echo "final a = Icon(LucideIcons.search);"
  echo "final b = Icon(CupertinoIcons.add);"
  echo "final c = Icon(LucideIcons500.package);"
  echo "final d = AppIcon(AppIcons.search);"
  echo "final e = Icon(AppIcons.search);"
} >"$U/lib/features/notes/presentation/widgets/note_icons.dart"
# Icon(AppIcons.x) is fine only in lib/core/theme/ and in the AppIcon widget's own file, not in the rest of the kit.
mkdir -p "$U/lib/core/theme" "$U/lib/core/common/widgets"
echo "final f = Icon(AppIcons.search);" >"$U/lib/core/theme/app_icon_theme.dart"
printf "class AppIcon {}\nfinal g = Icon(AppIcons.search);\n" >"$U/lib/core/common/widgets/app_icon.dart"
echo "final h = Icon(AppIcons.add);" >"$U/lib/core/common/widgets/app_button.dart"
expect "UI packages and icon families fail" 1 dart run "$S" --root "$U"
has "domain imports material_ui" "note.dart:1: F2-import: domain/ imports package:material_ui/material_ui.dart"
has "domain imports cupertino_ui" "note.dart:2: F2-import: domain/ imports package:cupertino_ui/cupertino_ui.dart"
has "F10 a Lucide icon" "note_icons.dart:1: F10-icon: Icon(LucideIcons.search)"
has "F10 a Cupertino icon" "note_icons.dart:2: F10-icon: Icon(CupertinoIcons.add)"
has "F10 a numbered family" "note_icons.dart:3: F10-icon: Icon(LucideIcons500.package)"
has "F10 Icon(AppIcons.x) skips AppIcon" "note_icons.dart:5: F10-icon: Icon(AppIcons.search) skips AppIcon"
has "AppIcons: AppIcon(), the theme and AppIcon's own file pass" "7 errors and 0 warnings in 5 files"

echo "== check_structure: the test budget (F17)"
B="$TMP/budget"
mkdir -p "$B/lib" "$B/test"
# 4 counted lines in lib/: the blank and the comment lines do not count, and the generated file is left out.
{ gen 4 'const a%d = 1;'; echo; echo '// a comment line'; } >"$B/lib/app.dart"
gen 9 'const g%d = 1;' >"$B/lib/app.g.dart"
gen 3 'const t%d = 1;' >"$B/test/app_test.dart"
expect "tests smaller than lib/ pass" 0 dart run "$S" --root "$B"
if [ "$(tail -n 2 "$OUT" | head -n 1)" = "budget: test/ 3 counted lines, lib/ 4" ]; then
  ok "the budget line, just before the summary"
else
  bad "the budget line, just before the summary"
fi
lacks "tests smaller than lib/: no budget warning" "F17-budget"
gen 2 'const u%d = 1;' >>"$B/test/app_test.dart"
expect "tests bigger than lib/: still a pass, even --strict" 0 dart run "$S" --root "$B" --strict
has "tests bigger than lib/: the warning" \
  "test/:1: F17-budget: warning: test/ has 5 counted lines, more than lib/ (4): prune before you add (RULES F17)"
expect "--files: the budget is no error there" 0 dart run "$S" --root "$B" --files test/app_test.dart
lacks "--files: no budget line, no budget warning" "budget:"

echo "== check_structure: config and usage errors (exit 2)"
for bad_config in '{"rules": {"F99": false}}' '{"sizeExceptions": [{"path": "lib/a.dart"}]}' '{"limits": {"file": 0}}' \
  '{"controllersDir": "bloc", "colours": true}' '{"generated": ["**/*.g.dart",]}'; do
  echo "$bad_config" >"$W/tool/kit/kit_config.json"
  expect "bad config refused: $bad_config" 2 dart run "$S" --root "$W"
done
has "bad config: says what is wrong" "is not valid JSON"
echo '{"sizeExceptions": [{"path": "lib/a.dart"}]}' >"$W/tool/kit/kit_config.json"
expect "an exception needs a reason" 2 dart run "$S" --root "$W"
has "an exception needs a reason: says so" 'sizeExceptions[0] (lib/a.dart) needs a "reason"'
rm -f "$W/tool/kit/kit_config.json"
expect "unknown argument" 2 dart run "$S" --root "$W" --colour
has "unknown argument: usage line" "usage: dart run tool/kit/check_structure.dart"
expect "--max-lines needs a number" 2 dart run "$S" --max-lines many
expect "a missing root" 2 dart run "$S" --root "$TMP/nowhere"
expect "--config to a missing file" 2 dart run "$S" --root "$W" --config "$TMP/nowhere.json"
expect "--help" 0 dart run "$S" --help
has "--help: usage line" "usage: dart run tool/kit/check_structure.dart"

echo "== check_structure: the default limits, and the shipped kit_config.json"
D="$TMP/defaults"
mkdir -p "$D/lib/features/notes/presentation/pages" "$D/lib/features/notes/presentation/controllers" \
  "$D/lib/core/common/data" "$D/test" "$D/tool/kit"
{
  echo "class NotesController {"
  echo "  void big() {"
  gen 59 "    print(%d);"
  echo "  }"
  echo "}"
} >"$D/lib/features/notes/presentation/controllers/notes_controller.dart"
{
  echo "class NotesPage extends StatelessWidget {"
  echo "  @override"
  echo "  Widget build(BuildContext context) {"
  echo "    return Column(children: ["
  gen 117 "      const SizedBox(),"
  echo "    ]);"
  echo "  }"
  echo "}"
} >"$D/lib/features/notes/presentation/pages/notes_page.dart"
{
  echo "const rows = ["
  gen 349 "  'r%d',"
  echo "];"
} >"$D/lib/core/common/data/rows.dart"
{
  echo "void main() {"
  gen 449 "  test('t%d', () {});"
  echo "}"
} >"$D/test/notes_test.dart"
expect "default limits: over by one line each" 1 dart run "$S" --root "$D"
has "default function limit 60" "big has 61 counted lines (limit 60)"
has "default build limit 120" "build has 121 counted lines (limit 120)"
has "default file limit 350" "rows.dart:1: F1-file: the file has 351 counted lines (limit 350)"
has "default test file limit 450" "notes_test.dart:1: F1-file: the file has 451 counted lines (limit 450)"
has "default limits: nothing else" "4 errors and 0 warnings in 4 files"
cp "$OUT" "$TMP/without-config"
cp "$TOOL/kit_config.json" "$D/tool/kit/kit_config.json"
expect "the shipped kit_config.json loads" 1 dart run "$S" --root "$D"
if cmp -s "$OUT" "$TMP/without-config"; then ok "the shipped kit_config.json equals the defaults"; else
  bad "the shipped kit_config.json equals the defaults"; fi

L_GOOD="$FIX/l10n/good"
L_BAD="$FIX/l10n/bad"

echo "== check_l10n: good catalogs"
expect "good catalogs pass" 0 dart run "$L" --root "$L_GOOD"
has "good: plural, select and nested placeholders" "check_l10n: passed, 0 errors and 0 warnings in 2 catalogs, 5 keys"
expect "no l10n.yaml: the kit's defaults" 0 dart run "$L" --root "$FIX/l10n/defaults"
has "defaults: lib/core/l10n and app_en.arb" "(lib/core/l10n/, template app_en.arb)"
expect "use-escaping: quoted braces are text" 0 dart run "$L" --root "$FIX/l10n/escaping"
has "use-escaping: arb-dir read from l10n.yaml" "(i18n/, template app_en.arb)"
cp -R "$FIX/l10n/escaping" "$TMP/no-escaping"
printf 'arb-dir: i18n\n' >"$TMP/no-escaping/l10n.yaml"
expect "without use-escaping the same text is a syntax error" 1 dart run "$L" --root "$TMP/no-escaping"
has "without use-escaping: says so" '"codeHint": message syntax: expected a placeholder name'

echo "== check_l10n: bad catalogs (every check)"
expect "bad catalogs fail" 1 dart run "$L" --root "$L_BAD" --max-lines 0
has "invalid JSON, with its line" "app_de.arb:3: F11-json: invalid JSON: expected a key in double quotes (a trailing comma?)"
has "duplicate key, with both lines" 'app_en.arb:7: F11-duplicate: "ordersTitle" appears twice (first at line 2)'
has "placeholder without @key" '"ordersGreeting" uses {name}'
has "@key declares an unused placeholder" '"@ordersTotal" declares {currency}, unused in the text'
has "placeholder without a type" '"@ordersTotal": placeholder {amount} has no "type"'
has "curly apostrophe" 'app_en.arb:8: F11-apostrophe: "authSignIn" holds a curly apostrophe (U+2019)'
has "missing key" 'app_fr.arb:1: F11-missing: no "ordersEmpty" (app_en.arb line 6)'
has "extra key" 'app_fr.arb:5: F11-extra: "ordersExtra" is not in app_en.arb'
has "placeholder names differ" '"ordersGreeting" uses {nom}; app_en.arb uses {name}'
has "message syntax" '"ordersTotal": message syntax'
has "summary with counts per rule" "check_l10n: FAILED, 10 errors and 0 warnings in 3 catalogs, 5 keys"
expect "capped output" 1 dart run "$L" --root "$L_BAD" --max-lines 2
has "capped: the 'more' line" "... 8 more findings not shown"
expect "--json fails the same way" 1 dart run "$L" --root "$L_BAD" --json
if command -v python3 >/dev/null 2>&1; then
  cp "$OUT" "$TMP/json" # expect rewrites $OUT, so python3 reads a copy
  expect "--json is valid JSON" 0 python3 -I -c '
import json, sys
d = json.load(open(sys.argv[1]))
assert d["tool"] == "check_l10n" and d["errors"] == 10 and d["counts"]["F11-metadata"] == 3, d' "$TMP/json"
fi

echo "== check_l10n: --files, an empty project, a missing template, usage"
expect "--files without an ARB file: nothing to check" 0 dart run "$L" --root "$L_BAD" --files lib/main.dart
has "--files without an ARB file: says so" "no ARB file among the files: nothing to check"
expect "--files with an ARB file checks every catalog" 1 dart run "$L" --root "$L_BAD" --files lib/core/l10n/app_fr.arb
mkdir -p "$TMP/empty"
expect "no catalog: a warning" 0 dart run "$L" --root "$TMP/empty"
has "no catalog: says where it looked" "F11-catalog: warning: no ARB catalog in lib/core/l10n/"
expect "no catalog with --strict fails" 1 dart run "$L" --root "$TMP/empty" --strict
mkdir -p "$TMP/notemplate/lib/core/l10n"
echo '{"ordersTitle": "Commandes"}' >"$TMP/notemplate/lib/core/l10n/app_fr.arb"
expect "a missing template fails" 1 dart run "$L" --root "$TMP/notemplate"
has "a missing template: says so" "the template app_en.arb is missing from lib/core/l10n/"
expect "unknown argument" 2 dart run "$L" --colour
has "unknown argument: usage line" "usage: dart run tool/kit/check_l10n.dart"
expect "--help" 0 dart run "$L" --help

echo
echo "checks: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
