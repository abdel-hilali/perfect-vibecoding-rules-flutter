# Recipe: Flutter traps that cost real time

## Problem

Some bugs look impossible: a colour the code sets is ignored, a test hangs forever, the computer freezes during a
build. Each one below cost hours once. Reading two lines costs seconds.

## Rule

- When something "cannot happen", scan this list before you debug. Each entry: the symptom, then the cause and fix.
- Found a new one? Add it here in two lines, and add a test that would have caught it.

## Code

```dart
// lib/features/orders/presentation/pages/orders_page.dart
    return Scaffold(
      body: Column(
        children: [
          AppTopBar(title: l10n.ordersTitle),
          Expanded(child: body),
        ],
      ),
    );
```

```properties
# android/gradle.properties
# Gradle's own heap. The flutter create template asks for 8 GB, which can freeze a 16 GB machine when an emulator,
# an editor and a browser also run; 3 GB builds a normal app. Metaspace is capped for the same reason.
org.gradle.jvmargs=-Xmx3g -XX:MaxMetaspaceSize=1g -XX:ReservedCodeCacheSize=256m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
# The Kotlin compiler runs in a second JVM with its own heap; without a cap it takes up to a quarter of the RAM.
kotlin.daemon.jvmargs=-Xmx1g
```

## Traps

- **The navigation bar ignores its colour on Android 15+.** Target SDK 35+ forces edge to edge: paint the page
  under the bar (system-bars.md).
- **"Looking up a deactivated widget's ancestor is unsafe".** A context used after an `await` whose page closed:
  check `mounted` (or `context.mounted`) first.
- **"A ChangeNotifier was used after being disposed".** An answer arrived after the screen closed: guard every
  notify with `_disposed` (state.md).
- **"Vertical viewport was given unbounded height".** A `ListView` straight in a `Column`: wrap it in `Expanded`,
  as above.
- **"Bottom overflowed" when the keyboard opens.** Fields in a `Column` with no scroll view: a `ListView` in
  `Expanded`, and let the `Scaffold` resize (forms.md).
- **The computer freezes during a build.** The template's 8 GB Gradle heap plus an emulator: the lean
  `gradle.properties` above, one build at a time.
- **"The getter isn't defined for AppLocalizations" right after an ARB edit.** The generated file is stale: run
  `flutter gen-l10n`.
- **A change does not show after hot reload.** Hot reload keeps the state and does not run `main()`, `initState` or
  static initializers again: hot restart (`assets/.env` too, read in `main()`). A change to `pubspec.yaml` or a
  native file needs a new `flutter run`.
- **`MissingPluginException` in a test.** Plugins have no platform in tests: fake the wrapper, or install the
  in-memory platform (shared_preferences: storage-env.md).
- **`pumpAndSettle` timed out.** A spinner never settles: `pump()` (tests.md).
- **An analyzer info on every import of `package:flutter/material.dart`.** Deprecated since Flutter 3.47: import
  `package:material_ui/material_ui.dart`.
- **`flutter analyze` rewrites `analysis_options.yaml`.** Flutter 3.50 adds the `android/**` and `ios/**` excludes
  when they are missing: keep them in the file.
- **`dart format --set-exit-if-changed` fails after a regenerate.** gen-l10n formats only with `format: true` in
  `l10n.yaml`.
- **The build fails on a fresh checkout.** `pubspec.yaml` declares `assets/.env`: copy it from `.env.example`.
- **A French iPhone opens the app in English.** iOS offers only the languages in `CFBundleLocalizations`.
- **Every 401 signs out after one failed refresh**, **"The FormData has already been finalized"**, **a `TypeError`
  from inside dio**: network.md.
- **A sheet opened from a tab sits on top of the bottom bar**: feedback.md.
- **The splash lost its edge-to-edge look** after `flutter_native_splash:create`: icons.md.
- **Uploaded photos carry the GPS position**: media.md.
- **`flutter pub get --offline` picks another version** than the one typed: it takes the newest cached version in
  the caret range. Read `pubspec.lock`.
- **An `// ignore:` with a reason still fails.** The reason must follow a non-word character
  (`// ignore: rule_name - reason`); a reason that starts with a word is read as another rule name.
