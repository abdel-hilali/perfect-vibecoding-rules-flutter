---
name: screen
description: Builds or changes a screen of the Flutter app the project's way - settle doc conflicts first (the conception wins), confirm the backend serves it or ship a guarded "coming soon" route plus a backend ask, build to the code rules (tokens, edges, icons, the text catalog, the four states, sizes, layers), register the route and its tests, then run the targeted checks and tell the owner where to look. Use when adding a page, a tab or a bottom-bar entry, wiring a new endpoint, or reworking an existing screen.
---

# Build a screen

Five steps, in order. Skipping step 0 is the most expensive mistake: a conflict settled after the build is baked
into code and costs a rebuild.

## 0. Settle doc conflicts BEFORE writing code

Three sources govern a screen. Each is the authority for one thing:

| Source | Authority for |
| --- | --- |
| The conception (the product rules) | Tabs, roles, flows, what the screen does. It wins any conflict. |
| The backend contract (its documented API, or the tables and their access rules) | What can be read or called, with which fields and error codes. |
| The design (mockups, a design file, screenshots) | The layout. |

- Grep `docs/DECISIONS.md` first: the question may already be settled.
- When the sources disagree, stop and ask the owner. One short question: the readings side by side, your
  recommendation first. Never pick silently.
- Record the answer: a numbered line in `docs/DECISIONS.md` (the date and the owner's words), or a backend ask.
- What the conception does not name is built only on the owner's yes.

## 1. Confirm the backend serves it

- Find each call the screen needs in the backend contract, and check that the real backend answers it, read-only (a
  read, a sign-in). Keep one real answer per call: the fake data source returns those shapes, never invented ones.
- Read the backend's change notes since your last look. They can change error codes, rate limits or a field's
  meaning (a list field that now replaces the set instead of adding to it).
- A route, a field or an error code is missing? Do not work around it in the app. Add an ask to the newest UNSENT
  part (`docs/BACKEND-ASKS-<n>.md`) and tell the owner, who carries it to the backend team. A sent part is never
  edited.
- Cannot build it yet? Ship a real route anyway: registered, gated by `appRedirect()` like the finished screen, its
  title from the catalog, a body that says "coming soon" (the kit's `EmptyState` with a catalog text). Mark it
  "coming soon" in `docs/PROGRESS.md` §5 with what it waits for (the ask's number). The mark goes the day it ships.
- **Every tab and every button leads to a page.** Never a dead tab, never a "page not found" behind a menu entry.

## 2. Build to the rules

The full rules are in `docs/RULES.md` (summary: `/perfect-vibecoding-rules-flutter:code-rules`, or
`docs/playbooks/code-rules/SKILL.md`). Working code for each pattern: the recipes
(`/perfect-vibecoding-rules-flutter:recipes`, or `docs/playbooks/recipes/SKILL.md`). The rules most often broken in
Flutter:

- **Tokens (F8).** Colours only from `context.colors`. No `Color(0x...)` and no `Colors.x` outside
  `lib/core/theme/` (`Colors.transparent` is the one exception). A new colour is a token in BOTH `AppColors.light`
  and `AppColors.dark`. Text styles from `AppTextStyles`, gaps from `AppSpacing`, corners from `AppRadius`,
  durations from `AppMotion`.
- **Edges (F9).** The page paints its background edge to edge. The top bar paints under the status bar and pads
  itself; a bottom bar is `DecoratedBox(color)` > `SafeArea(top: false)`; a list pads its bottom with
  `N + MediaQuery.paddingOf(context).bottom`; a sheet opens through `showAppSheet`. Never a `SafeArea` around the
  whole page, never `systemNavigationBarColor` to colour the bottom (Android 15 ignores it). An always-dark screen
  (camera, media viewer) sets its own `AnnotatedRegion`.
- **Icons (F10).** Only through `AppIcons` and `AppIcon` (sizes from `AppIconSize`), one family. No raw
  `Icon(Icons.x)` or `SvgPicture` in a page. An icon-only button has a `tooltip` or a `Semantics` label and a 48 dp
  tap target.
- **The text catalog (F11).** No literal user-facing text. Add the key to `app_en.arb` (camelCase, the feature's
  prefix: `ordersEmptyTitle`) and to every other catalog in the same change, by small edits; read it with
  `context.l10n.<key>`; then `flutter gen-l10n`. Layout right-to-left safe: `EdgeInsetsDirectional`,
  `AlignmentDirectional`, `start` and `end`.
- **The widget kit and the four states (F12).** Build from `core/common/widgets/`: the top bar, the buttons,
  `LoadingState`, `EmptyState` (it says what to do), `ErrorState` (with a retry), then the data. Feedback only
  through the app's toast helper, dialogs through `showConfirmDialog`. A second kind of button or bar needs the
  owner's yes and the design direction.
- **Sizes (F1).** A file at most 350 counted lines, a method 60, a `build` method 120. Too big? Extract a widget
  class into the feature's `widgets/`, never a `_buildX()` helper.
- **Layers (F2, F3).** The route builds the controller from the feature's module; the page reads it
  (`NotifierProvider.of`). The controller calls use cases, never a data source. `presentation` never imports
  `data/`; another feature is reached only through its `domain/`. Branch on the `Failure` type, never on a message.
- **Accessibility and motion (F16).** Tap targets at least 48 dp; the page works at 320x640 with text scale 1.3;
  motion 150 to 300 ms, none when `MediaQuery.disableAnimationsOf(context)` is true.

Before you change a colour, a font, the top bar, the bottom bar or the icons, read the project's design direction
(`.claude/skills/design-direction/SKILL.md`). It holds the settled corrections; do not reopen them.

## 3. Register the route and its tests

- The page has `static const path` (and `name` when it is opened by name). The feature's `<feature>_routes.dart`
  returns its routes; `core/router/app_router.dart` only assembles the lists. A new tab is a new branch of the
  `StatefulShellRoute.indexedStack` and a new item in `MainShell`'s bar.
- Gate it in `appRedirect()`, never inside the page. Add its cases to the redirect test
  (`test/core/router/app_redirect_test.dart`): signed out, each role, each gate that applies.
- Add its path to the routes test (for example `test/core/router/app_router_test.dart`): it fails when a path builds
  no page or a tab leads nowhere.
- Tests mirror `lib/`: the controller (loading, data, each failure, a stale answer dropped, no notify after
  dispose), the repository over a fake data source, the model (a good row, a bad row), and the page's widget test
  (the four states, at 320x640 with text scale 1.3, light and dark). A bug fix gets a regression test that fails
  without the fix.

## 4. Check it and say where to look

While building, targeted checks only (tier 1 of `/perfect-vibecoding-rules-flutter:gate`, or
`docs/playbooks/gate/SKILL.md`):

```bash
dart format <the files you changed>
scripts/tools/q-analyze.sh
scripts/tools/q-test.sh <the test files you touched>
dart run tool/kit/check_structure.dart --files <the files you changed>
dart run tool/kit/check_l10n.dart
```

The batch is done when the ONE gate passes (verify, a build, the owner's check on a phone), once, right before the
push, in a fresh session. Then tell the owner where to look:

| Screen | Account | Build or device | What you see | Do not tap |
| --- | --- | --- | --- | --- |
| Orders tab, then one order | a test account with orders | debug on your phone: hot restart (R) | the list, pull to refresh; the empty state on an account with no orders | "Cancel order": it writes to the live backend |

Say what the owner must do to see it: a hot reload (`r`), a hot restart (`R`: a new route, a changed `main.dart`,
a value set once in `initState`), or a new run or install (a new plugin, a native file, a change in `pubspec.yaml`,
the launcher icon, the splash). Plumbing with nothing visible: say "nothing to see on the phone yet".

In Claude Code: in a project set up with `/perfect-vibecoding-rules-flutter:new-project`, the design direction is a
project skill and loads by itself when a design task starts. Run the checks from the project's own
`scripts/tools/`, never the copy under `${CLAUDE_PLUGIN_ROOT}`: that copy would take the plugin's folder for the app.
