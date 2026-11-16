---
name: code-rules
description: Holds the code rules for a Flutter app built feature first in layers - size limits, layers and imports, ChangeNotifier controllers, typed errors, one API client, theme tokens with automatic light and dark, edge-to-edge system bars, one icon family, translation catalogs, tests and comments - and the check scripts that enforce them. Use when writing, reviewing or refactoring app code, adding a screen, widget, controller, repository, string, colour or icon, or when asked "what are the rules", "is this allowed" or "why does the analyzer or check_structure fail".
---

# Code rules

The full text is `docs/RULES.md` in the project (F1 to F18). This is the summary: when a change comes close to
a rule, read the rule itself. Working code for each rule lives in the `recipes` skill
(`/perfect-vibecoding-rules-flutter:recipes`, or `docs/playbooks/recipes/SKILL.md`).

## The ten rules that matter most

1. **Size limits, in counted lines** (blank and comment-only lines do not count): a source file 350, a test file
   450, a function or method 60, a `build` method 120. Generated files are exempt. Over a limit: split by
   responsibility (a widget class, a controller helper, a mapper, a use case), never squeeze lines. After each
   change run `dart run tool/kit/check_structure.dart --files <the files you changed>`.
2. **Layers, feature first.** `lib/core/...` and `lib/features/<feature>/{data,domain,presentation}`, plus
   `<feature>_routes.dart`. File names are snake_case with their folder's suffix: `_page`, `_controller`,
   `_repository` (domain), `_repository_impl` (data), `_model`, `_datasource`; `get_orders.dart` holds
   `class GetOrders`. `domain` is plain Dart; `presentation` never imports `data/`; a feature reads another
   feature only through its `domain/`.
3. **State.** One `ChangeNotifier` controller per screen in `presentation/controllers/`, built by the feature's
   module (`core/config/injection-modules/<feature>_module.dart`) and served by `NotifierProvider` (`of` listens,
   `read` does not). It calls use cases, exposes getters, guards `notifyListeners` with a `_disposed` flag and
   drops stale answers with a generation counter. First load from `initState`, never from `build()`. No bloc, no
   Riverpod, no get_it.
4. **Errors.** Data sources throw `ApiException`; repositories return `Result<T>` (`Success` or `FailureResult`)
   through one `_guard`, with a typed `Failure`. Branch on the type or the backend's `code`, never on a message.
   No empty `catch`, no swallowed `null`, never a stack trace, a URL or a token on screen.
5. **Network.** One `ApiClient` over dio (timeouts 15, 15 and 20 s; one shared token refresh; an
   `Idempotency-Key` on every create) or one `SupabaseGateway`. Only data sources know a path, a table or a column.
6. **Theme.** Colours only from `context.colors` (`AppColors`, a `ThemeExtension` with `light` and `dark` consts,
   every parameter `required`). No `Color(0x...)`, `Color.fromARGB` or `Colors.x` outside `lib/core/theme/`,
   except `Colors.transparent`. Text from `AppTextStyles` over one bundled font; spacing, radius and motion from
   their token classes.
7. **Edges.** Edge to edge; one `systemOverlayFor(colors)`, set in three places; never one `SafeArea` around the
   app; a bottom bar paints under the gesture bar; sheets open through `showAppSheet`.
8. **Icons and the widget kit.** One icon family, through `AppIcons` and `AppIcon`: no raw `Icon(Icons.x)`,
   `Icon(LucideIcons.x)` or `SvgPicture` outside `lib/core/theme/` and `lib/core/common/widgets/`, and no
   `Icon(AppIcons.x)` outside `lib/core/theme/` and the `AppIcon` widget (it skips the token size and colour).
   Pages are built from the kit's widgets. Never a `_buildX()` method that returns a widget: make it a widget
   class. Every data screen shows four states: loading, empty, error with retry, and the data.
9. **Text.** No literal user-facing text: the ARB catalogs in `lib/core/l10n/` (`app_en.arb` is the shape
   source), read with `context.l10n.<key>`; keys camelCase, prefixed by feature (`ordersEmptyTitle`); every
   locale edited together by small edits; the straight apostrophe only; right-to-left safe layout
   (`EdgeInsetsDirectional`, `start` and `end`).
