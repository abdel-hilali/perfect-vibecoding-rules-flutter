# {{PROJECT_NAME}}: the code rules

These are the standing rules for code in this Flutter app. Each one is a hard constraint, not a preference, and each
says what to do and why. Two other sources stand beside this file: the product rules (the conception) say who may do
what and which screens exist; the backend's documented API (the contract) says what the backend serves. When a rule
here and the code disagree, fix the code or change the rule on purpose. Never let them drift.

Working code for each rule: the `recipes` skill, or `docs/playbooks/recipes/` when the playbooks are installed. The
starter code these rules describe: the kit's `templates/boilerplate/`.

## F1 · Size limits, purity, comments

Counted lines: blank lines and comment-only lines do not count.

| What | Limit |
| --- | --- |
| A source file | 350 lines |
| A test file | 450 lines |
| A function or method | 60 lines |
| A `build` method | 120 lines |

- Enforced by `dart run tool/kit/check_structure.dart`. Run it with the files you changed: new code fails the moment it
  goes over a limit. Generated files are exempt: `*.g.dart`, `*.freezed.dart`, `lib/core/l10n/generated/`,
  `firebase_options.dart`.
- Why so strict: a big file is read whole by every agent that touches it, again and again. One 5,000-line file costs
  about 50K tokens per read, and an agent that must hold it in its head makes more mistakes.
- Over a limit? Split by responsibility: extract a widget (a class, never a `_buildX()` helper method), a controller
  helper, a mapper, a use case. Never squeeze lines together.
- An old file may be tolerated over its limit only in `sizeExceptions` in `tool/kit/kit_config.json`, with the reason,
  until someone splits it. Give the entry a `maxLines` cap at the file's size today, so it cannot grow. Only a file
  that was already too big when these rules arrived gets an entry.
