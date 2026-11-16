# Recipe: theme tokens, light and dark

## Problem

A colour typed in a widget does not change with the theme: the app then needs a "redraw everything" hack, and the
dark theme shows white panels. Text sizes, spacing and durations drift when every widget types its own numbers.

## Rule

- Colours live only in `lib/core/theme/app_colors.dart`: `AppColors extends ThemeExtension<AppColors>`, role names
  (`surface`, `onSurface`, `primary`, `danger`...), two consts `light` and `dark`, every parameter `required` (F8).
- Widgets read `context.colors.<token>` and `context.text.<style>`. Reading them subscribes the widget to the theme,
  so a theme change rebuilds it by itself.
- No `Color(0x...)`, `Colors.<name>` or `Color.fromARGB` outside `lib/core/theme/`, except `Colors.transparent`:
  `check_structure.dart` fails them. No token fits? Add one to `AppColors`, in both consts.
- Spacing, radius, durations and curves come from `AppSpacing`, `AppRadius` and `AppMotion`. One bundled font
  family, every weight declared in `pubspec.yaml`; never `google_fonts` at run time.
- `ThemeMode.system` by default; the user's choice (system, light, dark) is saved on the device.
- A test checks every text pair at 4.5:1, in both themes (F8, F16).

## Code

```dart
// lib/core/theme/app_colors.dart
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.surface,
    required this.surfaceRaised,
    required this.onSurface,
    // ...
  });
  // ...
  static const light = AppColors(
    brightness: Brightness.light,
    surface: Color(0xFFF7F7F5),
    surfaceRaised: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1A1C1E),
    // ...
  );
  // ...
}

extension AppColorsContext on BuildContext {
  /// The palette of the theme in force here. Reading it subscribes this widget to theme changes.
  AppColors get colors {
    final colors = Theme.of(this).extension<AppColors>();
    // ...
  }
}
```

```dart
// lib/core/theme/app_theme.dart
  static ThemeData _build(AppColors c) {
    final text = AppTextStyles(c);
    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: _scheme(c),
      scaffoldBackgroundColor: c.surface,
      canvasColor: c.surface,
      fontFamily: AppTextStyles.fontFamily,
      textTheme: text.toTextTheme(),
      // Widgets read the tokens through context.colors; this is where they come from.
      extensions: <ThemeExtension<dynamic>>[c],
      // ...
```

```dart
// lib/app.dart
  // Built once: a new ThemeData on every rebuild would make MaterialApp compare and animate for nothing.
  final ThemeData _light = AppTheme.light();
  final ThemeData _dark = AppTheme.dark();
  // ...
          theme: _light,
          darkTheme: _dark,
          themeMode: widget.settings.themeMode,
```

A widget reads tokens, never values:

```dart
// lib/features/orders/presentation/widgets/order_tile.dart
    final colors = context.colors;
    final text = context.text;
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: AppRadius.card,
        border: Border.all(color: colors.outline, width: 0.5),
      ),
```

```dart
// lib/core/theme/app_motion.dart
  /// [duration], or zero when the user turned animations off in the system settings.
  static Duration of(BuildContext context, Duration duration) {
    return MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
  }
```

```dart
// test/core/theme/app_colors_test.dart
/// The WCAG contrast ratio of two opaque colours, from 1 to 21.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
```

## Traps

- A `ThemeData` built inside `build()` gives `MaterialApp` a new theme on every settings change: build `light` and
  `dark` once, in the App's `State`.
- A new token goes into the constructor, both consts, `copyWith` and `lerp`. The `required` parameters make the
  compiler name each place you missed.
- Material's own widgets (buttons, switches, the date picker, the text selection handles) read `ColorScheme`, not
  `AppColors`: `AppTheme._scheme` maps the tokens into it. A Material widget that looks wrong in dark mode reads a
  slot that is not mapped yet.
- `AppColors.light.surface` must equal `app_surface` in `android/app/src/main/res/values/colors.xml` (and the dark
  one in `values-night/`): the window shows that colour before the first frame, so a difference flashes at start.
- `context.colors` throws "AppColors is missing" in a test that pumps a bare `MaterialApp`: pump pages with
  `pumpPage` (tests.md).
- `const TextStyle(color: ...)` is a static colour. Write `context.text.body.copyWith(...)` inside `build`.
- `Color.withOpacity` is deprecated: write `withValues(alpha: 0.55)`, and only inside `lib/core/theme/`.