10. **Tests and comments.** `test/` mirrors `lib/`. Fakes are hand-written classes that `implements` the real
    interface and return real shapes (no mockito, no mocktail). A regression test for every bug fix; widget tests
    for the four states at 320x640 with text scale 1.3. The test budget (F17): a test only for a bug no other test
    catches, one table test for many inputs, no duplicates, and `test/` smaller than `lib/`: a full
    `check_structure.dart` run warns when `test/` outgrows `lib/`. Comments say why, in the code's own terms;
    never cite a ticket, a report or an agent.

Also in `docs/RULES.md`: routing (F7), environment and secrets (F13), storage and the session (F14), media,
permissions and performance (F15), accessibility and motion (F16), the gate and the definition of done (F18), and
the anti-patterns list.

## Check your work

A change is done when its targeted checks pass. Each takes seconds.

| Command | Catches |
| --- | --- |
| `dart format <the files you changed>` | formatting (never the whole tree while agents work) |
| `scripts/tools/q-analyze.sh` | the analyzer, queued, with the kit's `analysis_options.yaml`: strict casts, inference and raw types; braces, `final`, `const`, `print`, `unawaited(...)`, `context` after an `await` |
| `scripts/tools/q-test.sh <test files>` | the tests of the touched files |
| `dart run tool/kit/check_structure.dart --files <the files you changed>` | F1 sizes; F2 folders, suffixes, snake_case names, use case class names, import direction; F8 static colours; F10 raw icons; F11 literal text; F12 widget helper methods |
| `dart run tool/kit/check_l10n.dart` | the catalogs: missing and extra keys, placeholders against the template and its `@key` metadata, duplicate keys, invalid JSON, curly apostrophes |

Both check scripts print one line per finding, `path:line: rule: message`, then one summary line, at most 60
findings (`--max-lines N` changes it). In a full run, F11 text and F12 helpers are warnings, which fail only with
`--strict`; the F17 budget warning never fails a run. With `--files`, every finding in those files is an error, so
new code meets every rule.

A batch is done when the ONE gate passes (`scripts/tools/verify.sh`, a build, the owner's check on a phone), run
once, right before the push or the release, in a fresh session (`/perfect-vibecoding-rules-flutter:gate`, or
`docs/playbooks/gate/SKILL.md`).

A check fails? Fix the code, not the check. If a rule is truly wrong for this project, say so to the owner and
change `docs/RULES.md` and the check together, on purpose.

## When a rule seems to block you

- A file must grow past its limit: split it first, then add the feature. Only a file that was already too big
  when the rules arrived gets a `sizeExceptions` entry, with its reason and a `maxLines` cap.
- No token fits a colour: add one to `AppColors`, in both `light` and `dark`.
- No icon fits: add one to `AppIcons`, from the app's one family.
- Two features need the same piece: lift it to `lib/core/` (widgets to `core/common/widgets/`, pure helpers to
  `core/common/data/`). Never import another feature's `data/` or `presentation/`.
- A string changes: edit every catalog with a small targeted edit (find the key with `grep -n`), then run
  `check_l10n.dart`.
- A lint fires: fix it. An `// ignore:` needs a one-line reason on the same line.
- A check reports a line that is not a real problem: show the owner the line and the output. Never switch a rule
  off to pass.
- The backend lacks what a screen needs: do not invent a shape. Say so to the owner.

## Setting the checks up

How to copy `tool/kit/` into a project, the fields of `kit_config.json`, the analyzer settings, size exceptions
and how to run the checks on changed files: [checks.md](checks.md).

In Claude Code: with the plugin installed, Claude loads this skill by itself when it writes or reviews app code;
you can also run it as `/perfect-vibecoding-rules-flutter:code-rules`. The scripts ship in
`${CLAUDE_PLUGIN_ROOT}/templates/tool/kit/` and the analyzer settings in
`${CLAUDE_PLUGIN_ROOT}/templates/analysis_options.yaml`; `/perfect-vibecoding-rules-flutter:new-project` copies
them into the project. The setup guide is `${CLAUDE_SKILL_DIR}/checks.md`.
