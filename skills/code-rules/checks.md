# Setting up the code checks

Three files in the project's `tool/kit/` folder and one at its root enforce `docs/RULES.md`:

| File | What it does |
| --- | --- |
| `tool/kit/check_structure.dart` | F1 sizes, F2 layout, names and imports, F8 colours, F10 icons, F11 literal text, F12 helpers, F17 test budget |
| `tool/kit/check_l10n.dart` | F11 catalogs: keys, placeholders, metadata, duplicate keys, JSON, apostrophes |
| `tool/kit/kit_config.json` | the settings of `check_structure.dart` (below) |
| `analysis_options.yaml` | the analyzer settings: strict modes and a strict, quiet lint set |

The two scripts import only `dart:` libraries: they need no package and no `pub get`, never use the network and
never write a file. They read only `lib/` and `test/`, so a big project folder (build output, old worktrees) does
not slow them down.

## 1. Copy them into the project

```
mkdir -p tool/kit
cp <kit>/templates/tool/kit/check_structure.dart <kit>/templates/tool/kit/check_l10n.dart tool/kit/
cp <kit>/templates/tool/kit/kit_config.json tool/kit/
cp <kit>/templates/analysis_options.yaml .
```

`<kit>` is the kit's folder (`${CLAUDE_PLUGIN_ROOT}` in Claude Code); the `new-project` skill does these copies.
If the project already has an `analysis_options.yaml`, merge by hand: keep the project's extra rules, add the
kit's. It needs `flutter_lints` as a dev dependency, which every new Flutter project has.

Then run both checks once, in the project's root:

```
dart run tool/kit/check_structure.dart
dart run tool/kit/check_l10n.dart
```

On an existing app, the first full run lists the old debt. Do not fix it all at once, and do not switch rules off:
set `controllersDir` if the app calls that folder `bloc`, add a `sizeExceptions` entry for each file that is
already too big (section 4), and check new work with `--files` (section 2). Split the old files one by one, as
their own small tasks.

## 2. Running the checks

| Option | Effect |
| --- | --- |
| (none) | every Dart file in `lib/` and `test/`, generated files left out |
| `--files F...` | only these files, and every finding in them is an error. Files that are not Dart, are deleted, or sit outside `lib/` and `test/` are skipped and counted, so a list from git works as it is |
| `--max-lines N` | at most N finding lines (default 60; `0` shows all), then "N more" and the summary |
| `--strict` | warnings fail the run too, except `F17-budget` |
| `--json` | one JSON object (`passed`, `errors`, `warnings`, `counts`, `findings`, `more`; `budget` in a full run) |
| `--root DIR` | the project's folder (default: the working folder) |
| `--config FILE` | `check_structure.dart` only: another settings file instead of `tool/kit/kit_config.json` |

The files you changed, tracked and new:

```
dart run tool/kit/check_structure.dart --files $(git diff --name-only HEAD) $(git ls-files --others --exclude-standard)
```

`check_l10n.dart` takes `--files` too: it checks every catalog when one of the files is an `.arb` file or
`l10n.yaml`, and says "nothing to check" otherwise. It reads `arb-dir`, `template-arb-file` and `use-escaping`
from `l10n.yaml`; what `l10n.yaml` does not set falls back to `lib/core/l10n` and `app_en.arb`.

