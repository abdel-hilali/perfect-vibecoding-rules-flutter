# The Flutter starter

Working starter code for a fresh `flutter create` app. It follows every rule in `docs/RULES.md` (F1 to F18), and it
runs with no backend: a fake session is signed in, and the orders tab reads a fake data source that answers with the
same JSON shapes a real backend sends. The package name inside is `kit_app`.

Proven on Flutter 3.50.0 (Dart 3.14.0) in a scratch app: `flutter analyze` 0 issues with the kit's
`analysis_options.yaml`, 129 tests passed out of 129, `check_structure.dart` and `check_l10n.dart --strict` clean,
`dart format --output=none --set-exit-if-changed lib test` clean.

## What is where

| Path | What it is |
| --- | --- |
| `pubspec.fragment.yaml` | The dependencies and `flutter:` entries to merge into the new pubspec.yaml. |
| `l10n.yaml` | gen-l10n settings: ARB files in `lib/core/l10n/`, output in `lib/core/l10n/generated/`. |
| `assets/.env.example` | Every env key with a placeholder. Copy it to `assets/.env` (git-ignored). |
| `android/app/src/main/res/` | Edge-to-edge launch and normal themes for light, dark, Android 12+; the splash colour; `raw/keep.xml`; a white notification icon. |
| `android/gradle.properties` | A lean Gradle: 3 GB heap, a 1 GB Kotlin daemon, a 15-minute idle timeout. |
| `lib/main.dart`, `lib/app.dart` | Bootstrap only, then the App widget: themes, locale, catalogs, system bars. |
| `lib/core/theme/` | `AppColors` (light and dark), text styles, spacing, radius, motion, icons, `AppTheme`, `systemOverlayFor`. |
| `lib/core/common/widgets/` | The widget kit: provider, top bar, bottom bar, buttons, text field, the four states, sheet, toast, dialog, image, back handler. |
| `lib/core/common/data/` | Pure helpers: typed JSON readers, `Paged<T>`, money format, random ids. |
| `lib/core/config/` | The typed `Env`, and one injection module per feature in `injection-modules/`. |
| `lib/core/errors/`, `lib/core/usecases/` | The sealed `Failure` family, `ApiException`, the sealed `Result<T>`. |
| `lib/core/network/` | The one `ApiClient` over dio and its four interceptors, the idempotency key, the token refresher. |
| `lib/core/router/` | The one `GoRouter`, the pure `appRedirect`, the tab shell `MainShell`. |
| `lib/core/storage/` | `SecureStore` (never throws), `AppPreferences`, the `Session`. |
| `lib/core/l10n/` | `app_en.arb` (the shape source), `app_fr.arb`, `app_ar.arb`, `context.l10n`, failure texts. |
| `lib/features/orders/` | The example feature, end to end: fake and HTTP data sources, model, repository, use case, controller, page. |
| `lib/features/settings/` | The second tab: theme (system, light, dark) and language, saved on the device. |
| `lib/features/auth/` | The sign-in gate's page, a "coming soon" body until the backend serves sign-in. |
| `test/` | Mirrors `lib/`. Hand-written fakes in `test/fakes/`, the page pump in `test/helpers/`. |

## How the new-project skill copies it

1. `flutter create --org <org> --project-name <name> --platforms android,ios <dir>`, then work in `<dir>`.
2. Delete `lib/main.dart` and `test/widget_test.dart`: they name the template's counter app.
3. Copy `lib/`, `test/`, `l10n.yaml` and `assets/` from here into the app.
4. Rename the package in every copied file: `package:kit_app/` becomes `package:<name>/`, in `lib/` and `test/`.
5. Merge the pubspec: keep the new pubspec.yaml down to the line before `dependencies:`, then paste
   `pubspec.fragment.yaml` under it. Remove `cupertino_icons`.
6. Copy `android/app/src/main/res/` over the new one (it adds files and replaces both `styles.xml`). Merge
   `android/gradle.properties`: replace the `org.gradle.jvmargs` line, add the two lines below it, and keep any other
   line the new template wrote.
7. Copy the kit's `templates/analysis_options.yaml` over the new one.
8. `cp assets/.env.example assets/.env`, fill it in, and add `assets/.env` to `.gitignore`. The build fails while
   `assets/.env` is missing: pubspec.yaml declares it.
9. On iOS, list the supported languages in `ios/Runner/Info.plist` (`CFBundleLocalizations`: en, fr, ar). iOS
   offers the app only the languages declared there, so without them a French phone can still open the app in English.
10. `flutter pub get --offline` (plain `flutter pub get` when a package is missing; it also runs gen-l10n), then
    `dart fix --apply --code=directives_ordering` (the new package name sorts in another place among the imports
    than `kit_app` did, and the analyzer fails on the order), `dart format lib test`, the analyzer,
    `check_structure.dart`, `check_l10n.dart` and the tests, through the queue.

## What to rename or replace

- The app's name: `appTitle` in every ARB file; `android:label` in the manifest; `CFBundleDisplayName` on iOS.
- The colours: `AppColors.light` and `AppColors.dark`, and `app_surface` in `res/values/colors.xml` and
  `res/values-night/colors.xml` (the same page colour, or the start flashes). The contrast test says when a pair
  falls under 4.5:1.
- The font: put the files in `assets/fonts/`, uncomment the `fonts:` block of the fragment, set
  `AppTextStyles.fontFamily`.
- The icons: Lucide through `AppIcons`. A designer's SVG set replaces `lucide_icons_flutter` with `flutter_svg`,
  `AppIcons` with asset paths, and the body of `AppIcon`; no page changes.
- The backend: `API_BASE_URL` in `assets/.env`; in `OrdersModule`, the one commented line swaps the fake data source
  for `HttpOrdersRemoteDataSource`.
- Sign-in: set `SessionModule.useFakeAccount` to false when the auth feature lands, and build it in
  `lib/features/auth/`.
- A new feature: copy the shape of `features/orders/` (same folders, same suffixes), add its module in
  `core/config/injection-modules/` and its routes to `app_router.dart`.

## Flutter 3.50 facts this code depends on

- Material lives in the `material_ui` package (Flutter 3.47 deprecated `package:flutter/material.dart`): every file
  imports `package:material_ui/material_ui.dart`. go_router 18 depends on it too.
- gen-l10n still writes `AppLocalizations.localizationsDelegates` with the deprecated `flutter_localizations`
  delegates. `app.dart` passes `AppLocalizations.delegate` plus material_ui's `GlobalMaterialLocalizations.delegates`;
  the `header:` in `l10n.yaml` keeps the unused list from failing the analyzer when the generated folder is analyzed.
- `flutter analyze` adds `android/**` and `ios/**` to the analyzer excludes of `analysis_options.yaml` when they are
  missing, and rewrites the file to do it.
- gen-l10n does not format its output unless `format: true` (set in `l10n.yaml`): without it, the gate's
  `dart format --set-exit-if-changed` fails after every regenerate.
