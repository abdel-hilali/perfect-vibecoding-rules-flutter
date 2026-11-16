# Recipe: icons, the launcher icon, the splash, notifications

## Problem

Two icon families look like two apps. A raw `Icon(Icons.x)` in a page cannot change family later, an icon-only
button without a label is silent for screen readers, and a notification with the launcher icon is a white square.

## Rule

- One family per app. Every icon comes through `AppIcons` (one file of constants) and the `AppIcon` widget: size
  from `AppIconSize` (16, 20, 24), colour from tokens. Never `Icon(Icons.x)`, `Icon(AppIcons.x)` or `SvgPicture` in
  a page (`check_structure.dart` fails them), and never a family name such as `LucideIcons.x` outside `AppIcons` (F10).
- Without a designer set: Lucide (`lucide_icons_flutter`). With designer SVGs: `assets/icons/common/` and
  `assets/icons/nav/` (`x.svg`, `x_active.svg`), single colour, drawn with `BlendMode.srcIn`; only `AppIcons` and
  `AppIcon` change. Remove `cupertino_icons`.
- An icon-only button has a label (tooltip and screen readers) and a 48 dp tap target (F16).
- Launcher icon by flutter_launcher_icons (adaptive background, foreground inside the 66 dp safe zone, a monochrome
  layer); splash by flutter_native_splash in the page colours; notification icon a white vector kept by `keep.xml`.

## Code

```dart
// lib/core/theme/app_icons.dart
abstract final class AppIcons {
  static const IconData orders = LucideIcons.package;
  static const IconData ordersActive = LucideIcons500.package;
  // ...
  /// The Dir variants mirror in right-to-left languages, so "back" points the right way in Arabic.
  static const IconData back = LucideIcons.arrowLeftDir;
```

```dart
// lib/core/common/widgets/app_icon_button.dart
    return IconButton(
      onPressed: onPressed,
      tooltip: label,
      constraints: const BoxConstraints(
        minWidth: AppSpacing.tapTarget,
        minHeight: AppSpacing.tapTarget,
      ),
      icon: AppIcon(
        icon,
        size: AppIconSize.lg,
        color: color ?? context.colors.onSurface,
      ),
    );
```

A page names the constant, never the family: `AppIconButton(icon: AppIcons.back, label: context.l10n.commonBack,
onPressed: ...)`. A badge is the one place the text scale is clamped:

```dart
// lib/core/common/widgets/app_bottom_bar.dart
      // The only place the text scale is clamped (F16): a badge must stay inside its pill.
      label: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: Text(tab.badgeCount.toString()),
      ),
```

The notification icon is `android/app/src/main/res/drawable/ic_stat_notify.xml`, a 24 dp white vector
(`android:fillColor="#FFFFFFFF"`): replace its path with the app's mark, keep it white.
`res/raw/keep.xml` (`tools:keep="@drawable/ic_stat_*"`) keeps it in release builds.

```yaml
# flutter_launcher_icons.yaml (not in the starter: add it with the real art)
flutter_launcher_icons:
  android: true
  ios: true
  image_path: assets/icons/src/app_icon.png
  # Android 8+: the art stays inside the 66 dp safe zone of the 108 dp foreground; launchers crop the rest.
  adaptive_icon_background: "#2F5BD3"
  adaptive_icon_foreground: assets/icons/src/app_icon_foreground.png
  # Android 13+ themed icons: one colour on transparent; the system tints it.
  adaptive_icon_monochrome: assets/icons/src/app_icon_monochrome.png
  # The App Store refuses an icon with an alpha channel.
  remove_alpha_ios: true
```

```yaml
# flutter_native_splash.yaml (not in the starter: add it with the real art)
flutter_native_splash:
  color: "#F7F7F5"
  color_dark: "#121416"
  image: assets/icons/src/splash_logo.png
  # Android 12+ draws its own splash: the icon in a circle, on these colours.
  android_12:
    image: assets/icons/src/splash_logo_android12.png
    icon_background_color: "#F7F7F5"
    icon_background_color_dark: "#121416"
    color: "#F7F7F5"
    color_dark: "#121416"
```

Both are dev dependencies, run after the art changes: `dart run flutter_launcher_icons` and
`dart run flutter_native_splash:create`. The splash colours are `AppColors.light.surface` and `.dark.surface`.

## Traps

- `dart run flutter_native_splash:create` rewrites the `LaunchTheme` of every `styles.xml`: it sets
  `windowDrawsSystemBarBackgrounds` to its `fullscreen` value (false by default). Diff the four files after each
  run and put the edge-to-edge items back (system-bars.md).
- Android draws a notification icon from its alpha channel only: a coloured or photo icon is a white square. A
  release build also drops an `ic_stat_*` named only from Dart, unless `keep.xml` keeps it.
- Art outside the 66 dp safe zone is cut by round launchers. Without the monochrome layer, the icon stays in full
  colour among themed icons (Android 13+).
- An SVG with several colours turns into one block under `BlendMode.srcIn`: icons are single colour by design.
- A decorative icon has no `semanticLabel`; an icon that carries meaning alone (a status) has one, from the catalog.
- Precache designer SVGs on the splash: an SVG loads after the first frame, so the bottom bar's icons pop in late.