Output: one line per finding, `path:line: rule: message` (a warning's message starts with `warning:`), errors
first, then one summary line with the count per rule. Exit codes: `0` clean, `1` findings that fail the run, `2` a
usage or settings error. A full `check_structure.dart` run (no `--files`) prints one more line just before the
summary, `budget: test/ <N> counted lines, lib/ <M>`, counted as F1 counts them, generated files left out;
`verify.sh` greps that line.

| Rule | `check_structure.dart` flags |
| --- | --- |
| `F1-file` | a file over 350 counted lines (a test file: 450), or past its `sizeExceptions` cap |
| `F1-function`, `F1-build` | a function, method, getter or constructor over 60 counted lines; a `build` method over 120 |
| `F1-exception` (warning) | a `sizeExceptions` entry that is no longer needed, or names a missing file |
| `F2-folder` | a file outside the folders of F2 (reported once per folder) |
| `F2-suffix` | a file without its folder's suffix (`_page.dart` in `pages/`, `_module.dart` in `injection-modules/`...) |
| `F2-name` | a file name that is not snake_case; a use case file without the class named after it |
| `F2-import` | `domain/` importing Flutter (`material_ui` and `cupertino_ui` too), dio, Supabase, `data/` or `presentation/`; `presentation/` importing `data/`; `data/` importing `presentation/`; a feature importing another feature's internals |
| `F8-color` | `Color(0x...)`, `Color.fromARGB`, `Color.fromRGBO`, `Color.from`, `Colors.<name>` outside `lib/core/theme/` (`Colors.transparent` is fine) |
| `F10-icon` | `Icon(Icons.x)`, or any other family (`Icon(LucideIcons.x)`, `Icon(CupertinoIcons.x)`), or `SvgPicture`, outside `lib/core/theme/` and `lib/core/common/widgets/` |
| `F10-icon` | `Icon(AppIcons.x)` outside `lib/core/theme/` and the `AppIcon` widget's own file: use `AppIcon` |
| `F11-text` (warning) | a string with a letter as the first argument of `Text(`, or as `hintText:`, `labelText:`, `tooltip:`, `semanticsLabel:` (not in `lib/core/l10n/`) |
| `F12-helper` (warning) | a method or function that returns a widget (`Widget _buildHeader()`), other than `build` and overrides |
| `F17-budget` (warning) | a full run whose `test/` has more counted lines than `lib/`; it never fails a run |

| Rule | `check_l10n.dart` flags |
| --- | --- |
| `F11-catalog` | no catalog found (a warning), or the template file missing |
| `F11-json` | invalid JSON (with its line), or a message that is not a string |
| `F11-duplicate` | a key written twice: JSON keeps the last one without a word |
| `F11-missing`, `F11-extra` | a key of the template missing from a locale; a key of a locale missing from the template |
| `F11-placeholder` | a locale whose placeholders differ from the template's; a message that does not parse |
| `F11-metadata` | a template message with placeholders and no `@key`, a placeholder not declared or declared but unused, a placeholder without a `type` |
| `F11-apostrophe` | the curly apostrophe (U+2019) in a message |

Placeholders are read the way gen-l10n reads them: `{name}`, and `{count, plural, ...}` or `{x, select, ...}`
with the placeholders inside every branch. With `use-escaping: true`, text between single quotes is literal.

## 3. kit_config.json

A key that starts with `//` is a comment. An unknown key or a wrong value stops the check with exit code 2, so a
typo never switches a rule off in silence.

| Field | Default | Meaning |
| --- | --- | --- |
| `limits` | `{"file": 350, "testFile": 450, "function": 60, "build": 120}` | F1 limits, in counted lines; keep them equal to `docs/RULES.md` |
| `controllersDir` | `"controllers"` | the controllers folder in `presentation/`; `"bloc"` for apps that use that name |
| `coreFolders` | `common/widgets`, `common/data`, `config`, `errors`, `network`, `supabase`, `router`, `storage`, `theme`, `l10n`, `usecases`, `permissions` | folders allowed under `lib/core/` (and anything below them) |
| `featureFolders` | the eight `data/`, `domain/` and `presentation/` folders of F2 | folders allowed under `lib/features/<feature>/`, besides `presentation/<controllersDir>/` and `<feature>_routes.dart` |
| `libFiles` | `main.dart`, `main_*.dart`, `app.dart` | files allowed directly in `lib/` |
| `generated` | `**/*.g.dart`, `**/*.freezed.dart`, `lib/core/l10n/generated/**`, `**/firebase_options.dart` | files never checked (`**/` any folders, `*` any part of a name) |
| `sizeExceptions` | `[]` | old files tolerated over F1 (section 4) |
| `rules` | every rule on | `false` switches a family (`"F11"`) or one check (`"F2-import"`) off |

Every change to these settings is a decision: write the reason in `docs/DECISIONS.md`. A new core folder or a
switched-off rule needs the owner's yes.

## 4. Size exceptions

Only a file that was already over a limit when the rules arrived gets an entry. New code never does.

```json
"sizeExceptions": [
  {
    "path": "lib/features/orders/presentation/pages/orders_page.dart",
    "reason": "Over 350 lines before the rules; split into widgets when the orders screen next changes.",
    "maxLines": 610
  }
]
```

- `path` is relative to the project's root; `reason` is required.
- The entry covers the file limit and the function and `build` limits of that file.
- `maxLines` (optional, recommended) is the file's counted lines today: the file fails once it grows past it.
- When the file is split and back within every limit, the check reports the entry as no longer needed: remove it.

To list the candidates on an old app, run the full check once and read the `F1-file` lines; the counted lines are
in each message.

## 5. How the counting works

- A line counts when code or the text of a string touches it. Blank lines and lines with only a comment (`//`,
  `///`, or a `/* ... */` block, which may nest) do not count.
- A function counts from its first line (after its annotations) to its closing brace, or to the `;` of an arrow
  body. Local functions and closures count as lines of the function around them. A test file's `main()` is not
  measured: it only registers the tests; the test file limit covers it.
- Code inside strings and comments is never code: `'Colors.red'` in a string, or a brace in a comment, changes
  nothing. Every string form is understood: single, double and triple quotes, raw strings, escapes, and
  `${...}` with nested braces and strings.
- What the checks cannot see: text that reaches `Text` through a variable or a condition, a colour built at run
  time, an import of another feature hidden behind a barrel file in `lib/core/`. Reviews still look for these.

## 6. The analyzer settings

`analysis_options.yaml` includes `package:flutter_lints/flutter.yaml`, turns on `strict-casts`,
`strict-inference` and `strict-raw-types`, leaves out `build/`, generated files and the platform folders
(`flutter analyze` rewrites the file to add each platform folder the app has), and adds a strict, quiet set:
each rule is one the code can always satisfy, most of them fixed by `dart fix --apply`. The file says why for each
rule that is not obvious, and why `require_trailing_commas` and `discarded_futures` are left out. Fix a lint;
never silence it without a one-line reason on the same line.

The two scripts pass these settings themselves. They start with `// dart format width=120`, so `dart format`
keeps them at that width in any project.

## 7. Tests of the checks (kit maintainers)

`bash tests/checks/run.sh` in the kit runs both scripts on the fixtures in `tests/checks/fixtures/` (a fake
project with good and bad files for each rule; good and bad catalogs) and on projects it builds in a temporary
folder. It needs Dart on the PATH, no network, and takes under a minute.
