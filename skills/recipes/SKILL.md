---
name: recipes
description: Gives working code for a Flutter app on this kit, excerpted from its tested starter: theme tokens, system bars edge to edge, icons and the launcher icon, translations, the one API client, typed errors, controllers, routing, modules, env and storage, images and uploads, forms, feedback, tests, and the Flutter traps that cost real time. Use when you build or fix one of these, ask "how do we do X here", add a screen, form, endpoint, upload or permission, or hit a strange Flutter bug.
---

# Recipes

Each recipe is one short file: the problem, the rule (an F-number of `docs/RULES.md`), minimal working code, and
the traps. Open only the recipe you need. The rules live in `docs/RULES.md`; recipes show how to follow them.

## Before you copy code

- The code comes from the kit's starter (`templates/boilerplate/`), which passes the analyzer, its tests and both
  checks on Flutter 3.50. Paths are the app's paths (`lib/...`, `test/...`, `android/...`). A block marked "not in
  the starter" passed the analyzer and its own tests in a copy of the starter; copy it when the app needs it.
- `// ...` marks lines left out. Copy the SHAPE, then rename to your domain: `orders`, `members` and
  `example.com` are examples, and `package:kit_app/` is the starter's package name (yours is in `pubspec.yaml`).
- If the project already has the file a recipe shows (for example `lib/core/network/api_client.dart`), follow and
  extend that file. Never create a second one.
- Import `package:material_ui/material_ui.dart`, never `package:flutter/material.dart`: it is deprecated since
  Flutter 3.47, and the analyzer info fails the gate.
- Read the recipe's Traps before you call the work done. Each trap cost someone hours.
- A change is done when its targeted checks pass: `dart format <files>`, `scripts/tools/q-analyze.sh`,
  `scripts/tools/q-test.sh <test files>`, `dart run tool/kit/check_structure.dart --files <files>` and
  `dart run tool/kit/check_l10n.dart`. A batch is done when the ONE gate passes, run once, before the push.

## Index

| Recipe | Open it when |
| --- | --- |
| [theme.md](theme.md) | Colours, a new token, light and dark, text styles, spacing, motion, the theme choice. |
| [system-bars.md](system-bars.md) | A status or navigation bar in the wrong colour, edge to edge, insets, a bottom bar, a sheet's edge. |
| [icons.md](icons.md) | An icon, an icon button, SVG icons, the launcher icon, the splash, the notification icon. |
| [l10n.md](l10n.md) | Any user-facing text, a new key, placeholders and plurals, dates and money, right to left. |
| [network.md](network.md) | A new endpoint, the `ApiClient`, headers, timeouts, the token refresh, paging, a fake data source. |
| [errors.md](errors.md) | `ApiException`, `Failure`, `Result`, a feature's own failure, parsing JSON, the text the user reads. |
| [state.md](state.md) | A controller, `NotifierProvider`, the first load, stale answers, notify after dispose, app-wide state. |
| [routing.md](routing.md) | A route, a tab, the redirect and its gates, `?next=`, deep links, back on a tab root. |
| [di.md](di.md) | A feature module, the fake data source swapped for the real one, app-wide objects, the start order. |
| [storage-env.md](storage-env.md) | `assets/.env`, `--dart-define`, a new `Env` key, the session, secure storage, preferences. |
| [media.md](media.md) | Network images, a photo upload, shrinking a photo, a permission. |
| [forms.md](forms.md) | A form, a text field, field errors, a create that must not run twice, the keyboard. |
| [feedback.md](feedback.md) | The four states of a screen, a toast, a sheet, a confirm dialog, pull to refresh, load more. |
| [tests.md](tests.md) | A unit or widget test, a fake, the 320x640 run, a test that hangs or flakes. |
| [traps.md](traps.md) | Something "impossible" happens. Scan this list before you debug. |

## Related

- The code rules these recipes implement: `docs/RULES.md` (playbook `docs/playbooks/code-rules/SKILL.md`).
- Adding a whole screen: `docs/playbooks/screen/SKILL.md`. Running the quality gate: `docs/playbooks/gate/SKILL.md`.

## In Claude Code

In Claude Code: this skill is `/perfect-vibecoding-rules-flutter:recipes`, and Claude loads it by itself when a
task matches. The recipe files sit beside this one, at `${CLAUDE_SKILL_DIR}/<recipe>.md`; the starter they quote is
at `${CLAUDE_PLUGIN_ROOT}/templates/boilerplate/`. The related skills are
`/perfect-vibecoding-rules-flutter:code-rules`, `/perfect-vibecoding-rules-flutter:screen` and
`/perfect-vibecoding-rules-flutter:gate`.
