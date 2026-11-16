# Recipe: system bars, edge to edge

## Problem

From Android 15 (target SDK 35 and up) every app draws edge to edge, and the navigation bar colour an app sets is
ignored: the only way to colour the bottom edge is to paint under it. One `SafeArea` around the app, or a bar style
set once at start, leaves a black or white strip, or icons nobody can read after a theme switch.

## Rule

- Edge to edge at start: `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)` (F9).
- ONE `systemOverlayFor(AppColors)` builds the style. It is set in three places: `SystemChrome` at start and on
  every theme change, an `AnnotatedRegion` in `MaterialApp.router(builder:)`, and `AppBarTheme.systemOverlayStyle`.
- Never one `SafeArea` around the app. Every page paints its background edge to edge; the top bar pads itself by
  the top inset; a bottom bar is `DecoratedBox(color) > SafeArea(top: false)`; lists pad their end by
  `N + MediaQuery.paddingOf(context).bottom`.
- A surface of another colour that reaches the bottom edge (a sheet) wraps its own `AnnotatedRegion`. Sheets open
  through `showAppSheet` only.
- Native side: `LaunchTheme` and `NormalTheme` in `values`, `values-night`, `values-v31`, `values-night-v31`; the
  window background is the first frame's colour; no edge-to-edge opt-out. A unit test checks each theme's style.

## Code

```dart
// lib/core/theme/system_bars.dart
SystemUiOverlayStyle systemOverlayFor(AppColors colors) {
  // Dark icons on a light page, light icons on a dark page, on both bars.
  final icons = colors.isDark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: _transparent,
    statusBarIconBrightness: icons,
    // iOS reads this one instead: the brightness of the content under the bar, the opposite of the icons.
    statusBarBrightness: colors.brightness,
    // ...
    systemNavigationBarColor: colors.surface,
    systemNavigationBarDividerColor: _transparent,
    systemNavigationBarIconBrightness: icons,
    // Without this, Android 10+ lays a grey scrim over a transparent navigation bar.
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );
}
```

```dart
// lib/app.dart
    SystemChrome.setSystemUIOverlayStyle(
      systemOverlayFor(dark ? AppColors.dark : AppColors.light),
    );
  // ...
          // Never one SafeArea here (F9): every page paints its own colour edge to edge.
          builder: (context, child) {
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: systemOverlayFor(context.colors),
              child: child ?? const SizedBox.shrink(),
            );
          },
```

The top bar and the bottom bar paint their own edge; a list pads its end by
`AppSpacing.lg + MediaQuery.paddingOf(context).bottom` (`orders_list.dart`):

```dart
// lib/core/common/widgets/app_top_bar.dart
    return ColoredBox(
      color: context.colors.surface,
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          top: MediaQuery.paddingOf(context).top,
        ),
```

```dart
// lib/core/common/widgets/app_bottom_bar.dart
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
```

```dart
// lib/core/common/widgets/show_app_sheet.dart
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: systemOverlayFor(colors)
          .copyWith(systemNavigationBarColor: colors.surfaceRaised),
      child: Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SafeArea(top: false, child: builder(context)),
      ),
    );
```

```xml
<!-- android/app/src/main/res/values-v31/styles.xml -->
    <style name="LaunchTheme" parent="@android:style/Theme.Light.NoTitleBar">
        <item name="android:windowBackground">@color/app_surface</item>
        <item name="android:windowDrawsSystemBarBackgrounds">true</item>
        <item name="android:statusBarColor">@android:color/transparent</item>
```

## Traps

- Look at both worlds: Android 15+ (the bar is transparent, the page's paint shows) and an older Android (the bar
  colour still applies).
- Scaffold sets the body's bottom inset to 0 under a `bottomNavigationBar`: in the tab shell the list pads by 0, on
  a pushed page by the gesture bar. The same list code is right in both places.
- `MediaQuery.of(context).padding` rebuilds the widget on every MediaQuery change, the keyboard included. Use
  `paddingOf` and `viewInsetsOf`: each listens to one value.
- `windowOptOutEdgeToEdgeEnforcement` stops working at target SDK 36. Never use it to "fix" a colour.
- An always-dark screen (camera, photo viewer, call) sets its own `AnnotatedRegion` with
  `systemOverlayFor(AppColors.dark)`, and says why in a comment.
- A sheet built by hand keeps the page's navigation bar colour under its raised surface, and a fixed background
  colour misses a live theme switch. Use `showAppSheet`.
