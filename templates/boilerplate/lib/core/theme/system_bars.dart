import 'package:flutter/services.dart';
import 'package:kit_app/core/theme/app_colors.dart';

const Color _transparent = Color(0x00000000);

/// The ONE style of the status bar and the navigation bar for a palette (F9).
///
/// It is set in three places, all from this function: SystemChrome at start and on every theme change (app.dart),
/// an AnnotatedRegion in MaterialApp.router(builder:), and AppBarTheme.systemOverlayStyle. The page paints its own
/// colour under both bars, so the edges match the page on every Android version.
SystemUiOverlayStyle systemOverlayFor(AppColors colors) {
  // Dark icons on a light page, light icons on a dark page, on both bars.
  final icons = colors.isDark ? Brightness.light : Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: _transparent,
    statusBarIconBrightness: icons,
    // iOS reads this one instead: the brightness of the content under the bar, the opposite of the icons.
    statusBarBrightness: colors.brightness,
    // Honoured only before Android 15. From Android 15 (target SDK 35+) the bar is always transparent, and the
    // page colour shows through because the app draws edge to edge.
    systemNavigationBarColor: colors.surface,
    systemNavigationBarDividerColor: _transparent,
    systemNavigationBarIconBrightness: icons,
    // Without this, Android 10+ lays a grey scrim over a transparent navigation bar.
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );
}