- The analyzer runs with the kit's `analysis_options.yaml`: strict casts, inference and raw types; braces on every block;
  `final` for locals never reassigned; `const` where possible; no `print` (use `debugPrint` behind `kDebugMode`, or the
  project's logger); `unawaited(...)` for a future you mean not to wait for. A lint is fixed, never silenced: an
  `// ignore:` needs a one-line reason on the same line.
- Material comes from the `material_ui` package (Flutter 3.47 and later): import `package:material_ui/material_ui.dart`,
  never `package:flutter/material.dart`. The old library is deprecated, and its analyzer info fails the gate.
  `flutter create` already adds `material_ui` to `pubspec.yaml`.
- Comments say why, in the code's own terms: the constraint, the trap, the reason for an odd choice. Never cite a ticket,
  a decision id, a report, an agent or a job. Bad: `// fix for review item 12`. Good:
  `// The server sends negative ids for local payloads, so 0 is not "missing".`

## F2 · Structure: features in layers

```
lib/
  main.dart                      bootstrap only: env, bindings, system bars, runApp
  app.dart                       the App widget: MaterialApp.router, themes, l10n
  core/
    common/widgets/              the shared widget kit (F12)
    common/data/                 pure helpers shared by features (formatters, parsers)
    config/env.dart              the typed Env (F13)
    config/injection-modules/    one <feature>_module.dart per feature (F4)
    errors/                      failures.dart, api_exception.dart (F5)
    network/                     api_client.dart and its interceptors (F6)
    router/                      app_router.dart, app_redirect.dart, main_shell.dart (F7)
    storage/                     secure_store.dart, preferences (F14)
    theme/                       app_colors.dart, app_text_styles.dart, app_theme.dart, system_bars.dart, tokens (F8, F9)
    l10n/                        app_en.arb (the shape source), app_<locale>.arb, generated/ (F11)
    usecases/result.dart         the sealed Result<T> (F5)
  features/<feature>/
    <feature>_routes.dart        List<RouteBase> for this feature
    data/datasources/            <feature>_remote_datasource.dart (abstract) + http_/supabase_/fake_ implementations
    data/models/                 <entity>_model.dart: fromJson/toJson over the entity
    data/repositories/           <feature>_repository_impl.dart
    domain/entities/             plain Dart classes; <feature>_failures.dart
    domain/repositories/         <feature>_repository.dart (abstract)
    domain/usecases/             one action per file: get_orders.dart holds class GetOrders
    presentation/controllers/    <name>_controller.dart (F3)
    presentation/pages/          <name>_page.dart, one per route
    presentation/widgets/        the pieces of this feature's pages
```

- File names are snake_case with the suffixes above. One public widget or class per file, named after the file.
- The dependency direction is one way: `presentation` → `domain` ← `data`. `domain` is plain Dart: no Flutter, no dio,
  no Supabase, no JSON. `presentation` never imports `data/`: it gets repositories and use cases from the module.
- Features never import each other's internals. Two features need the same piece? Lift it to `core/`. A feature may read
  another feature's public entity or use case only through `domain/`.
- Shared code goes where its kind says: widgets in `core/common/widgets/`, pure helpers in `core/common/data/`, tokens in
  `core/theme/`. Never a shared type declared inside a page.
- No demo, playground or test page under `lib/`. No `utils.dart` grab-bag.
- `check_structure.dart` enforces the layout, the suffixes, the import direction, the cross-feature imports and F1.

## F3 · State: controllers over ChangeNotifier

- Screen state lives in a controller: a `ChangeNotifier` in `presentation/controllers/`. Widgets render; they hold no
  business state beyond what a widget itself needs (an animation, a text field's focus).
- The route creates the controller from the feature module and serves it with the project's `NotifierProvider<T>`
  (`core/common/widgets/notifier_provider.dart`). The page reads it: `NotifierProvider.of<T>(context)` listens,
  `NotifierProvider.read<T>(context)` does not (use `read` in callbacks and `initState`).
- A controller exposes read-only getters (`isLoading`, `failure`, the data) and methods for actions. It calls use cases,
  never a data source, never dio.
- Every controller guards `notifyListeners()` with a `_disposed` flag, and drops stale answers with a generation counter:
  a reply to an old request never overwrites a newer one.
- First load: in the page's `initState`, by `addPostFrameCallback` → `read<T>(context).load()`. Never call a load from
  `build()`.
- App-wide state (the session, the theme choice, the locale) lives in app-wide controllers created once by their module,
  bound to the session (cleared on sign-out).
- No bloc, no Riverpod, no get_it, no `setState` for data that comes from a repository.

## F4 · Dependency injection: one module per feature

- `core/config/injection-modules/<feature>_module.dart`: a singleton (`OrdersModule.instance`) that builds the feature's
  objects. Shared objects are `late final` (created once, on first use); per-screen controllers come from `createX()`
  factories.
- The module is the only place that names a concrete class (`HttpOrdersRemoteDataSource`, `FakeOrdersRemoteDataSource`).
  Swapping the fake for the real data source is one line in the module.
- Tests build controllers and repositories by hand with fakes. They never reach into a module's singletons.

## F5 · Errors: typed, never swallowed

- Data sources throw `ApiException` (built by `ApiException.fromDio` or `fromSupabase`): the HTTP status, the backend's
  error `code`, and a safe message. Nothing else crosses the data layer.
- Repositories catch it in ONE private `_guard` and return a sealed `Result<T>`: `Success(value)` or
  `FailureResult(failure)`. A repository never throws to the presentation layer.
- `core/errors/failures.dart` declares a sealed `Failure` hierarchy: `NetworkFailure`, `TimeoutFailure`,
  `UnauthorizedFailure`, `ForbiddenFailure`, `NotFoundFailure`, `ConflictFailure`, `ValidationFailure`,
  `RateLimitFailure`, `ServerFailure`, `UnknownFailure`. A feature's own failures (`<feature>_failures.dart`) extend these.
- Branch on the failure type or the backend's `code`, never on a message: the message may change without notice.
- The controller turns a failure into a translated message (F11). Never show a stack trace, a URL, a token or a raw
  server message to the user. Never log a token or personal data.
- Never a swallowed failure: no empty `catch`, no `catch (_) { return null; }`. A bad row from the server is skipped and
  logged in debug, never a crash and never silence.
- Models parse defensively: `fromJson` reads each field with a typed helper (`intOf`, `stringOf`, `dateOf`, `listOf`) and
  a missing required field is a `ValidationFailure`, not a `TypeError`.

## F6 · Network: one client

- REST backends: ONE `ApiClient` over dio (`core/network/api_client.dart`). Base URL from `Env`. Timeouts: connect 15 s,
  send 15 s, receive 20 s (dio's receive timeout is the longest pause between two chunks, so it also catches a stalled
  download). Long transfers (uploads, downloads) also get a total time budget: a cancel token and a timer.
- Interceptors, in this order: the auth header; the response unwrap (the backend's envelope to its `data`); the
  unauthorized handler (ONE shared token refresh for every call that failed at the same time, one retry per call, never
  on `/auth/` paths, then sign-out); logging, in debug builds only, never with bodies that carry tokens.
- Headers on every call: `X-App-Version`, `X-Platform`, `X-Device-Id`. An `Idempotency-Key` on every create, so a retry
  after a lost answer never creates twice. After a `NetworkFailure` on a create, read the list again before you retry.
- Supabase backends: ONE `SupabaseGateway` (`core/network/` or `core/supabase/`): `Supabase.initialize` with a
  time-limited HTTP client (every request has a time budget) and `detectSessionInUri: false`. Data sources wrap every call
  in one `_call()` that maps errors to `ApiException.fromSupabase`.
- Data sources are the only code that knows a URL path, a table or a column. Paths and table names are constants in the
  data source, never strings in a controller.
- Lists that can grow are paginated: a cursor or page from the server, and "is there more" decided from what the server
  sent, not from what the app kept. Search inputs are debounced (about 350 ms).
- No request waterfalls: start independent reads together (`Future.wait`).
- HTTPS only. Android forbids cleartext traffic; iOS keeps App Transport Security on.

## F7 · Routing and guards

- go_router. ONE `GoRouter` in `core/router/app_router.dart`, with `refreshListenable` set to the session (and any other
  state the redirect reads).
- ONE pure function decides every redirect: `appRedirect(location, session: ..., ...)` in `core/router/app_redirect.dart`,
  unit-tested for each gate (signed out, onboarding, update required, role). No redirect logic inside pages.
- Every page has `static const path` (and `name` when it is navigated to by name). Each feature exports its routes from
  `<feature>_routes.dart`; `app_router.dart` only assembles them.
- The tab shell is a `StatefulShellRoute.indexedStack`: each tab keeps its own stack and scroll position. Its `MainShell`
  draws the app's bottom bar (F12). On a tab root, back twice leaves the app; elsewhere back pops.
- A screen the backend cannot serve yet is still a real, guarded route with a "coming soon" body: never a dead tab, never
  a 404 behind a button.
- Deep links accept only the app's own paths and validate every parameter. A `?next=` return path is an app path, never a
  URL.
- The backend checks every permission again. Hiding a button is not a permission.

## F8 · Theme: tokens only, light and dark automatic

- Colours live only in `core/theme/app_colors.dart`: `AppColors extends ThemeExtension<AppColors>`, with role-named
  tokens (`surface`, `surfaceRaised`, `onSurface`, `onSurfaceMuted`, `primary`, `onPrimary`, `outline`, `success`,
  `warning`, `danger`, `scrim`, ...) and two consts, `AppColors.light` and `AppColors.dark`. Every constructor parameter
  is `required`, so a token missing in one theme does not compile.
- Widgets read `context.colors.<token>` (an extension on `BuildContext`). Never a static colour in a widget: a static
  colour does not rebuild when the theme changes, and the app then needs a full redraw hack.
- No `Color(0x...)`, no `Colors.<name>` and no `Color.fromARGB` outside `lib/core/theme/`, except `Colors.transparent`.
  No token fits? Add one to `AppColors`, in both consts. `check_structure.dart` enforces this.
- Text styles come from `AppTextStyles` (`context.text.<style>`), over ONE bundled font family with every weight it uses
  declared in `pubspec.yaml`. Never `google_fonts` at run time: it downloads fonts, and one family per weight once broke
  `fontWeight`.
- Spacing, radius, durations and curves come from `AppSpacing`, `AppRadius` and `AppMotion`. A raw number for padding is
  fine only when it is a one-off optical correction, with a comment.
- `MaterialApp.router` gets `theme: AppTheme.light()`, `darkTheme: AppTheme.dark()` and `themeMode` from the user's
  choice: system (the default), light or dark, saved on the device (or on the account, when the app has one).
- Tests check the contrast of the main text tokens on their surfaces in both themes (4.5:1 for body text).
- A screen that must stay dark (camera, photo viewer, call) says so in a comment and uses the dark tokens explicitly.

## F9 · System bars: the app's colour, top and bottom

Every app looks the same at its edges: the status bar at the top and the navigation bar at the bottom take the colour of
the page under them, with icons that stay readable, in both themes.

- The app draws edge to edge: `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` at start. From Android 15
  (target SDK 35 and up) the system forces it anyway, and the navigation bar colour that apps set is ignored: the only way
  to colour the bottom edge is to paint under it.
- ONE function builds the style: `systemOverlayFor(AppColors c)` in `core/theme/system_bars.dart`: transparent status
  bar; icon brightness opposite to the page, on both bars; `statusBarBrightness` for iOS; `systemNavigationBarColor` =
  the page colour (it still matters before Android 15); transparent navigation bar divider;
  `systemNavigationBarContrastEnforced: false`.
- Set it in three places: `SystemChrome.setSystemUIOverlayStyle` at start and on every theme change; an `AnnotatedRegion`
  in `MaterialApp.router(builder:)`; and `AppBarTheme.systemOverlayStyle`.
- Never wrap the whole app in a `SafeArea`. Every page paints its background edge to edge. The top bar paints under the
  status bar and pads itself by the top inset. A bottom bar is `DecoratedBox(color: ...) > SafeArea(top: false)`, so its
  colour runs under the gesture bar. Scroll views pad their end by `N + MediaQuery.paddingOf(context).bottom`.
- A surface that reaches the bottom edge in another colour (a sheet, a bottom action bar) wraps its own
  `AnnotatedRegion` with the matching style. Sheets open through ONE `showAppSheet` helper: on the root navigator
  (`useRootNavigator: true`: from a tab, the nearest navigator is the tab's own, and the sheet would end on top of the
  bottom bar, which stays live), `useSafeArea: true`, no fixed background colour (the theme's is read on each build),
  an inner `SafeArea(top: false)`, keyboard padding.
- Always-dark screens set their own `AnnotatedRegion` with the dark style. The splash matches the native splash colours.
- Native side: `LaunchTheme` and `NormalTheme` in `res/values`, `values-night`, `values-v31` and `values-night-v31`,
  matching the splash; the window background equals the first frame's colour (no flash); no edge-to-edge opt-out
  (`windowOptOutEdgeToEdgeEnforcement` stops working at target SDK 36).
- A unit test checks `systemOverlayFor` for each theme: the icon brightness against the page brightness.

## F10 · Icons, launcher icon, splash

- One icon family per app, never two. Every icon comes through `AppIcons` (`core/theme/app_icons.dart`, one file of
  constants) and the `AppIcon` widget: size from `AppIconSize` (16, 20, 24), colour from tokens. With designer SVGs:
  `assets/icons/common/` for the UI, `assets/icons/nav/` for the bottom bar (`x.svg` inactive, `x_active.svg` active),
  single colour, snake_case, drawn with `BlendMode.srcIn`, precached on the splash. Without a designer set: Lucide.
  Never a raw `Icon(...)` in a page, whatever it shows (`Icons.x`, `LucideIcons.x`, even `AppIcons.x`), and never a
  raw `SvgPicture`: the `AppIcon` widget sets the size and the colour.
- An icon-only button has a `tooltip` or `Semantics(label:)` and a tap target of at least 48 dp.
- Remove packages the app does not use (`cupertino_icons` is in every new project and often used by nothing).
- The launcher icon comes from flutter_launcher_icons: an adaptive icon with a background layer, a foreground layer (the
  art inside the 66 dp safe zone) and a monochrome layer (Android 13 themed icons); `remove_alpha_ios: true`. The sources
  are kept as SVG next to the exported PNGs (`assets/icons/src/`).
- The native splash comes from flutter_native_splash with `color`, `color_dark` and an `android_12` block (icon and
  `icon_background_color` for both modes). The first Flutter frame shows the same colour and logo at the same place.
- Notifications use a white, single-colour vector icon (`res/drawable/ic_stat_<name>.xml`), kept in release builds by
  `res/raw/keep.xml`. Never the launcher icon (it shows as a white square).

## F11 · Text and translations

- Every user-facing string comes from the ARB catalogs in `lib/core/l10n/` through gen-l10n: `context.l10n.<key>`.
  `app_en.arb` is the shape source; every other locale has the same keys and the same placeholders. Even a one-language
  app keeps its text there: adding a language later is then a translation job, not a refactor.
- No literal user-facing text in widgets, controllers or failures. Tests read the catalog; they never retype a sentence.
- Keys are camelCase, prefixed by feature: `ordersEmptyTitle`, `authSignInButton`. Every key with a placeholder has its
  `@key` entry with the placeholder's type.
- `MaterialApp.router` sets `supportedLocales: AppLocalizations.supportedLocales` and `localizationsDelegates` to
  `[AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates]` (material_ui's list), so Material widgets
  (date pickers, the text selection menu) speak the app's language. Never the generated
  `AppLocalizations.localizationsDelegates`: it still names the flutter_localizations delegates (deprecated since
  Flutter 3.47), whose `MaterialLocalizations` is not the type material_ui widgets read.
- Edit every locale together, with small targeted edits. Never rewrite a whole catalog file: keys that other code reads
  get lost. Never read a whole catalog to change one key: find it with `grep -n`.
- The straight apostrophe (') only, so a search or a test finds the text.
- Right-to-left safe: `EdgeInsetsDirectional`, `AlignmentDirectional`, `TextAlign.start`/`end`, `start`/`end` in
  `Positioned.directional`. Never left/right for layout. Mixed-direction text (a name inside a sentence) is isolated.
- Dates, numbers and money are formatted by `intl` for the current locale, never by string building.
- `dart run tool/kit/check_l10n.dart` checks: the same keys in every locale, the same placeholders, no duplicate key (JSON
  keeps the last of two equal keys without a word), metadata for placeholders, no curly apostrophe.

## F12 · The shared widget kit

- `core/common/widgets/` holds the app's kit: the top bar, the main shell and bottom bar, buttons, text fields, `AppIcon`,
  `AppImage`, the states (`LoadingState`, `EmptyState`, `ErrorState` with a retry), `showAppSheet`, `showAppToast` (or one
  SnackBar helper), `showConfirmDialog`, `NotifierProvider`, the root back handler. A page is built from these; a
  second kind of button or bar needs the owner's yes and the design direction.
- Every data screen shows four states: loading (a skeleton or a spinner in tokens), empty (an `EmptyState` that says what
  to do), error (an `ErrorState` with retry), and the data. The widget tests cover all four.
- ONE way to give feedback: the app's toast or SnackBar helper, mounted once. Never a raw `ScaffoldMessenger` call in a
  page, never an `AlertDialog` built by hand.
- The top bar: the app's own widget, in the page colour, painted under the status bar (F9); title from the catalog; back
  button only on pushed pages.
- The bottom bar: the app's own widget in `MainShell`, in the page colour with a hairline on top; the active tab filled or
  bold in the brand colour, the others muted; 150 to 200 ms change; `HapticFeedback.selectionClick()`;
  `Semantics(selected:, label:)` on each tab; a badge's text scale clamped to 1.15 (only there).
- Lists use `ListView.builder` (or slivers); keys come from stable ids, never the index.
- Prefer `const` widgets; never build a widget tree in a helper method (`_buildHeader()`): make it a widget class, so it
  can be `const`, tested and rebuilt alone.

## F13 · Environment, secrets, security

- `assets/.env` (loaded by flutter_dotenv) holds public values only: the API base URL, a publishable key, a client id.
  Everything inside the app can be read by anyone who has the APK or IPA. Secrets (service keys, signing passwords, admin
  tokens) never ship in the app: they live on the server or in CI.
- `assets/.env` is git-ignored; `assets/.env.example` is committed with every key and a placeholder. `--dart-define`
  overrides a key for one build.
- `core/config/env.dart` is the typed `Env`: it reads every key once at start, and a missing required key fails at start
  with a clear message, not later with a null.
- Release builds are obfuscated (`--obfuscate --split-debug-info=build/symbols`); the symbols are kept out of git and
  stored with the release. Signing files (`key.properties`, keystores) are git-ignored and backed up by the owner.
- Never log a token, a password, a code or personal data. Debug logs are behind `kDebugMode`.
- Never build code that can cause injection, broken access control or a data leak. A request that can only be done
  unsafely: stop and tell the owner.
- WebViews load HTTPS only, with JavaScript channels only when needed and only for the app's own pages.
- Every permission in `AndroidManifest.xml` and `Info.plist` has a reason the app shows the user, asked at the moment it
  is needed, never at start. A contract test lists the permissions with their reason.

## F14 · Storage and the session

- The session (tokens, the user id) lives in secure storage through ONE `SecureStore` wrapper that never throws: a broken
  keystore reads as "signed out", never as a crash.
- Plain settings (theme choice, onboarding done, last tab) live in shared_preferences through one wrapper.
- Local databases or files with user data are encrypted when the data is personal, and wiped on sign-out.
- Sign-out runs every registered sign-out hook: controllers clear their data, caches empty, timers stop.
- Never store what the server is the authority for as if it were the truth: a cache shows, the server decides.

## F15 · Media, permissions, performance

- Images go through `AppImage`: decoded at the size shown (`cacheWidth` or `ResizeImage`), a placeholder while loading,
  an error state, a stable cache key when the URL is signed and changes.
- Photos the app uploads are shrunk on the phone (about 1600 px on the long side, quality about 85, EXIF and location
  stripped) and checked against the server's limits before upload.
- Permissions go through ONE wrapper (`core/permissions/`) that returns granted, denied or permanently denied, and opens
  the system settings when the user must change it there. Tests fake the wrapper.
- No work in `build()`: no network, no parsing, no heavy loops, no `DateTime.now()` driving layout. Heavy computing
  (parsing a big JSON, image work) runs in an isolate (`compute` or `Isolate.run`).
- Dispose what you create: controllers, `TextEditingController`s, `AnimationController`s, stream subscriptions, timers.
- After an `await` in a widget, check `context.mounted` (or `mounted`) before using the context.
- Dart: no `dynamic` outside the JSON edge (parse into typed models there); no `!` without a one-line reason why the value
  cannot be null; `late` only for module fields and values set in `initState`.

## F16 · Accessibility and motion

- Tap targets are at least 48 by 48 dp. Icon-only controls have a label.
- Never clamp the text scale for the whole app. Pages must work at 320x640 dp with a text scale of 1.3: the widget tests
  check it, and an overflow there is a real bug.
- Contrast: body text at least 4.5:1 on its surface, in both themes (F8).
- Motion explains a change (something arrived, opened, moved, is working): 150 to 300 ms, 400 ms only for a sheet or a
  drawer, durations and curves from `AppMotion`. It runs once; nothing bounces for attention. When
  `MediaQuery.disableAnimationsOf(context)` is true, there is none.
- Haptics are light and meaningful: a selection click on tab change, a light impact on a primary action. Never on scroll.

## F17 · Tests

- `test/` mirrors `lib/`: `test/features/orders/presentation/controllers/orders_controller_test.dart`.
- Unit tests for controllers (loading, success, each failure, stale answers dropped), repositories over fake data
  sources, models (good row, bad row), `appRedirect` (every gate), `systemOverlayFor` (each theme), helpers.
- Widget tests for each page: the four states of F12, at 320x640 with text scale 1.3, in light and dark.
- Fakes are hand-written classes that `implements` the real interface, in `test/fakes/` or beside the test. No mockito,
  no mocktail. A fake returns the same shapes the real backend returns (read a real answer first): a fake that invents
  shapes once hid a real bug for weeks.
- Every bug fix gets a regression test that fails without the fix.
- **The test budget.** A test earns its place only if it would catch a real bug that no other test catches. As a
  guide: a page, its four states and its main actions (about 6 to 10 widget tests); a controller, each state and each
  failure (about 5 to 10); a repository, a success and one test per failure type; a model, a good row and a bad row;
  `appRedirect`, one table test of every gate; a bug fix, one regression test. More than that needs a reason in the
  report.
- Many inputs are one table test (a list of cases in one loop), never one copy per input. The light, dark and
  320x640 runs of one page are one loop.
- Never test generated code, constants, plain getters, a hand-written `==` or `copyWith` that only restates the code,
  Flutter or a package itself, or the text of each locale (`check_l10n.dart` and one catalog test cover it).
- Before you add a test, search `test/` for one that covers the behaviour (`grep -rn '<class or key>' test/`) and
  extend it. Never add a test only to raise a count or a coverage number. A review asks for a test only by naming the
  bug it would catch.
- The tests stay smaller than the code they test. When `test/` holds more counted lines than `lib/` (a full
  `check_structure.dart` run warns, and `verify.sh` prints both counts), prune before you add: merge copies, drop
  duplicates and trivial tests, keep every test that guards behaviour.
- Contract tests keep files that must agree in agreement: the permissions and their reasons, the version in
  `pubspec.yaml` and the changelog, the native splash colours and the theme.
- Golden tests, when the project has them, run in their own folder and never block the gate on another machine's fonts.
- While working, run targeted checks only (F18). Run the whole suite once, in the gate.

## F18 · The quality gate and done

`scripts/tools/verify.sh` = `dart format --output=none --set-exit-if-changed lib test` → `flutter analyze` →
`dart run tool/kit/check_structure.dart` → `dart run tool/kit/check_l10n.dart` → `flutter test`.

A change is done when its targeted checks pass, with no rule disabled to get there, and every box below holds:

- the analyzer is clean (`scripts/tools/q-analyze.sh`); the changed files are formatted (`dart format <files>`);
- the tests of the touched files pass (`scripts/tools/q-test.sh <test files>`); a bug fix has its regression test;
- `check_structure.dart` passes for the changed files, and `check_l10n.dart` passes;
- files sit where F2 says, within the F1 limits;
- every new string is in every catalog; every new colour is a token in both themes;
- every new screen has its four states, its route, its test, and paints its edges (F9);
- no secret, token or personal data in the app, the logs or git;
- no unused dependency, no new dependency without the owner's yes.

A batch is done when the ONE gate passes (verify, then a build: `scripts/tools/q-build.sh apk --debug`, then the owner's
check on a real phone), run once, right before the push or the release, in a fresh session (the `gate` skill). Never run
the full suite or a build after each change: they take minutes and gigabytes of memory that other agents need.

## Anti-patterns: never again

- Colours as static constants read in widgets, then a "redraw everything" hack when the theme changes.
- `systemNavigationBarColor` relied on to colour the bottom edge (ignored from Android 15), or one `SafeArea` around the
  whole app.
- Material and Lucide icons mixed in one app; a raw `SvgPicture` in a page; an icon button with no label.
- Text typed inline in widgets, then a second language that takes a month.
- A 4,000-line page or controller that every agent must read whole.
- A repository that returns `null` on failure, a `catch (_) {}`, a branch on an error message.
- A data source called from a widget; a URL path in a controller; dio created in two places.
- Redirect logic spread over pages; a tab with no page behind it.
- Secrets in `assets/.env`; a committed keystore; a token in a debug log.
- Fakes that return shapes the real backend never sends.
- `flutter test` on the whole suite, or a build, after every small change.
